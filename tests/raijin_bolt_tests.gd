extends RefCounted
## Tambor de Raijin e Fúria de Raijin: cada elo do raio desenha um raio caindo do céu
## sobre o alvo (variante 0..7 do lightning.png); a corrente estica o raio entre os alvos.
## Os raios são só desenho: expiram em ~0,2 s, têm teto e somem no reset().
## Chamado por tests/integration_tests.gd, que passa o nó da cena e o _check.

const GAME_SCENE := "res://scenes/game/Game.tscn"


func run(host: Node, check: Callable) -> void:
	check.call(ResourceLoader.exists(AreaEffects.BOLT_TEXTURE), "textura do raio do Raijin existe")
	var scene := load(GAME_SCENE) as PackedScene
	var game := scene.instantiate() as HyakkiGame
	game.config = {"hero": "goro", "stage": "bamboo", "moon": 0, "mode": "normal", "seed": 13, "speed": 1}
	host.add_child(game)
	await host.get_tree().process_frame
	game.player.god_mode = true
	var origin := game.player.sim_pos
	for i: int in range(EnemyManager.CAPACITY):
		if game.enemies.alive[i] == 1:
			game.enemies.despawn(i)
	var areas := game.areas
	for id: StringName in [&"raijin", &"raijin_fury"]:
		areas.reset()
		var weapon := game._make_weapon(id)
		check.call(weapon is Raijin, "%s nasce com o comportamento Raijin" % id)
		if not weapon is Raijin:
			continue
		var targets: Array[int] = []
		for k: int in range(3):
			targets.append(game.enemies.spawn(&"slime_rice", origin + Vector2(50 + 35 * k, 0), 1000.0, 1.0))
		game.enemies.spatial.clear()
		for i: int in range(EnemyManager.CAPACITY):
			if game.enemies.alive[i] == 1:
				game.enemies.spatial.insert(i, game.enemies.pos[i])
		weapon.fire(origin)
		check.call(not areas.bolts.is_empty(), "%s cria um raio visual" % id)
		var sky := 0
		var chain := 0
		var variants_ok := true
		for b: Dictionary in areas.bolts:
			var from: Vector2 = b["from"]
			var to: Vector2 = b["to"]
			variants_ok = variants_ok and int(b["variant"]) >= 0 and int(b["variant"]) < AreaEffects.BOLT_VARIANTS
			if is_equal_approx(from.x, to.x) and is_equal_approx(to.y - from.y, AreaEffects.BOLT_FALL):
				sky += 1
			else:
				chain += 1
		check.call(sky >= 1, "%s: o raio cai do céu sobre o alvo" % id)
		check.call(variants_ok, "%s: variante do raio entre 0 e 7" % id)
		if id == &"raijin_fury":
			check.call(chain >= 1, "Fúria de Raijin estica o raio entre os alvos da corrente")
		check.call(areas.bolts.size() <= AreaEffects.MAX_BOLTS, "%s: raios dentro do teto" % id)
		areas.step(AreaEffects.BOLT_LIFE * 0.5)
		check.call(not areas.bolts.is_empty(), "%s: o raio ainda aparece no meio da vida" % id)
		areas.step(AreaEffects.BOLT_LIFE)
		check.call(areas.bolts.is_empty(), "%s: o raio expira" % id)
		for j: int in targets:
			if j >= 0:
				game.enemies.despawn(j)
	# Teto: muitos raios seguidos não acumulam além de MAX_BOLTS; reset() limpa.
	for _k: int in range(AreaEffects.MAX_BOLTS + 10):
		areas.add_bolt(origin - Vector2(0, AreaEffects.BOLT_FALL), origin)
	check.call(areas.bolts.size() == AreaEffects.MAX_BOLTS, "raios do Raijin ficam no teto")
	areas.reset()
	check.call(areas.bolts.is_empty(), "reset() limpa os raios do Raijin")
	game.queue_free()
	GameClock.paused = false
	await host.get_tree().process_frame
