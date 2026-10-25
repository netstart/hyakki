class_name WorldMap
extends Node2D
## Mapa infinito por chunks (plano 5.1) com os biomas de data/biomes.json: chão procedural com
## os tiles do Ninja Adventure (shaders/terrain_ground.gdshader), decoração em MultiMesh com
## vento, copas que deixam ver o herói e sombras (chunk_view.gd), estruturas coerentes por fase
## (terrain_layout.gd: ruas e quarteirões, bambuzal, templo, ruínas, Yomi, ladeira), lanternas
## destrutíveis, perigos por fase (5.3) e limites (corredor do Templo, arena do Yomi).
##
## Determinismo (plano 15.1): obstáculos, lanternas, estátuas e lava são função pura da semente
## e do chunk, calculados no passo fixo, iguais em qualquer nível gráfico. Só a montagem visual
## (um chunk por quadro) e a densidade da decoração SEM colisão dependem do nível.

const TILE := 16
const CHUNK_TILES := 16
const CHUNK := TILE * CHUNK_TILES
const SIM_RADIUS := 2
const BUILDS_PER_FRAME := 1
const SAFE_RADIUS := 90.0
## Grade dos obstáculos para resolve(): célula de 32 px e folga para o maior raio móvel.
const SOLID_CELL := 32.0
const SOLID_PAD := 24.0
## Densidade máxima de decoração (GfxQuality "decor_density" na Alta): scatter() gera para ela.
const MAX_DENSITY := 1.25
const LAVA_LIGHT := Color(1.0, 0.45, 0.15)
const LANTERN_LIGHT := Color(1.0, 0.7, 0.36)
const STATUE_SPRITE := "buddha_orb"
## Chunks preparados em paralelo no máximo.
const MAX_JOBS := 3

var game: HyakkiGame
var stage: Dictionary = {}
var seed_value: int = 0
## Metade do tamanho jogável em x e y (0 = sem limite).
var bounds := Vector2.ZERO
## Perigo ativo: tempestade de cinza.
var storm_active: bool = false
var biome: Dictionary = {}
var layout := TerrainLayout.new()
var art := TerrainArt.new()

var _overlay: Node2D
var _views: Node2D
var _materials: Dictionary = {}
var _art_ready: bool = false

## Dados determinísticos por chunk: {"items", "solids", "paint", "keepout", "lanterns",
## "statues", "lava"}.
var _chunks: Dictionary = {}
## Obstáculos indexados por célula (Vector2i -> [[pos, r], ...]) e chunks já indexados com
## os vizinhos. resolve() roda para cada inimigo a cada passo: assim olha uma célula só.
var _solid_cells: Dictionary = {}
var _solid_ready: Dictionary = {}
var _sim_active: Dictionary = {}
var _built: Dictionary = {}
var _build_queue: Array[Vector2i] = []
## Preparação em segundo plano (máscara e decoração espalhada): Vector2i -> job.
var _jobs: Dictionary = {}
var _destroyed_lanterns: Dictionary = {}
var _lantern_enemy: Dictionary = {}
var _statue_timer: float = 0.0
var _storm_timer: float = 0.0


func _ready() -> void:
	_views = Node2D.new()
	_views.name = "Chunks"
	add_child(_views)
	_overlay = Node2D.new()
	_overlay.z_index = 21
	_overlay.draw.connect(_draw_bounds)
	add_child(_overlay)
	var settings := get_node_or_null(^"/root/Settings")
	if settings != null:
		settings.connect("changed", func(k: String) -> void:
				if k == GfxQuality.changed_signal_key():
					apply_quality())


