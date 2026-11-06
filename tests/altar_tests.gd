extends RefCounted
## Altares do Selo (scripts/systems/altar_system.gd, scripts/game/world_map.gd "altars",
## scripts/game/bot_pilot.gd):
##   - posicionamento: função pura da semente (mesmos altares com a mesma semente, outros com
##     outra), longe do início, distância mínima entre altares, sólido no centro e o círculo do
##     ritual livre de terreno; nenhum na área de início;
##   - regras: pena do Elite, 1º altar (emboscada antes dos 3 min), tamanho da emboscada e saque;
##   - partida de verdade: ritual (runas, queda fora do círculo, volta a dormir), bloqueio com
##     chefe vivo, estouro → Elite que surge selado (invulnerável e parado) e é solto com letreiro,
##     poderes, morte com baú de chefe no chão e o altar vencido; emboscada com o campeão e a
##     bolsa de ryō (sem baú comum); partida suspensa no meio do ritual, do surgimento e com o
##     Elite em campo; o bot anda até o altar e fica até o selo quebrar.
## run_unit() roda sem autoloads (tests/run_tests.gd); run() precisa da árvore
## (tests/integration_tests.gd).

const TerrainTests := preload("res://tests/terrain_tests.gd")
const GAME_SCENE := "res://scenes/game/Game.tscn"
const STEP := 1.0 / 60.0
const STAGES: Array[String] = ["village", "bamboo", "temple", "dunes", "yomi", "secret"]

var _check: Callable
var _host: Node


# --- Regras e posicionamento (sem autoloads) -------------------------------------------------

func run_unit(check: Callable) -> void:
	_check = check
	_test_rules()
	for id: String in STAGES:
		_test_placement(id)
	_test_escape_windows()


func _test_rules() -> void:
	_check.call(is_equal_approx(AltarSystem.elite_chance(0), AltarSystem.ELITE_BASE), "altar: chance base de Elite")
	_check.call(AltarSystem.elite_chance(1) > AltarSystem.elite_chance(0) and AltarSystem.elite_chance(2) >= 1.0,
			"altar: a pena sobe e o 3º altar sem Elite garante")
	_check.call(AltarSystem.ambush_count(0.0) == 6 and AltarSystem.ambush_count(540.0) == 12
			and AltarSystem.ambush_count(3000.0) == AltarSystem.AMBUSH_CAP, "altar: emboscada 6 + 2×min/3, teto 16")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	_check.call(AltarSystem.loot(2, rng) == [[&"chest", Vector2.ZERO, {"boss": true}]]
			and AltarSystem.loot(3, rng)[0][2] == {"boss": true}, "altar: 2+ afixos dão baú de chefe")
	var chests := 0
	var rares := 0
	var bags := true
	for _k: int in 2000:
		var drop := AltarSystem.loot(1, rng)
		if drop.size() == 1 and drop[0][0] == &"chest" and (drop[0][2] as Dictionary).is_empty():
			chests += 1
		elif drop.size() == 2 and AltarSystem.RARE_ITEMS.has(drop[0][0]):
			rares += 1
			bags = bags and drop[1][0] == &"ryo_bag"
	_check.call(chests + rares == 2000 and absf(chests / 2000.0 - AltarSystem.CHEST_CHANCE) < 0.04 and bags,
			"altar: 1 afixo dá baú comum (%.0f%%) ou item raro + ryō", (chests / 20.0))


