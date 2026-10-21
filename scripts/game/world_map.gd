class_name WorldMap
extends Node2D
## Mapa infinito por chunks (plano 5.1): chão com os tilesets do Ninja Adventure,
## cenário com colisão só na base (plano 8.7.2), lanternas destrutíveis, perigos por
## fase (5.3) e limites (corredor do Templo, arena do Yomi).
##
## Determinismo (plano 15.1): obstáculos e lanternas são função pura da semente e do
## chunk, calculados no passo fixo. Só a montagem dos tiles na tela acontece por frame.

const TILE := 16
const CHUNK_TILES := 16
const CHUNK := TILE * CHUNK_TILES
const SIM_RADIUS := 2
const BUILDS_PER_FRAME := 1
const SAFE_RADIUS := 90.0
## Grade dos obstáculos para resolve(): célula de 32 px e folga para o maior raio móvel.
const SOLID_CELL := 32.0
const SOLID_PAD := 24.0
const TILESETS := {
	"floor": "res://assets/art/tilesets/floor.png",
	"floor_detail": "res://assets/art/tilesets/floor_detail.png",
	"nature": "res://assets/art/tilesets/nature.png",
	"house": "res://assets/art/tilesets/house.png",
	"village_abandoned": "res://assets/art/tilesets/village_abandoned.png",
	"desert": "res://assets/art/tilesets/desert.png",
	"element": "res://assets/art/tilesets/element.png",
	"interior_floor": "res://assets/art/tilesets/interior_floor.png",
	"dungeon": "res://assets/art/tilesets/dungeon.png",
}

var game: HyakkiGame
var stage: Dictionary = {}
var seed_value: int = 0
## Metade do tamanho jogável em x e y (0 = sem limite).
var bounds := Vector2.ZERO
## Perigo ativo: tempestade de cinza.
var storm_active: bool = false

var _ground: TileMapLayer
var _details: TileMapLayer
var _decor_layer: Node2D
var _canopy_layer: Node2D
var _hazard_layer: Node2D
var _tile_set: TileSet
var _source_ids: Dictionary = {}
var _textures: Dictionary = {}
var _decor_defs: Array[Dictionary] = []
var _decor_weights: PackedFloat32Array = []
var _ground_tiles: Array = []
var _ground_weights: PackedFloat32Array = []

## Dados determinísticos por chunk: {"decor": [...], "solids": [[pos, r]], "lanterns": [...],
## "statues": [...], "lava": [...]}
var _chunks: Dictionary = {}
## Obstáculos indexados por célula (Vector2i -> [[pos, r], ...]) e chunks já indexados com
## os vizinhos. resolve() roda para cada inimigo a cada passo: assim olha uma célula só.
var _solid_cells: Dictionary = {}
var _solid_ready: Dictionary = {}
var _sim_active: Dictionary = {}
var _built: Dictionary = {}
var _build_queue: Array[Vector2i] = []
var _destroyed_lanterns: Dictionary = {}
var _lantern_enemy: Dictionary = {}
var _statue_timer: float = 0.0
var _storm_timer: float = 0.0


func _ready() -> void:
	_ground = TileMapLayer.new()
	_ground.z_index = -20
	add_child(_ground)
	_details = TileMapLayer.new()
	_details.z_index = -19
	add_child(_details)
	_hazard_layer = Node2D.new()
	_hazard_layer.z_index = -18
	_hazard_layer.draw.connect(_draw_hazards)
	add_child(_hazard_layer)
	_decor_layer = Node2D.new()
	_decor_layer.z_index = -10
	_decor_layer.draw.connect(_draw_decor.bind(false))
	add_child(_decor_layer)
	_canopy_layer = Node2D.new()
	_canopy_layer.z_index = 20
	_canopy_layer.draw.connect(_draw_decor.bind(true))
	add_child(_canopy_layer)
	_tile_set = TileSet.new()
	_tile_set.tile_size = Vector2i(TILE, TILE)
	_ground.tile_set = _tile_set
	_details.tile_set = _tile_set


