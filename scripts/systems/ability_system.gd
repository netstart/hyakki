class_name AbilitySystem
extends RefCounted
## Habilidades dos guardiões (.ai/04-habilidades-dos-guardioes.md): 3 por herói, liberadas na
## partida pelo nível (1, 5 e 10), com custo numa energia própria (HeroEnergy) e recarga.
## Este sistema cuida de tudo que é comum: desbloqueio, custo (e o pagamento com vida da Yuki),
## recarga (× atributo "cooldown"), poder pelo nível, entrada, bot, save da partida suspensa,
## rastreio (RunTracker.abilities), voz, som, letreiro e os eventos da UI. O efeito de cada
## habilidade fica no comportamento do herói (HeroAbilities, BEHAVIOR_PATH).
## Tudo no passo fixo (step) e sem sorteio fora do game.rng: a mesma semente dá a mesma partida
## em 1x/2x/3x, e o hash de determinismo inclui energia, recargas e efeitos (hash_tag).
##
## Eventos (Events): ability_used(hero, slot, id, kanji), ability_failed(slot, Fail),
## ability_ready(slot) e ability_unlocked(slot, id).

## Motivo de uma habilidade não sair (check/activate, last_failure, Events.ability_failed).
enum Fail { NONE, LOCKED, COOLDOWN, NO_ENERGY, DEAD, PAUSED, MISSING, NO_TARGET }

const SLOTS := 3
const ACTIONS: Array[StringName] = [&"ability_1", &"ability_2", &"ability_3"]
const POWER_PER_LEVEL := 0.035
## O herói está "na luz" com a lanterna acesa de verdade: o mesmo limiar da "Escuridão" do
## RunTracker (raio < 60 = no escuro: Kuroe apagou, chefe comeu a luz com Kami de escuridão...).
const LIGHT_MIN_RADIUS := 60.0
## Voz: no máximo uma a cada VOICE_GAP_MS (tempo real, só áudio), e o volume dela.
const VOICE_GAP_MS := 2500
const VOICE_DB := -2.0
const VOICE_DIR := "res://assets/audio/voice/"
## Música abaixada ao soltar (dB, s).
const DUCK_DB := 3.0
const DUCK_TIME := 0.8
## Letreiro acima do herói (s de jogo).
const BANNER_TIME := 1.2
## Anel do clarão de lançamento: raio (px, + um degrau por slot) e duração (s).
const LAUNCH_RING := 26.0
const LAUNCH_RING_STEP := 8.0
const LAUNCH_RING_LIFE := 0.3
## Comportamento por herói: BEHAVIOR_PATH com o id (AkiAbilities, KentaAbilities...). Herói sem
## arquivo usa o HeroAbilities base, que só registra o uso.
const BEHAVIOR_PATH := "res://scripts/systems/abilities/%s_abilities.gd"
## Danos que não contam como "acerto das armas" para a energia (per_hit).
const NOT_WEAPON_HITS: Array[StringName] = [&"ultimate"]

var game: HyakkiGame
var hero_id: StringName = &""
var energy: HeroEnergy = HeroEnergy.new()
var behavior: HeroAbilities
## As 3 linhas de data/abilities.json do herói, na ordem dos slots.
var abilities: Array[Dictionary] = []
## Recarga restante por slot (s).
var cooldowns := PackedFloat32Array([0.0, 0.0, 0.0])
var uses: int = 0
var uses_by_slot := PackedInt32Array([0, 0, 0])
var last_failure: int = Fail.NONE
## Vida paga na última ativação (Yuki: falta de energia paga com vida; 0 = só energia).
var last_hp_price: float = 0.0
## Letreiro (só desenho): {"id", "kanji", "at" (tempo de jogo)} ou vazio.
var banner: Dictionary = {}
## Desenho dos efeitos e do letreiro (filho do HyakkiGame).
var layer: AbilityLayer

var _ids: Dictionary = {}
var _unlocked := PackedByteArray([0, 0, 0])
var _voice_ms: int = -100000


func _init(p_game: HyakkiGame) -> void:
	game = p_game
	layer = AbilityLayer.new()
	layer.system = self
	game.add_child(layer)