func setup(stage_data: Dictionary, run_seed: int) -> void:
	stage = stage_data
	seed_value = run_seed
	_chunks.clear()
	_solid_cells.clear()
	_solid_ready.clear()
	_sim_active.clear()
	_clear_views()
	_destroyed_lanterns.clear()
	_lantern_enemy.clear()
	storm_active = false
	_storm_timer = 0.0
	_statue_timer = 0.0
	var b: Array = stage.get("bounds", [])
	bounds = Vector2(float(b[0]), float(b[1])) if b.size() == 2 else Vector2.ZERO
	biome = TerrainArt.biome(String(stage.get("biome", stage.get("id", "village"))))
	layout.setup(run_seed, String(stage.get("id", "")), biome, bounds)
	_art_ready = false
	# Monta a tela inicial já aqui (início da partida), não no primeiro quadro: o custo cai no
	# carregamento e não num quadro do jogo.
	if is_inside_tree() and game != null and game.player != null and _views != null:
		_ensure_art()
		var view := game.view_size()
		var screen := Rect2(game.player.sim_pos - view * 0.5, view)
		var lo := chunk_of(screen.position)
		var hi := chunk_of(screen.end)
		for cy: int in range(lo.y, hi.y + 1):
			for cx: int in range(lo.x, hi.x + 1):
				_build_queue.append(Vector2i(cx, cy))
		_build_screen(screen)


## Arte e materiais (só quando há desenho; os testes de simulação não precisam).
func _ensure_art() -> void:
	if _art_ready:
		return
	_art_ready = true
	art.build(biome)
	var ground := ShaderMaterial.new()
	ground.shader = load("res://shaders/terrain_ground.gdshader") as Shader
	ground.set_shader_parameter("materials", art.materials_texture)
	ground.set_shader_parameter("materials_px", Vector2(art.materials_texture.get_size()))
	ground.set_shader_parameter("mat_info", art.mat_info)
	ground.set_shader_parameter("mat_tint", art.mat_tint)
	var bands := PackedVector4Array([Vector4(-1, 1, 0, -1)])
	var rims := PackedVector4Array([Vector4.ZERO])
	var b_list: Array = biome.get("bands", [])
	var r_list: Array = biome.get("rims", [])
	for k: int in range(5):
		var b: Array = b_list[k] if k < b_list.size() else [-1, 1, 0]
		# Canal da máscara de cada camada: 3 = caminhos (R), 4 = calçamento (G), 5 = especial (B).
		var channel: int = [-1, -1, 0, 1, 2][k]
		bands.append(Vector4(float(b[0]), float(b[1]), float(b[2]), float(channel)))
		var r: Array = r_list[k] if k < r_list.size() else ["#000000", 0.0]
		var rc := Color(String(r[0]))
		rims.append(Vector4(rc.r, rc.g, rc.b, float(r[1])))
	ground.set_shader_parameter("bands", bands)
	ground.set_shader_parameter("rims", rims)
	ground.set_shader_parameter("scales", layout.scales)
	ground.set_shader_parameter("noise_offset", layout.noise_offset)
	ground.set_shader_parameter("shade", float(biome.get("shade", 0.07)))
	ground.set_shader_parameter("ripple", float(biome.get("ripple", 0.0)))
	ground.set_shader_parameter("cracks", float(biome.get("cracks", 0.0)))
	ground.set_shader_parameter("crack_color", Color(String(biome.get("crack_color", "#ff5a1e"))))
	ground.set_shader_parameter("lava_slot", float(art.lava_slot))
	var decor_shader := load("res://shaders/terrain_decor.gdshader") as Shader
	_materials = {"ground": ground}
	for key: String in ["flat", "decor", "canopy"]:
		var m := ShaderMaterial.new()
		m.shader = decor_shader
		m.set_shader_parameter("fade_on", 0.0)
		_materials[key] = m
	_apply_material_quality()


## Troca do nível gráfico ao vivo: uniforms novos e todos os chunks remontados agora.
func apply_quality() -> void:
	if not _art_ready:
		return
	_apply_material_quality()
	var built: Array = _built.keys()
	_clear_views()
	for c: Vector2i in built:
		_build(c)


func _apply_material_quality() -> void:
	var sway := 1.0 if bool(GfxQuality.budget("grass_sway")) else 0.0
	(_materials["ground"] as ShaderMaterial).set_shader_parameter("detail", float(GfxQuality.level()))
	for key: String in ["decor", "canopy"]:
		(_materials[key] as ShaderMaterial).set_shader_parameter("sway_on", sway)
	(_materials["flat"] as ShaderMaterial).set_shader_parameter("sway_on", 0.0)


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
									6.0 * game.enemy_damage_mult(), "statue_shot", 5.0, 0.0, &"statue")
		"lava":
			for c: Vector2i in _sim_active:
				for spot: Array in chunk_data(c)["lava"]:
					if player.sim_pos.distance_to(spot[0]) < float(spot[1]):
						if player.lava_cd <= 0.0:
							player.lava_cd = 0.6
							player.take_damage(float(hazard.get("damage", 6)) * game.enemy_damage_mult(), &"lava")
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


