class_name AltarSystem
extends Node2D
## Altares do Selo (封印の祭壇, .ai/05-altares-e-elites.md): altares de pedra espalhados pelo mapa
## (WorldMap.chunk_data "altars"). A guardiã que fica no círculo lê o selo: 4 runas acendem, o anel
## de progresso enche, raios começam a cair em volta e, quando o selo quebra, o altar solta uma
## emboscada ou um Elite com afixos (EliteAffixes), com a animação de surgimento própria.
##
## Estados: DORMANT → CHANNELING → BREAKING → SPENT. Simulação em step(dt), só game.rng, igual em
## 1x/2x/3x e em qualquer nível gráfico. Os efeitos de cada momento ficam no AltarFx (só desenho e
## som); o chão (altar, anel, runas, círculo de runas, coluna) é desenhado aqui com texturas e o
## Stroke. O letreiro do Elite fica numa camada da tela (acima da escuridão, abaixo da HUD).
##
## Depuração (depois de "--"): --altar-test põe um altar sob a guardiã no começo (o ritual começa
## sozinho) e faz o selo soltar um Elite; --force-affixes=raijin,kongo escolhe os afixos (implica --altar-test).

enum State { DORMANT, CHANNELING, BREAKING, SPENT }

## Posicionamento (WorldMap.altar_site): chance por chunk, folga da borda do chunk, distância do
## início da fase, distância mínima entre altares, sólido no centro e o círculo livre de terreno.
const ALTAR_CHANCE := 0.12
const EDGE_MARGIN := 48.0
const MIN_START_DIST := 520.0
const MIN_GAP := 360.0
const SOLID_RADIUS := 9.0
const RADIUS := 44.0
const RESERVE_RADIUS := RADIUS + 10.0
## Ritual: tempo de leitura, queda fora do círculo (fração da velocidade), runas, ameaça (a partir de
## THREAT_AT os inimigos perto são puxados de leve para o altar).
const CHANNEL_TIME := 3.5
const DECAY := 0.5
const RUNES := 4
const THREAT_AT := 0.5
const THREAT_RADIUS := 150.0
const THREAT_PULL := 0.06
const AMBIENT_BOLT_CHANCE := 0.04
## Estouro (s desde o fim da leitura): raios, a silhueta sobe, rugido e o Elite solto; a emboscada
## sai em AMBUSH_AT. O spawner segura os comuns durante o estouro.
const BREAK_TIME := 1.6
const BOLT_TIMES: Array[float] = [0.1, 0.25, 0.4, 0.55, 0.7]
const RISE_AT := 0.8
const ROAR_AT := 1.4
const RELEASE_AT := 1.45
const AMBUSH_AT := 0.5
## Resultado: chance de Elite com "pena" (pity); o 1º altar é Elite só depois de FIRST_ELITE_T s.
const ELITE_BASE := 0.4
const ELITE_PITY := 0.3
const FIRST_ELITE_T := 180.0
## Emboscada: AMBUSH_BASE + AMBUSH_PER_3MIN por 3 min (até AMBUSH_CAP) num anel, mais o campeão.
const AMBUSH_BASE := 6.0
const AMBUSH_PER_3MIN := 2.0
const AMBUSH_CAP := 16
const AMBUSH_RING := 70.0
## O anel e o campeão surgem selados (sem dano e sem contato, com a marca no chão) e são soltos
## AMBUSH_RISE s depois; o campeão nasce fora do círculo, do lado oposto ao da guardiã.
const AMBUSH_RISE := 0.7
const CHAMPION_RING := RADIUS + 18.0
## Sino Purificador num Elite com afixos: tira só esta fração da vida máxima (chefes são imunes).
const PURIFY_ELITE := 0.25
## Elite: vida extra sobre a do Elite comum e os pesos dos arquétipos (prop e enxame não entram).
const ELITE_HP_BONUS := 1.6
const ARCHETYPE_WEIGHT := {"tank": 4.0, "charger": 3.0, "shooter": 3.0, "chaser": 2.0, "shade": 1.0,
		"splitter": 1.0}
## Saque: BOSS_CHEST_AFFIXES+ afixos dão baú de chefe; 1 afixo: CHEST_CHANCE baú comum, senão item raro + ryō.
const BOSS_CHEST_AFFIXES := 2
const CHEST_CHANCE := 0.65
const RARE_ITEMS: Array[StringName] = [&"solar_ember", &"hourglass", &"purifying_bell", &"magnet_scroll"]
## Explosão de ar do rugido (inimigos comuns e a guardiã levemente).
const BLAST_RADIUS := 90.0
const BLAST_FORCE := 170.0
const PLAYER_BLAST := 110.0
## Seta da HUD para o altar dormente mais perto fora da tela.
const ARROW_RANGE := 520.0
## Letreiro do Elite (s de jogo) e o "pulinho" dos itens que saem do Elite.
const BANNER_TIME := 2.8
const BANNER_FADE := 0.35
## Letreiro: começa abaixo do bloco do topo da HUD (armas e passivas, Hud.top_layout) e da barra do
## chefe (BossPanel), nunca acima de BANNER_TOP da altura; se a faixa passaria de BANNER_LIMIT da
## altura (telas baixas), o 強敵 encolhe de BANNER_TITLE para BANNER_TITLE_SMALL.
const BANNER_TOP := 0.2
const BANNER_LIMIT := 0.5
const BANNER_TITLE := 24
const BANNER_TITLE_SMALL := 16
const BANNER_GAP := 4.0
const BANNER_PAD := 3.0
const POP_TIME := 0.45
## Brilho dourado do altar depois do Elite vencido (s).
const VANQUISHED_GLOW := 6.0
## Arte (assets/art/altar/): o altar em 3 quadros 40x40 com a base no meio de baixo, o círculo de
## runas (branco, tingido), as 4 runas 12x12 e o ofuda 6x10. Zumbido em loop enquanto lê.
const ALTAR_PATH := "res://assets/art/altar/altar.png"
const ALTAR_FRAME := 40
const CIRCLE_PATH := "res://assets/art/altar/rune_circle.png"
const RUNES_PATH := "res://assets/art/altar/rune_marks.png"
const RUNE_FRAME := 12
const OFUDA_PATH := "res://assets/art/altar/ofuda.png"
const HUM_PATH := "res://assets/audio/sfx/alt_hum.wav"
const HUM_DB := -8.0
const HUM_RANGE := 360.0
const KANJI_FONT := "res://assets/fonts/fusion_pixel_12_ja.woff2"
const BANNER_LAYER := 9
## Cores do chão: anel adormecido, runas acesas, trava (chefe vivo) e a seta.
const RING_DIM := Color(0.62, 0.8, 1.0, 0.28)
const RUNE_LIT := Color(0.72, 0.9, 1.0)
const LOCK := Color(1.0, 0.45, 0.35)
const ARROW := Color(0.62, 0.84, 1.0)

