extends RefCounted
## Habilidades da Rin (scripts/systems/abilities/rin_abilities.gd), num cenário montado com os
## ajudantes de tests/ability_tests.gd (rodado por ele): Hamaya (flecha que atravessa a linha
## inteira, um golpe por inimigo, nada fora da linha ou além do alcance), Armadilha de Caça
## (prende e fere só os primeiros `max_catch`, gasta as cargas, no máx. 2 armadilhas, a raiz
## acaba), Salto da Andorinha (salta para trás invencível e o leque atravessa 3), partida
## suspensa (flechas no ar e armadilhas voltam iguais, mesmo hash) e o bot (mesmo estado na
## Baixa e na Alta).

const AbilityTests := preload("res://tests/ability_tests.gd")

var _check: Callable
var _t: AbilityTests


func run(host: Node, check: Callable) -> void:
	_check = check
	_t = AbilityTests.new()
	_t._check = check
	var game := await _t._new_game(host, "rin", 31)
	GameClock.paused = false
	game.level = 10
	_check.call(game.abilities.behavior is RinAbilities, "Rin usa o comportamento RinAbilities")
	_check_hamaya(game)
	_check_trap(game)
	_check_leap(game)
	await _check_save(host, game)
	game.queue_free()
	await host.get_tree().process_frame
	await _check_bot(host)
	GameClock.paused = true


func _ready_slot(game: HyakkiGame, slot: int) -> void:
	game.abilities.cooldowns[slot] = 0.0
	game.abilities.energy.value = game.abilities.energy_max()


func _hamaya_damage(game: HyakkiGame) -> float:
	return 60.0 * game.player.stats.get_stat("might") * game.abilities.power()


func _check_hamaya(game: HyakkiGame) -> void:
	_t._clear(game)
	_t._reset_abilities(game)
	var rin := game.abilities.behavior as RinAbilities
	game.level = 10
	var line: Array[int] = []
	for x: float in [40.0, 130.0, 250.0]:
		line.append(_t._spawn(game, Vector2(x, 1.0)))
	var off := _t._spawn(game, Vector2(-10.0, 70.0))
	var far := _t._spawn(game, Vector2(345.0, 0.0))
	for i: int in line + [off, far]:
		game.enemies.speed[i] = 0.0
		game.enemies.controlled[i] = 1
	_check.call(game.abilities.activate(0), "Hamaya sai")
	_check.call(rin._arrows.size() == 1 and (rin._arrows[0]["dir"] as Vector2).dot(Vector2.RIGHT) > 0.99,
			"Hamaya: mira no inimigo mais próximo")
	_t._tick(game, 3)
	_check.call(_t._lost(game, line[2]) == 0.0, "Hamaya: a flecha voa (não acerta tudo no mesmo passo)")
	_t._tick(game, 30)
	var cut := _hamaya_damage(game)
	var all_hit := true
	for i: int in line:
		all_hit = all_hit and absf(_t._lost(game, i) - cut) < 0.01
	_check.call(all_hit, "Hamaya: atravessa todos na linha, um golpe cada (%.1f)" % cut)
	_check.call(_t._lost(game, off) == 0.0 and _t._lost(game, far) == 0.0,
			"Hamaya: nada fora da linha nem além de 320 px")
	_check.call(game.tracker.damage_by_weapon.has(&"hamaya"), "Hamaya: dano registrado pela habilidade")
	_check.call(rin.has_visuals(), "Hamaya: o rastro de luz fica um pouco")
	_t._tick(game, 40)
	_check.call(rin._arrows.is_empty(), "Hamaya: o rastro some")
	# Sem inimigo: sai para a frente (para onde ela olha).
	_t._clear(game)
	_ready_slot(game, 0)
	game.player.facing = Vector2.UP
	_check.call(game.abilities.activate(0) and (rin._arrows[0]["dir"] as Vector2).dot(Vector2.UP) > 0.99,
			"Hamaya: sem inimigo, para a frente")
	_t._tick(game, 40)