## Conteúdo determinístico de um chunk (cacheado): primeiro a jogabilidade (lanternas,
## estátuas, lava), depois a estrutura do bioma, que evita esses pontos.
func chunk_data(c: Vector2i) -> Dictionary:
	if _chunks.has(c):
		return _chunks[c]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, c.x, c.y, String(stage.get("id", ""))])
	var origin := Vector2(c.x * CHUNK, c.y * CHUNK)
	var data := {"solids": [], "lanterns": [], "statues": [], "lava": []}
	var reserved: Array = []
	var lanterns := float(stage.get("lanterns_per_chunk", 2)) * (CHUNK / 512.0) * (CHUNK / 512.0)
	var lantern_count := int(lanterns) + (1 if rng.randf() < fmod(lanterns, 1.0) else 0)
	for _k: int in range(lantern_count):
		var at := origin + Vector2(rng.randf_range(16, CHUNK - 16), rng.randf_range(16, CHUNK - 16))
		if at.length() > SAFE_RADIUS * 0.6 and _inside_bounds(at, 16.0):
			(data["lanterns"] as Array).append(at.round())
			reserved.append([at.round(), 12.0])
	var hazard: Dictionary = stage.get("hazard", {})
	var statue_items: Array = []
	match String(hazard.get("type", "")):
		"statues":
			if rng.randf() < 0.5 * float(hazard.get("per_chunk", 1)):
				var at := origin + Vector2(rng.randf_range(40, CHUNK - 40), rng.randf_range(40, CHUNK - 40))
				if at.length() > 200.0 and _inside_bounds(at, 30.0):
					(data["statues"] as Array).append(at.round())
					(data["solids"] as Array).append([at, 8.0])
					reserved.append([at, 22.0])
					statue_items.append({"s": STATUE_SPRITE, "p": at.round() + Vector2(0, 8), "solid": 8.0,
							"sway": 0.0, "layer": "auto", "shadow": 28.0, "rank": -1.0, "tone": 0.5,
							"light": ["#9fd0ff", 30.0, 0.5, -20.0]})
		"lava":
			if rng.randf() < 0.45:
				var at := origin + Vector2(rng.randf_range(30, CHUNK - 30), rng.randf_range(30, CHUNK - 30))
				if at.length() > 150.0:
					var r := rng.randf_range(18.0, 30.0)
					(data["lava"] as Array).append([at.round(), r])
					reserved.append([at.round(), r + 8.0])
	var structure := layout.generate(c, reserved)
	(data["solids"] as Array).append_array(structure["solids"])
	var items: Array = structure["items"]
	items.append_array(statue_items)
	data["items"] = items
	var paint: Array = structure["paint"]
	for spot: Array in data["lava"]:
		paint.append(["circle", 2, spot[0], float(spot[1])])
	data["paint"] = paint
	data["keepout"] = structure["keepout"]
	_chunks[c] = data
	return data


func _inside_bounds(p: Vector2, margin: float) -> bool:
	if bounds.x > 0.0 and absf(p.x) > bounds.x - margin:
		return false
	if bounds.y > 0.0 and absf(p.y) > bounds.y - margin:
		return false
	return true