var game: HyakkiGame
var affixes: EliteAffixes
var visuals: AltarFx
## Chaves dos altares gastos -> {"pos", "vanquished" (tempo de jogo do Elite vencido, -1)}.
var spent: Dictionary = {}
## Altares em ritual ou estourando (chave -> estado do altar).
var runtime: Dictionary = {}
## Quantos altares quebraram nesta partida e quantos seguidos sem Elite (pena).
var awakened: int = 0
var since_elite: int = 0
## Depuração e testes: altares extras (fora do sorteio), resultado e afixos forçados.
var forced: Array[Vector2] = []
var force_outcome: StringName = &""
var force_affixes: Array[StringName] = []
## Letreiro do Elite na tela: {"name", "affixes", "at"} ou vazio.
var banner: Dictionary = {}

## Campeões vivos das emboscadas: índice -> uid (a bolsa de ryō no abate).
var _champions: Dictionary = {}
## Listas reaproveitadas (sem alocar por chamada): altares perto.
var _near_altars: Array = []
var _claimed: bool = false
var _seed: int = 0
var _warned: Dictionary = {}
var _cli_test: bool = false
var _hum: AudioStreamPlayer2D
var _hum_key: String = ""
var _altar_tex: Texture2D
var _circle_tex: Texture2D
var _rune_tex: Texture2D
var _ofuda_tex: Texture2D
var _glow: Node2D
var _under: Node2D
var _over: Node2D
var _banner: Control
var _banner_drawn: bool = false
var _font: Font
var _kanji_font: Font
var _near: Array[int] = []
var _look := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = -4
	_look.randomize()
	affixes = EliteAffixes.new(game)
	visuals = AltarFx.new(game)
	_altar_tex = _texture(ALTAR_PATH)
	_circle_tex = _texture(CIRCLE_PATH)
	_rune_tex = _texture(RUNES_PATH)
	_ofuda_tex = _texture(OFUDA_PATH)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow = Node2D.new()
	_glow.material = additive
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	_under = Node2D.new()
	_under.material = additive
	_under.z_as_relative = false
	_under.z_index = -1
	_under.draw.connect(func() -> void: affixes.draw_under(_under, FxLayer.wfx))
	add_child(_under)
	_over = Node2D.new()
	_over.z_as_relative = false
	_over.z_index = 6
	_over.draw.connect(_draw_over)
	add_child(_over)
	_hum = AudioStreamPlayer2D.new()
	_hum.bus = "SFX"
	_hum.volume_db = HUM_DB
	_hum.max_distance = HUM_RANGE
	_hum.attenuation = 1.6
	if ResourceLoader.exists(HUM_PATH):
		var stream := load(HUM_PATH) as AudioStream
		if stream is AudioStreamWAV:
			var wav := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
			stream = wav
		_hum.stream = stream
	add_child(_hum)
	var layer := CanvasLayer.new()
	layer.layer = BANNER_LAYER
	add_child(layer)
	_banner = Control.new()
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.draw.connect(_draw_banner)
	layer.add_child(_banner)
	_font = Locale.font if Locale.font else ThemeDB.fallback_font
	_kanji_font = load(KANJI_FONT) as Font if ResourceLoader.exists(KANJI_FONT) else _font
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--altar-test":
			_cli_test = true
		elif arg.begins_with("--force-affixes="):
			_cli_test = true
			for id: String in arg.get_slice("=", 1).split(",", false):
				if EliteAffixes.IDS.has(StringName(id)) and force_affixes.size() < EliteAffixes.MAX_AFFIXES:
					force_affixes.append(StringName(id))


