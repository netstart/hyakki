extends RefCounted
## Habilidades da Hana (energia Prece) num cenário montado (chamado por tests/ability_tests.gd):
## Purificação (leque com dano e empurrão, tiros purificados), Kekkai (lentidão, dano por tique,
## tiros bloqueados, cura dentro, duração), Selo da Avó (sem alvo devolve o custo; comum selado e
## morto pelo caminho normal com abate; chefe primeiro, atordoado e ferido) e o save/hash.

const AbilityTests := preload("res://tests/ability_tests.gd")
const GAME_SCENE := "res://scenes/game/Game.tscn"
const HP_MULT := 1000.0
const DT := 1.0 / 60.0

var _check: Callable


func run(host: Node, check: Callable) -> void:
	_check = check
	var game := await _new_game(host)
	GameClock.paused = false
	_check_harae(game)
	_check_kekkai(game)
	_check_seal(game)
	_check_seal_boss(game)
	_check_save(game)
	game.queue_free()
	await host.get_tree().process_frame
	GameClock.paused = true


func _new_game(host: Node) -> HyakkiGame:
	var scene := load(GAME_SCENE) as PackedScene
	var game := scene.instantiate() as HyakkiGame
	game.config = {"hero": "hana", "stage": "village", "moon": 0, "mode": "normal", "seed": 33, "speed": 1}
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


func _spawn(game: HyakkiGame, at: Vector2, speed: float = 35.0, id: StringName = &"slime_rice",
		hp_mult: float = HP_MULT) -> int:
	var i := game.enemies.spawn(id, at, hp_mult, 1.0)
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


func _fresh(game: HyakkiGame) -> HanaAbilities:
	_clear(game)
	game.abilities.reset()
	game.level = 10
	game.abilities.energy.value = game.abilities.energy_max()
	return game.abilities.behavior as HanaAbilities


func _scale(game: HyakkiGame) -> float:
	return game.player.stats.get_stat("might") * game.abilities.power()


func _check_harae(game: HyakkiGame) -> void:
	var ab := game.abilities
	var hana := _fresh(game)
	_check.call(hana != null, "Hana: comportamento HanaAbilities")
	if hana == null:
		return
	var front := _spawn(game, Vector2(35, 0), 0.0)
	var side := _spawn(game, Vector2(40, 30), 0.0)
	var behind := _spawn(game, Vector2(-50, 0), 0.0)
	var shots := game.enemy_shots
	shots.spawn(Vector2(30, 6), Vector2(-10, 0), 5.0, "fireball", 5.0)
	shots.spawn(Vector2(-40, 0), Vector2(-10, 0), 5.0, "fireball", 5.0)
	_check.call(ab.activate(0), "Purificação sai")
	var hit := 35.0 * _scale(game)
	_check.call(absf(_lost(game, front) - hit) < 0.01 and absf(_lost(game, side) - hit) < 0.01,
			"Purificação: leque de 100° fere (%.1f, %.1f de %.1f)" % [_lost(game, front), _lost(game, side), hit])
	_check.call(_lost(game, behind) == 0.0, "Purificação: quem está atrás fica")
	_check.call(game.enemies.vel[front].x > 50.0, "Purificação: empurra para fora")
	_check.call(shots.count_alive == 1, "Purificação: purifica só os tiros no leque")
	_check.call(hana.has_visuals() and not hana._bits.is_empty(), "Purificação: varredura e pétalas na tela")
	_tick(game, 70)
	_check.call(hana._sweeps.is_empty(), "Purificação: varredura acaba")


func _check_kekkai(game: HyakkiGame) -> void:
	var ab := game.abilities
	var hana := _fresh(game)
	var inside := _spawn(game, Vector2(45, 0), 0.0)
	# Perto do herói: no teste a tela é pequena e quem fica longe reaparece na borda.
	var outside := _spawn(game, Vector2(92, 0), 0.0)
	var player := game.player
	player.hp = player.max_hp() * 0.5
	var hp := player.hp
	_check.call(ab.activate(1), "Kekkai sai")
	var enemies := game.enemies
	_tick(game, 2)
	_check.call(enemies.slow[inside] > 0.0 and is_equal_approx(enemies.slow_mult[inside], 0.4),
			"Kekkai: quem está dentro fica −60% mais lento")
	_check.call(enemies.slow[outside] == 0.0, "Kekkai: quem está fora não")
	game.enemy_shots.spawn(Vector2(0, -120), Vector2(0, 150), 5.0, "fireball", 5.0)
	_tick(game, 62)
	_check.call(game.enemy_shots.count_alive == 0, "Kekkai: o tiro que entra se desfaz")
	var tick := 8.0 * _scale(game)
	_check.call(_lost(game, inside) >= tick * 3.0 - 0.01 and _lost(game, outside) == 0.0,
			"Kekkai: 8 a cada 0,5 s em quem está dentro (%.2f de %.2f)" % [_lost(game, inside), tick * 3.0])
	# Cura dentro menos a regeneração natural (medida fora, no mesmo tempo).
	var healed := player.hp - hp
	player.sim_pos = Vector2(0, 96)
	player.prev_pos = player.sim_pos
	var hp_out := player.hp
	_tick(game, 64)
	var natural := player.hp - hp_out
	var extra := healed - natural
	_check.call(absf(extra - 0.02 * player.max_hp() * 64.0 / 60.0) < 0.05,
			"Kekkai: cura 2%% da vida/s dentro (+%.2f além da regeneração em 64 passos)" % extra)
	_tick(game, 190)
	_check.call(hana._kek_time == 0.0, "Kekkai: acaba em 5 s")