## Começo da partida (depois do Player.setup): herói, energia, comportamento e recargas.
func reset() -> void:
	hero_id = StringName(String(game.player.hero.get("id", "aki")))
	var data := DB.hero_abilities(hero_id)
	energy = HeroEnergy.new(data.get("energy", {}))
	abilities.clear()
	_ids.clear()
	for row: Variant in data.get("abilities", []):
		var ability: Dictionary = row
		abilities.append(ability)
		var id := StringName(ability["id"])
		_ids[id] = true
		# Golpes com a cor e o som da habilidade ("hit" no formato de weapons.json).
		var look: Dictionary = ability.get("hit", {"fx": {"color": "#" + String(data["energy"]["color"])}})
		game.fx.register_style(id, look)
		game.hit_sounds.register(id, look)
	cooldowns.fill(0.0)
	uses = 0
	uses_by_slot.fill(0)
	last_failure = Fail.NONE
	banner = {}
	var path := BEHAVIOR_PATH % hero_id
	var script: GDScript = load(path) as GDScript if ResourceLoader.exists(path) else HeroAbilities
	behavior = script.new(self, hero_id) as HeroAbilities
	behavior.reset()
	# A partida começa no nível 1 (o HyakkiGame zera o nível depois deste reset).
	for slot: int in range(SLOTS):
		_unlocked[slot] = 1 if slot < abilities.size() and required_level(slot) <= 1 else 0


## Solta o comportamento (que aponta de volta para este sistema). Chamado pela AbilityLayer
## quando a partida é liberada.
func release() -> void:
	behavior = null
	layer = null


# --- Passo e eventos da simulação -----------------------------------------------------------

func step(dt: float) -> void:
	if behavior == null:
		return
	var player := game.player
	_update_unlocks(true)
	for slot: int in range(SLOTS):
		if cooldowns[slot] > 0.0:
			cooldowns[slot] = maxf(0.0, cooldowns[slot] - dt)
			if cooldowns[slot] <= 0.0 and _unlocked[slot] == 1:
				if not game.is_bot():
					HeroAbilities.play_sfx("ab_ready")
				Events.ability_ready.emit(slot)
	if player.is_alive:
		var moving := player.move_input.length_squared() > 0.01 or player.is_dashing()
		energy.step(dt, moving, hero_in_light(), player.stats)
	behavior.step(dt)
	if game.is_bot():
		_bot()


## Dano recebido (Player.take_damage, já com armadura e tetos).
func on_damage_taken(amount: float) -> void:
	energy.on_damage_taken(amount)


## Acerto de uma arma (HyakkiGame.deal_damage); danos das habilidades e do Golpe não contam.
func on_hit(source: StringName) -> void:
	if not _ids.has(source) and not NOT_WEAPON_HITS.has(source):
		energy.on_hit()


## Abate (HyakkiGame._on_enemy_killed, inclusive chefes).
func on_kill() -> void:
	energy.on_kill()


func hero_in_light() -> bool:
	return game.lantern.radius >= LIGHT_MIN_RADIUS


## Poder das habilidades no nível atual: 1 + 0,035 × (nível − 1).
func power() -> float:
	return 1.0 + POWER_PER_LEVEL * (game.level - 1)


# --- Ativação -------------------------------------------------------------------------------

## Teclas/controle (HyakkiGame._handle_actions): só correndo e sem pausa.
func handle_input() -> void:
	if not game.running or GameClock.paused:
		return
	for slot: int in range(mini(SLOTS, abilities.size())):
		if Input.is_action_just_pressed(ACTIONS[slot]):
			activate(slot)


## Por que a habilidade do slot não sairia agora (Fail.NONE = sai).
func check(slot: int) -> int:
	if slot < 0 or slot >= abilities.size() or behavior == null:
		return Fail.MISSING
	if not game.running or GameClock.paused:
		return Fail.PAUSED
	if not game.player.is_alive or game.death.is_active():
		return Fail.DEAD
	if not is_unlocked(slot):
		return Fail.LOCKED
	if cooldowns[slot] > 0.0:
		return Fail.COOLDOWN
	if not can_pay(slot):
		return Fail.NO_ENERGY
	return Fail.NONE