static func _texture(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _exit_tree() -> void:
	_stop_hum()


func reset() -> void:
	_stop_hum()
	spent.clear()
	runtime.clear()
	awakened = 0
	since_elite = 0
	banner = {}
	_champions.clear()
	_claimed = false
	_warned.clear()
	_seed = game.world.seed_value if game != null and game.world != null else 0
	if affixes != null:
		affixes.reset()
	forced.clear()
	if _cli_test and game != null and game.player != null:
		# Logo acima da guardiã, já dentro do círculo: o ritual começa sozinho (para assistir).
		forced.append((game.player.sim_pos + Vector2(0.0, -30.0)).round())
		force_outcome = &"elite"


## Altares não ativam com chefe (ou o Guardião do Limiar) vivo nem na travessia.
func is_blocked() -> bool:
	return game.bosses.active_count() > 0 or game.rift.crossing()


## Fases com altar: todas, salvo "altars": false em data/stages.json.
static func stage_has_altars(stage: Dictionary) -> bool:
	return bool(stage.get("altars", true))


func key_of(at: Vector2) -> String:
	return "%d:%d:%d" % [game.world.seed_value, roundi(at.x), roundi(at.y)]


## Altares perto da guardiã: os do mapa (chunks da simulação) e os forçados.
func altars_near() -> Array:
	_near_altars.clear()
	_near_altars.append_array(game.world.altars_active())
	_near_altars.append_array(forced)
	return _near_altars


func state_at(at: Vector2) -> int:
	var key := key_of(at)
	if spent.has(key):
		return State.SPENT
	if runtime.has(key):
		return int(runtime[key]["state"])
	return State.DORMANT


## Testes e depuração: põe um altar em `at` (fora do sorteio do mapa) e devolve a chave.
func place_altar(at: Vector2) -> String:
	forced.append(at.round())
	return key_of(at.round())


# --- Simulação -----------------------------------------------------------------------------

func step(dt: float) -> void:
	if game.world.seed_value != _seed:
		# Outro mundo (travessia): os rituais do mapa de lá ficam para trás.
		_seed = game.world.seed_value
		runtime.clear()
		forced.clear()
		_stop_hum()
	var blocked := is_blocked()
	var player := game.player
	for at: Vector2 in altars_near():
		var key := key_of(at)
		if spent.has(key) or runtime.has(key):
			continue
		if not player.is_alive or player.sim_pos.distance_to(at) > RADIUS:
			_warned.erase(key)
			continue
		if blocked:
			if not _warned.has(key):
				_warned[key] = true
				game.hud.toast(tr("altar.locked"), 2.0)
				AudioManager.play("a_denied", 0.8, 0.0, -6.0)
			continue
		runtime[key] = {"key": key, "pos": at, "state": State.CHANNELING, "progress": 0.0, "runes": 0, "t": 0.0,
				"outcome": &"", "enemy": &"", "affixes": [], "elite": -1, "uid": 0}
		_start_hum(key, at)
	for key: String in runtime.keys():
		var r: Dictionary = runtime[key]
		if int(r["state"]) == State.CHANNELING:
			_step_channel(r, dt, blocked)
		else:
			_step_break(r, dt)
	affixes.step(dt)
	if not banner.is_empty() and GameClock.game_time - float(banner["at"]) > BANNER_TIME:
		banner = {}


func _step_channel(r: Dictionary, dt: float, blocked: bool) -> void:
	var at: Vector2 = r["pos"]
	var player := game.player
	var inside := player.is_alive and not blocked and player.sim_pos.distance_to(at) <= RADIUS
	var progress := float(r["progress"])
	progress += dt / CHANNEL_TIME if inside else -dt * DECAY / CHANNEL_TIME
	progress = clampf(progress, 0.0, 1.0)
	r["progress"] = progress
	var lit := mini(RUNES, floori(progress * RUNES + 0.0001))
	for k: int in range(int(r["runes"]), lit):
		visuals.rune_lit(rune_point(at, k), k)
	r["runes"] = lit
	if inside and progress >= THREAT_AT:
		_threat(at)
		if _look.randf() < AMBIENT_BOLT_CHANCE * (1.0 + progress):
			visuals.ambient_bolt(at)
	if progress >= 1.0:
		_begin_break(r)
	elif progress <= 0.0:
		runtime.erase(String(r["key"]))
		if _hum_key == String(r["key"]):
			_stop_hum()


## Ameaça: os inimigos comuns perto puxados de leve para o altar (determinístico, sem sorteio).
func _threat(at: Vector2) -> void:
	var enemies := game.enemies
	enemies.query_circle(at, THREAT_RADIUS, _near)
	for j: int in _near:
		if not enemies.is_controllable(j) or enemies.elite[j] == 1:
			continue
		var d := at - enemies.pos[j]
		if d.length_squared() > 4.0:
			enemies.vel[j] = enemies.vel[j].lerp(d.normalized() * enemies.speed[j], THREAT_PULL)


## Fim da leitura: sorteia o resultado (com a pena), conta, avisa e começa o estouro.
func _begin_break(r: Dictionary) -> void:
	r["state"] = State.BREAKING
	r["t"] = 0.0
	r["progress"] = 1.0
	var outcome := roll_outcome()
	r["outcome"] = outcome
	if outcome == &"elite":
		r["enemy"] = pick_elite_type()
		var chosen: Array[StringName] = force_affixes.duplicate() if not force_affixes.is_empty() \
				else EliteAffixes.roll(game.rng, EliteAffixes.affix_count(GameClock.game_time, game.moon))
		r["affixes"] = chosen
	else:
		since_elite += 1
	awakened += 1
	if String(r["key"]) == _hum_key:
		_stop_hum()
	game.spawner.hush(BREAK_TIME)
	game.tracker.on_altar(outcome)
	Events.altar_awakened.emit(r["pos"], outcome)
	visuals.seal_break(r["pos"])


## &"elite" ou &"ambush": o 1º altar antes de FIRST_ELITE_T é emboscada; depois, a chance com pena.
func roll_outcome() -> StringName:
	if force_outcome != &"":
		return force_outcome
	if awakened == 0:
		return &"elite" if GameClock.game_time >= FIRST_ELITE_T else &"ambush"
	# Lua Vermelha I+: a chance com a pena vezes RedMoon.elite_mult (1,0 sem a regra).
	var chance := minf(1.0, elite_chance(since_elite) * RedMoon.elite_mult(game.moon))
	return &"elite" if game.rng.randf() < chance else &"ambush"


static func elite_chance(without_elite: int) -> float:
	return minf(1.0, ELITE_BASE + ELITE_PITY * without_elite)


func _step_break(r: Dictionary, dt: float) -> void:
	var t0 := float(r["t"])
	var t1 := t0 + dt
	r["t"] = t1
	var at: Vector2 = r["pos"]
	for k: int in BOLT_TIMES.size():
		if _crossed(t0, t1, BOLT_TIMES[k]):
			visuals.sky_bolt(at, k)
	if StringName(r["outcome"]) == &"elite":
		if _crossed(t0, t1, RISE_AT):
			_spawn_elite(r)
		var rec := affixes.record(int(r["elite"])) if int(r["elite"]) >= 0 else {}
		if not rec.is_empty() and float(rec["emerge"]) >= 0.0:
			rec["emerge"] = t1 - RISE_AT
		if _crossed(t0, t1, ROAR_AT):
			_roar(r)
		if _crossed(t0, t1, RELEASE_AT):
			_release(r)
	else:
		if _crossed(t0, t1, AMBUSH_AT):
			_spawn_ambush(r)
		if _crossed(t0, t1, AMBUSH_AT + AMBUSH_RISE):
			_release_ambush(r)
	if t1 >= BREAK_TIME:
		# O Elite pode ter morrido logo depois de solto (entre RELEASE_AT e BREAK_TIME): mantém o ouro.
		var before: Dictionary = spent.get(String(r["key"]), {})
		spent[String(r["key"])] = {"pos": at, "vanquished": float(before.get("vanquished", -1.0))}
		runtime.erase(String(r["key"]))


static func _crossed(t0: float, t1: float, mark: float) -> bool:
	return t0 < mark and t1 >= mark


## Inimigo da fase para o Elite: os já vistos nas ondas até agora, sem prop nem enxame, com peso
## por arquétipo (tanque, investida e atirador primeiro).
func pick_elite_type() -> StringName:
	var ids: Array[StringName] = []
	var weights := PackedFloat32Array()
	for wave: Variant in game.stage.get("waves", []):
		var w: Dictionary = wave
		if float(w["from"]) > GameClock.game_time and not ids.is_empty():
			break
		for id: String in (w["mix"] as Dictionary):
			var sid := StringName(id)
			var data: Dictionary = DB.enemies.get(sid, {})
			var arch := String(data.get("archetype", "chaser"))
			if ids.has(sid) or not ARCHETYPE_WEIGHT.has(arch):
				continue
			ids.append(sid)
			weights.append(float(ARCHETYPE_WEIGHT[arch]))
	if ids.is_empty():
		return &"slime_rice"
	return ids[WorldMap.weighted(game.rng, weights)]


## Lacaio do Névoa: o comum mais fraco da onda atual (sem enxame nem divisor).
func minion_type() -> StringName:
	var best := &"slime_rice"
	var best_hp := INF
	for wave: Variant in game.stage.get("waves", []):
		var w: Dictionary = wave
		if GameClock.game_time < float(w["from"]) or GameClock.game_time >= float(w["to"]):
			continue
		for id: String in (w["mix"] as Dictionary):
			var data: Dictionary = DB.enemies.get(StringName(id), {})
			if String(data.get("archetype", "")) in ["chaser", "charger", "shade"] and float(data.get("hp", 1)) < best_hp:
				best_hp = float(data.get("hp", 1))
				best = StringName(id)
	return best


## A silhueta sobe: o Elite nasce selado (sem dano, sem contato) e parado, com os afixos.
func _spawn_elite(r: Dictionary) -> void:
	var enemies := game.enemies
	var at := game.world.free_point((r["pos"] as Vector2) + Vector2(0.0, 18.0), 8.0)
	var i := enemies.spawn(StringName(r["enemy"]), at, game.enemy_hp_mult() * ELITE_HP_BONUS,
			game.enemy_damage_mult(), true)
	var list: Array[StringName] = []
	for id: Variant in r["affixes"]:
		list.append(StringName(id))
	if i < 0:
		# Sem vaga (EnemyManager.CAPACITY cheio): o selo entrega o saque do Elite e a pena continua.
		for drop: Array in loot(list.size(), game.rng):
			_pop_item(StringName(drop[0]), at, drop[1], drop[2])
		return
	since_elite = 0
	_seal(i)
	var rec := affixes.attach(i, list, String(r["key"]))
	rec["emerge"] = float(r["t"]) - RISE_AT
	r["elite"] = i
	r["uid"] = enemies.uid[i]
	visuals.elite_rise(at, enemies.type_scale[enemies.kind[i]])
	game.tracker.on_elite_spawned(list)
	Events.elite_spawned.emit(i, StringName(r["enemy"]), list.duplicate())


func _seal(i: int) -> void:
	var enemies := game.enemies
	enemies.sealed[i] = 1
	enemies.controlled[i] = 1
	enemies.vel[i] = Vector2.ZERO


## Rugido: explosão de ar (empurra os comuns e a guardiã), letreiro e os efeitos fortes.
func _roar(r: Dictionary) -> void:
	var i := int(r["elite"])
	var rec := affixes.record(i) if i >= 0 else {}
	if rec.is_empty():
		return
	var enemies := game.enemies
	var at: Vector2 = enemies.pos[i]
	enemies.push_from(at, BLAST_RADIUS, BLAST_FORCE)
	var player := game.player
	var away := player.sim_pos - at
	if player.is_alive and away.length() < BLAST_RADIUS and away.length() > 0.01:
		player.velocity += away.normalized() * PLAYER_BLAST
	var list: Array = rec["affixes"]
	banner = {"name": EliteAffixes.elite_name(StringName(rec["id"]), list), "affixes": list.duplicate(),
			"at": GameClock.game_time}
	visuals.elite_roar(at, EliteAffixes.color_of(StringName(list[0])), enemies.type_scale[enemies.kind[i]])


## O Elite é solto (sem selo, anda e usa os poderes).
func _release(r: Dictionary) -> void:
	var i := int(r["elite"])
	var rec := affixes.record(i) if i >= 0 else {}
	if rec.is_empty():
		return
	game.enemies.sealed[i] = 0
	game.enemies.controlled[i] = 0
	game.enemies.vel[i] = Vector2.ZERO
	rec["emerge"] = -1.0


## Emboscada: anel de inimigos da fase com raio e fumaça, mais o campeão (Elite sem afixos).
func _spawn_ambush(r: Dictionary) -> void:
	var at: Vector2 = r["pos"]
	var enemies := game.enemies
	var n := ambush_count(GameClock.game_time)
	var offset := game.rng.randf() * TAU
	var points: Array[Vector2] = []
	var rising: Array = []
	for k: int in n:
		var ring := at + Vector2.from_angle(offset + TAU * k / n) * AMBUSH_RING
		var p := game.world.free_point(game.world.clamp_to_bounds(ring), 6.0)
		var j := enemies.spawn(game.spawner.pick_type(GameClock.game_time), p, game.enemy_hp_mult(), game.enemy_damage_mult())
		if j >= 0:
			_seal(j)
			rising.append([j, enemies.uid[j]])
			points.append(p)
	var away := at - game.player.sim_pos
	var side := away.normalized() if away.length() > 0.01 else Vector2.UP
	var front := game.world.free_point(game.world.clamp_to_bounds(at + side * CHAMPION_RING), 8.0)
	var c := enemies.spawn(pick_elite_type(), front, game.enemy_hp_mult(), game.enemy_damage_mult(), true)
	if c >= 0:
		_seal(c)
		_champions[c] = enemies.uid[c]
		rising.append([c, enemies.uid[c]])
		points.append(front)
	r["rising"] = rising
	r["points"] = points
	visuals.ambush(at, points)
	game.hud.toast(tr("altar.ambush"), 2.2)


## Fim do surgimento da emboscada: o anel e o campeão andam e ferem.
func _release_ambush(r: Dictionary) -> void:
	var enemies := game.enemies
	for pair: Array in r.get("rising", []):
		var j := int(pair[0])
		if enemies.alive[j] == 1 and enemies.uid[j] == int(pair[1]):
			enemies.sealed[j] = 0
			enemies.controlled[j] = 0
	r["rising"] = []
	r["points"] = []


static func ambush_count(time: float) -> int:
	return mini(AMBUSH_CAP, roundi(AMBUSH_BASE + AMBUSH_PER_3MIN * time / 180.0))


## Um Elite morreu (EnemyManager._kill): Elite de altar ou campeão da emboscada fazem o próprio
## saque e o HyakkiGame não solta o baú comum (consume_claim).
func on_enemy_killed(i: int, at: Vector2) -> void:
	var rec := affixes.take_dead(i)
	if not rec.is_empty():
		_claimed = true
		_elite_slain(rec, at)
		return
	if _champions.has(i):
		if int(_champions[i]) == game.enemies.uid[i]:
			_claimed = true
			_pop_item(&"ryo_bag", at, Vector2(0.0, 0.0))
		_champions.erase(i)


## O último abate de Elite já teve o saque do altar (o baú comum não sai). Lê e zera.
func consume_claim() -> bool:
	var claimed := _claimed
	_claimed = false
	return claimed


func _elite_slain(rec: Dictionary, at: Vector2) -> void:
	var list: Array = rec["affixes"]
	var enemy_id := StringName(rec["id"])
	game.tracker.on_elite_slain(list)
	Events.elite_slain.emit(at, enemy_id, list.duplicate())
	var size := game.enemies.type_scale[game.enemies.type_of(enemy_id)] if game.enemies.type_of(enemy_id) >= 0 else 1.0
	visuals.elite_death(at, EliteAffixes.color_of(StringName(list[0])), size)
	for drop: Array in loot(list.size(), game.rng):
		_pop_item(StringName(drop[0]), at, drop[1], drop[2])
	var key := String(rec["altar"])
	if not spent.has(key) and runtime.has(key):
		# Morreu antes do fim do estouro: o altar já fica gasto e vencido.
		spent[key] = {"pos": runtime[key]["pos"], "vanquished": -1.0}
	if spent.has(key):
		spent[key]["vanquished"] = GameClock.game_time
		visuals.altar_vanquished(spent[key]["pos"])
	game.hud.toast(tr("altar.elite_slain"), 2.5)


## Saque do Elite com `count` afixos: [[id, deslocamento, extra], ...] (sorteio com `rng`).
static func loot(count: int, rng: RandomNumberGenerator) -> Array:
	if count >= BOSS_CHEST_AFFIXES:
		return [[&"chest", Vector2.ZERO, {"boss": true}]]
	if rng.randf() < CHEST_CHANCE:
		return [[&"chest", Vector2.ZERO, {}]]
	var rare: StringName = RARE_ITEMS[rng.randi_range(0, RARE_ITEMS.size() - 1)]
	return [[rare, Vector2(-14.0, 4.0), {}], [&"ryo_bag", Vector2(14.0, 4.0), {}]]


## Item no chão num ponto livre perto de `at + offset`, com o pulinho em arco a partir de `at`.
func _pop_item(id: StringName, at: Vector2, offset: Vector2, extra: Dictionary = {}) -> void:
	var data := extra.duplicate()
	data["pop"] = [at.x, at.y, GameClock.game_time]
	game.pickups.spawn_item(id, at + offset, data)


## O escudo do Elite `i` levou um golpe (EnemyManager.damage).
func on_shield_hit(i: int, _absorbed: float, broke: bool) -> void:
	affixes.on_shield_hit(i, broke)


## Linha do hash da partida (determinismo).
func hash_tag() -> String:
	var parts: PackedStringArray = []
	for key: String in runtime:
		var r: Dictionary = runtime[key]
		parts.append("%s:%d:%.3f:%s" % [key, int(r["state"]), float(r["progress"]), r["outcome"]])
	return " altares=%d/%d/%d[%s]{%s}" % [awakened, since_elite, spent.size(), ",".join(parts), affixes.hash_tag()]


# --- Partida suspensa ----------------------------------------------------------------------

func snapshot() -> Dictionary:
	var rows: Array = []
	for key: String in runtime:
		var r: Dictionary = runtime[key]
		rows.append({"key": key, "x": (r["pos"] as Vector2).x, "y": (r["pos"] as Vector2).y, "state": int(r["state"]),
				"progress": float(r["progress"]), "runes": int(r["runes"]), "t": float(r["t"]),
				"outcome": String(r["outcome"]), "enemy": String(r["enemy"]),
				"affixes": (r["affixes"] as Array).map(func(a: Variant) -> String: return String(a))})
	var spent_rows: Array = []
	for key: String in spent:
		var since := GameClock.game_time - float(spent[key]["vanquished"])
		spent_rows.append([key, (spent[key]["pos"] as Vector2).x, (spent[key]["pos"] as Vector2).y,
				since if float(spent[key]["vanquished"]) >= 0.0 else -1.0])
	return {"awakened": awakened, "since_elite": since_elite, "spent": spent_rows, "runtime": rows,
			"elites": affixes.snapshot(), "champions": _champion_rows(),
			"forced": forced.map(func(p: Vector2) -> Array: return [p.x, p.y])}


## Campeões vivos das emboscadas (inimigos não entram no snapshot: voltam pelo restore).
func _champion_rows() -> Array:
	var out: Array = []
	var enemies := game.enemies
	for i: int in _champions:
		if enemies.alive[i] == 1 and enemies.uid[i] == int(_champions[i]):
			out.append({"enemy": String(enemies.type_ids[enemies.kind[i]]), "x": enemies.pos[i].x, "y": enemies.pos[i].y,
					"hp": enemies.hp[i], "max_hp": enemies.max_hp[i]})
	return out


## Depois do start_run e do rift.restore (o mundo já é o certo): altares gastos, rituais e
## estouros em curso e os Elites vivos voltam (inimigos não entram no snapshot: são chamados de
## novo, com a vida, o escudo e o selo que tinham).
func restore(s: Dictionary) -> void:
	_seed = game.world.seed_value
	awakened = int(s.get("awakened", 0))
	since_elite = int(s.get("since_elite", 0))
	forced.clear()
	for p: Variant in s.get("forced", []):
		forced.append(Vector2(float(p[0]), float(p[1])))
	for row: Variant in s.get("spent", []):
		var a: Array = row
		# Tempo desde a vitória (a 4ª coluna; -1 = não vencido), contado a partir do relógio retomado.
		var since := float(a[3]) if a.size() > 3 else -1.0
		spent[String(a[0])] = {"pos": Vector2(float(a[1]), float(a[2])),
				"vanquished": GameClock.game_time - since if since >= 0.0 else -1.0}
	for row: Variant in s.get("runtime", []):
		var d: Dictionary = row
		var list: Array[StringName] = []
		for id: Variant in d.get("affixes", []):
			list.append(StringName(String(id)))
		var key := String(d["key"])
		runtime[key] = {"key": key, "pos": Vector2(float(d["x"]), float(d["y"])), "state": int(d["state"]),
				"progress": float(d["progress"]), "runes": int(d["runes"]), "t": float(d["t"]),
				"outcome": StringName(String(d["outcome"])), "enemy": StringName(String(d["enemy"])),
				"affixes": list, "elite": -1, "uid": 0}
		if int(d["state"]) == State.CHANNELING:
			_start_hum(key, runtime[key]["pos"])
	for row: Variant in s.get("elites", []):
		_respawn_elite(row)
	for row: Variant in s.get("champions", []):
		var d: Dictionary = row
		var c := game.enemies.spawn(StringName(String(d["enemy"])), Vector2(float(d["x"]), float(d["y"])), 1.0,
				game.enemy_damage_mult(), true)
		if c >= 0:
			game.enemies.max_hp[c] = float(d["max_hp"])
			game.enemies.hp[c] = clampf(float(d["hp"]), 1.0, game.enemies.max_hp[c])
			_champions[c] = game.enemies.uid[c]


func _respawn_elite(d: Dictionary) -> void:
	var enemies := game.enemies
	var i := enemies.spawn(StringName(String(d["enemy"])), Vector2(float(d["x"]), float(d["y"])), 1.0,
			game.enemy_damage_mult(), true)
	if i < 0:
		return
	enemies.max_hp[i] = float(d["max_hp"])
	enemies.hp[i] = clampf(float(d["hp"]), 1.0, enemies.max_hp[i])
	enemies.speed[i] *= EliteAffixes.SPEED_BONUS
	var list: Array[StringName] = []
	for id: Variant in d.get("affixes", []):
		list.append(StringName(String(id)))
	var rec := affixes.attach(i, list, String(d.get("altar", "")), false)
	enemies.shield[i] = float(d.get("shield", 0.0))
	affixes.load_power_state(i, rec, d.get("state", {}))
	if bool(d.get("sealed", false)):
		_seal(i)
		rec["emerge"] = float(d.get("emerge", -1.0))
	var r: Dictionary = runtime.get(String(d.get("altar", "")), {})
	if not r.is_empty():
		r["elite"] = i
		r["uid"] = enemies.uid[i]


# --- Luz, seta e zumbido -------------------------------------------------------------------

## Luz dos altares para a lanterna: [posição, cor, raio, força].
func collect_lights(center: Vector2, half: Vector2) -> Array:
	var out: Array = []
	var area := Rect2(center - half, half * 2.0).grow(140.0)
	var now := GameClock.game_time
	for at: Vector2 in altars_near():
		if not area.has_point(at):
			continue
		var key := key_of(at)
		var glow_at := at + Vector2(0.0, -14.0)
		if spent.has(key):
			var since := now - float(spent[key]["vanquished"])
			if float(spent[key]["vanquished"]) >= 0.0 and since < VANQUISHED_GLOW:
				out.append([glow_at, AltarFx.GOLD, 70.0, 1.0 - since / VANQUISHED_GLOW])
			continue
		if not runtime.has(key):
			out.append([glow_at, RUNE_LIT, 44.0, 0.5])
			continue
		var r: Dictionary = runtime[key]
		if int(r["state"]) == State.BREAKING:
			var k := clampf(1.0 - float(r["t"]) / BREAK_TIME, 0.0, 1.0)
			out.append([glow_at, RUNE_LIT.lerp(Color.WHITE, 0.5), 90.0 + 80.0 * k, 0.8 + 0.6 * k])
		else:
			var p := float(r["progress"])
			out.append([glow_at, RUNE_LIT, 50.0 + 50.0 * p, 0.6 + 0.5 * p])
	return out


## Altar dormente (ou em ritual) mais perto dentro de ARROW_RANGE; Vector2.INF se nenhum.
func arrow_target() -> Vector2:
	var best := Vector2.INF
	var best_d := ARROW_RANGE
	var me := game.player.sim_pos
	for at: Vector2 in altars_near():
		var key := key_of(at)
		if spent.has(key) or (runtime.has(key) and int(runtime[key]["state"]) == State.BREAKING):
			continue
		var d := me.distance_to(at)
		if d < best_d:
			best_d = d
			best = at
	return best


## Seta do altar fora da tela: losango de pedra com a runa acesa que pulsa (HUD, sem polígono
## por quadro).
static func draw_arrow(canvas: CanvasItem, edge: Vector2, dir: Vector2, now: float) -> void:
	var pulse := 0.5 + 0.5 * sin(now * 5.0)
	var glyph := (edge - dir * 4.0).round()
	Stroke.convex(canvas, PackedVector2Array([glyph + Vector2(0, -6), glyph + Vector2(6, 0), glyph + Vector2(0, 6),
			glyph + Vector2(-6, 0)]), Color(0.08, 0.1, 0.16, 0.85))
	Stroke.convex(canvas, PackedVector2Array([glyph + Vector2(0, -4), glyph + Vector2(4, 0), glyph + Vector2(0, 4),
			glyph + Vector2(-4, 0)]), Color(0.36, 0.42, 0.5, 0.95))
	canvas.draw_rect(Rect2(glyph - Vector2(1, 1), Vector2(2, 2)), Color(ARROW.lerp(Color.WHITE, pulse * 0.6), 1.0))
	var tip := edge + dir * (8.0 + pulse * 2.0)
	var side := dir.orthogonal() * 4.0
	var back := edge + dir * 2.0
	Stroke.convex(canvas, PackedVector2Array([tip, back + side, back - side]), Color(ARROW, 0.7 + 0.3 * pulse))


func _start_hum(key: String, at: Vector2) -> void:
	_hum_key = key
	if _hum == null or _hum.stream == null:
		return
	_hum.position = at
	_hum.pitch_scale = 0.8
	_hum.stream_paused = false
	_hum.play()


func _stop_hum() -> void:
	_hum_key = ""
	if _hum != null:
		_hum.stream_paused = false
		_hum.stop()


## O zumbido do ritual está tocando (testes).
func hum_playing() -> bool:
	return _hum != null and (_hum.playing or _hum.stream_paused)


## O zumbido está pausado junto com o relógio (testes).
func hum_paused() -> bool:
	return _hum != null and _hum.stream_paused


# --- Desenho -------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	queue_redraw()
	_glow.queue_redraw()
	_over.queue_redraw()
	if not affixes.records.is_empty():
		_under.queue_redraw()
	if not banner.is_empty() or _banner_drawn:
		_banner.queue_redraw()
	_banner_drawn = not banner.is_empty()
	# Pausado, `playing` fica falso: o teste é a chave do ritual (senão o zumbido não volta).
	if _hum_key != "" or _hum.stream_paused:
		_hum.stream_paused = GameClock.paused
		var r: Dictionary = runtime.get(_hum_key, {})
		if not r.is_empty():
			_hum.pitch_scale = 0.8 + 0.55 * float(r["progress"])



## Ponto da runa `k` no anel (em cima, direita, embaixo, esquerda).
static func rune_point(at: Vector2, k: int) -> Vector2:
	return at + Vector2.from_angle(-PI * 0.5 + k * PI * 0.5) * RADIUS


func _visible_rect() -> Rect2:
	var view := game.view_size()
	return Rect2(game.player.position - view * 0.5, view).grow(80.0)


func _draw() -> void:
	if game == null or game.player == null:
		return
	var screen := _visible_rect()
	var time := GameClock.game_time
	var blocked := is_blocked()
	for at: Vector2 in altars_near():
		if not screen.has_point(at):
			continue
		var key := key_of(at)
		var state := state_at(at)
		var r: Dictionary = runtime.get(key, {})
		_draw_ring(at, state, r, time, blocked)
		_draw_rising(r, time)
		_draw_altar(at, state, time)
		if blocked and state == State.DORMANT and game.player.sim_pos.distance_to(at) < RADIUS * 2.5:
			_draw_lock(at + Vector2(0.0, -40.0), time)


## Anel do ritual (tracejado que gira; cheio no ritual), arco de progresso, runas e o círculo de
## runas assado na textura (só gira e escala por quadro).
func _draw_ring(at: Vector2, state: int, r: Dictionary, time: float, blocked: bool) -> void:
	if state == State.SPENT:
		return
	var progress := float(r.get("progress", 0.0))
	var breaking := state == State.BREAKING
	var bt := float(r.get("t", 0.0))
	if _circle_tex != null and (state == State.CHANNELING or breaking):
		var k := progress if not breaking else 1.0
		var zoom := (RADIUS * 2.0 / _circle_tex.get_width()) * (0.7 + 0.3 * k)
		var fade := 1.0
		if breaking:
			zoom *= 1.0 + 0.9 * clampf(bt / BREAK_TIME, 0.0, 1.0)
			fade = clampf(1.0 - bt / BREAK_TIME, 0.0, 1.0)
		var spin := time * (0.4 + 1.6 * k) + (bt * bt * 6.0 if breaking else 0.0)
		draw_set_transform(at, spin, Vector2(zoom, zoom))
		draw_texture(_circle_tex, -_circle_tex.get_size() * 0.5, Color(RUNE_LIT, (0.25 + 0.6 * k) * fade))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if breaking:
		return
	var ring_color := Color(LOCK, 0.35) if blocked else RING_DIM
	if state == State.DORMANT:
		var spin := time * 0.3
		for k: int in 12:
			var a := spin + TAU * k / 12.0
			Stroke.arc(self, at, RADIUS, a, a + 0.32, 4, ring_color, 1.0)
	else:
		Stroke.arc(self, at, RADIUS, 0.0, TAU, 40, Color(RUNE_LIT, 0.35), 1.0)
		Stroke.arc(self, at, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * progress, maxi(4, roundi(40 * progress)),
				Color(RUNE_LIT.lerp(Color.WHITE, 0.5), 0.95), 2.0)
	var lit := int(r.get("runes", 0))
	for k: int in RUNES:
		var p := rune_point(at, k).round()
		var on := k < lit
		if _rune_tex != null:
			draw_texture_rect_region(_rune_tex, Rect2(p - Vector2(6, 6), Vector2(12, 12)),
					Rect2(k * RUNE_FRAME, 0, RUNE_FRAME, RUNE_FRAME),
					Color(RUNE_LIT.lerp(Color.WHITE, 0.4), 1.0) if on else Color(0.55, 0.6, 0.7, 0.55))
		else:
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), RUNE_LIT if on else Color(0.4, 0.45, 0.55, 0.6))


