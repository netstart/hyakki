extends RefCounted
## Itens no chão sempre alcançáveis (scripts/game/world_map.gd free_point/overlaps_solid e
## scripts/systems/pickup_manager.gd): baú, moeda, item de lanterna e brasa que nasceriam dentro
## de uma casa, muro ou estátua vão para o ponto livre mais perto, onde a guardiã chega.
##   - ponto dentro de um obstáculo sai para fora e não encosta em nenhum;
##   - ponto livre não muda; resultado determinístico e dentro dos limites;
##   - casa de vários círculos sobrepostos (um resolve() só cairia no vizinho) e ponto cercado;
##   - todas as casas e obstáculos reais da vila: o centro de cada um vira ponto livre;
##   - spawn_item (baú de elite, baú do chefe, moeda deslocada) e spawn (brasa) dentro de uma
##     casa acabam fora dela; sem mapa, o pickup fica onde pediram;
##   - Furacão de Fūjin não arrasta brasas para dentro dos obstáculos.
## run_unit() roda sem autoloads (tests/run_tests.gd); run() precisa da árvore
## (tests/integration_tests.gd).

const TerrainTests := preload("res://tests/terrain_tests.gd")
const R := PickupManager.SPAWN_CLEARANCE
## Centro do chunk (0, 0) e uma "casa" de três círculos sobrepostos em fileira, como as do
## terrain_layout.gd, mais uma estátua isolada longe dela.
const HOME := Vector2(128, 128)
const HOUSE := [[Vector2(108, 128), 14.0], [Vector2(128, 128), 14.0], [Vector2(148, 128), 14.0]]
const STATUE := [Vector2(60, 60), 8.0]

var _check: Callable


## Mapa vazio (semente qualquer) com só os obstáculos dados no chunk (0, 0).
static func world_with(solids: Array, bounds := Vector2.ZERO) -> WorldMap:
	var w := WorldMap.new()
	w.setup(TerrainTests.stage_data("village"), 7)
	w.bounds = bounds
	for cy: int in range(-3, 4):
		for cx: int in range(-3, 4):
			var data := {"solids": [], "lanterns": [], "statues": [], "lava": [], "items": [],
					"paint": [], "keepout": []}
			if cx == 0 and cy == 0:
				data["solids"] = solids.duplicate(true)
			w._chunks[Vector2i(cx, cy)] = data
	return w


func run_unit(check: Callable) -> void:
	_check = check
	_test_free_point()
	_test_overlapping_house()
	_test_enclosed()
	_test_bounds()
	_test_real_village()


func _test_free_point() -> void:
	var w := world_with([STATUE])
	_check.call(w.overlaps_solid(STATUE[0], R), "obstáculo: centro da estátua encosta")
	_check.call(not w.overlaps_solid(Vector2(100, 100), R), "obstáculo: ponto longe está livre")
	var inside := Vector2(62, 61)
	var out := w.free_point(inside, R)
	_check.call(not w.overlaps_solid(out, R), "ponto livre: dentro da estátua sai para fora")
	_check.call(out.distance_to(inside) <= STATUE[1] + R + 0.5, "ponto livre: sai pelo lado mais perto")
	var free := Vector2(100, 90)
	_check.call(w.free_point(free, R) == free, "ponto livre: ponto já livre não muda")
	var at_center := w.free_point(STATUE[0], R)
	_check.call(not w.overlaps_solid(at_center, R), "ponto livre: exatamente no centro também sai")
	_check.call(w.free_point(inside, R) == out, "ponto livre: determinístico")
	# Raio largo (caminho de 9 chunks) também resolve.
	_check.call(not w.overlaps_solid(w.free_point(inside, 30.0), 30.0), "ponto livre: raio largo sai")
	w.free()


## Casa de três círculos: sair do círculo do meio para o lado cairia no vizinho.
func _test_overlapping_house() -> void:
	var w := world_with(HOUSE)
	for at: Vector2 in [Vector2(128, 128), Vector2(118, 128), Vector2(138, 128), Vector2(108, 128),
			Vector2(128, 120), Vector2(140, 135)]:
		var out := w.free_point(at, R)
		_check.call(not w.overlaps_solid(out, R), "casa de vários círculos: %s fica livre" % at)
		_check.call(out.distance_to(at) <= 14.0 + R + 6.0, "casa de vários círculos: %s fica perto (%.1f px)"
				% [at, out.distance_to(at)])
	w.free()


