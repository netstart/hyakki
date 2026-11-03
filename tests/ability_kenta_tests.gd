extends RefCounted
## Habilidades do Kenta (energia Sombra) num cenário montado (chamado por tests/ability_tests.gd):
## Passo Sombrio (teleporte, corte no caminho, fumaça que deixa lentos, silhueta), Troca de Corpo
## (tronco-isca, invencibilidade, explosão no fim), Chuva de Makibishi (estrepes que picam e
## deixam lentos, kunai em círculo, duração) e o save/hash dos efeitos persistentes.

const AbilityTests := preload("res://tests/ability_tests.gd")
const GAME_SCENE := "res://scenes/game/Game.tscn"
const HP_MULT := 1000.0
const DT := 1.0 / 60.0

var _check: Callable


func run(host: Node, check: Callable) -> void:
	_check = check
	var game := await _new_game(host)
	GameClock.paused = false
	game.level = 10
	_check_shadow_step(game)
	_check_kawarimi(game)
	_check_makibishi(game)
	_check_save(game)
	game.queue_free()
	await host.get_tree().process_frame
	GameClock.paused = true


func _new_game(host: Node) -> HyakkiGame:
	var scene := load(GAME_SCENE) as PackedScene
	var game := scene.instantiate() as HyakkiGame
	game.config = {"hero": "kenta", "stage": "village", "moon": 0, "mode": "normal", "seed": 31, "speed": 1}
	host.add_child(game)
	await host.get_tree().process_frame
	GameClock.paused = true
	game.player.god_mode = true
	AbilityTests.neutral_stats(game)
	_clear(game)
	return game


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
	game.player.dash_time = 0.0


func _spawn(game: HyakkiGame, at: Vector2, speed: float = 35.0) -> int:
	var i := game.enemies.spawn(&"slime_rice", at, HP_MULT, 1.0)
	game.enemies.speed[i] = speed
	game.enemies.spatial.rebuild(game.enemies.pos, game.enemies.alive, EnemyManager.CAPACITY)
	return i


func _lost(game: HyakkiGame, i: int) -> float:
	return game.enemies.max_hp[i] - game.enemies.hp[i]


func _tick(game: HyakkiGame, steps: int) -> void:
	for _k: int in range(steps):
		GameClock.game_time += DT
		game.step_index += 1
		game.player.step(DT)
		game.enemies.step(DT)
		game.enemy_shots.step(DT)
		game.abilities.step(DT)


func _fresh(game: HyakkiGame) -> KentaAbilities:
	_clear(game)
	game.abilities.reset()
	game.level = 10
	game.abilities.energy.value = game.abilities.energy_max()
	return game.abilities.behavior as KentaAbilities


func _scale(game: HyakkiGame) -> float:
	return game.player.stats.get_stat("might") * game.abilities.power()


func _check_shadow_step(game: HyakkiGame) -> void:
	var ab := game.abilities
	var kenta := _fresh(game)
	_check.call(kenta != null, "Kenta: comportamento KentaAbilities")
	if kenta == null:
		return
	var player := game.player
	player.sim_pos = Vector2(-60, 0)
	player.prev_pos = player.sim_pos
	player.move_input = Vector2.RIGHT
	var a := _spawn(game, Vector2(-20, 0))
	var b := _spawn(game, Vector2(15, 3))
	var off := _spawn(game, Vector2(-10, 50))
	var smoked := _spawn(game, Vector2(-68, 8))
	var energy := ab.energy_value()
	_check.call(ab.activate(0), "Passo Sombrio sai")
	_check.call(is_equal_approx(ab.energy_value(), energy - 20.0), "Passo Sombrio: custa 20 de Sombra")
	var cut := 30.0 * _scale(game)
	_check.call(absf(_lost(game, a) - cut) < 0.01 and absf(_lost(game, b) - cut) < 0.01,
			"Passo Sombrio: corta quem cruzou (%.1f, %.1f de %.1f)" % [_lost(game, a), _lost(game, b), cut])
	_check.call(_lost(game, off) == 0.0, "Passo Sombrio: quem está fora do caminho fica")
	_check.call(absf(player.sim_pos.x - 50.0) < 1.0, "Passo Sombrio: teleporte de 110 px (x = %.1f)" % player.sim_pos.x)
	_check.call(player.invuln > 0.0, "Passo Sombrio: invencível no instante do teleporte")
	var enemies := game.enemies
	_check.call(enemies.slow[smoked] > 0.0 and is_equal_approx(enemies.slow_mult[smoked], 0.5),
			"Passo Sombrio: fumaça na origem deixa lento (−50%)")
	_check.call(kenta._smokes.size() == 1 and kenta._ghosts.size() == 1 and kenta.has_visuals(),
			"Passo Sombrio: fumaça e silhueta residual na tela")
	_check.call(game.tracker.damage_by_weapon.has(&"shadow_step"), "Passo Sombrio: dano registrado")
	player.move_input = Vector2.ZERO
	_tick(game, 100)
	_check.call(kenta._smokes.is_empty() and kenta._ghosts.is_empty(), "Passo Sombrio: fumaça some em 1,5 s")