## Marcas vermelhas que se fecham sob quem surge da emboscada (selados, ainda sem ferir).
func _draw_rising(r: Dictionary, time: float) -> void:
	var points: Array = r.get("points", [])
	if points.is_empty():
		return
	var k := clampf((float(r["t"]) - AMBUSH_AT) / AMBUSH_RISE, 0.0, 1.0)
	var pulse := 0.6 + 0.4 * sin(time * 24.0)
	for p: Vector2 in points:
		draw_circle(p, 9.0, Color(1.0, 0.25, 0.2, 0.18 + 0.12 * k))
		Stroke.arc(self, p, 9.0 + 8.0 * (1.0 - k), 0.0, TAU, 14, Color(1.0, 0.35, 0.3, 0.8 * pulse), 1.0)


## O altar (quadro pelo estado) com dois ofuda pendurados que balançam (só os não gastos).
func _draw_altar(at: Vector2, state: int, time: float) -> void:
	var base := at.round() + Vector2(0.0, 8.0)
	draw_texture_rect(FxLayer.soft_texture(), Rect2(base - Vector2(16, 5), Vector2(32, 10)), false,
			Color(0.02, 0.0, 0.05, 0.55))
	var frame := 0 if state == State.DORMANT else (2 if state == State.SPENT else 1)
	if _altar_tex != null:
		var cell := Vector2(ALTAR_FRAME, ALTAR_FRAME)
		draw_texture_rect_region(_altar_tex, Rect2(base - Vector2(ALTAR_FRAME * 0.5, ALTAR_FRAME), cell),
				Rect2(frame * ALTAR_FRAME, 0, ALTAR_FRAME, ALTAR_FRAME))
	else:
		var stone := Color(0.45, 0.47, 0.52) if state != State.SPENT else Color(0.3, 0.3, 0.33)
		draw_rect(Rect2(base + Vector2(-12, -10), Vector2(24, 10)), stone.darkened(0.3))
		draw_rect(Rect2(base + Vector2(-9, -24), Vector2(18, 14)), stone)
		draw_rect(Rect2(base + Vector2(-13, -28), Vector2(26, 4)), stone.lightened(0.15))
	if state == State.SPENT or _ofuda_tex == null:
		return
	var shake := 1.0 if state == State.DORMANT else 4.0
	for side: float in [-1.0, 1.0]:
		var hang := base + Vector2(side * 11.0, -27.0)
		var swing := sin(time * (2.0 + shake) + side) * 0.25 * shake
		draw_set_transform(hang, swing, Vector2.ONE)
		draw_texture_rect_region(_ofuda_tex, Rect2(Vector2(-3, 0), Vector2(6, 10)), Rect2(0 if side < 0 else 6, 0, 6, 10))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Cadeado sobre o altar enquanto um chefe vive.