## Mesma semente → mesmos altares; longe do início, separados, sólidos e com o círculo livre.
func _test_placement(id: String) -> void:
	var stage := TerrainTests.stage_data(id)
	var a := WorldMap.new()
	a.setup(stage, 4242)
	var b := WorldMap.new()
	b.setup(stage, 4242)
	var c := WorldMap.new()
	c.setup(stage, 777)
	var list_a: Array[Vector2] = []
	var list_c: Array[Vector2] = []
	var same := true
	var intrusions: Array = []
	var solid_ok := true
	for cy: int in range(-7, 8):
		for cx: int in range(-7, 8):
			var ch := Vector2i(cx, cy)
			var da: Array = a.chunk_data(ch)["altars"]
			same = same and da == (b.chunk_data(ch)["altars"] as Array)
			for at: Vector2 in da:
				list_a.append(at)
				solid_ok = solid_ok and (a.chunk_data(ch)["solids"] as Array).any(func(s: Array) -> bool:
						return (s[0] as Vector2) == at and is_equal_approx(float(s[1]), AltarSystem.SOLID_RADIUS))
				var near := a.chunk_of(at)
				for ny: int in range(near.y - 1, near.y + 2):
					for nx: int in range(near.x - 1, near.x + 2):
						for s: Array in a.chunk_data(Vector2i(nx, ny))["solids"]:
							if (s[0] as Vector2) != at and (s[0] as Vector2).distance_to(at) - float(s[1]) < AltarSystem.RADIUS - 6.0:
								intrusions.append(at)
			list_c.append_array(c.chunk_data(ch)["altars"])
	_check.call(same, "altar %s: mesma semente, mesmos altares", id)
	_check.call(list_a.size() >= 2, "altar %s: há altares no mapa (%d em 15×15 chunks)", [id, list_a.size()])
	_check.call(list_a != list_c, "altar %s: outra semente, outros altares", id)
	var far := list_a.all(func(p: Vector2) -> bool: return p.length() >= AltarSystem.MIN_START_DIST)
	_check.call(far, "altar %s: nenhum a menos de %.0f px do início", [id, AltarSystem.MIN_START_DIST])
	var gap := INF
	for i: int in list_a.size():
		for j: int in range(i + 1, list_a.size()):
			gap = minf(gap, list_a[i].distance_to(list_a[j]))
	_check.call(gap >= AltarSystem.MIN_GAP, "altar %s: distância mínima entre altares (%.0f px)", [id, gap])
	_check.call(solid_ok, "altar %s: sólido no centro", id)
	_check.call(intrusions.is_empty(), "altar %s: círculo do ritual livre de terreno %s", [id, intrusions.slice(0, 3)])
	var lantern_hits: Array = []
	for at: Vector2 in list_a:
		var ch := a.chunk_of(at)
		for ny: int in range(ch.y - 1, ch.y + 2):
			for nx: int in range(ch.x - 1, ch.x + 2):
				for l: Vector2 in a.chunk_data(Vector2i(nx, ny))["lanterns"]:
					if l.distance_to(at) <= AltarSystem.RESERVE_RADIUS + 12.0:
						lantern_hits.append(at)
	_check.call(lantern_hits.is_empty(), "altar %s: lanternas (também dos chunks vizinhos) longe do círculo", id)
	var sites_ok := true
	for cy: int in range(-3, 4):
		for cx: int in range(-3, 4):
			sites_ok = sites_ok and a.hazard_sites(Vector2i(cx, cy))["lanterns"] == a.chunk_data(Vector2i(cx, cy))["lanterns"]
	_check.call(sites_ok, "altar %s: sorteio das lanternas sem montar o chunk = o do chunk", id)
	var inside := list_a.all(func(p: Vector2) -> bool: return a.clamp_to_bounds(p) == p)
	_check.call(inside, "altar %s: dentro dos limites da fase", id)
	for w: WorldMap in [a, b, c]:
		w.free()


# --- Partida (com a árvore) ------------------------------------------------------------------

func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	await _test_ritual()
	await _test_blocked()
	await _test_elite()
	await _test_ambush()
	await _test_first_and_pity()
	await _test_snapshot_ritual()
	await _test_snapshot_emerging()
	await _test_snapshot_elite()
	await _test_bot_visits()
	await _test_visuals()
	await _test_hum_pause()
	await _test_purify()
	await _test_ambush_rise()
	await _test_capacity_full()
	await _test_quick_kill()
	await _test_snapshot_state()
	await _test_quality_switch()
	GameClock.paused = false
	await _host.get_tree().process_frame


func _new_game(seed_value: int = 515) -> HyakkiGame:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = {"hero": "aki", "stage": "village", "moon": 0, "mode": "normal", "seed": seed_value, "speed": 1}
	_host.add_child(game)
	await _host.get_tree().process_frame
	GameClock.paused = true
	game.player.god_mode = true
	return game


func _free(game: HyakkiGame) -> void:
	game.queue_free()
	GameClock.paused = false
	await _host.get_tree().process_frame


## Passos manuais (relógio parado); telas que abrirem são respondidas como o bot. A guardiã fica
## em `hold` (Vector2.INF = solta).
func _tick(game: HyakkiGame, count: int, hold: Vector2 = Vector2.INF) -> void:
	for _k: int in count:
		if hold != Vector2.INF:
			game.player.sim_pos = hold
			game.player.velocity = Vector2.ZERO
		GameClock.game_time += STEP
		game._on_tick(STEP)
		if game.hud.overlay_open():
			game.hud.bot_answer()


## Altar de teste ao lado da guardiã, sem inimigos comuns por perto (o spawner fica calado).
func _altar(game: HyakkiGame, offset: Vector2 = Vector2(80, 0)) -> Vector2:
	var at := (game.player.sim_pos + offset).round()
	game.altars.place_altar(at)
	game.spawner.fixed_target = 0
	game.spawner.hush(999.0)
	return at


