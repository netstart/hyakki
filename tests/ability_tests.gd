extends RefCounted
## Habilidades dos guardiões (.ai/04-habilidades-dos-guardioes.md):
##   run_unit (tests/run_tests.gd, sem autoloads): cada regra de cada energia (HeroEnergy) com os
##     números de data/abilities.json, pagamento com vida da Yuki e save da energia;
##   run (tests/integration_tests.gd): dados, AbilitySystem (desbloqueio, custo, recarga com o
##     atributo, falhas, eventos, poder, ganchos de energia, save/load da partida suspensa),
##     primitivas (inimigos, tiros, jogador), as 3 habilidades da Aki num cenário montado, os
##     outros heróis sem quebrar e o bot usando as habilidades com o mesmo hash na Baixa e na Alta.

const GAME_SCENE := "res://scenes/game/Game.tscn"
const DATA := "res://data/abilities.json"
## Vida dos alvos de teste (não morrem com os golpes).
const HP_MULT := 1000.0
const DT := 1.0 / 60.0
## Passos da partida do bot no teste de determinismo.
const BOT_STEPS := 900
## Passos da partida do bot de cada guardião no nível 10 (as 3 habilidades saem).
const BOT_HERO_STEPS := 3600
const BOT_HERO_START := 240.0
## Energias e habilidades da especificação (ids fixos).
const SPEC := {
	"aki": ["order_flame", "dawn_step", "lantern_wall", "century_flame"],
	"kenta": ["shadow", "shadow_step", "kawarimi", "makibishi"],
	"hana": ["prayer", "harae", "kekkai", "grandmother_seal"],
	"goro": ["penance", "diamond_body", "shakujo", "master_mantra"],
	"rin": ["focus", "hamaya", "hunting_trap", "swallow_leap"],
	"tora": ["forge_heat", "anvil_hammer", "chain_pull", "quench"],
	"yuki": ["oni_blood", "oni_claw", "oni_roar", "onikiri_whirl"],
}

var _check: Callable
var _events: Dictionary = {}


# --- Unitários: HeroEnergy -----------------------------------------------------------------

func run_unit(check: Callable) -> void:
	_check = check
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	check.call(parsed is Array and (parsed as Array).size() == SPEC.size(), "abilities.json: 7 heróis")
	if not parsed is Array:
		return
	var rules: Dictionary = {}
	for row: Variant in parsed:
		rules[String(row["id"])] = (row as Dictionary)["energy"]
	_unit_aki(HeroEnergy.new(rules["aki"]))
	_unit_kenta(HeroEnergy.new(rules["kenta"]))
	_unit_hana(HeroEnergy.new(rules["hana"]))
	_unit_goro(HeroEnergy.new(rules["goro"]))
	_unit_rin(HeroEnergy.new(rules["rin"]))
	_unit_tora(HeroEnergy.new(rules["tora"]))
	_unit_yuki(HeroEnergy.new(rules["yuki"]))
	var e := HeroEnergy.new(rules["aki"])
	e.value = 33.0
	e.since_gain = 2.5
	var copy := HeroEnergy.new(rules["aki"])
	copy.load_state(JSON.parse_string(JSON.stringify(e.state())))
	check.call(is_equal_approx(copy.value, 33.0) and is_equal_approx(copy.since_gain, 2.5), "energia: state/load_state")
	check.call(HeroEnergy.new({}).value == 100.0, "energia sem regras: cheia em 100")


func _near(a: float, b: float, label: String) -> void:
	_check.call(absf(a - b) < 0.001, "%s (esperado %.3f, veio %.3f)" % [label, b, a])


func _unit_aki(e: HeroEnergy) -> void:
	_check.call(e.id == &"order_flame" and is_equal_approx(e.value, 100.0) and is_equal_approx(e.max_value, 100.0),
			"Aki: Chama da Ordem começa cheia (100)")
	e.value = 0.0
	e.step(1.0, false, true)
	_near(e.value, 10.0, "Aki: 5/s dobrado na luz")
	e.value = 0.0
	e.step(1.0, true, false)
	_near(e.value, 2.5, "Aki: metade fora da luz")
	e.value = 99.0
	e.step(1.0, false, true)
	_near(e.value, 100.0, "Aki: não passa do máximo")
	_check.call(not e.pays_with_hp() and e.hp_cost(200.0, 100.0, 100.0) == INF, "Aki: não paga com vida")
	_check.call(e.pay(200.0, 100.0, 100.0) < 0.0 and is_equal_approx(e.value, 100.0), "Aki: sem energia não gasta")
	_near(e.pay(25.0), 0.0, "Aki: paga só com energia")
	_near(e.value, 75.0, "Aki: custo sai da energia")


func _unit_kenta(e: HeroEnergy) -> void:
	_near(e.value, 50.0, "Kenta: Sombra começa em 50")
	e.value = 0.0
	e.step(1.0, true, true)
	_near(e.value, 8.0, "Kenta: 8/s em movimento")
	e.value = 0.0
	e.step(1.0, false, true)
	_near(e.value, 2.0, "Kenta: 2/s parado")
	e.value = 0.0
	e.step(1.0, true, false)
	_near(e.value, 12.0, "Kenta: ×1,5 fora da luz")


func _unit_hana(e: HeroEnergy) -> void:
	_near(e.value, 120.0, "Hana: Prece começa cheia (120)")
	e.value = 0.0
	e.step(1.0, false, true)
	_near(e.value, 4.0, "Hana: 4/s sem regeneração")
	var stats := StatBlock.new()
	stats.set_source("t", {"regen": 1.5})
	e.value = 0.0
	e.step(1.0, true, false, stats)
	_near(e.value, 7.0, "Hana: + 2 × atributo regen")