static func weighted(rng: RandomNumberGenerator, weights: PackedFloat32Array) -> int:
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
	if game == null or game.player == null:
		return
	_ensure_art()
	var cam := game.player.position
	var view := game.view_size()
	var min_c := chunk_of(cam - view * 0.5 - Vector2(CHUNK, CHUNK) * 0.5)
	var max_c := chunk_of(cam + view * 0.5 + Vector2(CHUNK, CHUNK) * 0.5)
	for cy: int in range(min_c.y, max_c.y + 1):
		for cx: int in range(min_c.x, max_c.x + 1):
			var c := Vector2i(cx, cy)
			if not _built.has(c) and not _build_queue.has(c):
				_build_queue.append(c)
	# Sem nada montado (início, troca de fase) monta toda a tela de uma vez. Depois, a máscara e
	# a decoração espalhada de cada chunk novo são preparadas numa thread do WorkerThreadPool
	# (o mais perto primeiro) e o chunk pronto é montado aqui, um por quadro, sem travar.
	# Com o jogo parado (pausa, sequência de morte) a câmera não sai do lugar: nada a montar.
	var idle := GameClock.paused and not _built.is_empty()
	if not _build_queue.is_empty() and not idle:
		var center := chunk_of(cam)
		_build_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				return (a - center).length_squared() < (b - center).length_squared())
		if _built.is_empty():
			_build_screen(Rect2(cam - view * 0.5, view))
		else:
			for c: Vector2i in _build_queue:
				if _jobs.size() >= MAX_JOBS:
					break
				if not _jobs.has(c):
					_start_job(c)
	if not idle:
		_finish_jobs()
	# Remove chunks muito longe da câmera.
	for c: Vector2i in _built.keys():
		if c.x < min_c.x - 2 or c.x > max_c.x + 2 or c.y < min_c.y - 2 or c.y > max_c.y + 2:
			_unbuild(c)
	var dt := get_process_delta_time()
	var screen := Rect2(cam - view * 0.5, view)
	for v: ChunkView in _built.values():
		v.update_fade(cam, game.enemies, dt, screen)
	if bounds != Vector2.ZERO:
		_overlay.queue_redraw()


## Fração de decoração sem colisão que entra no nível atual (Baixa ⊂ Média ⊂ Alta).
static func density_fraction() -> float:
	return clampf(float(GfxQuality.budget("decor_density")) / MAX_DENSITY, 0.0, 1.0)


## Itens que o chunk desenha no nível atual: estrutura inteira + espalhados com rank abaixo da
## densidade.
func visual_items(c: Vector2i, mask: Image = null) -> Array:
	var data := chunk_data(c)
	var items: Array = (data["items"] as Array).duplicate()
	var frac := density_fraction()
	for it: Dictionary in layout.scatter(c, data, mask):
		if float(it["rank"]) < frac:
			items.append(it)
	return items


func _build(c: Vector2i) -> void:
	var paint: Array = chunk_data(c)["paint"]
	var mask := ChunkView.paint_mask(Vector2(c) * float(CHUNK), paint)
	_mount(c, visual_items(c, mask), mask)


func _mount(c: Vector2i, items: Array, mask: Image) -> void:
	_ensure_art()
	_build_queue.erase(c)
	var view := ChunkView.new()
	view.name = "C_%d_%d" % [c.x, c.y]
	_views.add_child(view)
	view.build(c, items, mask, art, _materials, bool(GfxQuality.budget("soft_shadows")))
	_built[c] = view


## Primeiro quadro: monta já só os chunks que aparecem na tela, preparados em paralelo; os da
## margem seguem pelo caminho normal (threads, um por quadro).
func _build_screen(screen: Rect2) -> void:
	var lo := chunk_of(screen.position)
	var hi := chunk_of(screen.end)
	var now: Array[Vector2i] = []
	for c: Vector2i in _build_queue:
		if c.x >= lo.x and c.x <= hi.x and c.y >= lo.y and c.y <= hi.y:
			now.append(c)
			if not _jobs.has(c):
				_start_job(c)
	for c: Vector2i in now:
		var job: Dictionary = _jobs[c]
		WorkerThreadPool.wait_for_task_completion(job["task"])
		_jobs.erase(c)
		_mount(c, job["items"], job["mask"])


## Prepara um chunk numa thread: a estrutura (jogabilidade) já está pronta aqui na principal.
func _start_job(c: Vector2i) -> void:
	var job := {"c": c, "data": chunk_data(c), "frac": density_fraction(), "layout": layout}
	job["task"] = WorkerThreadPool.add_task(_prepare.bind(job), false, "chunk")
	_jobs[c] = job