func _check_trap(game: HyakkiGame) -> void:
	var enemies := game.enemies
	_t._clear(game)
	_t._reset_abilities(game)
	var rin := game.abilities.behavior as RinAbilities
	game.level = 10
	var r := 40.0 * game.player.stats.get_stat("area")
	_check.call(game.abilities.activate(1) and rin._traps.size() == 1, "Armadilha sai aos pés")
	var trap: Dictionary = rin._traps[0]
	_check.call((trap["pos"] as Vector2) == Vector2.ZERO and int(trap["left"]) == 6, "Armadilha: 6 cargas")
	var inside: Array[int] = []
	for k: int in range(8):
		var i := _t._spawn(game, Vector2.from_angle(TAU * k / 8.0) * r * 0.5)
		enemies.speed[i] = 0.0
		inside.append(i)
	var outside := _t._spawn(game, Vector2(r + 30.0, 0.0))
	enemies.speed[outside] = 0.0
	_t._tick(game, 1)
	var rooted := 0
	var hurt := 0
	var damage := 40.0 * game.player.stats.get_stat("might") * game.abilities.power()
	for i: int in inside:
		rooted += 1 if enemies.root[i] > 0.0 else 0
		hurt += 1 if absf(_t._lost(game, i) - damage) < 0.01 else 0
	_check.call(rooted == 6 and hurt == 6,
			"Armadilha: prende e fere só os 6 primeiros (%d presos, %d feridos)" % [rooted, hurt])
	_check.call(enemies.root[outside] <= 0.0 and _t._lost(game, outside) == 0.0, "Armadilha: quem está fora fica")
	_check.call(int(trap["left"]) == 0 and bool(trap["spent"]), "Armadilha: sem cargas, fecha")
	var held := -1
	for i: int in inside:
		if enemies.root[i] > 0.0:
			held = i
			break
	game.player.sim_pos = Vector2(0, 90)
	var at := enemies.pos[held]
	enemies.speed[held] = 35.0
	_t._tick(game, 60)
	_check.call(enemies.pos[held].distance_to(at) < 0.01, "Armadilha: preso não anda")
	_t._tick(game, 150)
	_check.call(enemies.pos[held].distance_to(at) > 1.0, "Armadilha: solta depois de 3 s")
	_check.call(rin._traps.is_empty(), "Armadilha: gasta, some")
	# No máximo 2: a terceira tira a mais antiga.
	_t._clear(game)
	for k: int in range(3):
		game.player.sim_pos = Vector2(k * 100.0, 0.0)
		_ready_slot(game, 1)
		game.abilities.activate(1)
	_check.call(rin._traps.size() == 2 and (rin._traps[0]["pos"] as Vector2).x == 100.0,
			"Armadilha: no máximo 2 (sai a mais antiga)")
	# Uma presa só gasta uma carga; a armadilha dura 12 s.
	var one := _t._spawn(game, Vector2(200.0, 5.0))
	enemies.speed[one] = 0.0
	_t._tick(game, 2)
	_check.call(int(rin._traps[1]["left"]) == 5, "Armadilha: cada presa gasta uma carga (restam 5)")
	_t._tick(game, int(12.5 / AbilityTests.DT))
	_check.call(rin._traps.is_empty(), "Armadilha: some em 12 s")
	game.player.sim_pos = Vector2.ZERO