func _unit_goro(e: HeroEnergy) -> void:
	_near(e.value, 0.0, "Goro: Penitência começa vazia")
	e.step(1.0, false, true)
	_near(e.value, 1.5, "Goro: 1,5/s de base")
	e.on_damage_taken(10.0)
	_near(e.value, 16.5, "Goro: +1,5 por vida perdida")
	e.on_kill()
	_near(e.value, 17.1, "Goro: +0,6 por abate")
	e.step(3.0, false, true)
	_near(e.value, 21.6, "Goro: segue ganhando até 4 s sem evento")
	e.step(1.0, false, true)
	_near(e.value, 19.6, "Goro: perde 2/s depois de 4 s sem ganhar")
	e.on_hit(5)
	_check.call(e.since_gain > 0.0, "Goro: acerto de arma não conta como ganho")
	e.on_kill()
	e.step(1.0, false, true)
	_near(e.value, 21.7, "Goro: abate volta a esquentar")


func _unit_rin(e: HeroEnergy) -> void:
	_near(e.value, 100.0, "Rin: Foco começa cheio")
	e.value = 0.0
	e.step(1.0, false, false)
	_near(e.value, 14.0, "Rin: 14/s parada")
	e.value = 0.0
	e.step(1.0, true, true)
	_near(e.value, 4.0, "Rin: 4/s em movimento")


func _unit_tora(e: HeroEnergy) -> void:
	_near(e.value, 0.0, "Tora: Calor começa frio")
	e.step(1.0, true, true)
	_near(e.value, 0.0, "Tora: não esquenta sozinho")
	e.on_hit(5)
	_near(e.value, 2.5, "Tora: +0,5 por acerto")
	e.on_kill()
	_near(e.value, 3.5, "Tora: +1 por abate")
	e.step(2.9, false, true)
	_near(e.value, 3.5, "Tora: segura o calor até 3 s")
	e.step(0.5, false, true)
	_near(e.value, 2.0, "Tora: perde 3/s depois de 3 s sem acertar")


func _unit_yuki(e: HeroEnergy) -> void:
	_near(e.value, 30.0, "Yuki: Sangue Oni começa em 30")
	e.step(1.0, true, true)
	_near(e.value, 28.0, "Yuki: a luz queima 2/s")
	e.step(1.0, true, false)
	_near(e.value, 30.0, "Yuki: +2/s fora da luz")
	e.on_kill()
	_near(e.value, 33.0, "Yuki: +3 por abate")
	e.value = 10.0
	_near(e.hp_cost(25.0, 100.0, 100.0), 7.5, "Yuki: falta paga com vida (1 por 2)")
	_check.call(e.hp_cost(25.0, 35.0, 100.0) == INF and not e.can_afford(25.0, 35.0, 100.0),
			"Yuki: não paga com vida abaixo de 30%")
	_check.call(e.pay(25.0, 35.0, 100.0) < 0.0 and is_equal_approx(e.value, 10.0), "Yuki: recusa sem gastar")
	_near(e.pay(25.0, 100.0, 100.0), 7.5, "Yuki: pagamento devolve a vida a tirar")
	_near(e.value, 0.0, "Yuki: energia zera ao pagar com vida")
	e.value = 40.0
	_near(e.pay(25.0, 100.0, 100.0), 0.0, "Yuki: com energia não usa vida")


# --- Integração ---------------------------------------------------------------------------

func run(host: Node, check: Callable) -> void:
	_check = check
	_check_data()
	# Save com todos os power-ups no máximo (como depois dos testes do Santuário): os cenários não
	# podem depender do que outros testes compraram (neutral_stats).
	var powerups: Dictionary = SaveManager.data["powerups"]
	var saved_powerups := powerups.duplicate()
	for id: StringName in DB.ids("powerups"):
		powerups[String(id)] = 5
	var game := await _new_game(host, "aki", 21)
	_check_system(game)
	_check_primitives(game)
	_check_player(game)
	_check_aki(game)
	await _check_save(host, game)
	game.queue_free()
	await host.get_tree().process_frame
	await _check_energy_hooks(host)
	await (load("res://tests/ability_goro_tests.gd") as GDScript).new().run(host, check, self)
	await (load("res://tests/ability_tora_tests.gd") as GDScript).new().run(host, check, self)
	await (load("res://tests/ability_kenta_tests.gd") as GDScript).new().run(host, check)
	await (load("res://tests/ability_hana_tests.gd") as GDScript).new().run(host, check)
	await (load("res://tests/ability_rin_tests.gd") as GDScript).new().run(host, check)
	await (load("res://tests/ability_yuki_tests.gd") as GDScript).new().run(host, check)
	await (load("res://tests/ability_status_tests.gd") as GDScript).new().run(host, check)
	await _check_other_heroes(host)
	await _check_bot_determinism(host)
	await _check_bot_every_hero(host)
	SaveManager.data["powerups"] = saved_powerups
	GameClock.paused = false
	await host.get_tree().process_frame


