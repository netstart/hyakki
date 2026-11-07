extends RefCounted
## Projéteis e obstáculos (scripts/game/world_map.gd solid_hit, scripts/core/geometry.gd
## segment_enters_circle, scripts/systems/projectile_manager.gd e enemy_shot_manager.gd): casas,
## árvores, pedras, estátuas e altares param os tiros da guardiã e dos inimigos.
##   - solid_hit: t do contato no caminho, passa ao lado, sai livre de dentro, obstáculo do chunk
##     vizinho e passo longo sem atravessar um obstáculo fino (amostras a cada SOLID_PAD px);
##   - kunai: quem está atrás do obstáculo não leva dano e o kunai acaba no contato; quem está entre
##     a mão e o obstáculo leva, no mesmo passo;
##   - tiro inimigo pela casa se desfaz e a guardiã não leva dano (sem a casa, leva);
##   - tiro da estátua nasce no centro dela e sai voando.
## run_unit() roda sem autoloads (tests/run_tests.gd); run() precisa da árvore
## (tests/integration_tests.gd).

const AbilityTests := preload("res://tests/ability_tests.gd")
const TerrainTests := preload("res://tests/terrain_tests.gd")
const DT := 1.0 / 60.0

var _check: Callable


## Mapa vazio com só os obstáculos dados, cada um no chunk do seu centro.
static func world_with(w: WorldMap, solids: Array) -> WorldMap:
	w._solid_cells.clear()
	w._solid_ready.clear()
	for cy: int in range(-3, 4):
		for cx: int in range(-3, 4):
			w._chunks[Vector2i(cx, cy)] = {"solids": [], "lanterns": [], "statues": [], "lava": [],
					"altars": [], "items": [], "paint": [], "keepout": []}
	for solid: Array in solids:
		(w._chunks[w.chunk_of(solid[0])]["solids"] as Array).append(solid)
	return w


func run_unit(check: Callable) -> void:
	_check = check
	var w := WorldMap.new()
	w.setup(TerrainTests.stage_data("village"), 7)
	world_with(w, [[Vector2(128, 128), 10.0], [Vector2(262, 10), 8.0]])
	var t := w.solid_hit(Vector2(100, 128), Vector2(120, 128), 3.0)
	_check.call(absf(t - 0.75) < 0.01, "obstáculo no caminho: contato em t=0,75 (%.3f)", t)
	_check.call(w.solid_hit(Vector2(100, 145), Vector2(120, 145), 3.0) == -1.0, "obstáculo ao lado: passa")
	_check.call(w.solid_hit(Vector2(128, 128), Vector2(148, 128), 3.0) == -1.0,
			"começa dentro do obstáculo: sai livre")
	_check.call(w.solid_hit(Vector2(142, 128), Vector2(160, 128), 3.0) == -1.0, "afastando-se: -1")
	# Passo todo no chunk (0, 0), obstáculo no chunk (1, 0): contato em x = 262 - 11 = 251.
	t = w.solid_hit(Vector2(236, 10), Vector2(252, 10), 3.0)
	_check.call(absf(t - 15.0 / 16.0) < 0.01, "obstáculo do chunk vizinho: contato (%.3f)", t)
	world_with(w, [[Vector2(128, 128), 2.0], [Vector2(170, 128), 2.0]])
	# 180 px num passo: as células das pontas não veem o obstáculo fino do meio.
	t = w.solid_hit(Vector2(40, 128), Vector2(220, 128), 3.0)
	_check.call(absf(t - 83.0 / 180.0) < 0.01, "passo longo: para no primeiro obstáculo, sem atravessar (%.3f)", t)
	t = w.solid_hit(Vector2(220, 128), Vector2(40, 128), 3.0)
	_check.call(absf(t - 45.0 / 180.0) < 0.01, "passo longo ao contrário: o primeiro é o outro (%.3f)", t)
	w.free()


func run(host: Node, check: Callable) -> void:
	_check = check
	var a := AbilityTests.new()
	a._check = check
	var game := await a._new_game(host, "aki", 31)
	var shots := game.projectiles
	# Kunai rápido (50 px por passo): o obstáculo em x = 60 para o passo em x = 47.
	world_with(game.world, [[Vector2(60, 0), 10.0]])
	var front := a._spawn(game, Vector2(30, 0))
	var behind := a._spawn(game, Vector2(100, 0))
	var k := shots.spawn(&"kunai", "kunai", Vector2.ZERO, Vector2(3000, 0), 10.0, 3.0, -1, 2.0)
	for _s: int in range(30):
		shots.step(DT)
	_check.call(shots.alive[k] == 0 and absf(shots.pos[k].x - 47.0) < 0.5,
			"kunai acaba no obstáculo (x = %.1f)", shots.pos[k].x)
	_check.call(a._lost(game, front) > 0.0, "kunai: quem está antes do obstáculo leva dano no mesmo passo")
	_check.call(a._lost(game, behind) == 0.0, "kunai: quem está atrás do obstáculo não leva dano")
	a._clear(game)
	# Tiro inimigo de cima para a guardiã em (0, 0), com uma casa no meio (god_mode só segura a vida em 1).
	var player := game.player
	world_with(game.world, [[Vector2(0, -40), 10.0]])
	var hp := player.hp
	game.enemy_shots.spawn(Vector2(0, -100), Vector2(0, 150), 5.0, "fireball", 5.0)
	for _s: int in range(60):
		game.enemy_shots.step(DT)
	_check.call(game.enemy_shots.count_alive == 0, "tiro inimigo se desfaz na casa")
	_check.call(player.hp == hp, "tiro inimigo pela casa: guardiã sem dano")
	game.enemy_shots.spawn(Vector2(-100, 0), Vector2(150, 0), 5.0, "fireball", 5.0)
	for _s: int in range(60):
		game.enemy_shots.step(DT)
	_check.call(player.hp < hp, "tiro inimigo sem casa no meio: guardiã leva dano")
	player.hp = player.max_hp()
	player.invuln = 0.0
	# Tiro da estátua: nasce no centro dela e sai voando.
	world_with(game.world, [[Vector2(60, 60), 8.0]])
	game.enemy_shots.spawn(Vector2(60, 60), Vector2(-1, -1).normalized() * 55.0, 6.0, "statue_shot", 5.0)
	for _s: int in range(30):
		game.enemy_shots.step(DT)
	var out := -1.0
	for i: int in range(EnemyShotManager.CAPACITY):
		if game.enemy_shots.alive[i] == 1:
			out = game.enemy_shots.pos[i].distance_to(Vector2(60, 60))
	_check.call(out > 8.0 + EnemyShotManager.HIT_RADIUS, "tiro da estátua sai dela (%.1f px do centro)", out)
	game.enemy_shots.clear_all()
	game.queue_free()
	GameClock.paused = false
	await host.get_tree().process_frame