## Ponto cercado por um anel de obstáculos: resolve() empurra para outro círculo do anel; a
## busca em anéis acha a saída de fora (a guardiã não entra no miolo, que nem cabe nela).
func _test_enclosed() -> void:
	var ring: Array = []
	for k: int in range(12):
		ring.append([HOME + Vector2.from_angle(TAU * k / 12.0) * 18.0, 12.0])
	var w := world_with(ring)
	_check.call(w.overlaps_solid(HOME, R), "cercado: miolo não cabe a guardiã")
	var out := w.free_point(HOME, R)
	_check.call(not w.overlaps_solid(out, R), "cercado: resultado livre")
	_check.call(out.distance_to(HOME) > 18.0 + 12.0, "cercado: sai para fora do anel")
	w.free()


func _test_bounds() -> void:
	var w := world_with([[Vector2(90, 0), 12.0]], Vector2(96, 96))
	var out := w.free_point(Vector2(94, 0), R)
	_check.call(not w.overlaps_solid(out, R), "limites: obstáculo encostado na borda, resultado livre")
	_check.call(absf(out.x) <= 96.0 and absf(out.y) <= 96.0, "limites: resultado dentro do mapa")
	_check.call(w.free_point(Vector2(300, -60), R) == Vector2(96, -60), "limites: ponto fora volta para a borda")
	w.free()


## Vila de verdade: o centro de cada obstáculo (casas, muros, árvores) vira ponto livre.
func _test_real_village() -> void:
	var w := TerrainTests._world("village", 31)
	var total := 0
	var bad := 0
	for cy: int in range(-2, 3):
		for cx: int in range(-2, 3):
			for solid: Array in w.chunk_data(Vector2i(cx, cy))["solids"]:
				total += 1
				var out := w.free_point(solid[0], R)
				if w.overlaps_solid(out, R) or out.distance_to(solid[0]) > float(solid[1]) + 60.0:
					bad += 1
	_check.call(total > 20, "vila: obstáculos reais para testar (%d)" % total)
	_check.call(bad == 0, "vila: todo centro de obstáculo vira ponto livre perto (%d falhas)" % bad)
	w.free()


func run(host: Node, check: Callable) -> void:
	_check = check
	var game := HyakkiGame.new()
	game.rng.seed = 5
	var world := world_with(HOUSE)
	game.world = world
	var pickups := PickupManager.new()
	pickups.game = game
	# Só as listas de _ready(), sem texturas: o teste não desenha.
	pickups.pos.resize(PickupManager.CAPACITY)
	pickups.prev.resize(PickupManager.CAPACITY)
	pickups.value.resize(PickupManager.CAPACITY)
	pickups.spd.resize(PickupManager.CAPACITY)
	pickups.attracted.resize(PickupManager.CAPACITY)
	pickups.alive.resize(PickupManager.CAPACITY)
	pickups.reset()
	pickups.spawn_item(&"chest", Vector2(128, 128))
	pickups.spawn_item(&"chest", Vector2(120, 126), {"boss": true})
	pickups.spawn_item(&"coin", Vector2(128, 128) + Vector2(4, 0))
	pickups.spawn_item(pickups.random_item_id(), Vector2(148, 130))
	_check.call(pickups.items.size() == 4, "pickup: quatro itens no chão")
	for item: Dictionary in pickups.items:
		_check.call(not world.overlaps_solid(item["pos"], R), "pickup: %s nasce fora da casa" % item["id"])
	_check.call(bool(pickups.items[1].get("boss", false)), "pickup: baú do chefe mantém o extra")
	pickups.spawn(Vector2(130, 127), 3)
	var gem := -1
	for i: int in range(PickupManager.CAPACITY):
		if pickups.alive[i] == 1:
			gem = i
	_check.call(gem >= 0 and not world.overlaps_solid(pickups.pos[gem], R), "pickup: brasa nasce fora da casa")
	# Furacão no meio da casa: a brasa desliza pela borda, não entra.
	for _k: int in range(60):
		pickups.pull_gems(Vector2(128, 128), 200.0, 120.0, 1.0 / 60.0)
	_check.call(not world.overlaps_solid(pickups.pos[gem], R - 0.5), "pickup: furacão não arrasta brasa para dentro")
	# Sem mapa: fica onde pediram.
	game.world = null
	pickups.spawn_item(&"chest", Vector2(128, 128))
	_check.call(pickups.items.back()["pos"] == Vector2(128, 128), "pickup: sem mapa, fica onde pediram")
	pickups.free()
	world.free()
	game.free()
	await host.get_tree().process_frame
