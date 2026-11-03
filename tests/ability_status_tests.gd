extends RefCounted
## Indicadores de estado nos inimigos (EnemyLook.status_flags / _draw_status), rodado por
## tests/ability_tests.gd: cada primitiva das habilidades (lento, preso, medo, isca, atordoado)
## acende o seu bit e só o dele; o medo vale sobre a isca (dividem o ponto); chefe não ganha
## lento/preso/medo/isca; o tom do lento puxa para o azul; os estados somem quando o tempo acaba;
## e, num quadro desenhado de verdade, um indicador por estado (os atordoados usam as estrelas,
## que já existiam) e nenhum nos inimigos sem estado, com 500 inimigos na tela.

const AbilityTests := preload("res://tests/ability_tests.gd")
const Look := preload("res://scripts/systems/enemy_look.gd")

var _check: Callable
var _t: AbilityTests


func run(host: Node, check: Callable) -> void:
	_check = check
	_t = AbilityTests.new()
	_t._check = check
	var game := await _t._new_game(host, "aki", 51)
	GameClock.paused = false
	_check_flags(game)
	await _check_drawn(host, game)
	game.queue_free()
	await host.get_tree().process_frame
	GameClock.paused = true


func _check_flags(game: HyakkiGame) -> void:
	var enemies := game.enemies
	var look := enemies.look
	_t._clear(game)
	var plain := _t._spawn(game, Vector2(-60, 0))
	var slow := _t._spawn(game, Vector2(-30, 0))
	var rooted := _t._spawn(game, Vector2(0, 30))
	var scared := _t._spawn(game, Vector2(30, 0))
	var lured := _t._spawn(game, Vector2(60, 0))
	var stunned := _t._spawn(game, Vector2(0, -30))
	enemies.apply_slow(slow, 0.5, 1.0)
	enemies.root_one(rooted, 1.0)
	enemies.fear_circle(Vector2(30, 0), 4.0, 1.0)
	enemies.lure_circle(Vector2(60, 0), 4.0, Vector2(60, 60), 1.0)
	enemies.stun_one(stunned, 1.0)
	_check.call(look.status_flags(plain) == 0, "estado: sem efeito, sem indicador")
	_check.call(look.status_flags(slow) == Look.STATUS_SLOW, "estado: lento")
	_check.call(look.status_flags(rooted) == Look.STATUS_ROOT, "estado: preso")
	_check.call(look.status_flags(scared) == Look.STATUS_FEAR, "estado: com medo")
	_check.call(look.status_flags(lured) == Look.STATUS_LURE, "estado: atraído pela isca")
	_check.call(look.status_flags(stunned) == Look.STATUS_STUN, "estado: atordoado")
	enemies.fear_circle(Vector2(60, 0), 4.0, 1.0)
	_check.call(look.status_flags(lured) == Look.STATUS_FEAR, "estado: medo depois da isca vale o medo")
	var tint := Look.slow_tint(Color(1.0, 0.6, 0.4, 0.5))
	_check.call(tint.b > 0.4 and tint.r < 1.0 and is_equal_approx(tint.a, 0.5), "estado: lento puxa o tom para o azul")
	var boss := enemies.spawn(DB.ids("bosses")[0], Vector2(0, 80), AbilityTests.HP_MULT, 1.0)
	_t._reindex(game)
	enemies.slow_circle(Vector2(0, 80), 30.0, 0.5, 1.0)
	enemies.root_circle(Vector2(0, 80), 30.0, 1.0)
	enemies.fear_circle(Vector2(0, 80), 30.0, 1.0)
	_check.call(look.status_flags(boss) == 0, "estado: chefe sem lento, preso nem medo")
	_t._tick(game, int(1.3 / AbilityTests.DT))
	var left := 0
	for i: int in [slow, rooted, scared, lured, stunned]:
		left += 1 if look.status_flags(i) != 0 else 0
	_check.call(left == 0, "estado: os indicadores somem quando o efeito acaba (%d)" % left)
	_t._clear(game)


## Quadro desenhado de verdade (o _draw do EnemyManager): um indicador por inimigo afetado
## (lento, preso, medo, isca) e nenhum nos outros, também com 500 inimigos.
func _check_drawn(host: Node, game: HyakkiGame) -> void:
	var enemies := game.enemies
	var look := enemies.look
	_t._clear(game)
	GameClock.paused = true
	var affected: Array[int] = []
	for k: int in range(4):
		affected.append(_t._spawn(game, Vector2(-45 + k * 30, 0)))
	enemies.apply_slow(affected[0], 0.5, 5.0)
	enemies.root_one(affected[1], 5.0)
	enemies.fear[affected[2]] = 5.0
	enemies.lure[affected[3]] = 5.0
	enemies.goal[affected[3]] = Vector2(80, 0)
	for k: int in range(4):
		_t._spawn(game, Vector2(-45 + k * 30, 30))
	await _frames(host, 3)
	_check.call(look.visible_count() >= 8, "estado: inimigos na tela (%d)" % look.visible_count())
	_check.call(look.status_drawn == 4, "estado: um indicador por inimigo afetado (%d)" % look.status_drawn)
	# Horda: 500 inimigos na tela, metade com algum estado.
	_t._clear(game)
	var count := 0
	for k: int in range(500):
		var at := Vector2(-120 + (k % 25) * 10, -60 + (k / 25) * 6)
		var i := enemies.spawn(&"slime_rice", at, AbilityTests.HP_MULT, 1.0)
		if i < 0:
			continue
		match k % 6:
			0:
				enemies.apply_slow(i, 0.5, 5.0)
			1:
				enemies.root_one(i, 5.0)
			2:
				enemies.fear[i] = 5.0
		count += 1 if k % 6 < 3 else 0
	_t._reindex(game)
	await _frames(host, 3)
	var shown := look.visible_count()
	_check.call(look.status_drawn <= EnemyLook.MAX_STATUS_MARKS,
			"estado: no máximo %d marcas por quadro na horda (%d)" % [EnemyLook.MAX_STATUS_MARKS, look.status_drawn])
	_check.call(shown > 100 and look.status_drawn > 0 and look.status_drawn <= count,
			"estado: horda de 500 desenhada com indicadores (%d na tela, %d indicadores, %s)" % [shown, look.status_drawn,
				enemies.view_rect])
	_t._clear(game)
	GameClock.paused = false


func _frames(host: Node, n: int) -> void:
	for _k: int in range(n):
		await host.get_tree().process_frame