## Lê o selo até o estouro (a guardiã parada dentro do círculo).
func _channel(game: HyakkiGame, at: Vector2) -> void:
	var spot := at + Vector2(0, AltarSystem.RADIUS * 0.6)
	_tick(game, roundi(AltarSystem.CHANNEL_TIME / STEP) + 2, spot)


func _test_ritual() -> void:
	var game := await _new_game()
	var at := _altar(game)
	var spot := at + Vector2(0, 26)
	_tick(game, 1, spot)
	var key := game.altars.key_of(at)
	_check.call(game.altars.state_at(at) == AltarSystem.State.CHANNELING, "altar: entrar no círculo começa o ritual")
	_tick(game, roundi(AltarSystem.CHANNEL_TIME * 0.55 / STEP), spot)
	var r: Dictionary = game.altars.runtime[key]
	_check.call(int(r["runes"]) == 2 and float(r["progress"]) > 0.5, "altar: 2 runas acesas na metade (%d)", r["runes"])
	_check.call(game.fx.bolts_alive() >= 0, "altar: raios decorativos não quebram")
	var before := float(r["progress"])
	_tick(game, 60, at + Vector2(0, AltarSystem.RADIUS + 30.0))
	_check.call(float(r["progress"]) < before and is_equal_approx(before - float(r["progress"]),
			1.0 / AltarSystem.CHANNEL_TIME * AltarSystem.DECAY * 60 * STEP),
			"altar: fora do círculo o progresso cai pela metade")
	_check.call(int(r["runes"]) < 2, "altar: runas apagam ao cair")
	_tick(game, roundi(AltarSystem.CHANNEL_TIME * 2.0 / STEP), at + Vector2(0, AltarSystem.RADIUS + 30.0))
	_check.call(game.altars.state_at(at) == AltarSystem.State.DORMANT and not game.altars.runtime.has(key),
			"altar: progresso zerado volta a dormir")
	await _free(game)


func _test_blocked() -> void:
	var game := await _new_game()
	var at := _altar(game)
	game.bosses.spawn(&"tanuki", false)
	_tick(game, 60, at + Vector2(0, 26))
	_check.call(game.altars.is_blocked() and game.altars.state_at(at) == AltarSystem.State.DORMANT,
			"altar: com chefe vivo o selo não cede")
	_check.call(String(game.hud.get("_toast").text) == TranslationServer.translate("altar.locked"),
			"altar: aviso do selo travado")
	for boss: Dictionary in game.bosses.bosses:
		game.enemies.despawn(int(boss["index"]))
	game.bosses.bosses.clear()
	_tick(game, 30, at + Vector2(0, 26))
	_check.call(game.altars.state_at(at) == AltarSystem.State.CHANNELING, "altar: sem o chefe o ritual começa")
	await _free(game)


