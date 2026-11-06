extends RefCounted
## Habilidades da Yuki (scripts/systems/abilities/yuki_abilities.gd), num cenário montado com os
## ajudantes de tests/ability_tests.gd (rodado por ele): Garra Oni (salto até o mais próximo e 3
## garradas só em volta dela), Rugido Oni (medo nos comuns, dano, tiros desfeitos, chefe sem
## medo), Redemoinho Onikiri (12 golpes em 2 s, roubo de vida com teto, +30% de velocidade que
## sai no fim), preço de sangue (vida paga, número vermelho e pulso no corpo), partida suspensa
## no meio do redemoinho (mesmo estado, hash e velocidade) e o bot (mesmo estado na Baixa e na
## Alta).

const AbilityTests := preload("res://tests/ability_tests.gd")

var _check: Callable
var _t: AbilityTests


func run(host: Node, check: Callable) -> void:
	_check = check
	_t = AbilityTests.new()
	_t._check = check
	var game := await _t._new_game(host, "yuki", 41)
	GameClock.paused = false
	_check.call(game.abilities.behavior is YukiAbilities, "Yuki usa o comportamento YukiAbilities")
	_check_claw(game)
	_check_roar(game)
	_check_whirl(game)
	_check_blood(game)
	await _check_save(host, game)
	game.queue_free()
	await host.get_tree().process_frame
	await _check_bot(host)
	GameClock.paused = true


func _fresh(game: HyakkiGame) -> YukiAbilities:
	_t._clear(game)
	_t._reset_abilities(game)
	game.level = 10
	game.abilities.energy.value = game.abilities.energy_max()
	return game.abilities.behavior as YukiAbilities


func _scale(game: HyakkiGame) -> float:
	return game.player.stats.get_stat("might") * game.abilities.power()


func _check_claw(game: HyakkiGame) -> void:
	var yuki := _fresh(game)
	var target := _t._spawn(game, Vector2(70.0, 0.0))
	var off := _t._spawn(game, Vector2(-20.0, -110.0))
	for i: int in [target, off]:
		game.enemies.speed[i] = 0.0
		game.enemies.controlled[i] = 1
		game.enemies.resist[i] = 1.0
	_check.call(game.abilities.activate(0), "Garra Oni sai")
	_check.call(game.player.is_dashing() and game.player.invuln > 0.0, "Garra Oni: salto invencível")
	_t._tick(game, 12)
	_check.call(game.player.sim_pos.x > 55.0 and game.player.sim_pos.x < 70.0,
			"Garra Oni: salta até o inimigo mais próximo sem passar dele (x=%.1f)", game.player.sim_pos.x)
	_t._tick(game, 30)
	var claws := 3.0 * 30.0 * _scale(game)
	_check.call(absf(_t._lost(game, target) - claws) < 0.01,
			"Garra Oni: 3 garradas de 30 (%.1f de %.1f)", [_t._lost(game, target), claws])
	_check.call(_t._lost(game, off) == 0.0, "Garra Oni: só em volta dela (%.1f)", _t._lost(game, off))
	_check.call(yuki._gashes.size() == 3, "Garra Oni: três cortes no chão")
	_t._tick(game, 120)
	_check.call(not yuki.has_visuals(), "Garra Oni: cortes e rastro somem")


func _check_roar(game: HyakkiGame) -> void:
	_fresh(game)
	var enemies := game.enemies
	var r := 150.0 * game.player.stats.get_stat("area")
	var near := _t._spawn(game, Vector2(50.0, 0.0))
	var mid := _t._spawn(game, Vector2(0.0, -110.0))
	var far := _t._spawn(game, Vector2(r + 40.0, 0.0))
	var boss := enemies.spawn(DB.ids("bosses")[0], Vector2(-80.0, 0.0), AbilityTests.HP_MULT, 1.0)
	_t._reindex(game)
	game.enemy_shots.spawn(Vector2(60.0, 60.0), Vector2(-10.0, 0.0), 5.0, "fireball", 5.0)
	game.enemy_shots.spawn(Vector2(0.0, r + 60.0), Vector2.ZERO, 5.0, "fireball", 5.0)
	_check.call(game.abilities.activate(1), "Rugido Oni sai")
	_check.call(enemies.fear[near] > 2.0 and enemies.fear[mid] > 2.0 and enemies.fear[far] <= 0.0,
			"Rugido: medo em quem está no raio")
	_check.call(enemies.fear[boss] <= 0.0, "Rugido: chefe não sente medo")
	var hit := 25.0 * _scale(game)
	_check.call(absf(_t._lost(game, near) - hit) < 0.01 and _t._lost(game, far) == 0.0, "Rugido: 25 em quem está no raio")
	_check.call(game.enemy_shots.count_alive == 1, "Rugido: tiros no raio desfeitos, o de fora segue")
	var d0 := enemies.pos[near].length()
	_t._tick(game, 60)
	_check.call(enemies.pos[near].length() > d0 + 20.0,
			"Rugido: com medo, foge dela (%.1f → %.1f)", [d0, enemies.pos[near].length()])
	_t._tick(game, 120)
	_check.call(enemies.fear[near] <= 0.0, "Rugido: o medo acaba")