func _check_kawarimi(game: HyakkiGame) -> void:
	var ab := game.abilities
	var kenta := _fresh(game)
	var player := game.player
	player.move_input = Vector2.UP
	var near := _spawn(game, Vector2(25, 0), 0.0)
	# Perto do herói: no teste a tela é pequena e quem fica longe reaparece na borda.
	var far := _spawn(game, Vector2(-80, 0))
	var outside := _spawn(game, Vector2(0, 260))
	_check.call(ab.activate(1), "Troca de Corpo sai")
	var log_pos := kenta._log_pos
	_check.call(log_pos == Vector2.ZERO and player.sim_pos.distance_to(log_pos) > 30.0,
			"Troca de Corpo: Kenta salta e o tronco fica no lugar")
	_check.call(player.invuln >= 1.0 - 0.001, "Troca de Corpo: invencível 1 s")
	var enemies := game.enemies
	_check.call(enemies.lure[far] > 0.0 and enemies.goal[far] == log_pos,
			"Troca de Corpo: yōkai até 180 px perseguem o tronco")
	_check.call(enemies.lure[outside] == 0.0, "Troca de Corpo: quem está longe não é atraído")
	var d0 := enemies.pos[far].distance_to(log_pos)
	player.move_input = Vector2.ZERO
	_tick(game, 60)
	_check.call(enemies.pos[far].distance_to(log_pos) < d0 - 20.0, "Troca de Corpo: o atraído anda até o tronco")
	_check.call(_lost(game, near) == 0.0 and kenta._log_time > 0.0, "Troca de Corpo: o tronco espera 3 s")
	_tick(game, 125)
	var blast := 80.0 * _scale(game)
	_check.call(kenta._log_time == 0.0 and _lost(game, near) >= blast - 0.01,
			"Troca de Corpo: o tronco explode (%.0f de %.0f)" % [_lost(game, near), blast])


func _check_makibishi(game: HyakkiGame) -> void:
	var ab := game.abilities
	var kenta := _fresh(game)
	var still := _spawn(game, Vector2(50, 0), 0.0)
	_check.call(ab.activate(2), "Chuva de Makibishi sai")
	var r := 90.0 * game.player.stats.get_stat("area")
	var inside := kenta._caltrops.size() == 12
	for c: Dictionary in kenta._caltrops:
		inside = inside and (c["pos"] as Vector2).length() <= r + 0.01
	_check.call(inside, "Makibishi: 12 estrepes dentro de r 90")
	_check.call(kenta._kunai.size() == 8, "Makibishi: 8 kunai em círculo")
	_tick(game, 30)
	var scale := _scale(game)
	_check.call(kenta._kunai.is_empty() and _lost(game, still) >= 25.0 * scale - 0.01,
			"Makibishi: a kunai voa até o fim e acerta (%.1f de %.1f)" % [_lost(game, still), 25.0 * scale])
	# Pisada: um inimigo parado em cima de um estrepe pica a cada 0,4 s e fica lento.
	var spot: Vector2 = kenta._caltrops[0]["pos"]
	var stepper := _spawn(game, spot, 0.0)
	_tick(game, 26)
	var enemies := game.enemies
	var pricks := _lost(game, stepper) / (18.0 * scale)
	_check.call(pricks >= 0.99, "Makibishi: quem pisa leva 18 (%.2f pisadas)" % pricks)
	_check.call(enemies.slow[stepper] > 0.0 and is_equal_approx(enemies.slow_mult[stepper], 0.6),
			"Makibishi: quem pisa fica −40% mais lento")
	_check.call(kenta.hash_tag().contains("kenta=0,0.000,12,0"), "Makibishi: no hash")
	_tick(game, 340)
	_check.call(kenta._caltrops.is_empty(), "Makibishi: estrepes somem em 6 s")


## Partida suspensa: fumaça, tronco, estrepes e kunai voltam iguais (state → JSON → load_state).
func _check_save(game: HyakkiGame) -> void:
	var ab := game.abilities
	var kenta := _fresh(game)
	_spawn(game, Vector2(40, 0), 0.0)
	game.player.move_input = Vector2.RIGHT
	ab.activate(2)
	_tick(game, 3)
	ab.energy.value = ab.energy_max()
	ab.activate(1)
	ab.energy.value = ab.energy_max()
	ab.activate(0)
	var saved := JSON.stringify(kenta.state())
	var copy := KentaAbilities.new(ab, &"kenta")
	copy.load_state(JSON.parse_string(saved))
	_check.call(JSON.stringify(copy.state()) == saved, "Kenta: state/load_state mantém fumaça, tronco, estrepes e kunai")
	_check.call(copy.hash_tag() == kenta.hash_tag() and kenta.hash_tag().begins_with(" kenta=1,"),
			"Kenta: mesmo hash depois de retomar (%s)" % kenta.hash_tag())
	copy.reset()
	_check.call(not copy.has_visuals() and copy.hash_tag() == " kenta=0,0.000,0,0", "Kenta: reset limpa tudo")
	game.player.move_input = Vector2.ZERO
	_clear(game)
	ab.reset()