## Solta a habilidade do slot (0..2). Falha sem gastar nada e diz o motivo em `last_failure`
## (e em Events.ability_failed; sem energia, toca a recusa).
func activate(slot: int) -> bool:
	var reason := check(slot)
	if reason != Fail.NONE:
		return _fail(slot, reason)
	var ability := abilities[slot]
	var player := game.player
	var before := energy.state()
	var hp_before := player.hp
	var price := energy.pay(cost(slot), player.hp, player.max_hp())
	last_hp_price = maxf(price, 0.0)
	if price > 0.0:
		player.hp -= price
		game.fx.add_number(player.sim_pos + Vector2(0.0, player.sprite_top()), price,
				DamagePalette.classify_taken(price, player.max_hp()), player.max_hp())
	if not behavior.cast(slot, ability, power()):
		energy.load_state(before)
		player.hp = hp_before
		return _fail(slot, Fail.NO_TARGET)
	last_failure = Fail.NONE
	cooldowns[slot] = cooldown_total(slot)
	uses += 1
	uses_by_slot[slot] += 1
	game.tracker.on_ability(StringName(ability["id"]))
	_announce(slot, ability)
	return true


func _fail(slot: int, reason: int) -> bool:
	last_failure = reason
	Events.ability_failed.emit(slot, reason)
	# Recusa curta só sem energia (o cue ab_denied; sem ele, o "cancelar" da interface).
	if reason == Fail.NO_ENERGY and not game.is_bot() and not HeroAbilities.play_sfx("ab_denied"):
		AudioManager.play_ui("ui_cancel")
	return false


## Retorno ao soltar: letreiro, voz (se o arquivo existir, no máximo uma a cada VOICE_GAP_MS),
## som de lançamento (se o cue existir), música abaixada e o evento da UI.
func _announce(slot: int, ability: Dictionary) -> void:
	var id := StringName(ability["id"])
	var kanji := String(ability.get("kanji", ""))
	banner = {"id": id, "kanji": kanji, "at": GameClock.game_time}
	_launch_fx(slot)
	HeroAbilities.play_sfx(String(ability.get("sfx", "ab_%s" % id)))
	_voice(String(ability.get("voice", "")))
	AudioManager.duck(DUCK_DB, DUCK_TIME)
	Events.ability_used.emit(hero_id, slot, id, kanji)


## Clarão de lançamento comum às 21 habilidades (só desenho, fora do hash): luz na cor da
## energia no herói, anel com borda escura por baixo (lê sobre a horda) que cresce mais nas
## habilidades mais altas, e faíscas em volta. O efeito próprio de cada uma vem por cima.
func _launch_fx(slot: int) -> void:
	var fx := game.fx
	if fx == null:
		return
	var at := game.player.sim_pos + Vector2(0.0, -6.0)
	var color := energy.color
	var bright := color.lerp(Color.WHITE, 0.35)
	var reach := LAUNCH_RING + LAUNCH_RING_STEP * slot
	fx.flash(at, 18.0 + 6.0 * slot, Color(bright, 0.9), 0.16)
	fx.add_ring(at, reach, Color(0.05, 0.02, 0.03, 0.7), LAUNCH_RING_LIFE, 4.0)
	fx.add_ring(at, reach, Color(bright, 1.0), LAUNCH_RING_LIFE, 2.0)
	fx.sparks(at, Vector2.ZERO, bright, [3, 6, 10][FxLayer.wfx], 130.0 + 20.0 * slot, PI, 0.22)


func _voice(voice: String) -> void:
	if voice.is_empty() or game.is_bot():
		return
	var now := UiClock.msec()
	if now - _voice_ms < VOICE_GAP_MS:
		return
	var options: Array[String] = []
	for suffix: String in ["", "_b"]:
		var path := VOICE_DIR + voice + suffix + ".ogg"
		if ResourceLoader.exists(path):
			options.append(path)
	if options.is_empty():
		return
	_voice_ms = now
	# Sorteio só de áudio (fora da simulação).
	AudioManager.play(options.pick_random(), 1.0, 0.03, VOICE_DB)


## Regras fixas do bot (BotPilot.ability_slot): no máximo uma habilidade por passo.
func _bot() -> void:
	var slot := BotPilot.ability_slot(game)
	if slot >= 0:
		activate(slot)


