class_name JourneyMap
extends Control
## Mapa da Jornada do Guardião (seleção de fase): o arquipélago pintado a tinta, à moda de
## um mapa antigo, com os pontos de luta ligados pela estrada. Cada ponto mostra o chefe
## final da fase: colorido e com o selo 祓 quando vencida, em silhueta com a lanterna
## chamando quando liberada, e sob a névoa quando bloqueada. A guardiã escolhida fica ao
## lado do ponto selecionado e caminha até o próximo.
##
## Desempenho (Android): o mapa só é redesenhado quando muda de tamanho ou de estado; as
## animações (lanterna, guardiã) são Tweens em nós filhos pequenos.

signal stage_selected(id: StringName)

## Lado do quadrado tocável de cada ponto (o medalhão tem 28 px de diâmetro).
const NODE_SIZE := 32.0
## Distância mínima entre os centros dos pontos, em x ou em y (os quadrados não se tocam).
const MIN_GAP := 35.0
## Margens da área onde os pontos são encaixados (título em cima, luas embaixo).
const MARGIN_LEFT := 26.0
const MARGIN_RIGHT := 26.0
const MARGIN_TOP := 52.0
const MARGIN_BOTTOM := 30.0
const SEAL_FONT := "res://assets/fonts/fusion_pixel_12_ja.woff2"
const SEAL_FALLBACK := "祓"

const SEA_LIGHT := Color("2d3a6b")
const SEA_DARK := Color("141a38")
const WAVE := Color(0.62, 0.7, 0.92, 0.32)
const LAND := Color("cbbd8a")
const LAND_DARK := Color("a99a64")
const CLIFF := Color("6e5330")
const INK := Color("24170f")
const SNOW := Color("f1efe6")
const SAND := Color("e9d49a")
const EMBER := Color("7a2a20")
const ROAD_RED := Color("c0392b")
const ROAD_OPEN := Color("f6e7bf")
const GOLD := Color("ffd166")
const VERMILION := Color("b8322a")
## Silhueta do chefe ainda não vencido (liberada) e a mais apagada (bloqueada).
const SILHOUETTE := Color(0.06, 0.05, 0.1)
const SILHOUETTE_LOCKED := Color(0.1, 0.09, 0.16, 0.55)

static var _face_cache: Dictionary = {}

var nodes: Dictionary = {}
var selected: StringName = &""

var _xf := Transform2D.IDENTITY
var _centers: Dictionary = {}
var _land: Array[PackedVector2Array] = []
var _snow: Array[PackedVector2Array] = []
var _korea := PackedVector2Array()
var _roads: Dictionary = {}
var _waves: PackedVector2Array = PackedVector2Array()
var _states: Dictionary = {}
var _seal_font: Font
var _hero: MapHero
var _title: Label
var _laid_out_size := Vector2.ZERO