## Roda na thread: só lê a estrutura do chunk e o bioma; não toca na árvore nem em caches.
static func _prepare(job: Dictionary) -> void:
	var c: Vector2i = job["c"]
	var data: Dictionary = job["data"]
	var mask := ChunkView.paint_mask(Vector2(c) * float(CHUNK), data["paint"])
	var items: Array = (data["items"] as Array).duplicate()
	var frac := float(job["frac"])
	for it: Dictionary in (job["layout"] as TerrainLayout).scatter(c, data, mask):
		if float(it["rank"]) < frac:
			items.append(it)
	job["mask"] = mask
	job["items"] = items


## Monta um chunk já preparado por quadro (o que ainda está na fila e na tela).
func _finish_jobs() -> void:
	var mounted := 0
	for c: Vector2i in _jobs.keys():
		var job: Dictionary = _jobs[c]
		if mounted >= BUILDS_PER_FRAME or not WorkerThreadPool.is_task_completed(job["task"]):
			continue
		WorkerThreadPool.wait_for_task_completion(job["task"])
		_jobs.erase(c)
		if not _build_queue.has(c) or not job.has("mask"):
			continue
		_mount(c, job["items"], job["mask"])
		mounted += 1


func _exit_tree() -> void:
	_drop_jobs()


func _drop_jobs() -> void:
	for c: Vector2i in _jobs:
		WorkerThreadPool.wait_for_task_completion(_jobs[c]["task"])
	_jobs.clear()


func _unbuild(c: Vector2i) -> void:
	var view: Node = _built.get(c)
	_built.erase(c)
	if view != null:
		view.queue_free()


func _clear_views() -> void:
	for c: Vector2i in _built:
		var view: Node = _built[c]
		if view != null:
			view.queue_free()
	_built.clear()
	_build_queue.clear()
	_drop_jobs()


## Chunks montados (testes e luzes).
func built_views() -> Dictionary:
	return _built


## Luzes do cenário perto de `center` (lanternas de pedra, tochas, lava, estátuas, lanternas
## destrutíveis ainda de pé): [posição, cor, raio, força].
func collect_lights(center: Vector2, half: Vector2) -> Array:
	var out: Array = []
	var area := Rect2(center - half, half * 2.0)
	for c: Vector2i in _built:
		var view: ChunkView = _built[c]
		for l: Array in view.lights:
			if area.grow(float(l[2])).has_point(l[0]):
				out.append(l)
		for spot: Array in chunk_data(c)["lava"]:
			if area.grow(float(spot[1]) * 2.5).has_point(spot[0]):
				out.append([spot[0], LAVA_LIGHT, float(spot[1]) * 2.6, 0.95])
	for c: Vector2i in _lantern_enemy:
		for i: int in _lantern_enemy[c]:
			if i >= 0 and game.enemies.alive[i] == 1 and game.enemies.is_prop(i):
				var at: Vector2 = game.enemies.pos[i] + Vector2(0, -18)
				if area.grow(60.0).has_point(at):
					out.append([at, LANTERN_LIGHT, 60.0, 0.9])
	return out


## Fora dos limites: escurece em degradê (Templo e Yomi).
func _draw_bounds() -> void:
	if game == null or game.player == null:
		return
	var cam := game.player.position
	var view := game.view_size() + Vector2(64, 64)
	var rect := Rect2(cam - view * 0.5, view)
	for step: int in range(4):
		var inset := float(step) * 10.0
		var shade := Color(0.02, 0.01, 0.05, 0.3 + 0.18 * step)
		var bx := bounds.x + inset
		var by := bounds.y + inset
		if bounds.y > 0.0:
			if rect.position.y < -by:
				_overlay.draw_rect(Rect2(rect.position, Vector2(rect.size.x, -by - rect.position.y)), shade)
			if rect.end.y > by:
				_overlay.draw_rect(Rect2(Vector2(rect.position.x, by), Vector2(rect.size.x, rect.end.y - by)), shade)
		if bounds.x > 0.0:
			if rect.position.x < -bx:
				_overlay.draw_rect(Rect2(rect.position, Vector2(-bx - rect.position.x, rect.size.y)), shade)
			if rect.end.x > bx:
				_overlay.draw_rect(Rect2(Vector2(bx, rect.position.y), Vector2(rect.end.x - bx, rect.size.y)), shade)