func setup(stage_data: Dictionary, run_seed: int) -> void:
	stage = stage_data
	seed_value = run_seed
	_chunks.clear()
	_solid_cells.clear()
	_solid_ready.clear()
	_sim_active.clear()
	_built.clear()
	_build_queue.clear()
	_destroyed_lanterns.clear()
	_lantern_enemy.clear()
	_ground.clear()
	_details.clear()
	storm_active = false
	_storm_timer = 0.0
	_statue_timer = 0.0
	var b: Array = stage.get("bounds", [])
	bounds = Vector2(float(b[0]), float(b[1])) if b.size() == 2 else Vector2.ZERO
	_decor_defs.clear()
	_decor_weights.clear()
	for def: Variant in stage.get("decor", []):
		var d: Dictionary = (def as Dictionary).duplicate()
		var tex := _texture(String(d["tileset"]))
		var r: Array = d["rect"]
		d["src"] = _tight_rect(tex, Rect2(r[0] * TILE, r[1] * TILE, r[2] * TILE, r[3] * TILE))
		d["tex"] = tex
		_decor_defs.append(d)
		_decor_weights.append(float(d.get("weight", 1)))
	var ground: Dictionary = stage.get("ground", {})
	_ground_tiles = ground.get("tiles", [])
	_ground_weights.clear()
	for t: Variant in _ground_tiles:
		_ground_weights.append(float((t as Array)[2]))
	queue_redraw()


# --- Simulação (passo fixo) -----------------------------------------------------

func step(dt: float) -> void:
	var center := chunk_of(game.player.sim_pos)
	var wanted: Dictionary = {}
	for cy: int in range(center.y - SIM_RADIUS, center.y + SIM_RADIUS + 1):
		for cx: int in range(center.x - SIM_RADIUS, center.x + SIM_RADIUS + 1):
			var c := Vector2i(cx, cy)
			wanted[c] = true
			if not _sim_active.has(c):
				_activate(c)
	for c: Vector2i in _sim_active.keys():
		if not wanted.has(c):
			_deactivate(c)
	_step_hazards(dt)


func _activate(c: Vector2i) -> void:
	_sim_active[c] = true
	var data := chunk_data(c)
	var destroyed: Dictionary = _destroyed_lanterns.get(c, {})
	var lantern_ids: Array[int] = []
	for k: int in range((data["lanterns"] as Array).size()):
		if destroyed.has(k):
			lantern_ids.append(-1)
			continue
		var at: Vector2 = data["lanterns"][k]
		var i := game.enemies.spawn(&"stone_lantern", at, 1.0, 0.0)
		lantern_ids.append(i)
		if i >= 0:
			game.enemies.set_meta("lantern_%d" % i, [c, k])
	_lantern_enemy[c] = lantern_ids


func _deactivate(c: Vector2i) -> void:
	_sim_active.erase(c)
	var ids: Array = _lantern_enemy.get(c, [])
	for i: int in ids:
		if i >= 0 and game.enemies.alive[i] == 1 and game.enemies.is_prop(i):
			game.enemies.despawn(i)
	_lantern_enemy.erase(c)


## Chamado quando uma lanterna é destruída, para não voltar ao reentrar no chunk.
func on_prop_destroyed(enemy_index: int) -> void:
	var key := "lantern_%d" % enemy_index
	if not game.enemies.has_meta(key):
		return
	var info: Array = game.enemies.get_meta(key)
	game.enemies.remove_meta(key)
	var c: Vector2i = info[0]
	if not _destroyed_lanterns.has(c):
		_destroyed_lanterns[c] = {}
	(_destroyed_lanterns[c] as Dictionary)[int(info[1])] = true