## Ritual completo até o Elite: estouro, surgimento selado, letreiro, poderes, morte e saque.
func _test_elite() -> void:
	var game := await _new_game()
	GameClock.game_time = 620.0
	game.spawner.skip_until(620.0)
	var at := _altar(game)
	var events: Array = []
	var cb := func(p: Vector2, outcome: StringName) -> void: events.append([p, outcome])
	Events.altar_awakened.connect(cb)
	var spawned: Array = []
	var cb2 := func(i: int, id: StringName, list: Array) -> void: spawned.append([i, id, list])
	Events.elite_spawned.connect(cb2)
	game.altars.force_affixes = [&"raijin", &"kongo"]
	_channel(game, at)
	_check.call(game.altars.state_at(at) == AltarSystem.State.BREAKING, "altar: o selo quebra ao fim da leitura")
	_check.call(events.size() == 1 and events[0][1] == &"elite" and game.tracker.altars_awakened == 1,
			"altar: evento e contagem do selo quebrado (Elite depois dos 3 min)")
	_check.call(game.fx.papers_alive() > 0 and game.fx.pillars_alive() > 0, "altar: estilhaços de ofuda e coluna de luz")
	_tick(game, roundi(AltarSystem.RISE_AT / STEP) + 2, at + Vector2(-30, 30))
	_check.call(spawned.size() == 1, "altar: o Elite surge do altar")
	if spawned.is_empty():
		Events.altar_awakened.disconnect(cb)
		Events.elite_spawned.disconnect(cb2)
		await _free(game)
		return
	var i := int(spawned[0][0])
	var enemies := game.enemies
	_check.call(enemies.sealed[i] == 1 and enemies.controlled[i] == 1 and enemies.elite[i] == 1,
			"altar: Elite selado e parado durante o surgimento")
	var hp := enemies.hp[i]
	game.deal_damage(&"katana", i, 99999.0, Vector2.RIGHT, 100.0)
	_check.call(enemies.alive[i] == 1 and is_equal_approx(enemies.hp[i], hp), "altar: invulnerável durante o surgimento")
	var look := game.altars.affixes.body_look(i)
	_check.call(look.x < 1.2 and look.y > 0.0, "altar: silhueta na cor do afixo subindo do chão")
	var base := float(DB.enemies[StringName(spawned[0][1])]["hp"]) * game.enemy_hp_mult() * AltarSystem.ELITE_HP_BONUS \
			* EnemyManager.ELITE_HP * EliteAffixes.hp_mult(2)
	_check.call(absf(enemies.max_hp[i] - base) < base * 0.05,
			"altar: vida do Elite com 2 afixos (%.0f ≈ %.0f)", [enemies.max_hp[i], base])
	_check.call(enemies.shield[i] > 0.0, "altar: escudo do Diamante")
	_tick(game, roundi((AltarSystem.BREAK_TIME - AltarSystem.RISE_AT) / STEP) + 2, at + Vector2(-30, 30))
	_check.call(enemies.sealed[i] == 0 and enemies.controlled[i] == 0, "altar: Elite solto depois do rugido")
	_check.call(not game.altars.banner.is_empty() and String(game.altars.banner["name"]).length() > 0
			and game.altars.banner_rect().size.x > 0.0, "altar: letreiro com o nome do Elite")
	_check.call(game.altars.state_at(at) == AltarSystem.State.SPENT, "altar: gasto depois do estouro")
	# Poderes: o Trovão marca círculos perto da guardiã.
	var telegraphs := 0
	for _s: int in 6:
		_tick(game, 60, at + Vector2(-60, 40))
		for e: Dictionary in game.areas.effects:
			if int(e["kind"]) == AreaEffects.Kind.TELEGRAPH and StringName(e["source"]) == StringName(spawned[0][1]):
				telegraphs += 1
	_check.call(telegraphs > 0, "altar: Trovão marca os raios perto da guardiã")
	# Morte: o escudo absorve e depois a vida; baú de chefe no chão e o altar vencido.
	var items_before := game.pickups.items.size()
	for _k: int in 4:
		if enemies.alive[i] == 1:
			game.deal_damage(&"katana", i, enemies.max_hp[i] * 2.0, Vector2.RIGHT, 0.0)
	_check.call(enemies.alive[i] == 0, "altar: Elite vencido")
	var boss_chests := game.pickups.items.filter(func(it: Dictionary) -> bool:
			return it["id"] == &"chest" and bool(it.get("boss", false)))
	_check.call(boss_chests.size() == 1 and game.pickups.items.size() == items_before + 1,
			"altar: só o baú de chefe no chão (sem o baú comum)")
	_check.call(game.tracker.altar_elites_slain == 1 and game.tracker.elite_affix_max == 2
			and game.tracker.elite_affixes_slain.has(&"raijin"), "altar: Missões registram o Elite vencido")
	_check.call(float(game.altars.spent[game.altars.key_of(at)]["vanquished"]) >= 0.0,
			"altar: selo vencido (brilho dourado)")
	Events.altar_awakened.disconnect(cb)
	Events.elite_spawned.disconnect(cb2)
	await _free(game)


## Emboscada: anel de inimigos e o campeão, que deixa a bolsa de ryō (sem baú).
func _test_ambush() -> void:
	var game := await _new_game()
	GameClock.game_time = 360.0
	game.spawner.skip_until(360.0)
	var at := _altar(game)
	game.altars.force_outcome = &"ambush"
	_channel(game, at)
	_tick(game, roundi(AltarSystem.AMBUSH_AT / STEP) - 2, at + Vector2(-20, 30))
	var common := game.enemies.count_common
	_tick(game, 4, at + Vector2(-20, 30))
	var expected := AltarSystem.ambush_count(GameClock.game_time)
	_check.call(game.enemies.count_common >= common + expected + 1,
			"altar: emboscada de %d inimigos (%d → %d)", [expected, common, game.enemies.count_common])
	_check.call(game.tracker.altar_ambushes == 1 and String(game.hud.get("_toast").text) ==
			TranslationServer.translate("altar.ambush"), "altar: aviso e contagem da emboscada")
	var champ := -1
	for k: int in EnemyManager.CAPACITY:
		if game.enemies.alive[k] == 1 and game.enemies.elite[k] == 1:
			champ = k
	_check.call(champ >= 0 and not game.altars.affixes.has(champ), "altar: campeão sem afixos")
	_tick(game, roundi(AltarSystem.BREAK_TIME / STEP), at + Vector2(-20, 30))
	if champ >= 0 and game.enemies.alive[champ] == 1:
		game.deal_damage(&"katana", champ, 999999.0, Vector2.RIGHT, 0.0)
	var ids := game.pickups.items.map(func(it: Dictionary) -> StringName: return it["id"])
	_check.call(ids.has(&"ryo_bag") and not ids.has(&"chest"), "altar: campeão deixa ryō, não baú (%s)", [ids])
	await _free(game)