func _draw_lock(at: Vector2, time: float) -> void:
	var p := (at + Vector2(0.0, roundf(sin(time * 3.0)))).round()
	draw_rect(Rect2(p + Vector2(-4, -3), Vector2(9, 9)), Color(0.05, 0.03, 0.05, 0.85))
	draw_rect(Rect2(p + Vector2(-2, -2), Vector2(5, 1)), LOCK)
	draw_rect(Rect2(p + Vector2(-3, -1), Vector2(1, 2)), LOCK)
	draw_rect(Rect2(p + Vector2(2, -1), Vector2(1, 2)), LOCK)
	draw_rect(Rect2(p + Vector2(-3, 1), Vector2(7, 4)), LOCK.darkened(0.2))
	draw_rect(Rect2(p + Vector2(0, 2), Vector2(1, 2)), Color(0.05, 0.03, 0.05))


## Brilho aditivo: runas acesas, o altar que lê, o estouro e o ouro do Elite vencido.
func _draw_glow() -> void:
	if game == null or game.player == null or not FxLayer.glow:
		return
	var screen := _visible_rect()
	var now := GameClock.game_time
	for at: Vector2 in altars_near():
		if not screen.has_point(at):
			continue
		var key := key_of(at)
		var core := at + Vector2(0.0, -14.0)
		if spent.has(key):
			var since := now - float(spent[key]["vanquished"])
			if float(spent[key]["vanquished"]) >= 0.0 and since < VANQUISHED_GLOW:
				FxLayer.draw_soft(_glow, core, 26.0, Color(AltarFx.GOLD, 0.5 * (1.0 - since / VANQUISHED_GLOW)))
			continue
		var r: Dictionary = runtime.get(key, {})
		var pulse := 0.75 + 0.25 * sin(now * 4.0 + at.x)
		if r.is_empty():
			FxLayer.draw_soft(_glow, core, 14.0, Color(RUNE_LIT, 0.22 * pulse))
			continue
		if int(r["state"]) == State.BREAKING:
			var k := clampf(1.0 - float(r["t"]) / BREAK_TIME, 0.0, 1.0)
			FxLayer.draw_soft(_glow, core, 40.0 + 20.0 * k, Color(RUNE_LIT.lerp(Color.WHITE, 0.5), 0.7 * k))
			continue
		var p := float(r["progress"])
		FxLayer.draw_soft(_glow, core, 16.0 + 14.0 * p, Color(RUNE_LIT, (0.3 + 0.4 * p) * pulse))
		for k: int in int(r["runes"]):
			FxLayer.draw_soft(_glow, rune_point(at, k), 9.0, Color(RUNE_LIT, 0.7 * pulse))