func _ready() -> void:
	clip_contents = true
	_seal_font = load(SEAL_FONT) as Font if ResourceLoader.exists(SEAL_FONT) else null
	for id: StringName in DB.ids("stages"):
		var node := MapNode.new()
		node.name = "Node_%s" % id
		node.stage_id = id
		node.size = Vector2(NODE_SIZE, NODE_SIZE)
		node.custom_minimum_size = node.size
		node.focus_mode = Control.FOCUS_ALL
		node.seal_font = _seal_font
		node.face = face_texture(_final_boss(id))
		node.shape = silhouette_texture(_final_boss(id), 20)
		node.pressed.connect(_on_node_pressed.bind(id))
		node.focus_entered.connect(select.bind(id))
		add_child(node)
		nodes[id] = node
	_hero = MapHero.new()
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hero)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	_title.add_theme_constant_override("outline_size", 6)
	_title.add_theme_color_override("font_outline_color", Color("120c1e"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	resized.connect(_layout)


## Atualiza estados (vencida / liberada / bloqueada), luas e a guardiã escolhida.
func refresh(hero_id: StringName) -> void:
	_title.text = tr("stages.title")
	for id: StringName in nodes:
		var best := SaveManager.stage_best(id)
		var node := nodes[id] as MapNode
		_states[id] = JourneyGeo.stage_state(bool(best["won"]), MetaProgress.is_stage_unlocked(id))
		node.state = _states[id]
		node.moons = maxi(0, int(best["max_moon"])) if bool(best["won"]) else 0
		node.seal_text = _seal_kanji()
		node.tooltip_text = _node_tooltip(id)
		node.set_glowing(node.state == &"open")
		node.queue_redraw()
	_hero.set_hero(DB.heroes.get(hero_id, DB.heroes.get(&"aki", {})))
	_layout()
	queue_redraw()


func node_state(id: StringName) -> StringName:
	return _states.get(id, &"locked")


func node_center(id: StringName) -> Vector2:
	return _centers.get(id, Vector2.ZERO)


## Estado do trecho de estrada que chega à fase (o mesmo da fase de destino).
func road_state(id: StringName) -> StringName:
	return node_state(id) if _roads.has(id) else &""


func hero_position() -> Vector2:
	return _hero.position + _hero.size * 0.5


func select(id: StringName, animate: bool = true) -> void:
	if not nodes.has(id):
		return
	var changed := id != selected
	for key: StringName in nodes:
		(nodes[key] as MapNode).selected = key == id
		(nodes[key] as MapNode).queue_redraw()
	selected = id
	_place_hero(animate and changed)
	if changed:
		stage_selected.emit(id)


func focus_selected() -> void:
	if nodes.has(selected):
		(nodes[selected] as Control).grab_focus()


func _on_node_pressed(id: StringName) -> void:
	AudioManager.play_ui("ui_accept")
	(nodes[id] as Control).grab_focus()
	select(id)


static func _final_boss(stage_id: StringName) -> StringName:
	var bosses: Array = DB.stage(stage_id).get("bosses", [])
	return StringName(String((bosses[bosses.size() - 1] as Dictionary)["id"])) if not bosses.is_empty() else &""


static func faceset_path(boss_id: StringName) -> String:
	var data: Dictionary = DB.bosses.get(boss_id, {})
	if data.is_empty():
		return ""
	return String(data["sprite"]["path"]).get_base_dir().path_join("Faceset.png")


## Faceset recortado em círculo (o retrato do Ninja Adventure é quadrado e opaco).
static func face_texture(boss_id: StringName, side: int = 24) -> Texture2D:
	var path := faceset_path(boss_id)
	var key := "%s|%d" % [path, side]
	if _face_cache.has(key):
		return _face_cache[key]
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var image := (load(path) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(side, side, Image.INTERPOLATE_NEAREST)
	var r := side * 0.5
	for y: int in range(side):
		for x: int in range(side):
			if Vector2(x + 0.5 - r, y + 0.5 - r).length() > r:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	var tex := ImageTexture.create_from_image(image)
	_face_cache[key] = tex
	return tex


## Silhueta do corpo do chefe: primeiro quadro do sprite (que tem fundo transparente),
## recortado no que é desenhado, reduzido para caber em `side` e pintado de branco (a cor
## vem do modulate). O retrato (Faceset) é opaco e viraria um disco liso.
static func silhouette_texture(boss_id: StringName, side: int = 24) -> Texture2D:
	var data: Dictionary = DB.bosses.get(boss_id, {})
	if data.is_empty():
		return null
	var sprite: Dictionary = data["sprite"]
	var path := String(sprite["path"])
	var key := "shape|%s|%d" % [path, side]
	if _face_cache.has(key):
		return _face_cache[key]
	if not ResourceLoader.exists(path):
		return null
	var image := (load(path) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var frame: Array = sprite.get("frame", [16, 16])
	image = image.get_region(Rect2i(0, 0, mini(int(frame[0]), image.get_width()), mini(int(frame[1]), image.get_height())))
	var used := image.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		image = image.get_region(used)
	var factor := minf(float(side) / image.get_width(), float(side) / image.get_height())
	if factor >= 2.0:
		factor = floorf(factor)
	var fit := Vector2i(maxi(1, roundi(image.get_width() * factor)), maxi(1, roundi(image.get_height() * factor)))
	image.resize(fit.x, fit.y, Image.INTERPOLATE_NEAREST if factor >= 1.0 else Image.INTERPOLATE_BILINEAR)
	var out := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	var origin := Vector2i((side - fit.x) / 2, side - fit.y - maxi(0, (side - fit.y) / 4))
	for y: int in range(fit.y):
		for x: int in range(fit.x):
			if image.get_pixel(x, y).a > 0.35:
				out.set_pixel(origin.x + x, origin.y + y, Color.WHITE)
	var tex := ImageTexture.create_from_image(out)
	_face_cache[key] = tex
	return tex


func _seal_kanji() -> String:
	var text := tr("stages.seal_kanji")
	if text == "stages.seal_kanji" or text.is_empty():
		text = SEAL_FALLBACK
	return text


func _node_tooltip(id: StringName) -> String:
	if id == &"secret" and node_state(id) == &"locked":
		return "???"
	return tr("stage.%s.name" % id)


# --- Layout -------------------------------------------------------------------------

func _layout() -> void:
	if size.x < 10.0 or size.y < 10.0 or nodes.is_empty():
		return
	var area := Rect2(Vector2(MARGIN_LEFT, MARGIN_TOP),
			size - Vector2(MARGIN_LEFT + MARGIN_RIGHT, MARGIN_TOP + MARGIN_BOTTOM))
	var projected: Array[Vector2] = []
	for id: StringName in nodes:
		projected.append(JourneyGeo.project(JourneyGeo.STAGES.get(id, Vector2(135, 35))))
	_xf = JourneyGeo.fit(projected, area)
	var raw := {}
	for id: StringName in nodes:
		raw[id] = _xf * JourneyGeo.project(JourneyGeo.STAGES.get(id, Vector2(135, 35)))
	_centers = JourneyGeo.separate(raw, MIN_GAP, area)
	for id: StringName in nodes:
		var node := nodes[id] as MapNode
		node.position = (_centers[id] as Vector2) - node.size * 0.5
	_set_focus_neighbors()
	_land.clear()
	for poly: Array in [JourneyGeo.HOKKAIDO, JourneyGeo.HONSHU, JourneyGeo.SHIKOKU, JourneyGeo.KYUSHU]:
		_land.append(JourneyGeo.project_all(poly, _xf))
	for poly: Array in JourneyGeo.ISLETS:
		_land.append(JourneyGeo.project_all(poly, _xf))
	_korea = JourneyGeo.project_all(JourneyGeo.KOREA, _xf)
	# Neve: o norte de Honshu (acima de 39,7°) e Hokkaido inteiro.
	var north := JourneyGeo.project_all([Vector2(137, 39.7), Vector2(144, 39.7), Vector2(144, 46),
			Vector2(137, 46)], _xf)
	_snow.clear()
	_snow.append_array(Geometry2D.intersect_polygons(_land[1], north))
	_snow.append(_land[0])
	_build_roads()
	_build_waves()
	var title_left := 96.0
	_title.position = Vector2(title_left, 6)
	_title.size = Vector2(size.x - title_left - 8.0, 30)
	_laid_out_size = size
	_place_hero(false)
	queue_redraw()


func _build_roads() -> void:
	_roads.clear()
	var ordered := DB.ids("stages")
	ordered.sort_custom(func(a: StringName, b: StringName) -> bool:
		return int(DB.stage(a)["order"]) < int(DB.stage(b)["order"]))
	for i: int in range(1, ordered.size()):
		var from: StringName = ordered[i - 1]
		var to: StringName = ordered[i]
		var pts := PackedVector2Array([_centers[from]])
		pts.append_array(JourneyGeo.project_all(JourneyGeo.VIA.get(to, []), _xf))
		pts.append(_centers[to])
		_roads[to] = JourneyGeo.catmull_rom(pts, 10)


## Marcas de onda (seigaiha) espalhadas só pelo mar, numa grade com desvio fixo.
func _build_waves() -> void:
	_waves = PackedVector2Array()
	var step := Vector2(30, 22)
	var rows := int(size.y / step.y) + 1
	var cols := int(size.x / step.x) + 1
	for row: int in range(rows):
		for col: int in range(cols):
			var p := Vector2(col * step.x + (step.x * 0.5 if row % 2 == 1 else 0.0) + 6.0,
					row * step.y + 14.0) + Vector2(sin(row * 3.1 + col) * 5.0, cos(col * 1.7 + row) * 3.0)
			if _on_land(p, 7.0):
				continue
			_waves.append(p)


func _on_land(p: Vector2, pad: float) -> bool:
	for poly: PackedVector2Array in _land + [_korea]:
		for offset: Vector2 in [Vector2.ZERO, Vector2(pad, 0), Vector2(-pad, 0), Vector2(0, pad), Vector2(0, -pad)]:
			if Geometry2D.is_point_in_polygon(p + offset, poly):
				return true
	return false


## Setas do teclado/controle: vizinho mais próximo em cada direção.
func _set_focus_neighbors() -> void:
	var dirs := {SIDE_LEFT: Vector2.LEFT, SIDE_RIGHT: Vector2.RIGHT, SIDE_TOP: Vector2.UP, SIDE_BOTTOM: Vector2.DOWN}
	for id: StringName in nodes:
		var node := nodes[id] as Control
		for side: int in dirs:
			var best: StringName = &""
			var best_score := INF
			for other: StringName in nodes:
				if other == id:
					continue
				var delta: Vector2 = (_centers[other] as Vector2) - (_centers[id] as Vector2)
				var along := delta.dot(dirs[side])
				if along <= 0.0 or along < absf(delta.cross(dirs[side])) * 0.5:
					continue
				var score := delta.length() + absf(delta.cross(dirs[side])) * 1.5
				if score < best_score:
					best_score = score
					best = other
			node.set_focus_neighbor(side, node.get_path_to(nodes[best]) if best != &"" else NodePath())


func _place_hero(animate: bool) -> void:
	if _hero == null or not _centers.has(selected):
		return
	var target := _hero_spot(selected)
	if animate and is_inside_tree():
		_hero.walk_to(target)
	else:
		_hero.stop_at(target)


## Lugar da guardiã ao lado do ponto: o lado mais longe dos outros pontos, dentro do mapa.
func _hero_spot(id: StringName) -> Vector2:
	var c: Vector2 = _centers[id]
	var hs := _hero.size
	var best := c + Vector2(-NODE_SIZE * 0.5 - hs.x * 0.5 - 2.0, -4.0)
	var best_score := -INF
	var sides: Array[Vector2] = [Vector2(-1, -0.25), Vector2(1, -0.25), Vector2(0, -1), Vector2(-0.8, 0.6),
			Vector2(0.8, 0.6)]
	for offset: Vector2 in sides:
		var spot := c + Vector2(offset.x * (NODE_SIZE * 0.5 + hs.x * 0.5 + 2.0),
				offset.y * (NODE_SIZE * 0.5 + hs.y * 0.5))
		var rect := Rect2(spot - hs * 0.5, hs)
		if not Rect2(Vector2(4, 40), size - Vector2(8, 44)).encloses(rect):
			continue
		var score := INF
		for other: StringName in _centers:
			if other != id:
				score = minf(score, spot.distance_to(_centers[other]))
		if score > best_score:
			best_score = score
			best = spot
	return best - hs * 0.5


# --- Desenho ------------------------------------------------------------------------

func _draw() -> void:
	if _laid_out_size != size:
		_layout()
	var w := size.x
	var h := size.y
	# Mar em tinta índigo: mais claro no alto, quase preto nos cantos de baixo.
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([SEA_LIGHT, SEA_LIGHT.darkened(0.15), SEA_DARK, SEA_DARK.lightened(0.05)]))
	for k: int in range(0, int(h), 6):
		draw_line(Vector2(0, k), Vector2(w, k), Color(0, 0, 0, 0.06), 1.0)
	for p: Vector2 in _waves:
		for r: float in [5.0, 3.0, 1.2]:
			draw_arc(p, r, PI, TAU, 8, WAVE, 1.0)
	_draw_land(_korea, false)
	for i: int in range(_land.size()):
		_draw_land(_land[i], i >= 4)
	for poly: PackedVector2Array in _snow:
		draw_colored_polygon(poly, Color(SNOW, 0.72))
	_draw_regions()
	for i: int in range(_land.size()):
		draw_polyline(_closed(_land[i]), INK, 1.0)
	draw_polyline(_closed(_korea), Color(INK, 0.6), 1.0)
	_draw_mountains()
	_draw_fuji(_at(JourneyGeo.FUJI))
	# Faixas de névoa dourada (kasumi), como nos mapas e biombos antigos.
	_draw_kasumi(Vector2(w * 0.17, h * 0.36), 64.0)
	_draw_kasumi(Vector2(w * 0.52, h * 0.88), 84.0)
	_draw_kasumi(Vector2(w * 0.9, h * 0.63), 56.0)
	_draw_roads()
	_draw_torii()
	_draw_compass(Vector2(w - 26, h - 26))
	_draw_country_seal(Vector2(12, 44))
	_draw_frame()


func _at(lon_lat: Vector2) -> Vector2:
	return _xf * JourneyGeo.project(lon_lat)


func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var out := poly.duplicate()
	if not out.is_empty():
		out.append(out[0])
	return out


func _draw_land(poly: PackedVector2Array, small: bool) -> void:
	if poly.size() < 3:
		return
	var shadow := PackedVector2Array()
	var cliff := PackedVector2Array()
	for p: Vector2 in poly:
		shadow.append(p + Vector2(2, 3))
		cliff.append(p + Vector2(0.5, 1.5))
	draw_colored_polygon(shadow, Color(0.03, 0.03, 0.1, 0.45))
	draw_colored_polygon(cliff, CLIFF)
	draw_colored_polygon(poly, LAND_DARK if small else LAND)


func _draw_regions() -> void:
	# Tottori: dunas cor de areia, com riscos de vento.
	var dune := _at(JourneyGeo.TOTTORI_SAND)
	_draw_blob(dune, Vector2(11, 4), SAND)
	for k: int in range(3):
		draw_line(dune + Vector2(-7 + k * 4, -1 + k), dune + Vector2(-3 + k * 4, -2 + k), Color("b89a5a"), 1.0)
	# Unzen: terra queimada e fumaça do vulcão.
	var unzen := _at(Vector2(130.3, 32.76))
	_draw_blob(unzen, Vector2(9, 6), Color(EMBER, 0.75))
	for k: int in range(3):
		draw_circle(unzen + Vector2(4 + k * 3, -6 - k * 5), 2.5 + k, Color(0.45, 0.42, 0.45, 0.55 - k * 0.12))
	# Bosques (pontinhos de tinta verde) em Honshu central.
	for lon_lat: Vector2 in [Vector2(137.2, 35.9), Vector2(136.4, 35.2), Vector2(139.2, 37.0),
			Vector2(140.4, 38.2), Vector2(133.2, 35.0), Vector2(131.0, 32.4), Vector2(133.5, 33.6)]:
		var p := _at(lon_lat)
		for k: int in range(4):
			draw_circle(p + Vector2((k % 2) * 4 - 2, floorf(k / 2.0) * 3), 1.5, Color("6f7a3e"))


func _draw_blob(at: Vector2, radius: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for k: int in range(12):
		var a := TAU * k / 12.0
		pts.append(at + Vector2(cos(a) * radius.x, sin(a) * radius.y) * (1.0 + 0.12 * sin(a * 3.0)))
	draw_colored_polygon(pts, color)


## Nuvem de névoa (kasumi) suave: um só polígono translúcido, com bolhas em cima.
func _draw_kasumi(c: Vector2, width: float) -> void:
	var pts := PackedVector2Array()
	for k: int in range(32):
		var a := TAU * k / 32.0
		var up := sin(a) < 0.0
		var puff := 1.0 + (0.9 * absf(sin(a * 3.0)) if up else 0.0)
		pts.append(c + Vector2(cos(a) * width * 0.5, sin(a) * 4.0 * puff))
	draw_colored_polygon(pts, Color(0.95, 0.88, 0.7, 0.16))


func _draw_mountains() -> void:
	for lon_lat: Vector2 in JourneyGeo.MOUNTAINS:
		var p := _at(lon_lat)
		var base := 5.0
		draw_colored_polygon(PackedVector2Array([p + Vector2(-base, 2), p + Vector2(0, -5), p + Vector2(base, 2)]),
				Color("8a7a4a"))
		if lon_lat.y > 37.0:
			draw_colored_polygon(PackedVector2Array([p + Vector2(-2, -2), p + Vector2(0, -5), p + Vector2(2, -2)]), SNOW)
		draw_polyline(PackedVector2Array([p + Vector2(-base, 2), p + Vector2(0, -5), p + Vector2(base, 2)]),
				Color(INK, 0.8), 1.0)


func _draw_fuji(p: Vector2) -> void:
	var peak := PackedVector2Array([p + Vector2(-9, 4), p + Vector2(-2, -8), p + Vector2(2, -8), p + Vector2(9, 4)])
	draw_colored_polygon(peak, Color("5b6a8f"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -2), p + Vector2(-2, -8), p + Vector2(2, -8),
			p + Vector2(5, -2), p + Vector2(2, -3), p + Vector2(0, -1.5), p + Vector2(-2, -3)]), SNOW)
	draw_polyline(peak, INK, 1.0)


func _draw_roads() -> void:
	for id: StringName in _roads:
		var line: PackedVector2Array = _roads[id]
		match node_state(id):
			&"cleared":
				draw_polyline(line, Color(INK, 0.7), 3.0)
				draw_polyline(line, ROAD_RED, 2.0)
			&"open":
				var dash := JourneyGeo.dashes(line, 4.0, 3.0)
				for k: int in range(0, dash.size() - 1, 2):
					draw_line(dash[k] + Vector2(0, 1), dash[k + 1] + Vector2(0, 1), Color(INK, 0.6), 2.0)
				draw_multiline(dash, ROAD_OPEN, 2.0)
			_:
				draw_multiline(JourneyGeo.dashes(line, 2.0, 4.0), Color(ROAD_OPEN, 0.35), 1.0)


func _draw_torii() -> void:
	# Grande Santuário de Izumo, terra adentro e a sudoeste do ponto (que fica na costa).
	var p := _at(JourneyGeo.IZUMO_TORII)
	var red := Color("c8402e")
	draw_rect(Rect2(p + Vector2(-5, -5), Vector2(1.5, 9)), red)
	draw_rect(Rect2(p + Vector2(3.5, -5), Vector2(1.5, 9)), red)
	draw_rect(Rect2(p + Vector2(-7, -7), Vector2(14, 2)), Color("2a1a14"))
	draw_rect(Rect2(p + Vector2(-6, -5), Vector2(12, 1.5)), red)
	draw_rect(Rect2(p + Vector2(-5, -2.5), Vector2(10, 1)), red)


func _draw_compass(c: Vector2) -> void:
	draw_circle(c, 13.0, Color(0.05, 0.06, 0.15, 0.4))
	draw_arc(c, 13.0, 0.0, TAU, 24, Color(GOLD, 0.6), 1.0)
	draw_arc(c, 9.0, 0.0, TAU, 20, Color(GOLD, 0.3), 1.0)
	# Norte de verdade: o mapa está girado, então a agulha também.
	var north := Vector2.UP.rotated(deg_to_rad(JourneyGeo.TILT_DEG))
	var side := north.orthogonal()
	draw_colored_polygon(PackedVector2Array([c + north * 12.0, c + side * 3.0, c - side * 3.0]), VERMILION)
	draw_colored_polygon(PackedVector2Array([c - north * 11.0, c + side * 3.0, c - side * 3.0]), Color("e8dcc0"))
	draw_colored_polygon(PackedVector2Array([c + side * 8.0, c + north * 2.0, c - north * 2.0]), Color(GOLD, 0.7))
	draw_colored_polygon(PackedVector2Array([c - side * 8.0, c + north * 2.0, c - north * 2.0]), Color(GOLD, 0.7))
	if _seal_font:
		draw_string(_seal_font, c + north * 15.0 + Vector2(-6, 4), "北", HORIZONTAL_ALIGNMENT_CENTER, 12, 12,
				Color(GOLD, 0.9))


## Carimbo vermelho "日本" (escrito na vertical, como num mapa antigo).
func _draw_country_seal(p: Vector2) -> void:
	var rect := Rect2(p, Vector2(18, 32))
	draw_rect(rect, Color(VERMILION, 0.85))
	draw_rect(rect.grow(-1.5), Color("f3e1c2", 0.9), false, 1.0)
	if _seal_font:
		draw_string(_seal_font, p + Vector2(3, 14), "日", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f3e1c2"))
		draw_string(_seal_font, p + Vector2(3, 28), "本", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f3e1c2"))


func _draw_frame() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r.grow(-1.0), Color("120c1e"), false, 2.0)
	draw_rect(r.grow(-3.5), Color(GOLD, 0.55), false, 1.0)
	for corner: Vector2 in [Vector2(3, 3), Vector2(size.x - 3, 3), Vector2(3, size.y - 3), size - Vector2(3, 3)]:
		draw_rect(Rect2(corner - Vector2(3, 3), Vector2(6, 6)), Color(GOLD, 0.8))
		draw_rect(Rect2(corner - Vector2(1.5, 1.5), Vector2(3, 3)), Color("120c1e"))


# --- Ponto de luta --------------------------------------------------------------------

## Medalhão de um ponto de luta: chefe final da fase sobre papel claro, estado e luas.
class MapNode:
	extends BaseButton

	const RADIUS := 14.0
	const FACE := 24.0
	const PAPER := Color("e9dcb8")
	const PAPER_LOCKED := Color("d3ccba")

	var stage_id: StringName
	var state: StringName = &"locked"
	## Retrato colorido (vencida) e silhueta do corpo do chefe (liberada / bloqueada).
	var face: Texture2D
	var shape: Texture2D
	var moons: int = 0
	var selected: bool = false
	var seal_font: Font
	var seal_text: String = "祓"
	var glow: float = 0.0:
		set(value):
			glow = value
			queue_redraw()
	var _pulse: Tween

	func set_glowing(on: bool) -> void:
		if _pulse:
			_pulse.kill()
			_pulse = null
		glow = 0.0
		if on and is_inside_tree():
			_pulse = create_tween().set_loops()
			_pulse.tween_property(self, "glow", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
			_pulse.tween_property(self, "glow", 0.0, 0.8).set_trans(Tween.TRANS_SINE)

	## Cor aplicada à imagem do chefe: natural (vencida) ou silhueta (liberada / bloqueada).
	func face_modulate() -> Color:
		match state:
			&"cleared":
				return Color.WHITE
			&"open":
				return SILHOUETTE
		return SILHOUETTE_LOCKED

	func has_seal() -> bool:
		return state == &"cleared"

	func _draw() -> void:
		var c := size * 0.5
		if state == &"open":
			for k: int in range(4):
				draw_circle(c, RADIUS + 2.0 + k * 2.0 + glow * 3.0, Color(1.0, 0.72, 0.3, 0.1 + 0.06 * glow))
		if selected:
			draw_circle(c, RADIUS + 4.5, Color(1.0, 0.95, 0.75, 0.35))
			draw_arc(c, RADIUS + 3.5, 0.0, TAU, 32, Color.WHITE, 1.5)
		draw_circle(c + Vector2(1, 2), RADIUS + 1.0, Color(0, 0, 0, 0.5))
		var rim := {&"cleared": GOLD, &"open": Color("e0a050"), &"locked": Color("6a6672")}
		draw_circle(c, RADIUS + 1.0, rim.get(state, Color.GRAY))
		draw_circle(c, RADIUS - 0.5, INK)
		draw_circle(c, RADIUS - 1.5, PAPER_LOCKED if state == &"locked" else PAPER)
		if state == &"cleared":
			if face:
				draw_texture_rect(face, Rect2(c - Vector2(FACE, FACE) * 0.5, Vector2(FACE, FACE)), false)
			draw_arc(c, RADIUS - 1.0, 0.0, TAU, 32, Color("8a5a12"), 1.0)
			var seal := Rect2(c + Vector2(4, 3), Vector2(13, 13))
			draw_rect(seal.grow(1.0), PAPER)
			draw_rect(seal, VERMILION)
			if seal_font:
				draw_string(seal_font, seal.position + Vector2(0.5, 11), seal_text, HORIZONTAL_ALIGNMENT_CENTER,
						13, 12, Color("fff1d6"))
		else:
			# Lanterna atrás da silhueta (pulsando quando liberada).
			var lamp := Color(1.0, 0.82, 0.45, 0.35 + 0.25 * glow) if state == &"open" else Color(1, 1, 1, 0.12)
			draw_circle(c + Vector2(0, -1), RADIUS - 5.0, lamp)
			if shape:
				var side := shape.get_size()
				draw_texture_rect(shape, Rect2(c - side * 0.5 + Vector2(0, 1), side), false, face_modulate())
		if state == &"locked":
			_draw_mist(c)
			_draw_shimenawa(c)
		if moons > 0:
			var start := c.x - (moons - 1) * 3.0
			for k: int in range(moons):
				var at := Vector2(start + k * 6.0, size.y + 3.0)
				draw_circle(at, 2.5, Color(0, 0, 0, 0.6))
				draw_circle(at, 2.0, Color("e8432f"))
		if has_focus() and not selected:
			draw_arc(c, RADIUS + 3.0, 0.0, TAU, 32, Color(GOLD, 0.8), 1.0)

	## Fiapos de névoa translúcidos por cima da silhueta.
	func _draw_mist(c: Vector2) -> void:
		for wisp: Array in [[Vector2(-4, -4), 7.0], [Vector2(4, 2), 7.0]]:
			var at: Vector2 = c + wisp[0]
			var half: float = wisp[1]
			draw_line(at - Vector2(half, 0), at + Vector2(half, 0), Color(0.95, 0.96, 1.0, 0.3), 2.0)
			draw_line(at - Vector2(half - 3.0, -1), at + Vector2(half - 4.0, -1), Color(1, 1, 1, 0.18), 1.0)

	## Corda sagrada (shimenawa) com tiras de papel (shide): o caminho está fechado.
	func _draw_shimenawa(c: Vector2) -> void:
		var rope := PackedVector2Array()
		for k: int in range(9):
			var t := k / 8.0
			rope.append(c + Vector2(-RADIUS - 1.0 + t * (RADIUS * 2.0 + 2.0), 8.0 + sin(t * PI) * 3.0))
		draw_polyline(rope, Color("3a2a12"), 4.0)
		draw_polyline(rope, Color("d6b25e"), 2.0)
		for k: int in range(1, 8, 2):
			draw_line(rope[k] + Vector2(-1, -1), rope[k] + Vector2(1, 1), Color("7a5a22"), 1.0)
		for k: int in [3, 5]:
			var top := rope[k] + Vector2(0, 1)
			draw_polyline(PackedVector2Array([top, top + Vector2(2, 2), top + Vector2(0, 4), top + Vector2(2, 6)]),
					Color("fdfbf2"), 1.5)


# --- Guardiã no mapa ------------------------------------------------------------------

## A guardiã escolhida, parada ao lado do ponto selecionado (com leve balanço) ou andando.
class MapHero:
	extends Control

	var sheet: SpriteSheet
	var dir: int = SpriteSheet.Dir.DOWN
	var frame: int = 0
	var bob: float = 0.0:
		set(value):
			bob = value
			queue_redraw()
	var walking: bool = false
	var _move: Tween
	var _bob: Tween
	var _flip: bool = false

	func set_hero(hero: Dictionary) -> void:
		if hero.is_empty():
			return
		if String(hero.get("layout", "dir4")) == "side":
			var frame_size: Array = hero.get("frame", [16, 16])
			sheet = SpriteSheet.load_sheet(String(hero["sprite"]), "side",
					Vector2(float(frame_size[0]), float(frame_size[1])), 1, false, float(hero.get("draw_scale", 1.0)))
			_flip = bool(hero.get("faces_left", false))
		else:
			sheet = SpriteSheet.load_sheet(String(hero["sprite"]), "dir4", Vector2(16, 16), 4)
			_flip = false
		size = sheet.frame_size
		queue_redraw()

	func stop_at(at: Vector2) -> void:
		if _move:
			_move.kill()
		walking = false
		position = at
		dir = SpriteSheet.Dir.DOWN
		frame = 0
		_start_bob()

	func walk_to(at: Vector2) -> void:
		if _move:
			_move.kill()
		var delta := at - position
		if absf(delta.x) > absf(delta.y):
			dir = SpriteSheet.Dir.RIGHT if delta.x > 0.0 else SpriteSheet.Dir.LEFT
		else:
			dir = SpriteSheet.Dir.DOWN if delta.y > 0.0 else SpriteSheet.Dir.UP
		walking = true
		_move = create_tween()
		_move.tween_property(self, "position", at, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_move.parallel().tween_method(func(t: float) -> void:
			frame = int(t * 6.0)
			queue_redraw(), 0.0, 1.0, 0.35)
		_move.tween_callback(stop_at.bind(at))

	func _start_bob() -> void:
		if _bob == null and is_inside_tree():
			_bob = create_tween().set_loops()
			_bob.tween_property(self, "bob", -1.5, 0.45).set_trans(Tween.TRANS_SINE)
			_bob.tween_property(self, "bob", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
		queue_redraw()

	func _draw() -> void:
		if sheet == null:
			return
		var s := sheet.frame_size
		var feet := Vector2(s.x * 0.5, s.y - 1.0)
		# Folha "side": olha para um lado só; espelha para olhar na direção do passo (direita parado).
		var mirror := sheet.layout != "dir4" and _flip != (dir == SpriteSheet.Dir.LEFT)
		draw_circle(feet + Vector2(0, 1), 5.0, Color(0, 0, 0, 0.35))
		var region := sheet.region(frame if walking else 0, dir if sheet.layout == "dir4" else 0)
		var lift := 0.0 if walking else bob
		if mirror:
			draw_set_transform(Vector2(s.x, lift), 0.0, Vector2(-1, 1))
		else:
			draw_set_transform(Vector2(0, lift))
		draw_texture_rect_region(sheet.texture, Rect2(Vector2.ZERO, s), region)
		draw_set_transform(Vector2.ZERO)