func _check_seal(game: HyakkiGame) -> void:
	var ab := game.abilities
	var hana := _fresh(game)
	var energy := ab.energy_value()
	_check.call(not ab.activate(2) and ab.last_failure == AbilitySystem.Fail.NO_TARGET,
			"Selo da Avó: sem ninguém no alcance não sai")
	_check.call(is_equal_approx(ab.energy_value(), energy) and ab.cooldown_left(2) == 0.0,
			"Selo da Avó: sem alvo devolve o custo e não entra em recarga")
	var weak := _spawn(game, Vector2(-60, 0), 0.0, &"slime_rice", 10.0)
	var strong := _spawn(game, Vector2(90, 0), 0.0)
	var far := _spawn(game, Vector2(0, 260), 0.0, &"slime_rice", 5000.0)
	var kills := game.tracker.kills
	_check.call(ab.activate(2), "Selo da Avó sai")
	_check.call(hana._seals.size() == 1 and int(hana._seals[0]["target"]) == strong,
			"Selo da Avó: mira o mais forte no alcance")
	_tick(game, 30)
	var enemies := game.enemies
	_check.call(enemies.alive[strong] == 1 and enemies.stun[strong] > 0.0 and float(hana._seals[0]["bind"]) > 0.0,
			"Selo da Avó: os ofuda chegam e prendem o alvo")
	_tick(game, 62)
	_check.call(enemies.alive[strong] == 0 and hana._seals.is_empty(), "Selo da Avó: o selado se desfaz em 1 s")
	_check.call(game.tracker.kills == kills + 1, "Selo da Avó: conta o abate (%d → %d)" % [kills, game.tracker.kills])
	_check.call(enemies.alive[weak] == 1 and enemies.alive[far] == 1, "Selo da Avó: só o alvo é selado")


func _check_seal_boss(game: HyakkiGame) -> void:
	var ab := game.abilities
	var hana := _fresh(game)
	var strong := _spawn(game, Vector2(-40, 0), 0.0, &"slime_rice", 9000.0)
	var boss := _spawn(game, Vector2(85, 0), 0.0, DB.ids("bosses")[0])
	_check.call(ab.activate(2), "Selo da Avó no chefe sai")
	_check.call(int(hana._seals[0]["target"]) == boss, "Selo da Avó: chefe primeiro")
	_tick(game, 30)
	var enemies := game.enemies
	var stun := 2.5 * game.player.stats.get_stat("duration")
	_check.call(enemies.alive[boss] == 1 and enemies.stun[boss] >= stun - 0.1,
			"Selo da Avó: chefe atordoado 2,5 s (%.2f)" % enemies.stun[boss])
	var wound := 200.0 * _scale(game)
	_check.call(_lost(game, boss) >= wound - 0.01,
			"Selo da Avó: chefe leva 200 (%.1f)" % _lost(game, boss))
	_check.call(_lost(game, strong) == 0.0, "Selo da Avó: o comum forte fica")
	_tick(game, 100)
	_check.call(not hana._seals.is_empty() and enemies.alive[boss] == 1,
			"Selo da Avó: ofuda presos no chefe enquanto dura")
	_tick(game, 60)
	_check.call(hana._seals.is_empty(), "Selo da Avó: os ofuda caem do chefe no fim")


## Partida suspensa: barreira e selos voltam iguais (state → JSON → load_state).
func _check_save(game: HyakkiGame) -> void:
	var ab := game.abilities
	var hana := _fresh(game)
	_spawn(game, Vector2(60, 0), 0.0)
	ab.activate(1)
	ab.activate(2)
	_tick(game, 5)
	var saved := JSON.stringify(hana.state())
	var copy := HanaAbilities.new(ab, &"hana")
	copy.load_state(JSON.parse_string(saved))
	_check.call(JSON.stringify(copy.state()) == saved, "Hana: state/load_state mantém kekkai e selos")
	_check.call(copy.hash_tag() == hana.hash_tag() and hana.hash_tag().begins_with(" hana=4.9"),
			"Hana: mesmo hash depois de retomar (%s)" % hana.hash_tag())
	copy.reset()
	_check.call(not copy.has_visuals() and copy.hash_tag() == " hana=0.000,0", "Hana: reset limpa tudo")
	_clear(game)
	ab.reset()