func _draw_over() -> void:
	if game != null and game.enemies != null and game.enemies.look != null:
		affixes.draw_over(_over)


# --- Letreiro do Elite ---------------------------------------------------------------------

## Caixa do letreiro na tela agora (vazia sem letreiro): testes de layout.
func banner_rect() -> Rect2:
	if banner.is_empty():
		return Rect2()
	return banner_layout(String(banner["name"]), banner["affixes"], _banner.size, MenuKit.safe_insets(_banner))["plate"]


## Posições do letreiro numa tela `view` com o recorte `insets`: a faixa ("plate"), o 強敵 e os
## kanji ("title_at"), o nome ("name_at") e o tamanho da fonte do nome ("name_size", encolhe para
## caber).
func banner_layout(elite_name: String, list: Array, view: Vector2, insets: Vector2) -> Dictionary:
	var left := insets.x + 8.0
	var right := view.x - insets.y - 8.0
	var center := roundf((left + right) * 0.5)
	var title := "強敵"
	var kanji := ""
	for id: Variant in list:
		kanji += EliteAffixes.kanji_of(StringName(id))
	var name_size := 12
	var name_w := _font.get_string_size(elite_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	while name_w > right - left - 16.0 and name_size > 8:
		name_size -= 1
		name_w = _font.get_string_size(elite_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	var top := roundf(maxf(view.y * BANNER_TOP, banner_top_clear()))
	var title_size := BANNER_TITLE
	if top + _banner_height(title_size, name_size) > view.y * BANNER_LIMIT:
		title_size = BANNER_TITLE_SMALL
	var title_w := _kanji_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var title_ascent := _kanji_font.get_ascent(title_size)
	var chips_w := list.size() * 14.0
	var width := minf(right - left, maxf(title_w + chips_w * 2.0 + 24.0, name_w + 24.0))
	# Linhas de base medidas pela fonte: o 強敵 inteiro dentro da faixa, o nome embaixo dele.
	var title_base := top + BANNER_PAD + ceilf(title_ascent)
	var name_base := title_base + ceilf(_font.get_ascent(name_size)) + 2.0
	var plate := Rect2(center - roundf(width * 0.5), top, roundf(width), _banner_height(title_size, name_size))
	return {"plate": plate, "title": title, "kanji": kanji, "title_size": title_size,
			"title_at": Vector2(center - roundf(title_w * 0.5), title_base), "name_size": name_size,
			"name_at": Vector2(center - roundf(name_w * 0.5), name_base),
			"chips_y": roundf(title_base - title_ascent * 0.5), "title_w": title_w}


## Altura da faixa: título, nome (com a descida) e as folgas.
func _banner_height(title_size: int, name_size: int) -> float:
	return BANNER_PAD + ceilf(_kanji_font.get_ascent(title_size)) + 2.0 + ceilf(_font.get_height(name_size)) \
			+ BANNER_PAD


## Primeira linha livre abaixo do topo da HUD: as duas fileiras de ícones (Hud.top_layout) e a barra
## do chefe com o nome (BossPanel), mais BANNER_GAP.
static func banner_top_clear() -> float:
	var icons := 28.0 + SkillIconPainter.ICON + 3.0 + SkillIconPainter.ICON
	var boss := BossPanel.BAR_Y + BossPanel.BAR_H + 17.0
	return maxf(icons, boss) + BANNER_GAP


## Faixa escura que abre de dentro para fora, o 強敵 grande em ouro com estalo, um ícone de cada
## afixo dos dois lados e o nome do Elite embaixo; fio na cor do 1º afixo e um risco claro que
## corre na entrada.
func _draw_banner() -> void:
	if banner.is_empty() or game == null:
		return
	var age := GameClock.game_time - float(banner["at"])
	var list: Array = banner["affixes"]
	var lay := banner_layout(String(banner["name"]), list, _banner.size, MenuKit.safe_insets(_banner))
	var alpha := clampf((BANNER_TIME - age) / BANNER_FADE, 0.0, 1.0)
	var open := clampf(age / 0.18, 0.0, 1.0)
	var plate: Rect2 = lay["plate"]
	var w := plate.size.x * (1.0 - pow(1.0 - open, 3.0))
	var band := Rect2(plate.get_center().x - w * 0.5, plate.position.y, w, plate.size.y)
	var accent := EliteAffixes.color_of(StringName(list[0])) if not list.is_empty() else AltarFx.GOLD
	_banner.draw_rect(band.grow(1.0), Color(0.0, 0.0, 0.0, 0.5 * alpha))
	_banner.draw_rect(band, Color(0.06, 0.02, 0.05, 0.82 * alpha))
	_banner.draw_rect(Rect2(band.position.x, band.position.y, band.size.x, 1.0), Color(accent, 0.8 * alpha))
	_banner.draw_rect(Rect2(band.position.x, band.end.y - 1.0, band.size.x, 1.0), Color(accent, 0.8 * alpha))
	if open < 1.0:
		return
	var sweep := clampf((age - 0.18) / 0.3, 0.0, 1.0)
	if sweep < 1.0:
		var x := plate.position.x + plate.size.x * sweep
		_banner.draw_rect(Rect2(x - 2.0, plate.position.y + 1.0, 4.0, plate.size.y - 2.0),
				Color(1, 1, 1, 0.6 * (1.0 - sweep)))
	var pop := 1.0 - clampf((age - 0.18) / 0.16, 0.0, 1.0)
	var title_at: Vector2 = lay["title_at"]
	var font_size := int(lay["title_size"])
	var zoom := 1.0 + 0.35 * pop * pop
	var pivot := title_at + Vector2(float(lay["title_w"]) * 0.5, -8.0)
	_banner.draw_set_transform(pivot, 0.0, Vector2(zoom, zoom))
	var local := title_at - pivot
	_banner.draw_string_outline(_kanji_font, local, String(lay["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4,
			Color(0.1, 0.02, 0.0, alpha))
	_banner.draw_string(_kanji_font, local, String(lay["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			Color(AltarFx.GOLD.lerp(Color.WHITE, pop), alpha))
	_banner.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Kanji dos afixos em chips dos dois lados do título.
	var cy := float(lay["chips_y"])
	var title_w := float(lay["title_w"])
	for k: int in list.size():
		var id := StringName(list[k])
		var side := -1.0 if k % 2 == 0 else 1.0
		var slot := floorf(k / 2.0)
		var cx := plate.get_center().x + side * (title_w * 0.5 + 12.0 + slot * 16.0)
		var chip := Rect2(Vector2(roundf(cx - 7.0), roundf(cy - 7.0)), Vector2(14, 14))
		_banner.draw_rect(chip, Color(EliteAffixes.color_of(id).darkened(0.55), alpha))
		_banner.draw_rect(chip, Color(EliteAffixes.color_of(id), alpha), false, 1.0)
		var glyph := EliteAffixes.kanji_of(id)
		var gw := _kanji_font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_banner.draw_string(_kanji_font, Vector2(chip.get_center().x - gw * 0.5, chip.end.y - 2.0), glyph,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, alpha))
	var name_at: Vector2 = lay["name_at"]
	var name_size := int(lay["name_size"])
	_banner.draw_string_outline(_font, name_at, String(banner["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, 3,
			Color(0, 0, 0, 0.9 * alpha))
	_banner.draw_string(_font, name_at, String(banner["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, name_size,
			Color(accent.lerp(Color.WHITE, 0.55), alpha))