## O 1º altar antes dos 3 min é emboscada; depois a pena garante o Elite no 3º.
func _test_first_and_pity() -> void:
	var game := await _new_game()
	var altars := game.altars
	GameClock.game_time = 60.0
	_check.call(altars.roll_outcome() == &"ambush", "altar: 1º altar antes dos 3 min é emboscada")
	GameClock.game_time = 200.0
	_check.call(altars.roll_outcome() == &"elite", "altar: 1º altar depois dos 3 min é Elite")
	altars.awakened = 3
	altars.since_elite = 2
	_check.call(altars.roll_outcome() == &"elite", "altar: 3º altar sem Elite garante o Elite")
	var elite := 0
	altars.since_elite = 0
	for _k: int in 400:
		elite += 1 if altars.roll_outcome() == &"elite" else 0
	_check.call(absf(elite / 400.0 - AltarSystem.ELITE_BASE) < 0.08, "altar: chance base %.0f%%", (elite / 4.0))
	var type := altars.pick_elite_type()
	var arch := String(DB.enemies[type].get("archetype", ""))
	_check.call(arch != "swarm" and arch != "prop", "altar: Elite é um inimigo da fase (%s, %s)", [type, arch])
	await _free(game)


func _test_snapshot_ritual() -> void:
	var game := await _new_game()
	var at := _altar(game)
	_tick(game, roundi(AltarSystem.CHANNEL_TIME * 0.5 / STEP), at + Vector2(0, 26))
	var key := game.altars.key_of(at)
	var progress := float(game.altars.runtime[key]["progress"])
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	await _free(game)
	var again := await _new_game()
	again.restore_snapshot(snap)
	again.close_pause()
	GameClock.paused = true
	_check.call(again.altars.runtime.has(key) and is_equal_approx(float(again.altars.runtime[key]["progress"]), progress),
			"retomada: ritual volta no mesmo progresso")
	again.spawner.hush(999.0)
	_channel(again, at)
	_check.call(again.altars.state_at(at) in [AltarSystem.State.BREAKING, AltarSystem.State.SPENT],
			"retomada: o ritual termina depois de voltar")
	await _free(again)


## No meio do surgimento: o Elite volta selado com os mesmos afixos e é solto no tempo certo.
func _test_snapshot_emerging() -> void:
	var game := await _new_game()
	GameClock.game_time = 620.0
	game.spawner.skip_until(620.0)
	var at := _altar(game)
	game.altars.force_affixes = [&"iwa"]
	_channel(game, at)
	_tick(game, roundi((AltarSystem.RISE_AT + 0.2) / STEP), at + Vector2(-30, 30))
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	await _free(game)
	var again := await _new_game()
	again.restore_snapshot(snap)
	again.close_pause()
	GameClock.paused = true
	again.spawner.hush(999.0)
	var i := _affixed(again)
	_check.call(i >= 0 and again.enemies.sealed[i] == 1 and again.altars.affixes.record(i)["affixes"] == [&"iwa"],
			"retomada: Elite surgindo volta selado e com os afixos")
	_tick(again, roundi(AltarSystem.BREAK_TIME / STEP), at + Vector2(-30, 30))
	_check.call(i >= 0 and again.enemies.alive[i] == 1 and again.enemies.sealed[i] == 0
			and again.altars.state_at(at) == AltarSystem.State.SPENT, "retomada: o surgimento termina e o Elite é solto")
	await _free(again)