func _step_hazards(dt: float) -> void:
	var hazard: Dictionary = stage.get("hazard", {})
	var kind := String(hazard.get("type", ""))
	var player := game.player
	match kind:
		"statues":
			_statue_timer -= dt
			if _statue_timer <= 0.0:
				_statue_timer = float(hazard.get("interval", 4.5))
				for c: Vector2i in _sim_active:
					for at: Vector2 in chunk_data(c)["statues"]:
						var d := player.sim_pos - at
						if d.length() < 220.0 and d.length() > 30.0:
							game.enemy_shots.spawn(at, d.normalized() * 55.0,
									6.0 * game.enemy_damage_mult(), "statue_shot")
		"lava":
			for c: Vector2i in _sim_active:
				for spot: Array in chunk_data(c)["lava"]:
					if player.sim_pos.distance_to(spot[0]) < float(spot[1]):
						if player.lava_cd <= 0.0:
							player.lava_cd = 0.6
							player.take_damage(float(hazard.get("damage", 6)) * game.enemy_damage_mult())
		"ash_storm":
			_storm_timer += dt
			var interval := float(hazard.get("interval", 90))
			var duration := float(hazard.get("duration", 15))
			storm_active = fmod(_storm_timer, interval) > interval - duration
			game.enemies.speed_mult = 1.0
			if storm_active:
				player.slow_time = maxf(player.slow_time, 0.1)
				player.slow_factor = 1.0 - float(hazard.get("slow", 0.2))


## Empurra um círculo para fora dos obstáculos (desliza pela borda, plano 8.7.2).
func resolve(p: Vector2, r: float) -> Vector2:
	if r > SOLID_PAD:
		return _resolve_wide(p, r)
	var c := chunk_of(p)
	if not _solid_ready.has(c):
		_index_solids_around(c)
	var cell := Vector2i(floori(p.x / SOLID_CELL), floori(p.y / SOLID_CELL))
	var solids: Array = _solid_cells.get(cell, [])
	for solid: Array in solids:
		var center: Vector2 = solid[0]
		var min_dist: float = float(solid[1]) + r
		var d := p - center
		var d2 := d.length_squared()
		if d2 < min_dist * min_dist:
			if d2 < 0.0001:
				d = Vector2.RIGHT
				d2 = 1.0
			p = center + d / sqrt(d2) * min_dist
	return p


## Caminho antigo (9 chunks) para raios maiores que a folga da grade.
func _resolve_wide(p: Vector2, r: float) -> Vector2:
	var c := chunk_of(p)
	for cy: int in range(c.y - 1, c.y + 2):
		for cx: int in range(c.x - 1, c.x + 2):
			for solid: Array in chunk_data(Vector2i(cx, cy))["solids"]:
				var center: Vector2 = solid[0]
				var min_dist: float = float(solid[1]) + r
				var d := p - center
				var d2 := d.length_squared()
				if d2 < min_dist * min_dist:
					if d2 < 0.0001:
						d = Vector2.RIGHT
						d2 = 1.0
					p = center + d / sqrt(d2) * min_dist
	return p


## Garante que os obstáculos do chunk e dos 8 vizinhos estão na grade.
func _index_solids_around(c: Vector2i) -> void:
	for cy: int in range(c.y - 1, c.y + 2):
		for cx: int in range(c.x - 1, c.x + 2):
			var n := Vector2i(cx, cy)
			if _solid_ready.has(n):
				continue
			var data := chunk_data(n)
			if bool(data.get("indexed", false)):
				continue
			data["indexed"] = true
			for solid: Array in data["solids"]:
				var center: Vector2 = solid[0]
				var reach := float(solid[1]) + SOLID_PAD
				var lo := Vector2i(floori((center.x - reach) / SOLID_CELL), floori((center.y - reach) / SOLID_CELL))
				var hi := Vector2i(floori((center.x + reach) / SOLID_CELL), floori((center.y + reach) / SOLID_CELL))
				for gy: int in range(lo.y, hi.y + 1):
					for gx: int in range(lo.x, hi.x + 1):
						var key := Vector2i(gx, gy)
						if not _solid_cells.has(key):
							_solid_cells[key] = []
						(_solid_cells[key] as Array).append(solid)
	_solid_ready[c] = true