func _check_data() -> void:
	InputSetup.ensure_actions()
	_check.call(DB.abilities.size() == SPEC.size(), "DB: 7 heróis com habilidades")
	var icons := "res://assets/art/ui/ability_icons/"
	for hero: String in SPEC:
		var ids: Array = SPEC[hero]
		var data := DB.hero_abilities(StringName(hero))
		_check.call(DB.heroes.has(StringName(hero)), "habilidades: herói %s existe" % hero)
		var energy: Dictionary = data.get("energy", {})
		_check.call(String(energy.get("id", "")) == ids[0], "%s: energia %s" % [hero, ids[0]])
		_check.call(Color.html_is_valid(String(energy.get("color", ""))) and float(energy.get("max", 0)) > 0.0,
				"%s: energia com cor e máximo" % hero)
		_check.call(String(energy.get("icon", "")) == icons + "energy_%s.png" % ids[0], "%s: ícone da energia" % hero)
		var list: Array = data.get("abilities", [])
		_check.call(list.size() == 3, "%s: 3 habilidades" % hero)
		for k: int in range(mini(3, list.size())):
			var a: Dictionary = list[k]
			var id := String(a["id"])
			_check.call(id == ids[k + 1], "%s: habilidade %d é %s" % [hero, k + 1, ids[k + 1]])
			_check.call(int(a.get("level", 0)) == [1, 5, 10][k], "%s: nível %d" % [id, [1, 5, 10][k]])
			_check.call(float(a.get("cost", 0)) > 0.0 and float(a.get("cooldown", 0)) > 0.0, "%s: custo e recarga" % id)
			_check.call(float(a["cost"]) <= float(energy.get("max", 0)), "%s: custo cabe na energia" % id)
			_check.call(not String(a.get("kanji", "")).is_empty(), "%s: kanji" % id)
			_check.call(String(a.get("icon", "")) == icons + id + ".png", "%s: caminho do ícone" % id)
			_check.call(String(a.get("voice", "")) == "%s_%d" % [hero, k + 1], "%s: voz %s_%d" % [id, hero, k + 1])
			_check.call(String(a.get("sfx", "")) == "ab_" + id, "%s: som ab_%s" % [id, id])
			_check.call(not DB.weapons.has(StringName(id)), "%s: id não colide com arma" % id)
			_check.call(DB.ability(StringName(id)) == a, "DB.ability(%s)" % id)
			_check.call((a.get("bot", {}) as Dictionary).has("near"), "%s: regra do bot" % id)
	var aki: Array = DB.hero_abilities(&"aki")["abilities"]
	_check.call(HeroAbilities.param(aki[0], "distance") == 90.0 and HeroAbilities.param(aki[0], "damage") == 40.0
			and float(aki[0]["cost"]) == 25.0 and float(aki[0]["cooldown"]) == 4.0, "Passo da Aurora: 90 px, 40, 25, 4 s")
	_check.call(HeroAbilities.param(aki[1], "radius") == 70.0 and HeroAbilities.param(aki[1], "burn") == 12.0
			and HeroAbilities.param(aki[1], "tick") == 0.25 and HeroAbilities.param(aki[1], "time") == 3.0,
			"Muralha da Lanterna: r 70, 12 a cada 0,25 s, 3 s")
	_check.call(HeroAbilities.param(aki[2], "damage") == 120.0 and HeroAbilities.param(aki[2], "ground_damage") == 15.0
			and HeroAbilities.param(aki[2], "reach") == 160.0, "Chama de Cem Anos: 120, brasa 15, alcance 160")
	for slot: int in range(3):
		_check.call(InputMap.has_action(AbilitySystem.ACTIONS[slot]), "entrada %s existe" % AbilitySystem.ACTIONS[slot])
	_check.call(_has_key(&"ability_1", KEY_1) and _has_key(&"ability_1", KEY_J) and _has_key(&"ability_3", KEY_L),
			"habilidades nas teclas 1/2/3 e J/K/L")
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"pause", &"speed", &"ultimate"]:
		for slot: int in range(3):
			for event: InputEvent in InputMap.action_get_events(AbilitySystem.ACTIONS[slot]):
				_check.call(not InputMap.action_has_event(action, event),
						"%s não conflita com %s" % [AbilitySystem.ACTIONS[slot], action])