## Elite em campo: volta com a vida, o escudo e os afixos.
func _test_snapshot_elite() -> void:
	var game := await _new_game()
	GameClock.game_time = 620.0
	game.spawner.skip_until(620.0)
	var at := _altar(game)
	game.altars.force_affixes = [&"kongo", &"yomi"]
	_channel(game, at)
	_tick(game, roundi(AltarSystem.BREAK_TIME / STEP) + 2, at + Vector2(-30, 30))
	var i := _affixed(game)
	game.enemies.hp[i] = game.enemies.max_hp[i] * 0.4
	var hp := game.enemies.hp[i]
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	await _free(game)
	var again := await _new_game()
	again.restore_snapshot(snap)
	again.close_pause()
	var j := _affixed(again)
	_check.call(j >= 0 and absf(again.enemies.hp[j] - hp) < 1.0 and again.enemies.shield[j] > 0.0
			and again.altars.affixes.record(j)["affixes"] == [&"kongo", &"yomi"] and again.enemies.sealed[j] == 0,
			"retomada: Elite em campo volta com vida, escudo e afixos")
	_check.call(again.altars.state_at(at) == AltarSystem.State.SPENT and again.altars.awakened == 1,
			"retomada: altar gasto continua gasto")
	await _free(again)


func _affixed(game: HyakkiGame) -> int:
	for k: int in game.altars.affixes.records:
		if game.altars.affixes.has(k):
			return k
	return -1


## O bot (saudável, sem chefe) anda até o altar e fica até o selo quebrar.
func _test_bot_visits() -> void:
	var game := await _new_game()
	var at := _altar(game, Vector2(170, 60))
	_check.call(BotPilot.altar_goal(game) == at, "bot: mira o altar dormente perto")
	game.player.hp = game.player.max_hp() * 0.4
	_check.call(BotPilot.altar_goal(game) == Vector2.INF, "bot: ferido não vai ao altar")
	game.player.hp = game.player.max_hp()
	var steps := 0
	while game.altars.state_at(at) != AltarSystem.State.BREAKING and steps < 900:
		game.player.move_input = BotPilot.input(game)
		_tick(game, 1)
		steps += 1
	_check.call(game.altars.state_at(at) == AltarSystem.State.BREAKING,
			"bot: anda até o altar e fica até o selo quebrar (%.1f s)", (steps * STEP))
	await _free(game)


## Efeitos novos do FxLayer: raio ramificado, coluna de luz, papel e aberração (só desenho).
func _test_visuals() -> void:
	var game := await _new_game()
	var fx := game.fx
	var rng_state := game.rng.state
	fx.lightning_bolt(Vector2(0, -150), Vector2.ZERO, Color.WHITE, 3.0, 3)
	fx.light_pillar(Vector2.ZERO, Color.WHITE)
	fx.paper_burst(Vector2.ZERO, 10)
	fx.gather(Vector2.ZERO, 50.0, Color.WHITE, 8)
	_check.call(fx.bolts_alive() == 1 and fx.pillars_alive() == 1 and fx.papers_alive() == 10,
			"fx: raio, coluna e papel criados")
	_check.call(game.rng.state == rng_state, "fx: efeitos não tocam no rng da partida")
	await _host.get_tree().process_frame
	_tick(game, 90)
	_check.call(fx.bolts_alive() == 0 and fx.pillars_alive() == 0 and fx.papers_alive() == 0, "fx: efeitos somem sozinhos")
	await _free(game)


## Dá para sair a tempo: o anel da Rocha cabe na fuga do guardião mais lento saindo do centro, e
## as poças do Yomi avisam por tempo suficiente.
func _test_escape_windows() -> void:
	var slowest := 1.0
	var file := FileAccess.open("res://data/heroes.json", FileAccess.READ)
	for h: Dictionary in JSON.parse_string(file.get_as_text()):
		slowest = minf(slowest, 1.0 + float((h.get("modifiers", {}) as Dictionary).get("speed", 0.0)))
	var speed := float(StatBlock.DEFS["speed"][0]) * slowest
	var run := speed * (EliteAffixes.IWA_WINDUP - Player.ACCEL_TIME)
	_check.call(run > EliteAffixes.IWA_RADIUS + Player.RADIUS,
			"afixo iwa: o mais lento (%.0f px/s) sai do anel a tempo (%.0f > %.0f px)", [speed, run,
			EliteAffixes.IWA_RADIUS + Player.RADIUS])
	_check.call(EliteAffixes.YOMI_WINDUP >= 0.6 and EliteAffixes.YOMI_BEHIND > 0.0, "afixo yomi: aviso ≥ 0,6 s, no rastro")