func _check_whirl(game: HyakkiGame) -> void:
	var yuki := _fresh(game)
	var player := game.player
	var ring: Array[int] = []
	for k: int in range(4):
		var i := _t._spawn(game, Vector2.from_angle(TAU * k / 4.0) * 30.0)
		game.enemies.speed[i] = 0.0
		game.enemies.controlled[i] = 1
		game.enemies.resist[i] = 1.0
		ring.append(i)
	var speed := player.stats.get_stat("speed")
	player.hp = player.max_hp() * 0.4
	var hp := player.hp
	_check.call(game.abilities.activate(2), "Redemoinho Onikiri sai")
	var bonus: float = StatBlock.DEFS["speed"][0] * 0.3
	_check.call(is_equal_approx(player.stats.get_stat("speed"), speed + bonus), "Redemoinho: +30% de velocidade")
	_t._tick(game, int(2.1 / AbilityTests.DT))
	var each := 12.0 * 22.0 * _scale(game)
	var all_hit := true
	for i: int in ring:
		all_hit = all_hit and absf(_t._lost(game, i) - each) < 0.05
	_check.call(all_hit, "Redemoinho: 12 golpes de 22 em 2 s (%.1f de %.1f)", [_t._lost(game, ring[0]), each])
	var regen := player.stats.get_stat("regen") * 2.2
	var healed := player.hp - hp
	_check.call(healed >= 30.0 - 0.01 and healed <= 30.0 + regen + 0.01,
			"Redemoinho: rouba vida até o teto de 30 (%.1f)", healed)
	_check.call(_t._lost(game, ring[0]) * 4.0 * 0.1 > 30.0, "Redemoinho: o teto limitou o roubo")
	_check.call(yuki._whirl_time <= 0.0 and is_equal_approx(player.stats.get_stat("speed"), speed),
			"Redemoinho: acaba e a velocidade volta")
	player.hp = player.max_hp()


func _check_blood(game: HyakkiGame) -> void:
	var yuki := _fresh(game)
	var player := game.player
	var ab := game.abilities
	ab.energy.value = 0.0
	var hp := player.hp
	_check.call(ab.activate(0), "Preço de sangue: sem energia, paga com vida")
	_check.call(is_equal_approx(ab.last_hp_price, 12.5) and is_equal_approx(player.hp, hp - 12.5),
			"Preço de sangue: 1 de vida por 2 de energia (%.1f)", ab.last_hp_price)
	var number := game.fx.last_number()
	_check.call(not number.is_empty() and int(number.get("kind", -1)) == DamagePalette.Kind.TAKEN,
			"Preço de sangue: número vermelho da vida perdida")
	_check.call(yuki._blood_time > 0.0 and yuki.has_visuals(), "Preço de sangue: pulso vermelho no corpo")
	_t._tick(game, 60)
	_check.call(yuki._blood_time <= 0.0, "Preço de sangue: o pulso acaba")
	ab.energy.value = ab.energy_max()
	ab.cooldowns[0] = 0.0
	ab.activate(0)
	_check.call(ab.last_hp_price == 0.0, "Preço de sangue: com energia, nada de vida")
	_t._tick(game, 60)
	player.hp = player.max_hp()


## Partida suspensa no meio do redemoinho: mesmo estado, hash e a velocidade extra de volta.
func _check_save(host: Node, game: HyakkiGame) -> void:
	_fresh(game)
	var e := _t._spawn(game, Vector2(20.0, 0.0))
	game.enemies.speed[e] = 0.0
	game.enemies.controlled[e] = 1
	game.abilities.activate(2)
	_t._tick(game, 30)
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	var before := JSON.stringify(game.abilities.state())
	var hash_before := game.abilities.hash_tag()
	var speed := game.player.stats.get_stat("speed")
	var second := await _t._new_game(host, "yuki", 41)
	second.restore_snapshot(snap)
	_check.call(JSON.stringify(second.abilities.state()) == before, "Yuki: partida retomada no meio do redemoinho")
	_check.call(second.abilities.hash_tag() == hash_before, "Yuki: partida retomada com o mesmo hash")
	_check.call(is_equal_approx(second.player.stats.get_stat("speed"), speed),
			"Yuki: velocidade do redemoinho volta junto")
	second.queue_free()
	await host.get_tree().process_frame
	GameClock.paused = false
	_t._tick(game, 120)


func _check_bot(host: Node) -> void:
	var summaries: Array[String] = []
	var uses: Array[String] = []
	for level: int in [GfxQuality.LOW, GfxQuality.HIGH]:
		GfxQuality.set_override(level)
		FxLayer.refresh_quality()
		var game := await _t._new_game(host, "yuki", 7, true)
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
		_check.call(game.abilities.uses > 0, "Yuki: bot usa as habilidades (%s)", uses[-1])
		game.queue_free()
		await host.get_tree().process_frame
	GfxQuality.clear_override()
	FxLayer.refresh_quality()
	_check.call(summaries[0] == summaries[1] and uses[0] == uses[1], "Yuki: bot com o mesmo estado na Baixa e na Alta")
