extends RefCounted
## Habilidades do Goro (scripts/systems/abilities/goro_abilities.gd) num cenário montado, no estilo
## de _check_aki (tests/ability_tests.gd, que empresta os ajudantes): Corpo de Diamante (redução de
## dano, espinhos, contorno), Golpe do Shakujō (antecipação, dano, atordoamento), Mantra do Mestre
## (3 pulsos, cura por atingido com teto) e a partida suspensa com os efeitos em curso.

var _check: Callable
var _t: RefCounted


func run(host: Node, check: Callable, helpers: RefCounted) -> void:
	_check = check
	_t = helpers
	var game: HyakkiGame = await _t._new_game(host, "goro", 21)
	var ab := game.abilities
	_t._reset_abilities(game)
	var goro := ab.behavior as GoroAbilities
	_check.call(goro != null, "Goro: comportamento próprio (GoroAbilities)")
	if goro == null:
		game.queue_free()
		return
	game.level = 10
	_check_diamond(game, goro)
	_check_shakujo(game, goro)
	_check_mantra(game, goro)
	await _check_save(host, game)
	game.queue_free()
	await host.get_tree().process_frame
	GameClock.paused = true


func _full(game: HyakkiGame) -> void:
	game.abilities.energy.value = game.abilities.energy_max()
	game.abilities.cooldowns.fill(0.0)


func _check_diamond(game: HyakkiGame, goro: GoroAbilities) -> void:
	var ab := game.abilities
	var player := game.player
	_t._clear(game)
	player.invuln = 0.0
	player.damage.reset()
	var plain := player.take_damage(30.0, &"test")
	player.damage.reset()
	player.invuln = 0.0
	player.hp = player.max_hp()
	_full(game)
	_check.call(ab.activate(0), "Corpo de Diamante sai")
	_check.call(is_equal_approx(player.guard_mult, 0.4) and player.guard_time > 3.9,
			"Corpo de Diamante: −60% de dano por 4 s")
	_check.call(is_equal_approx(player.thorns_fraction, 0.5) and player.thorns_source == &"diamond_body",
			"Corpo de Diamante: devolve 50% do contato")
	var guarded := player.take_damage(30.0, &"test")
	player.damage.reset()
	_check.call(guarded > 0.0 and guarded < plain * 0.6,
			"Corpo de Diamante: golpe reduzido (%.1f de %.1f)" % [guarded, plain])
	player.invuln = 0.0
	# Quem encosta leva o dano devolvido.
	var e: int = _t._spawn(game, Vector2(2, 0))
	game.enemies.speed[e] = 0.0
	game.enemies.dmg[e] = 30.0
	_t._tick(game, 20)
	_check.call(_t._lost(game, e) > 0.0 and game.tracker.damage_by_weapon.has(&"diamond_body"),
			"Corpo de Diamante: espinhos ferem quem encosta")
	_check.call(player.ability_rim.a > 0.0 and goro.has_visuals(), "Corpo de Diamante: contorno dourado no corpo")
	_t._clear(game)
	_t._tick(game, 240)
	_check.call(goro._diamond_time <= 0.0 and player.guard_time <= 0.0 and player.ability_rim.a == 0.0,
			"Corpo de Diamante: acaba em 4 s e apaga o contorno")
	player.hp = player.max_hp()


func _check_shakujo(game: HyakkiGame, goro: GoroAbilities) -> void:
	var ab := game.abilities
	var mp := game.player.stats.get_stat("might") * ab.power()
	_t._clear(game)
	# Fora do raio de verdade (110 × área do herói), com folga para o tamanho do inimigo.
	var reach := goro.area_of(ab.ability(1), "radius")
	var near: int = _t._spawn(game, Vector2(60, 0))
	var far: int = _t._spawn(game, Vector2(0, reach + 40.0))
	# Preso: longe da tela o EnemyManager recicla o inimigo para a borda.
	game.enemies.root_one(far, 99.0)
	_full(game)
	_check.call(ab.activate(1), "Golpe do Shakujō sai")
	_t._tick(game, 3)
	_check.call(_t._lost(game, near) == 0.0 and goro._slams.size() == 1, "Shakujō: o cajado sobe antes de bater")
	_t._tick(game, 8)
	var blow := 70.0 * mp
	_check.call(_t._lost(game, near) >= blow - 0.01 and _t._lost(game, near) <= blow * 2.0 + 0.01,
			"Shakujō: onda de %.0f no raio (veio %.1f)" % [blow, _t._lost(game, near)])
	_check.call(game.enemies.stun[near] > 0.9, "Shakujō: atordoa ~1,2 s")
	_check.call(_t._lost(game, far) == 0.0, "Shakujō: fora do raio fica")
	_check.call(not goro._cracks.is_empty() and goro._staff_time > 0.0, "Shakujō: rachaduras e o cajado fincado")