## O zumbido do ritual (e o do portal) pausa com o relógio e volta depois.
func _test_hum_pause() -> void:
	var game := await _new_game()
	var at := _altar(game)
	_tick(game, 30, at + Vector2(0, 26))
	var has_stream := game.altars.get("_hum").stream != null
	GameClock.paused = true
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	var paused := game.altars.hum_paused()
	GameClock.paused = false
	await _host.get_tree().process_frame
	var back := game.altars.hum_playing() and not game.altars.hum_paused()
	GameClock.paused = true
	_check.call(not has_stream or (paused and back),
			"altar: zumbido pausa com o relógio e volta (%s, %s)", [paused, back])
	game.rift.midboss_done = true
	game.rift.open_portal(game.player.sim_pos + Vector2(120, 0))
	await _host.get_tree().process_frame
	var hum: AudioStreamPlayer2D = game.rift.get("_hum")
	GameClock.paused = false
	await _host.get_tree().process_frame
	_check.call(hum.stream == null or (hum.playing and not hum.stream_paused), "portal: zumbido volta depois da pausa")
	GameClock.paused = true
	var soft := FxLayer.soft_texture()
	_check.call(soft != null and soft == FxLayer.soft_texture(), "altar: sombra usa a textura suave em cache")
	await _free(game)


## Sino Purificador: Elite com afixos leva só PURIFY_ELITE da vida (os comuns somem).
func _test_purify() -> void:
	var game := await _new_game()
	var i := game.enemies.spawn(&"kappa_young", game.player.sim_pos + Vector2(20, 0), 30.0, 1.0, true)
	game.altars.affixes.attach(i, [&"raijin"], "")
	var j := game.enemies.spawn(&"slime_rice", game.player.sim_pos + Vector2(-20, 0), 1.0, 1.0)
	var hp := game.enemies.max_hp[i]
	game.pickups.purify_screen()
	_check.call(game.enemies.alive[i] == 1 and absf(game.enemies.hp[i] - hp * (1.0 - AltarSystem.PURIFY_ELITE)) < 1.0
			and game.enemies.alive[j] == 0,
			"sino: Elite com afixos leva %.0f%%, comuns somem (%d, %.0f de %.0f, %d)", [AltarSystem.PURIFY_ELITE * 100.0,
			game.enemies.alive[i], game.enemies.hp[i], hp, game.enemies.alive[j]])
	await _free(game)


## Emboscada surge selada (sem dano, marca no chão) e o campeão nasce fora do círculo.
func _test_ambush_rise() -> void:
	var game := await _new_game()
	GameClock.game_time = 360.0
	game.spawner.skip_until(360.0)
	var at := _altar(game)
	game.altars.force_outcome = &"ambush"
	_channel(game, at)
	_tick(game, roundi(AltarSystem.AMBUSH_AT / STEP) + 2, at + Vector2(-20, 30))
	var sealed := 0
	var champ := -1
	for k: int in EnemyManager.CAPACITY:
		if game.enemies.alive[k] == 1 and game.enemies.sealed[k] == 1:
			sealed += 1
			if game.enemies.elite[k] == 1:
				champ = k
	_check.call(sealed >= AltarSystem.ambush_count(GameClock.game_time), "altar: emboscada surge selada (%d)", sealed)
	_check.call(champ >= 0 and game.enemies.pos[champ].distance_to(at) > AltarSystem.RADIUS,
			"altar: campeão nasce fora do círculo")
	if champ >= 0:
		var hp := game.enemies.hp[champ]
		game.deal_damage(&"katana", champ, 9999.0, Vector2.RIGHT, 0.0)
		_check.call(game.enemies.hp[champ] == hp, "altar: campeão invulnerável enquanto surge")
	_check.call(AltarSystem.AMBUSH_RISE >= 0.6, "altar: surgimento da emboscada ≥ 0,6 s")
	_tick(game, roundi(AltarSystem.AMBUSH_RISE / STEP) + 2, at + Vector2(-20, 30))
	_check.call(champ < 0 or game.enemies.sealed[champ] == 0, "altar: emboscada solta depois do surgimento")
	await _free(game)


## Sem vaga para o Elite (limite do EnemyManager): o saque sai do altar e a pena não zera.
func _test_capacity_full() -> void:
	var game := await _new_game()
	GameClock.game_time = 620.0
	game.spawner.skip_until(620.0)
	var at := _altar(game)
	game.altars.force_affixes = [&"raijin", &"kongo"]
	game.altars.since_elite = 2
	_channel(game, at)
	_tick(game, roundi(AltarSystem.RISE_AT / STEP) - 3, at + Vector2(-30, 30))
	# Enche todas as vagas a cada passo (a katana quebra lanternas e libera vagas).
	for _s: int in 6:
		while game.enemies.spawn(&"slime_rice", at + Vector2(400, 400), 1e6, 0.0) >= 0:
			pass
		_tick(game, 1, at + Vector2(-30, 30))
	var chests := game.pickups.items.filter(func(it: Dictionary) -> bool: return it["id"] == &"chest")
	_check.call(chests.size() == 1 and game.altars.since_elite == 2 and game.altars.affixes.count() == 0,
			"altar: sem vaga, baú do Elite no chão e a pena continua (%d)", game.altars.since_elite)
	await _free(game)