func clamp_to_bounds(p: Vector2) -> Vector2:
	if bounds.x > 0.0:
		p.x = clampf(p.x, -bounds.x, bounds.x)
	if bounds.y > 0.0:
		p.y = clampf(p.y, -bounds.y, bounds.y)
	return p


func chunk_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))


## Conteúdo determinístico de um chunk (cacheado).
func chunk_data(c: Vector2i) -> Dictionary:
	if _chunks.has(c):
		return _chunks[c]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, c.x, c.y, String(stage.get("id", ""))])
	var origin := Vector2(c.x * CHUNK, c.y * CHUNK)
	var data := {"decor": [], "solids": [], "lanterns": [], "statues": [], "lava": []}
	var placed: Array[Vector2] = []
	var per_chunk := float(stage.get("decor_per_chunk", 8)) * (CHUNK / 512.0) * (CHUNK / 512.0)
	var count := int(per_chunk) + (1 if rng.randf() < fmod(per_chunk, 1.0) else 0)
	for _k: int in range(count):
		if _decor_defs.is_empty():
			break
		var at := origin + Vector2(rng.randf_range(8, CHUNK - 8), rng.randf_range(8, CHUNK - 8))
		if at.length() < SAFE_RADIUS or not _inside_bounds(at, 20.0):
			continue
		var def := _decor_defs[_weighted(rng, _decor_weights)]
		var solid := float(def.get("solid", 0))
		var too_close := false
		for other: Vector2 in placed:
			if other.distance_to(at) < solid + 20.0:
				too_close = true
				break
		if too_close:
			continue
		placed.append(at)
		(data["decor"] as Array).append({"def": def, "pos": at.round()})
		if solid > 0.0:
			(data["solids"] as Array).append([at + Vector2(0, -solid * 0.3), solid])
	var lanterns := float(stage.get("lanterns_per_chunk", 2)) * (CHUNK / 512.0) * (CHUNK / 512.0)
	var lantern_count := int(lanterns) + (1 if rng.randf() < fmod(lanterns, 1.0) else 0)
	for _k: int in range(lantern_count):
		var at := origin + Vector2(rng.randf_range(16, CHUNK - 16), rng.randf_range(16, CHUNK - 16))
		if at.length() > SAFE_RADIUS * 0.6 and _inside_bounds(at, 16.0):
			(data["lanterns"] as Array).append(at.round())
	var hazard: Dictionary = stage.get("hazard", {})
	match String(hazard.get("type", "")):
		"statues":
			if rng.randf() < 0.5 * float(hazard.get("per_chunk", 1)):
				var at := origin + Vector2(rng.randf_range(40, CHUNK - 40), rng.randf_range(40, CHUNK - 40))
				if at.length() > 200.0 and _inside_bounds(at, 30.0):
					(data["statues"] as Array).append(at.round())
					(data["solids"] as Array).append([at, 8.0])
		"lava":
			if rng.randf() < 0.45:
				var at := origin + Vector2(rng.randf_range(30, CHUNK - 30), rng.randf_range(30, CHUNK - 30))
				if at.length() > 150.0:
					(data["lava"] as Array).append([at.round(), rng.randf_range(18.0, 30.0)])
	_chunks[c] = data
	return data


func _inside_bounds(p: Vector2, margin: float) -> bool:
	if bounds.x > 0.0 and absf(p.x) > bounds.x - margin:
		return false
	if bounds.y > 0.0 and absf(p.y) > bounds.y - margin:
		return false
	return true