func _check_leap(game: HyakkiGame) -> void:
	var enemies := game.enemies
	_t._clear(game)
	_t._reset_abilities(game)
	var rin := game.abilities.behavior as RinAbilities
	game.level = 10
	var row: Array[int] = []
	for k: int in range(5):
		var i := _t._spawn(game, Vector2(14.0 + k * 12.0, 0.0))
		enemies.speed[i] = 0.0
		enemies.controlled[i] = 1
		enemies.resist[i] = 1.0
		row.append(i)
	_check.call(game.abilities.activate(2), "Salto da Andorinha sai")
	_check.call(game.player.is_dashing() and game.player.invuln > 0.2, "Salto: invencível no salto")
	_t._tick(game, 16)
	_check.call(game.player.sim_pos.x < -70.0 and absf(game.player.sim_pos.y) < 1.0,
			"Salto: 80 px para trás, longe do inimigo (x=%.1f)" % game.player.sim_pos.x)
	_check.call(rin._arrows.size() == 9, "Salto: leque de 9 flechas ao cair")
	_t._tick(game, 40)
	var arrow := 35.0 * game.player.stats.get_stat("might") * game.abilities.power()
	var first := 0
	for k: int in range(3):
		first += 1 if _t._lost(game, row[k]) >= arrow - 0.01 else 0
	_check.call(first == 3, "Salto: a flecha do meio acerta os 3 primeiros (%d)" % first)
	_check.call(_t._lost(game, row[3]) == 0.0 and _t._lost(game, row[4]) == 0.0,
			"Salto: cada flecha atravessa só 3 (%.1f, %.1f)" % [_t._lost(game, row[3]), _t._lost(game, row[4])])
	_t._tick(game, 60)
	_check.call(rin._arrows.is_empty() and not rin._leap_active, "Salto: flechas acabam no alcance")


## Partida suspensa no meio: flecha no ar e armadilha armada voltam iguais (mesmo hash).
func _check_save(host: Node, game: HyakkiGame) -> void:
	_t._clear(game)
	_t._reset_abilities(game)
	var ab := game.abilities
	var rin := ab.behavior as RinAbilities
	game.level = 10
	var e := _t._spawn(game, Vector2(200.0, 0.0))
	game.enemies.speed[e] = 0.0
	game.enemies.controlled[e] = 1
	ab.activate(1)
	var near := _t._spawn(game, Vector2(10.0, 0.0))
	game.enemies.speed[near] = 0.0
	game.enemies.controlled[near] = 1
	_t._tick(game, 2)
	game.player.facing = Vector2.RIGHT
	ab.activate(0)
	_t._tick(game, 2)
	_check.call(rin._arrows.size() == 1 and rin._traps.size() == 1, "save: flecha no ar e armadilha armada")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	var before := JSON.stringify(ab.state())
	var hash_before := ab.hash_tag()
	var second := await _t._new_game(host, "rin", 31)
	second.restore_snapshot(snap)
	var other := second.abilities.behavior as RinAbilities
	_check.call(JSON.stringify(second.abilities.state()) == before, "Rin: partida retomada com os mesmos efeitos")
	_check.call(second.abilities.hash_tag() == hash_before, "Rin: partida retomada com o mesmo hash")
	_check.call(other._traps.size() == 1 and int(other._traps[0]["left"]) == 5
			and (other._traps[0]["caught"] as Array).size() == 1,
			"Rin: armadilha retomada com as cargas e quem já pegou")
	second.queue_free()
	await host.get_tree().process_frame
	GameClock.paused = false


## Bot com as 3 liberadas: usa as habilidades e dá o mesmo estado na Baixa e na Alta.
func _check_bot(host: Node) -> void:
	var summaries: Array[String] = []
	var uses: Array[String] = []
	for level: int in [GfxQuality.LOW, GfxQuality.HIGH]:
		GfxQuality.set_override(level)
		FxLayer.refresh_quality()
		var game := await _t._new_game(host, "rin", 7, true)
		game.start_run(game.config)
		GameClock.paused = true
		game.player.god_mode = true
		game.level = 10
		for _k: int in range(AbilityTests.BOT_STEPS):
			GameClock.paused = false
			GameClock.game_time += AbilityTests.DT
			game._on_tick(AbilityTests.DT)
		summaries.append(game.state_summary("BOT"))
		uses.append(str(Array(game.abilities.uses_by_slot)))
		_check.call(game.abilities.uses > 0, "Rin: bot usa as habilidades (%s)" % uses[-1])
		game.queue_free()
		await host.get_tree().process_frame
	GfxQuality.clear_override()
	FxLayer.refresh_quality()
	_check.call(summaries[0] == summaries[1] and uses[0] == uses[1], "Rin: bot com o mesmo estado na Baixa e na Alta")