## Elite vencido logo depois de solto (antes do fim do estouro): o altar fica vencido.
func _test_quick_kill() -> void:
	var game := await _new_game()
	GameClock.game_time = 620.0
	game.spawner.skip_until(620.0)
	var at := _altar(game)
	game.altars.force_affixes = [&"iwa"]
	_channel(game, at)
	_tick(game, roundi(AltarSystem.RELEASE_AT / STEP) + 2, at + Vector2(-30, 30))
	var i := _affixed(game)
	if i >= 0:
		game.deal_damage(&"katana", i, 1e9, Vector2.RIGHT, 0.0)
	_tick(game, roundi(0.4 / STEP), at + Vector2(-30, 30))
	var key := game.altars.key_of(at)
	_check.call(i >= 0 and game.altars.spent.has(key) and float(game.altars.spent[key]["vanquished"]) >= 0.0,
			"altar: Elite vencido no fim do estouro deixa o altar vencido")
	await _free(game)


## Retomada guarda recargas, poder em curso, escudo (recarga), campeões e o ouro do altar vencido;
## o hash dos afixos não depende do índice do inimigo.
func _test_snapshot_state() -> void:
	var game := await _new_game()
	GameClock.game_time = 620.0
	game.spawner.skip_until(620.0)
	var i := game.enemies.spawn(&"kappa_young", game.player.sim_pos + Vector2(90, 0), 30.0, 1.0, true)
	var rec := game.altars.affixes.attach(i, [&"kongo", &"raijin"], "")
	rec["timers"][&"raijin"] = 1.25
	game.enemies.shield[i] = 0.0
	rec["shield_cd"] = 3.5
	var c := game.enemies.spawn(&"skeleton_peasant", game.player.sim_pos + Vector2(-90, 0), 3.0, 1.0, true)
	game.altars.set("_champions", {c: game.enemies.uid[c]})
	game.altars.spent["x"] = {"pos": Vector2(300, 300), "vanquished": GameClock.game_time - 2.0}
	var tag := game.altars.affixes.hash_tag()
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	await _free(game)
	var again := await _new_game()
	# Outros inimigos antes: o Elite volta em outra vaga, e o hash não muda por isso.
	for _k: int in 5:
		again.enemies.spawn(&"slime_rice", again.player.sim_pos + Vector2(500, 0), 1.0, 0.0)
	again.restore_snapshot(snap)
	again.close_pause()
	GameClock.paused = true
	var j := _affixed(again)
	var back := again.altars.affixes.record(j) if j >= 0 else {}
	_check.call(not back.is_empty() and is_equal_approx(float(back["timers"][&"raijin"]), 1.25)
			and is_equal_approx(float(back["shield_cd"]), 3.5) and again.enemies.shield[j] == 0.0,
			"retomada: recargas e recarga do escudo voltam")
	_check.call(again.altars.affixes.hash_tag() == tag, "retomada: hash dos afixos igual (sem o índice)")
	var champs: Dictionary = again.altars.get("_champions")
	_check.call(champs.size() == 1, "retomada: campeão da emboscada volta")
	var since := GameClock.game_time - float(again.altars.spent.get("x", {"vanquished": -99.0})["vanquished"])
	_check.call(again.altars.spent.has("x") and absf(since - 2.0) < 0.1,
			"retomada: altar vencido mantém o brilho")
	await _free(again)


## Troca de qualidade no meio da chuva (Auto rebaixando): o desenho do quadro não lê além das
## cotas novas (o erro "Out of bounds 160/24" do céu).
func _test_quality_switch() -> void:
	var game := await _new_game()
	var weather := WeatherSystem.of(game)
	if weather == null:
		await _free(game)
		return
	GfxQuality.set_override(GfxQuality.HIGH)
	weather.apply_quality()
	var sky := weather.sky()
	sky.set("_active", sky.drop_capacity())
	sky.set("_mote_active", int(GfxQuality.budget("ambient_motes")))
	GfxQuality.set_override(GfxQuality.MEDIUM)
	weather.apply_quality()
	var motes_ok := int(sky.get("_mote_active")) <= int(GfxQuality.budget("ambient_motes"))
	_check.call(sky.active_drops() <= sky.drop_capacity() and motes_ok,
			"clima: troca de qualidade ao vivo não deixa gotas além da cota")
	await _host.get_tree().process_frame
	GfxQuality.clear_override()
	weather.apply_quality()
	await _free(game)