static func _weighted(rng: RandomNumberGenerator, weights: PackedFloat32Array) -> int:
	var total := 0.0
	for w: float in weights:
		total += w
	var roll := rng.randf() * total
	for i: int in range(weights.size()):
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1


# --- Desenho (por frame) --------------------------------------------------------

func _process(_delta: float) -> void:
	var cam := game.player.position
	var view := game.view_size()
	var min_c := chunk_of(cam - view * 0.5 - Vector2(CHUNK, CHUNK) * 0.5)
	var max_c := chunk_of(cam + view * 0.5 + Vector2(CHUNK, CHUNK) * 0.5)
	for cy: int in range(min_c.y, max_c.y + 1):
		for cx: int in range(min_c.x, max_c.x + 1):
			var c := Vector2i(cx, cy)
			if not _built.has(c) and not _build_queue.has(c):
				_build_queue.append(c)
	# Constrói primeiro o chunk mais perto, um por frame, para não travar.
	if not _build_queue.is_empty():
		var center := chunk_of(cam)
		_build_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				return (a - center).length_squared() < (b - center).length_squared())
		for _k: int in range(BUILDS_PER_FRAME):
			if _build_queue.is_empty():
				break
			_build(_build_queue.pop_front())
	# Remove chunks muito longe da câmera.
	for c: Vector2i in _built.keys():
		if c.x < min_c.x - 2 or c.x > max_c.x + 2 or c.y < min_c.y - 2 or c.y > max_c.y + 2:
			_unbuild(c)
	_decor_layer.queue_redraw()
	_canopy_layer.queue_redraw()
	_hazard_layer.queue_redraw()


func _build(c: Vector2i) -> void:
	_built[c] = true
	var ground: Dictionary = stage.get("ground", {})
	var ground_source := _source(String(ground.get("tileset", "floor")))
	var block: Array = ground.get("block", [])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, c.x, c.y, "ground"])
	var details: Dictionary = stage.get("details", {})
	var detail_tiles: Array = details.get("tiles", [])
	var detail_source := _source(String(details.get("tileset", "floor_detail"))) if not detail_tiles.is_empty() else -1
	var density := float(details.get("density", 0.0))
	for ty: int in range(CHUNK_TILES):
		for tx: int in range(CHUNK_TILES):
			var cell := Vector2i(c.x * CHUNK_TILES + tx, c.y * CHUNK_TILES + ty)
			var atlas: Vector2i
			if block.size() == 4:
				atlas = Vector2i(int(block[0]) + posmod(cell.x, int(block[2])),
						int(block[1]) + posmod(cell.y, int(block[3])))
			else:
				var t: Array = _ground_tiles[_weighted(rng, _ground_weights)]
				atlas = Vector2i(int(t[0]), int(t[1]))
			_ensure_tile(ground_source, atlas)
			_ground.set_cell(cell, ground_source, atlas)
			if detail_source >= 0 and rng.randf() < density:
				var d: Array = detail_tiles[rng.randi_range(0, detail_tiles.size() - 1)]
				var datlas := Vector2i(int(d[0]), int(d[1]))
				_ensure_tile(detail_source, datlas)
				_details.set_cell(cell, detail_source, datlas)


func _unbuild(c: Vector2i) -> void:
	_built.erase(c)
	for ty: int in range(CHUNK_TILES):
		for tx: int in range(CHUNK_TILES):
			var cell := Vector2i(c.x * CHUNK_TILES + tx, c.y * CHUNK_TILES + ty)
			_ground.erase_cell(cell)
			_details.erase_cell(cell)