func _has_key(action: StringName, key: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == key:
			return true
	return false


func _new_game(host: Node, hero: String, seed_value: int, bot: bool = false) -> HyakkiGame:
	var scene := load(GAME_SCENE) as PackedScene
	var game := scene.instantiate() as HyakkiGame
	game.config = {"hero": hero, "stage": "village", "moon": 0, "mode": "normal", "seed": seed_value, "speed": 1}
	game._bot = bot
	host.add_child(game)
	await host.get_tree().process_frame
	GameClock.paused = true
	game.player.god_mode = true
	neutral_stats(game)
	_clear(game)
	return game


## Atributos só do herói: tira os power-ups do Santuário e os bônus da Loja que o save de teste
## pode ter acumulado em outros testes (ou numa rodada interrompida). Sem isso, área, poder e
## armadura mudam os raios e danos dos cenários conforme a ordem dos testes.
static func neutral_stats(game: HyakkiGame) -> void:
	var stats := game.player.stats
	stats.set_source("powerups", {})
	stats.set_source("shop", {})
	game.player.hp = game.player.max_hp()


func _clear(game: HyakkiGame) -> void:
	for i: int in range(EnemyManager.CAPACITY):
		if game.enemies.alive[i] == 1:
			game.enemies.despawn(i)
	game.enemies.spatial.clear()
	game.enemy_shots.clear_all()
	game.player.sim_pos = Vector2.ZERO
	game.player.prev_pos = Vector2.ZERO
	game.player.velocity = Vector2.ZERO
	game.player.move_input = Vector2.ZERO
	game.player.invuln = 0.0


func _spawn(game: HyakkiGame, at: Vector2, id: StringName = &"slime_rice") -> int:
	var i := game.enemies.spawn(id, at, HP_MULT, 1.0)
	game.enemies.speed[i] = 35.0
	_reindex(game)
	return i


func _reindex(game: HyakkiGame) -> void:
	game.enemies.spatial.rebuild(game.enemies.pos, game.enemies.alive, EnemyManager.CAPACITY)


func _lost(game: HyakkiGame, i: int) -> float:
	return game.enemies.max_hp[i] - game.enemies.hp[i]


## Passos só do que as habilidades mexem (sem spawner, chefes, armas nem pickups).
func _tick(game: HyakkiGame, steps: int) -> void:
	for _k: int in range(steps):
		GameClock.game_time += DT
		game.step_index += 1
		game.player.step(DT)
		game.enemies.step(DT)
		game.enemy_shots.step(DT)
		game.abilities.step(DT)


func _listen() -> Array[Callable]:
	_events = {"used": [], "failed": [], "ready": [], "unlocked": []}
	var calls: Array[Callable] = [
		func(_h: StringName, slot: int, id: StringName, kanji: String) -> void:
			(_events["used"] as Array).append([slot, id, kanji]),
		func(slot: int, reason: int) -> void: (_events["failed"] as Array).append([slot, reason]),
		func(slot: int) -> void: (_events["ready"] as Array).append(slot),
		func(slot: int, id: StringName) -> void: (_events["unlocked"] as Array).append([slot, id]),
	]
	Events.ability_used.connect(calls[0])
	Events.ability_failed.connect(calls[1])
	Events.ability_ready.connect(calls[2])
	Events.ability_unlocked.connect(calls[3])
	return calls


func _unlisten(calls: Array[Callable]) -> void:
	Events.ability_used.disconnect(calls[0])
	Events.ability_failed.disconnect(calls[1])
	Events.ability_ready.disconnect(calls[2])
	Events.ability_unlocked.disconnect(calls[3])


## Desbloqueio, custo, recarga (× atributo), falhas com motivo, eventos, poder e leitura da UI.
func _check_system(game: HyakkiGame) -> void:
	var ab := game.abilities
	var fail := AbilitySystem.Fail
	var calls := _listen()
	GameClock.paused = false
	_check.call(ab.behavior is AkiAbilities, "Aki usa o comportamento AkiAbilities")
	_check.call(ab.energy_id() == &"order_flame" and ab.energy_max() == 100.0 and ab.energy_value() == 100.0,
			"Aki começa com a Chama da Ordem cheia")
	_check.call(ab.energy_color() == Color("ffb347"), "cor da energia vem do JSON")
	_check.call(ab.slot_count() == 3 and ab.ability_id(2) == &"century_flame", "3 slots na ordem do JSON")
	_check.call(ab.is_unlocked(0) and not ab.is_unlocked(1) and not ab.is_unlocked(2), "nível 1: só a 1ª liberada")
	_check.call(ab.required_level(1) == 5 and ab.required_level(2) == 10, "níveis exigidos 5 e 10")
	_check.call(not ab.activate(1) and ab.last_failure == fail.LOCKED, "travada: falha LOCKED")
	_check.call(ab.check(7) == fail.MISSING, "slot inexistente: MISSING")
	_check.call(ab.activate(0), "Passo da Aurora sai no nível 1")
	_check.call(is_equal_approx(ab.energy_value(), 75.0), "custo de 25 sai da energia")
	_check.call(is_equal_approx(ab.cooldown_left(0), 4.0) and is_equal_approx(ab.cooldown_fraction(0), 1.0),
			"recarga de 4 s começa cheia")
	_check.call(not ab.activate(0) and ab.last_failure == fail.COOLDOWN, "em recarga: falha COOLDOWN")
	_check.call(game.tracker.abilities == 1 and int(game.tracker.ability_uses.get(&"dawn_step", 0)) == 1,
			"RunTracker conta o uso")
	_check.call(ab.uses == 1 and ab.uses_by_slot[0] == 1, "AbilitySystem conta o uso por slot")
	var used: Array = _events["used"]
	_check.call(used.size() == 1 and used[0][1] == &"dawn_step" and used[0][2] == "暁閃",
			"Events.ability_used com id e kanji")
	_check.call(not ab.banner.is_empty() and ab.layer.banner_visible(), "letreiro acima do herói")
	_check.call((_events["failed"] as Array).size() == 2 and _events["failed"][0] == [1, fail.LOCKED],
			"Events.ability_failed com o motivo")
	game.player.stats.set_source("test", {"cooldown": -0.5})
	_check.call(is_equal_approx(ab.cooldown_total(0), 2.0), "recarga × atributo cooldown")
	ab.cooldowns[0] = 0.0
	ab.activate(0)
	_check.call(is_equal_approx(ab.cooldown_left(0), 2.0), "recarga com o atributo ao usar")
	game.player.stats.set_source("test", {})
	ab.cooldowns[0] = DT * 0.5
	_tick(game, 12)
	_check.call((_events["ready"] as Array).has(0) and ab.is_ready(0), "Events.ability_ready ao fim da recarga")
	ab.energy.value = 10.0
	_check.call(not ab.can_pay(0) and not ab.activate(0) and ab.last_failure == fail.NO_ENERGY
			and is_equal_approx(ab.energy_value(), 10.0), "sem energia: NO_ENERGY e nada gasto")
	_check.call(ab.hp_price(0) == INF, "Aki não paga com vida")
	ab.energy.value = 100.0
	GameClock.paused = true
	_check.call(not ab.activate(0) and ab.last_failure == fail.PAUSED, "pausado: PAUSED")
	GameClock.paused = false
	game.player.is_alive = false
	_check.call(not ab.activate(0) and ab.last_failure == fail.DEAD, "morto: DEAD")
	game.player.is_alive = true
	game.level = 10
	_check.call(is_equal_approx(ab.power(), 1.0 + 0.035 * 9.0), "poder = 1 + 0,035 × (nível − 1)")
	_tick(game, 1)
	var unlocked: Array = _events["unlocked"]
	_check.call(unlocked.size() == 2 and unlocked[0] == [1, &"lantern_wall"] and unlocked[1] == [2, &"century_flame"],
			"Events.ability_unlocked nos níveis 5 e 10")
	_check.call(ab.is_unlocked(1) and ab.is_unlocked(2), "nível 10: as 3 liberadas")
	game.level = 1
	_unlisten(calls)
	_clear(game)
	_reset_abilities(game)


func _reset_abilities(game: HyakkiGame) -> void:
	game.abilities.reset()
	game.player.dash_time = 0.0
	GameClock.paused = false


# --- Primitivas ------------------------------------------------------------------------------

func _check_primitives(game: HyakkiGame) -> void:
	var enemies := game.enemies
	GameClock.paused = false
	game.player.sim_pos = Vector2(0, -70)
	# Controle versus um inimigo de referência (mesma distância do herói, do outro lado).
	var control := _spawn(game, Vector2(-60, -10))
	var slowed := _spawn(game, Vector2(60, -10))
	_check.call(enemies.slow_circle(Vector2(60, -10), 8.0, 0.5, 2.0) == 1, "slow_circle pega só quem está no círculo")
	var c0 := enemies.pos[control]
	var s0 := enemies.pos[slowed]
	_tick(game, 40)
	var moved_control := enemies.pos[control].distance_to(c0)
	var moved_slowed := enemies.pos[slowed].distance_to(s0)
	_check.call(moved_slowed < moved_control * 0.7 and moved_slowed > 0.0,
			"lentidão −50%% anda menos (%.1f × %.1f)" % [moved_slowed, moved_control])
	enemies.apply_slow(slowed, 0.8, 1.0)
	_check.call(is_equal_approx(enemies.slow_mult[slowed], 0.5), "lentidão: vale a mais forte em curso")
	_clear(game)
	game.player.sim_pos = Vector2(0, -70)
	var rooted := _spawn(game, Vector2(40, 0))
	_check.call(enemies.root_circle(Vector2(40, 0), 10.0, 1.0, 1) == 1, "root_circle respeita o máximo")
	var r0 := enemies.pos[rooted]
	_tick(game, 30)
	_check.call(enemies.pos[rooted].distance_to(r0) < 0.01, "preso não anda")
	_tick(game, 40)
	_check.call(enemies.pos[rooted].distance_to(r0) > 1.0, "a raiz acaba")
	_clear(game)
	var scared := _spawn(game, Vector2(30, 0))
	_check.call(enemies.fear_circle(Vector2.ZERO, 50.0, 1.0) == 1, "fear_circle")
	_tick(game, 30)
	_check.call(enemies.pos[scared].x > 35.0, "medo: foge do ponto (x=%.1f)" % enemies.pos[scared].x)
	_clear(game)
	var lured := _spawn(game, Vector2(30, 0))
	enemies.lure_circle(Vector2.ZERO, 50.0, Vector2(30, 60), 2.0)
	_tick(game, 60)
	_check.call(enemies.pos[lured].y > 15.0 and enemies.pos[lured].distance_to(Vector2(30, 60)) < 45.0,
			"isca: persegue o ponto e não o herói (%s)" % enemies.pos[lured])
	_clear(game)
	game.player.sim_pos = Vector2(0, 80)
	var pulled := _spawn(game, Vector2(70, 0))
	enemies.pull_to(Vector2.ZERO, 100.0, 12.0)
	_tick(game, 24)
	_check.call(enemies.pos[pulled].length() < 22.0,
			"pull_to arrasta até perto do ponto (%.1f)" % enemies.pos[pulled].length())
	_clear(game)
	_check_boss_resist(game)
	_check_queries(game)
	_check_shots(game)
	_clear(game)


func _check_boss_resist(game: HyakkiGame) -> void:
	var enemies := game.enemies
	var boss := _spawn(game, Vector2(20, 0), DB.ids("bosses")[0])
	var common := _spawn(game, Vector2(-20, 0))
	enemies.slow_circle(Vector2.ZERO, 60.0, 0.5, 2.0)
	enemies.root_circle(Vector2.ZERO, 60.0, 2.0)
	enemies.fear_circle(Vector2.ZERO, 60.0, 2.0)
	_check.call(enemies.slow[boss] == 0.0 and enemies.root[boss] == 0.0 and enemies.fear[boss] == 0.0,
			"chefe ignora lentidão, raiz e medo")
	_check.call(enemies.root[common] > 0.0 and enemies.fear[common] > 0.0, "comum leva raiz e medo")
	enemies.stun_circle(Vector2.ZERO, 60.0, 2.0)
	_check.call(is_equal_approx(enemies.stun[boss], 2.0 * EnemyManager.BOSS_STUN)
			and is_equal_approx(enemies.stun[common], 2.0),
			"atordoamento em área: chefe só %d%%" % roundi(EnemyManager.BOSS_STUN * 100.0))
	enemies.stun_one(boss, 2.5)
	_check.call(is_equal_approx(enemies.stun[boss], 2.5), "stun_one atordoa o chefe pelo tempo cheio")
	var at := enemies.pos[boss]
	enemies.pull_to(Vector2(-200, 0), 400.0)
	enemies.push_out_of(Vector2(20, 0), 50.0, 200.0)
	_check.call(enemies.pos[boss] == at, "chefe não é puxado nem empurrado")
	_clear(game)


func _check_queries(game: HyakkiGame) -> void:
	var enemies := game.enemies
	var on_line := _spawn(game, Vector2(50, 0))
	var off_line := _spawn(game, Vector2(50, 40))
	var behind := _spawn(game, Vector2(-50, 0))
	var out: Array[int] = []
	enemies.query_segment(Vector2.ZERO, Vector2(100, 0), 5.0, out)
	_check.call(out.size() == 1 and out[0] == on_line, "query_segment: só quem toca a linha")
	enemies.query_cone(Vector2.ZERO, Vector2.RIGHT, deg_to_rad(30.0), 80.0, out)
	_check.call(out.has(on_line) and not out.has(off_line) and not out.has(behind), "query_cone: só dentro do leque")
	enemies.query_cone(Vector2.ZERO, Vector2.RIGHT, deg_to_rad(45.0), 80.0, out)
	_check.call(out.has(off_line) and not out.has(behind), "query_cone: leque mais aberto pega o de lado")
	_check.call(enemies.count_in_circle(Vector2.ZERO, 60.0) == 3 and enemies.count_in_circle(Vector2(-50, 0), 10.0) == 1,
			"count_in_circle")
	_clear(game)
	for k: int in range(4):
		_spawn(game, Vector2(60, 30) + Vector2.from_angle(k * 1.6) * 4.0)
	_spawn(game, Vector2(-50, 0))
	var best := enemies.densest_point(Vector2.ZERO, 160.0, 20.0)
	_check.call(best.distance_to(Vector2(60, 30)) < 8.0, "densest_point acha o maior grupo (%s)" % best)
	_check.call(enemies.densest_point(Vector2(500, 500), 50.0, 20.0) == Vector2.INF, "densest_point sem ninguém: INF")
	_clear(game)
	var inside := _spawn(game, Vector2(10, 0))
	_check.call(enemies.push_out_of(Vector2.ZERO, 40.0, 100.0) == 1, "push_out_of")
	_check.call(enemies.pos[inside].length() >= 40.0 and enemies.vel[inside].x > 0.0,
			"push_out_of: vai para a borda e para fora")


func _check_shots(game: HyakkiGame) -> void:
	var shots := game.enemy_shots
	shots.clear_all()
	for at: Vector2 in [Vector2(20, 0), Vector2(0, 50), Vector2(-20, 0)]:
		shots.spawn(at, Vector2.ZERO, 1.0, "fireball", 9.0)
	_check.call(shots.clear_cone(Vector2.ZERO, Vector2.RIGHT, 0.5, 40.0) == 1 and shots.cleared[0] == Vector2(20, 0),
			"clear_cone apaga só o tiro do leque")
	_check.call(shots.clear_circle(Vector2.ZERO, 60.0, 30.0) == 1 and shots.cleared[0] == Vector2(0, 50),
			"clear_circle com faixa apaga só o anel")
	_check.call(shots.count_alive == 1 and shots.clear_circle(Vector2.ZERO, 30.0) == 1 and shots.count_alive == 0,
			"clear_circle cheio")


func _check_player(game: HyakkiGame) -> void:
	var player := game.player
	player.god_mode = false
	_clear(game)
	player.add_guard(0.4, 1.0)
	_check.call(is_equal_approx(player.take_damage(10.0), 4.0), "redução de dano temporária (−60%)")
	_tick(game, 70)
	player.invuln = 0.0
	_check.call(is_equal_approx(player.take_damage(10.0), 10.0), "a redução acaba")
	player.invuln = 0.0
	player.add_armor(3.0, 1.0)
	_check.call(is_equal_approx(player.take_damage(10.0), 7.0), "armadura temporária")
	_tick(game, 70)
	player.invuln = 0.0
	_check.call(is_equal_approx(player.take_damage(10.0), 10.0), "a armadura acaba")
	player.hp = player.max_hp()
	_clear(game)
	player.add_thorns(0.5, 2.0, &"diamond_body")
	var biter := _spawn(game, Vector2(3, 0))
	game.enemies.contact_cd[biter] = 0.0
	var contact := game.enemies.dmg[biter]
	_tick(game, 1)
	_check.call(is_equal_approx(_lost(game, biter), contact * 0.5),
			"espinhos devolvem 50%% do contato (%.2f)" % _lost(game, biter))
	_check.call(game.tracker.damage_by_weapon.has(&"diamond_body"), "espinhos registrados pela fonte")
	player.thorns_time = 0.0
	_clear(game)
	_spawn(game, Vector2(0, 50))
	_check.call(player.aim_direction(Player.Aim.NEAREST).distance_to(Vector2.DOWN) < 0.01, "mira no inimigo mais próximo")
	player.facing = Vector2.LEFT
	_check.call(player.aim_direction() == Vector2.LEFT, "parado: mira na última direção")
	player.move_input = Vector2(0, -1)
	_check.call(player.aim_direction(Player.Aim.MOVE) == Vector2.UP, "andando: mira no movimento")
	_clear(game)
	player.sim_pos = Vector2(-45, 0)
	player.dash(Vector2.RIGHT, 90.0, 0.16, 0.1)
	_check.call(player.is_dashing() and player.invuln > 0.16, "avanço fica invencível")
	_check.call(player.take_damage(10.0) == 0.0, "nada fere durante o avanço")
	_tick(game, 12)
	_check.call(absf(player.sim_pos.x - 45.0) < 1.5 and not player.is_dashing(),
			"avanço de 90 px (x=%.1f)" % player.sim_pos.x)
	player.sim_pos = Vector2.ZERO
	_check.call(player.blink(Vector2.LEFT, 30.0).distance_to(Vector2(-30, 0)) < 0.01, "teleporte instantâneo")
	var bounds := game.world.bounds
	game.world.bounds = Vector2(40, 40)
	player.sim_pos = Vector2(20, 0)
	player.dash(Vector2.RIGHT, 90.0, 0.16)
	_tick(game, 12)
	_check.call(player.sim_pos.x <= 40.0 + 0.001, "avanço não passa da borda da arena")
	game.world.bounds = bounds
	player.hp = player.max_hp()
	player.god_mode = true
	_clear(game)


# --- Aki ---------------------------------------------------------------------------------

func _check_aki(game: HyakkiGame) -> void:
	var ab := game.abilities
	_reset_abilities(game)
	var aki := ab.behavior as AkiAbilities
	game.level = 10
	var power := ab.power()
	var might := game.player.stats.get_stat("might")
	# 1. Passo da Aurora: corta quem está no caminho, uma vez cada.
	_clear(game)
	game.player.sim_pos = Vector2(-45, 0)
	game.player.move_input = Vector2.RIGHT
	var a := _spawn(game, Vector2(-10, 0))
	var b := _spawn(game, Vector2(20, 2))
	var off := _spawn(game, Vector2(0, 45))
	_check.call(ab.activate(0), "Passo da Aurora sai")
	_tick(game, 14)
	var cut := 40.0 * might * power
	_check.call(absf(_lost(game, a) - cut) < 0.01 and absf(_lost(game, b) - cut) < 0.01,
			"Passo da Aurora: corta todos no caminho uma vez (%.1f, %.1f de %.1f)" % [_lost(game, a), _lost(game, b), cut])
	_check.call(_lost(game, off) == 0.0, "Passo da Aurora: quem está fora do caminho fica")
	_check.call(game.player.sim_pos.x > 40.0, "Passo da Aurora: avança 90 px")
	_check.call(game.tracker.damage_by_weapon.has(&"dawn_step"), "dano registrado pela habilidade")
	_check.call(aki.has_visuals(), "rastro de luz fica na tela")
	# 2. Muralha da Lanterna: empurra quem está dentro, apaga tiros, queima a borda.
	_clear(game)
	game.player.move_input = Vector2.ZERO
	var inside := _spawn(game, Vector2(25, 0))
	var outside := _spawn(game, Vector2(-86, 0))
	game.enemy_shots.spawn(Vector2(0, -110), Vector2(0, 160), 5.0, "fireball", 5.0)
	var hp := game.player.hp
	_check.call(ab.activate(1), "Muralha da Lanterna sai")
	var r := 70.0 * game.player.stats.get_stat("area")
	_tick(game, 15)
	_check.call(game.enemies.pos[inside].length() >= r - 6.0, "Muralha: empurra para fora quem estava dentro")
	_tick(game, 60)
	_check.call(game.enemy_shots.count_alive == 0 and is_equal_approx(game.player.hp, hp), "Muralha: apaga o tiro no anel")
	_check.call(_lost(game, inside) >= 12.0 * might * power * 3.0 - 0.01, "Muralha: queima quem está na borda")
	_tick(game, 120)
	_check.call(game.enemies.pos[outside].length() >= r - 6.0, "Muralha: quem chega não entra")
	_check.call(_lost(game, outside) > 0.0, "Muralha: quem chega na borda queima")
	_tick(game, 30)
	_check.call(not aki.has_visuals() or aki._wall_time <= 0.0, "Muralha: acaba em 3 s")
	# 3. Chama de Cem Anos: no maior grupo, coluna depois de 0,5 s e chão em brasa.
	_clear(game)
	var group: Array[int] = []
	for k: int in range(5):
		group.append(_spawn(game, Vector2(70, 30) + Vector2.from_angle(k * 1.3) * 5.0))
		game.enemies.speed[group[k]] = 0.0
	var lone := _spawn(game, Vector2(-70, 0))
	_check.call(ab.activate(2), "Chama de Cem Anos sai")
	_check.call(aki._flames.size() == 1 and (aki._flames[0]["to"] as Vector2).distance_to(Vector2(70, 30)) < 8.0,
			"Chama: mira no maior grupo")
	_tick(game, 20)
	_check.call(_lost(game, group[0]) == 0.0, "Chama: a coluna espera 0,5 s")
	_tick(game, 12)
	var column := 120.0 * might * power
	var all_hit := true
	for i: int in group:
		all_hit = all_hit and _lost(game, i) >= column - 0.01
	_check.call(all_hit and _lost(game, lone) == 0.0, "Chama: coluna de fogo (%.0f) só no grupo" % column)
	_check.call(aki._grounds.size() == 1, "Chama: chão em brasa")
	var before := _lost(game, group[0])
	_tick(game, 62)
	_check.call(_lost(game, group[0]) - before >= 15.0 * might * power * 2.0 - 0.01, "Chama: o chão queima a cada 0,5 s")
	_tick(game, 200)
	_check.call(aki._grounds.is_empty(), "Chama: o chão apaga em 4 s")
	game.level = 1
	_clear(game)
	_reset_abilities(game)


## Partida suspensa: energia, recargas e efeitos persistentes da Aki voltam iguais.
func _check_save(host: Node, game: HyakkiGame) -> void:
	var ab := game.abilities
	game.level = 10
	_clear(game)
	_spawn(game, Vector2(60, 0))
	ab.activate(1)
	ab.activate(2)
	_tick(game, 40)
	ab.activate(0)
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	# Antes do próximo quadro (o relógio solto anda as duas partidas um passo).
	var before := JSON.stringify(ab.state())
	var hash_before := ab.hash_tag()
	var tracked := game.tracker.abilities
	var second := await _new_game(host, "aki", 21)
	second.restore_snapshot(snap)
	var after := JSON.stringify(second.abilities.state())
	_check.call(after == before, "partida retomada mantém energia, recargas e efeitos das habilidades")
	_check.call(second.tracker.abilities == tracked, "partida retomada mantém RunTracker.abilities")
	_check.call(second.abilities.hash_tag() == hash_before, "partida retomada: mesmo hash das habilidades")
	_check.call((second.abilities.behavior as AkiAbilities)._grounds.size() == 1
			and (second.abilities.behavior as AkiAbilities)._wall_time > 0.0, "partida retomada: chão em brasa e muralha")
	second.queue_free()
	await host.get_tree().process_frame
	GameClock.paused = true


## Ganchos de energia na partida: dano recebido (Goro), acerto de arma e abate (Tora), luz.
func _check_energy_hooks(host: Node) -> void:
	var goro := await _new_game(host, "goro", 5)
	goro.player.god_mode = false
	var e := goro.abilities.energy
	e.value = 0.0
	var taken := goro.player.take_damage(10.0)
	_check.call(taken > 0.0 and is_equal_approx(e.value, 1.5 * taken), "Goro: Penitência com o dano recebido")
	goro.queue_free()
	await host.get_tree().process_frame
	var tora := await _new_game(host, "tora", 5)
	var heat := tora.abilities.energy
	var target := _spawn(tora, Vector2(30, 0))
	tora.deal_damage(&"kusarigama", target, 1.0, Vector2.RIGHT, 0.0)
	_check.call(is_equal_approx(heat.value, 0.5), "Tora: acerto de arma esquenta")
	tora.deal_damage(&"anvil_hammer", target, 1.0, Vector2.RIGHT, 0.0)
	tora.deal_damage(&"kusarigama", target, 1.0, Vector2.RIGHT, 0.0, false, true)
	_check.call(is_equal_approx(heat.value, 0.5), "Tora: dano de habilidade e tique contínuo não esquentam")
	var weak := tora.enemies.spawn(&"slime_rice", Vector2(-30, 0), 0.01, 1.0)
	tora.deal_damage(&"kusarigama", weak, 999.0, Vector2.RIGHT, 0.0)
	_check.call(is_equal_approx(heat.value, 0.5 + 0.5 + 1.0), "Tora: abate esquenta")
	tora.lantern.radius = 30.0
	_check.call(not tora.abilities.hero_in_light(), "lanterna fraca: fora da luz")
	tora.queue_free()
	await host.get_tree().process_frame
	var yuki := await _new_game(host, "yuki", 5)
	var ab := yuki.abilities
	GameClock.paused = false
	ab.energy.value = 10.0
	var hp := yuki.player.hp
	_check.call(is_equal_approx(ab.hp_price(0), 7.5) and ab.activate(0), "Yuki: paga a falta com vida")
	_check.call(is_equal_approx(yuki.player.hp, hp - 7.5) and ab.energy_value() == 0.0, "Yuki: vida e energia descontadas")
	ab.cooldowns[0] = 0.0
	yuki.player.hp = yuki.player.max_hp() * 0.32
	_check.call(not ab.activate(0) and ab.last_failure == AbilitySystem.Fail.NO_ENERGY, "Yuki: abaixo de 30% não paga")
	yuki.queue_free()
	await host.get_tree().process_frame


## Heróis com o comportamento padrão: as 3 saem, contam e nada quebra no passo.
func _check_other_heroes(host: Node) -> void:
	for hero: String in SPEC:
		if hero == "aki":
			continue
		var game := await _new_game(host, hero, 9)
		var ab := game.abilities
		GameClock.paused = false
		game.level = 10
		# Um alvo no alcance (o Selo da Avó não sai sem ninguém).
		_spawn(game, Vector2(60, 0))
		var ok := ab.behavior != null
		for slot: int in range(3):
			ab.energy.value = ab.energy_max()
			ok = ab.activate(slot) and ok
		_tick(game, 30)
		_check.call(ok and ab.uses == 3 and game.tracker.abilities == 3, "%s: as 3 habilidades saem e contam" % hero)
		_check.call(ab.state().has("behavior") and not ab.hash_tag().is_empty(), "%s: state e hash" % hero)
		game.queue_free()
		await host.get_tree().process_frame
	GameClock.paused = true


## Bot com as habilidades liberadas: usa as 3, e o mesmo estado sai na Baixa e na Alta.
func _check_bot_determinism(host: Node) -> void:
	var summaries: Array[String] = []
	var uses: Array[int] = []
	for level: int in [GfxQuality.LOW, GfxQuality.HIGH]:
		GfxQuality.set_override(level)
		FxLayer.refresh_quality()
		var game := await _new_game(host, "aki", 7, true)
		# Recomeça sem soltar o relógio: o 1º quadro anda um número de passos que depende da máquina.
		game.start_run(game.config)
		GameClock.paused = true
		game.player.god_mode = true
		game.level = 10
		for _k: int in range(BOT_STEPS):
			GameClock.paused = false
			GameClock.game_time += DT
			game._on_tick(DT)
		summaries.append(game.state_summary("BOT"))
		uses.append(game.abilities.uses_by_slot[0] * 10000 + game.abilities.uses_by_slot[1] * 100
				+ game.abilities.uses_by_slot[2])
		_check.call(game.abilities.uses_by_slot[1] > 0 and game.abilities.uses_by_slot[2] > 0,
				"bot usa as habilidades (%s)" % [Array(game.abilities.uses_by_slot)])
		game.queue_free()
		await host.get_tree().process_frame
	GfxQuality.clear_override()
	FxLayer.refresh_quality()
	_check.call(summaries[0] == summaries[1] and uses[0] == uses[1],
			"bot com habilidades: mesmo estado na Baixa e na Alta (%s | %s)" % summaries)
	GameClock.paused = true


## E2E do bot com as três habilidades de cada guardião: partida do bot no nível 10 por
## BOT_HERO_STEPS passos, com a regra de guardar energia para a mais forte (BotPilot.ability_slot)
## soltando as 3. Antes da reserva, a 1ª (barata e frequente) não deixava juntar energia para a
## 3ª do Kenta, da Hana, do Goro e da Rin em partidas inteiras.
func _check_bot_every_hero(host: Node) -> void:
	for hero: String in SPEC:
		var game := await _new_game(host, hero, 7, true)
		game.start_run(game.config)
		GameClock.paused = true
		game.player.god_mode = true
		game.level = 10
		# Meio da partida (horda mais densa), como no fim da rodada longa do bot.
		GameClock.game_time = BOT_HERO_START
		game.spawner.skip_until(BOT_HERO_START)
		for _k: int in range(BOT_HERO_STEPS):
			GameClock.paused = false
			GameClock.game_time += DT
			game._on_tick(DT)
		var used := game.abilities.uses_by_slot
		_check.call(used[0] > 0 and used[1] > 0 and used[2] > 0,
				"bot (%s, nível 10) usa as 3 habilidades %s" % [hero, Array(used)])
		# Reserva: com energia só para a 1ª e a 3ª fora da recarga, a 1ª espera.
		var ab := game.abilities
		ab.cooldowns.fill(0.0)
		ab.energy.value = ab.cost(0) + 1.0
		game.step_index = BotPilot.ABILITY_EVERY * 1000
		_check.call(ab.cost(2) <= ab.cost(0) + 1.0 or BotPilot.ability_slot(game) != 0,
				"bot (%s) guarda energia para a 3ª habilidade" % hero)
		game.queue_free()
		await host.get_tree().process_frame
	GameClock.paused = true