func _update_unlocks(emit: bool) -> void:
	for slot: int in range(abilities.size()):
		if _unlocked[slot] == 0 and game.level >= required_level(slot):
			_unlocked[slot] = 1
			if emit:
				Events.ability_unlocked.emit(slot, StringName(abilities[slot]["id"]))


# --- Leitura para a UI ----------------------------------------------------------------------

func slot_count() -> int:
	return abilities.size()


func ability(slot: int) -> Dictionary:
	return abilities[slot] if slot >= 0 and slot < abilities.size() else {}


func ability_id(slot: int) -> StringName:
	return StringName(ability(slot).get("id", ""))


func energy_id() -> StringName:
	return energy.id


func energy_value() -> float:
	return energy.value


func energy_max() -> float:
	return energy.max_value


func energy_fraction() -> float:
	return energy.fraction()


func energy_color() -> Color:
	return energy.color


func energy_icon() -> String:
	return String(energy.rules.get("icon", ""))


func required_level(slot: int) -> int:
	return int(ability(slot).get("level", 1))


func is_unlocked(slot: int) -> bool:
	return slot >= 0 and slot < abilities.size() and game.level >= required_level(slot)


func cost(slot: int) -> float:
	return float(ability(slot).get("cost", 0.0))


## Recarga cheia do slot agora: a base × o atributo "cooldown" (o mesmo das armas).
func cooldown_total(slot: int) -> float:
	return float(ability(slot).get("cooldown", 0.0)) * game.player.stats.get_stat("cooldown")


func cooldown_left(slot: int) -> float:
	return cooldowns[slot] if slot >= 0 and slot < SLOTS else 0.0


## 1 logo depois de usar, 0 pronta.
func cooldown_fraction(slot: int) -> float:
	var total := cooldown_total(slot)
	return clampf(cooldown_left(slot) / total, 0.0, 1.0) if total > 0.0 else 0.0


## Liberada e sem recarga (pode faltar energia).
func is_ready(slot: int) -> bool:
	return is_unlocked(slot) and cooldown_left(slot) <= 0.0


## Tem energia (ou, na Yuki, vida acima do piso para pagar a diferença).
func can_pay(slot: int) -> bool:
	var player := game.player
	return energy.can_afford(cost(slot), player.hp, player.max_hp())


## Vida que sairia agora para pagar o slot (0 se a energia basta; INF se não pode).
func hp_price(slot: int) -> float:
	var player := game.player
	return energy.hp_cost(cost(slot), player.hp, player.max_hp())


# --- Save da partida suspensa e determinismo ------------------------------------------------

func state() -> Dictionary:
	return {"hero": String(hero_id), "energy": energy.state(), "cooldowns": Array(cooldowns),
			"uses": uses, "uses_by_slot": Array(uses_by_slot), "behavior": behavior.state() if behavior else {}}


## Depois do restore do nível (HyakkiGame.restore_snapshot): desbloqueios sem evento.
func load_state(s: Dictionary) -> void:
	if s.is_empty() or StringName(String(s.get("hero", ""))) != hero_id:
		_update_unlocks(false)
		return
	energy.load_state(s.get("energy", {}))
	var saved: Array = s.get("cooldowns", [])
	for slot: int in range(mini(SLOTS, saved.size())):
		cooldowns[slot] = maxf(0.0, float(saved[slot]))
	uses = int(s.get("uses", 0))
	var by_slot: Array = s.get("uses_by_slot", [])
	for slot: int in range(mini(SLOTS, by_slot.size())):
		uses_by_slot[slot] = int(by_slot[slot])
	if behavior:
		behavior.load_state(s.get("behavior", {}))
	_update_unlocks(false)


## Parte do hash da partida (HyakkiGame.state_summary).
## Linha do fim da partida do bot (--quit-at): nível e usos de cada habilidade, na ordem dos slots.
func uses_line() -> String:
	var parts: PackedStringArray = []
	for slot: int in range(abilities.size()):
		parts.append("%s=%d" % [abilities[slot]["id"], uses_by_slot[slot]])
	return "HABILIDADES nivel=%d %s" % [game.level, " ".join(parts)]


func hash_tag() -> String:
	return " hab=%d,%.3f,%.3f,%.3f,%.3f%s" % [uses, energy.value, cooldowns[0], cooldowns[1], cooldowns[2],
			behavior.hash_tag() if behavior else ""]