func _draw_decor(canopy: bool) -> void:
	var layer := _canopy_layer if canopy else _decor_layer
	var player_pos := game.player.position
	for c: Vector2i in _built:
		var data := chunk_data(c)
		for item: Dictionary in data["decor"]:
			var def: Dictionary = item["def"]
			var src: Rect2 = def["src"]
			var at: Vector2 = item["pos"]
			var dst := Rect2(at - Vector2(src.size.x * 0.5, src.size.y), src.size)
			if not canopy:
				layer.draw_texture_rect_region(def["tex"], dst, src)
			elif src.size.y > 24.0:
				# Copa: a parte de cima dos objetos altos fica na frente dos personagens.
				var cut := src.size.y - 14.0
				var top_src := Rect2(src.position, Vector2(src.size.x, cut))
				var top_dst := Rect2(dst.position, Vector2(dst.size.x, cut))
				var alpha := 0.55 if top_dst.grow(4.0).has_point(player_pos) else 1.0
				layer.draw_texture_rect_region(def["tex"], top_dst, top_src, Color(1, 1, 1, alpha))
		if not canopy:
			for at: Vector2 in data["statues"]:
				var tex := _texture("house")
				var src := Rect2(3 * TILE, 15 * TILE, 2 * TILE, 2 * TILE)
				layer.draw_texture_rect_region(tex, Rect2(at - Vector2(16, 28), src.size), src)
	if canopy and bounds != Vector2.ZERO:
		_draw_bounds(layer)


func _draw_hazards() -> void:
	var time := GameClock.game_time
	for c: Vector2i in _built:
		for spot: Array in chunk_data(c)["lava"]:
			var pulse := 0.5 + 0.5 * sin(time * 2.0 + float(spot[1]))
			_hazard_layer.draw_circle(spot[0], float(spot[1]), Color(1.0, 0.35, 0.1, 0.45 + 0.15 * pulse))
			_hazard_layer.draw_circle(spot[0], float(spot[1]) * 0.6, Color(1.0, 0.75, 0.25, 0.4 + 0.2 * pulse))


## Fora dos limites: escurece (Templo e Yomi).
func _draw_bounds(layer: Node2D) -> void:
	var cam := game.player.position
	var view := game.view_size() + Vector2(64, 64)
	var shade := Color(0.02, 0.01, 0.05, 0.85)
	var rect := Rect2(cam - view * 0.5, view)
	if bounds.y > 0.0:
		if rect.position.y < -bounds.y:
			layer.draw_rect(Rect2(rect.position, Vector2(rect.size.x, -bounds.y - rect.position.y)), shade)
		if rect.end.y > bounds.y:
			layer.draw_rect(Rect2(Vector2(rect.position.x, bounds.y), Vector2(rect.size.x, rect.end.y - bounds.y)), shade)
	if bounds.x > 0.0:
		if rect.position.x < -bounds.x:
			layer.draw_rect(Rect2(rect.position, Vector2(-bounds.x - rect.position.x, rect.size.y)), shade)
		if rect.end.x > bounds.x:
			layer.draw_rect(Rect2(Vector2(bounds.x, rect.position.y), Vector2(rect.end.x - bounds.x, rect.size.y)), shade)


func _texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load(TILESETS[name]) as Texture2D
	return _textures[name]


func _source(name: String) -> int:
	if _source_ids.has(name):
		return _source_ids[name]
	var src := TileSetAtlasSource.new()
	src.texture = _texture(name)
	src.texture_region_size = Vector2i(TILE, TILE)
	var id := _tile_set.add_source(src)
	_source_ids[name] = id
	return id


func _ensure_tile(source_id: int, atlas: Vector2i) -> void:
	var src := _tile_set.get_source(source_id) as TileSetAtlasSource
	if not src.has_tile(atlas):
		src.create_tile(atlas)


## Aperta o retângulo ao redor dos pixels opacos (os retângulos dos dados são aproximados).
func _tight_rect(tex: Texture2D, rect: Rect2) -> Rect2:
	var image := tex.get_image()
	if image.is_compressed():
		image.decompress()
	var region := image.get_region(Rect2i(rect))
	var used := region.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return rect
	return Rect2(rect.position + Vector2(used.position), Vector2(used.size))