func _check_mantra(game: HyakkiGame, goro: GoroAbilities) -> void:
	var ab := game.abilities
	var player := game.player
	var mp := player.stats.get_stat("might") * ab.power()
	_t._clear(game)
	var group: Array[int] = []
	for k: int in range(5):
		group.append(_t._spawn(game, Vector2.from_angle(k * 1.2) * 90.0))
		game.enemies.speed[group[k]] = 0.0
	player.hp = player.max_hp() * 0.5
	var hp := player.hp
	_full(game)
	_check.call(ab.activate(2), "Mantra do Mestre sai")
	var pulse := 45.0 * mp
	_check.call(_t._lost(game, group[0]) >= pulse - 0.01, "Mantra: 1º pulso na hora")
	_check.call(is_equal_approx(player.hp, hp + 5.0), "Mantra: cura 1 por inimigo atingido (%.1f)" % (player.hp - hp))
	_t._tick(game, 40)
	_check.call(goro._mantra_left == 1, "Mantra: 2º pulso depois de 0,6 s")
	_t._tick(game, 40)
	_check.call(goro._mantra_left == 0 and _t._lost(game, group[0]) >= pulse * 3.0 - 0.01, "Mantra: 3 pulsos")
	# Teto de cura por pulso.
	_t._clear(game)
	for k: int in range(24):
		var j: int = _t._spawn(game, Vector2.from_angle(k * 0.26) * (40.0 + 3.0 * k))
		game.enemies.speed[j] = 0.0
	player.hp = player.max_hp() * 0.3
	hp = player.hp
	_full(game)
	ab.activate(2)
	_check.call(is_equal_approx(player.hp, hp + 15.0), "Mantra: cura no máximo 15 por pulso (%.1f)" % (player.hp - hp))
	_t._tick(game, 90)
	_check.call(goro._mantra_left == 0, "Mantra: acaba")
	player.hp = player.max_hp()
	_t._clear(game)


## Partida suspensa no meio do Corpo de Diamante, do Shakujō no ar e do Mantra.
func _check_save(host: Node, game: HyakkiGame) -> void:
	var ab := game.abilities
	_t._clear(game)
	_t._spawn(game, Vector2(50, 0))
	_full(game)
	ab.activate(0)
	ab.activate(2)
	_full(game)
	ab.activate(1)
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	var before := JSON.stringify(ab.state())
	var hash_before := ab.hash_tag()
	var second: HyakkiGame = await _t._new_game(host, "goro", 21)
	second.restore_snapshot(snap)
	var goro2 := second.abilities.behavior as GoroAbilities
	_check.call(JSON.stringify(second.abilities.state()) == before, "Goro: partida retomada mantém os efeitos")
	_check.call(second.abilities.hash_tag() == hash_before, "Goro: partida retomada, mesmo hash")
	_check.call(goro2._slams.size() == 1 and goro2._mantra_left == 2 and goro2._diamond_time > 3.0,
			"Goro: retomada com o cajado no ar, 2 pulsos e o Corpo de Diamante")
	_check.call(is_equal_approx(second.player.guard_mult, 0.4) and second.player.thorns_time > 3.0,
			"Goro: retomada reaplica a redução e os espinhos")
	second.queue_free()
	await host.get_tree().process_frame
	GameClock.paused = false
	_t._reset_abilities(game)
