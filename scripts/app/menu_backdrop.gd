class_name MenuBackdrop
extends Control
## Fundo animado dos menus: "Hyakki Yagyō", o desfile noturno dos cem demônios. Um diorama
## em camadas, de trás para a frente: céu índigo com estrelas, lua com halo e nuvens, duas
## cordilheiras, a procissão de yōkai andando na crista do meio (com lanternas de papel e
## hitodama), o vale escuro, o caminho de pedra até o torii, os tōrō, a guardiã escolhida
## com a lanterna, árvores em silhueta nas bordas, névoa e vinheta. Só Ninja Adventure.
## A luz vem da paleta (sem véu preto por cima). O terço esquerdo fica escuro e calmo
## porque a lista do menu fica ali; o canto superior direito tem o chip de moedas.
## Custo: ~200 comandos de desenho por quadro; gradientes, polígonos e texturas são
## montados no _ready ou quando o tamanho muda, nunca a cada quadro.

const WALKER_PATHS: Array[String] = [
	"res://assets/art/actors/enemies/oni_red/SpriteSheet.png",
	"res://assets/art/actors/enemies/lantern_red/SpriteSheet.png",
	"res://assets/art/actors/enemies/kitsune/SpriteSheet.png",
	"res://assets/art/actors/enemies/skeleton/SpriteSheet.png",
	"res://assets/art/actors/enemies/ghost_monk/SpriteSheet.png",
	"res://assets/art/actors/enemies/tanuki_small/SpriteSheet.png",
	"res://assets/art/actors/enemies/kappa_green/SpriteSheet.png",
	"res://assets/art/actors/enemies/spirit/SpriteSheet.png",
	"res://assets/art/actors/enemies/tengu_small/SpriteSheet.png",
	"res://assets/art/actors/enemies/lantern_green/SpriteSheet.png",
	"res://assets/art/actors/enemies/bakeneko/SpriteSheet.png",
]
## Folhas "strip" (uma linha, desenho olhando para a esquerda), como em data/enemies.json.
const STRIP_WALKERS: Array[String] = ["tanuki_small", "bakeneko"]
const DEFAULT_HERO := "aki"
## Faixa vertical (fração da altura) onde fica a crista em que a procissão anda.
const RIDGE_BAND := Vector2(0.38, 0.52)
const WALKER_SPACING := 34.0
const WALKER_SPEED := 9.0
const HERO_CHECK_INTERVAL := 0.5

const SKY_TOP := Color("0b0a1f")
const SKY_HORIZON := Color("2a1636")
const FAR_RIDGE := Color("1e1738")
const FAR_RIM := Color("3a2e5c")
const MID_RIDGE := Color("110d20")
const MID_RIM := Color("332a58")
const WALKER_TINT := Color(0.26, 0.23, 0.4)
const GRASS_TINT := Color(0.17, 0.23, 0.33)
const TORII_TINT := Color(0.72, 0.5, 0.62)
const TORO_TINT := Color(0.36, 0.34, 0.48)
const HERO_TINT := Color(0.82, 0.78, 0.9)
const TREE_FAR := Color(0.06, 0.05, 0.11)
const TREE_NEAR := Color(0.035, 0.03, 0.07)
const NIGHT_SHADE := Color("05040c")
const MOON := Color("f1e9d2")
const MOONLIGHT := Color("b9b3e8")
const WARM := Color("ffb45a")
const WISP := Color("bfe4ff")

var _floor: Texture2D
var _nature: Texture2D
var _house: Texture2D
var _element: Texture2D
var _fog: Texture2D
var _grass: ImageTexture
var _sky: GradientTexture2D
var _glow: GradientTexture2D
var _vignette: GradientTexture2D
var _left_shade: GradientTexture2D
var _ground_shade: GradientTexture2D
var _hero: SpriteSheet
var _hero_id := ""
## Herói "side" (Yuki): tamanho do quadro e quadros parados; ZERO = folha dir4.
var _hero_side := Vector2.ZERO
var _hero_idle_frames := 1
var _walker_sheets: Array[SpriteSheet] = []
var _walker_flip: Array[bool] = []
var _time := 0.0
var _hero_check := 0.0

# Geometria que só muda com o tamanho (montada em _layout).
var _layout_size := Vector2.ZERO
var _far_poly := PackedVector2Array()
var _far_line := PackedVector2Array()
var _mid_poly := PackedVector2Array()
var _mid_line := PackedVector2Array()
var _mid_heights := PackedFloat32Array()
var _ridge_step := 6.0
var _stars := PackedVector3Array()
var _ground_y := 0.0
var _torii := Rect2()
var _walkers := PackedVector2Array()
# Pontos de luz do último quadro, lidos pela camada aditiva.
var _wisps := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _toro_fire := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var _hero_lamp := Vector2.ZERO
var _flies := PackedVector3Array()
## Camada de luz (mistura aditiva) e camada de sombra (vinheta), filhas desenhadas por cima.
var _light: Control
var _shade: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_floor = load("res://assets/art/tilesets/floor.png") as Texture2D
	_nature = load("res://assets/art/tilesets/nature.png") as Texture2D
	_house = load("res://assets/art/tilesets/house.png") as Texture2D
	_element = load("res://assets/art/tilesets/element.png") as Texture2D
	_fog = load("res://assets/art/fx/environment/Fog.png") as Texture2D
	# Um ladrilho de grama vira textura própria para repetir num só comando.
	_grass = ImageTexture.create_from_image(_floor.get_image().get_region(Rect2i(0, 12 * 16, 16, 16)))
	_flies.resize(12)
	_sky = _gradient([SKY_TOP, Color("17123a"), SKY_HORIZON, Color("4a2448")], [0.0, 0.4, 0.78, 1.0],
			Vector2(0, 0), Vector2(0, 1), Vector2i(4, 96))
	_glow = _gradient([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0)],
			[0.0, 0.25, 0.6, 1.0], Vector2(0.5, 0.5), Vector2(1.0, 0.5), Vector2i(48, 48), true)
	var shade := NIGHT_SHADE
	_vignette = _gradient([Color(shade, 0.0), Color(shade, 0.25), Color(shade, 0.85)], [0.0, 0.55, 1.0],
			Vector2(0.62, 0.5), Vector2(1.25, 0.5), Vector2i(64, 32), true)
	_left_shade = _gradient([Color(shade, 0.72), Color(shade, 0.45), Color(shade, 0.0)], [0.0, 0.45, 1.0],
			Vector2(0, 0), Vector2(1, 0), Vector2i(64, 4))
	_ground_shade = _gradient([Color(MID_RIDGE, 0.95), Color(MID_RIDGE, 0.35), Color(shade, 0.0), Color(shade, 0.55)],
			[0.0, 0.3, 0.6, 1.0], Vector2(0, 0), Vector2(0, 1), Vector2i(4, 48))
	for path: String in WALKER_PATHS:
		var strip := path.get_base_dir().get_file() in STRIP_WALKERS
		if strip:
			_walker_sheets.append(SpriteSheet.load_sheet(path, "strip", Vector2(16, 16), 0, true))
		else:
			_walker_sheets.append(SpriteSheet.load_sheet(path, "dir4", Vector2(16, 16), 4))
		_walker_flip.append(strip)
	_refresh_hero()
	visibility_changed.connect(_refresh_hero)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light = _layer(_draw_lights)
	_light.material = add
	_shade = _layer(_draw_shade)


func _layer(painter: Callable) -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.draw.connect(painter)
	add_child(layer)
	return layer


## Herói desenhado agora (o escolhido no save, ou "aki").
func hero_id() -> String:
	return _hero_id


## Pés de cada yōkai da procissão no último quadro desenhado.
func walker_positions() -> PackedVector2Array:
	return _walkers


## Altura da crista do meio (onde a procissão anda) no x dado.
func ridge_y(x: float) -> float:
	if _mid_heights.is_empty():
		return 0.0
	var f := clampf(x / _ridge_step, 0.0, _mid_heights.size() - 1.001)
	var i := floori(f)
	return lerpf(_mid_heights[i], _mid_heights[i + 1], f - i)


func _process(delta: float) -> void:
	_time += delta
	_hero_check += delta
	if _hero_check >= HERO_CHECK_INTERVAL:
		_hero_check = 0.0
		_refresh_hero()
	queue_redraw()
	_light.queue_redraw()
	_shade.queue_redraw()


func _refresh_hero() -> void:
	var selected: Variant = SaveManager.data.get("selected", {})
	var id := DEFAULT_HERO
	if selected is Dictionary:
		id = String((selected as Dictionary).get("hero", DEFAULT_HERO))
	if not DB.heroes.has(StringName(id)):
		id = DEFAULT_HERO
	if id == _hero_id and _hero != null:
		return
	_hero_id = id
	var data: Dictionary = DB.heroes.get(StringName(id), {})
	var path := String(data.get("sprite", "res://assets/art/actors/heroes/%s/SpriteSheet.png" % id))
	if String(data.get("layout", "dir4")) == "side":
		var frame: Array = data.get("frame", [16, 16])
		_hero = SpriteSheet.load_sheet(path, "side", Vector2(float(frame[0]), float(frame[1])), 1, false,
				float(data.get("draw_scale", 1.0)))
		_hero_side = _hero.frame_size
		_hero_idle_frames = maxi(1, int(data.get("idle_frames", 1)))
	else:
		_hero = SpriteSheet.load_sheet(path, "dir4", Vector2(16, 16), 4)
		_hero_side = Vector2.ZERO
		_hero_idle_frames = 1


static func _gradient(colors: Array[Color], offsets: Array[float], from: Vector2, to: Vector2,
		tex_size: Vector2i, radial: bool = false) -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	g.offsets = PackedFloat32Array(offsets)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = tex_size.x
	tex.height = tex_size.y
	tex.fill = GradientTexture2D.FILL_RADIAL if radial else GradientTexture2D.FILL_LINEAR
	tex.fill_from = from
	tex.fill_to = to
	return tex


## Recalcula cristas, estrelas e posições fixas para o tamanho atual.
func _layout(area: Vector2) -> void:
	_layout_size = area
	var w := area.x
	var h := area.y
	_ground_y = roundf(h * 0.58)
	var count := ceili(w / _ridge_step) + 2
	_far_line.resize(count)
	_mid_line.resize(count)
	_mid_heights.resize(count)
	for i: int in range(count):
		var x := i * _ridge_step
		var u := x / w
		# Montes ao longe: picos agudos (|sin|) somados a ondas largas.
		var far := 0.36 - 0.07 * absf(sin(u * 5.1 + 0.6)) - 0.035 * sin(u * 13.0 + 1.3) - 0.012 * sin(u * 41.0)
		far -= 0.06 * exp(-pow((u - 0.62) * 4.0, 2.0))
		_far_line[i] = Vector2(x, roundf(h * far))
		# Crista do meio: colinas suaves, sempre dentro de RIDGE_BAND.
		var mid := 0.455 + 0.025 * sin(u * 6.3 + 2.0) + 0.012 * sin(u * 17.0 + 0.4)
		_mid_heights[i] = roundf(h * clampf(mid, RIDGE_BAND.x + 0.02, RIDGE_BAND.y - 0.02))
		_mid_line[i] = Vector2(x, _mid_heights[i])
	_far_poly = _close(_far_line, _ground_y + 4.0)
	_mid_poly = _close(_mid_line, _ground_y + 4.0)
	# Estrelas fixas (sem RNG global), só no céu acima dos montes.
	_stars.resize(44)
	for k: int in range(44):
		var sx := fposmod(k * 151.7 + 37.0, w)
		var sy := fposmod(k * 67.3 + 11.0, h * 0.34)
		_stars[k] = Vector3(roundf(sx), roundf(sy), fposmod(k * 0.37, 1.0))
	var torii_size := Vector2(96, 64)
	_torii = Rect2(Vector2(roundf(w * 0.5 - 48.0), _ground_y + 18.0 - torii_size.y), torii_size)


static func _close(line: PackedVector2Array, bottom: float) -> PackedVector2Array:
	var poly := line.duplicate()
	poly.append(Vector2(line[line.size() - 1].x, bottom))
	poly.append(Vector2(line[0].x, bottom))
	return poly


func _draw() -> void:
	# Sob um pai que não é Control as âncoras não dão tamanho: usa a tela inteira.
	var area := size if size.x > 1.0 and size.y > 1.0 else get_viewport_rect().size
	if area != _layout_size:
		_layout(area)
	var w := area.x
	var h := area.y
	draw_texture_rect(_sky, Rect2(0, 0, w, _ground_y), false)
	_draw_stars()
	_draw_moon(w, h)
	# Montes ao longe e a crista do meio, com a borda tocada pela lua.
	draw_colored_polygon(_far_poly, FAR_RIDGE)
	draw_polyline(_far_line, FAR_RIM, 1.0)
	_draw_fog_band(roundf(h * 0.37), 30.0, 4.0, Color(0.55, 0.42, 0.72, 0.13), w)
	draw_colored_polygon(_mid_poly, MID_RIDGE)
	draw_polyline(_mid_line, MID_RIM, 1.0)
	_draw_procession(w)
	_draw_ground(w, h)
	_draw_torii_and_lanterns(w, h)
	_draw_hero(w)
	_draw_frame_trees(w, h)
	_draw_fog_band(h - 40.0, 48.0, 6.0, Color(0.58, 0.5, 0.82, 0.12), w)
	_draw_fireflies(w, h)


## Camada aditiva: halos das lanternas, hitodama, vaga-lumes e poças de luz no chão.
## Mais fraca no terço esquerdo, onde fica a lista do menu.
func _draw_lights() -> void:
	var w := _layout_size.x
	if w <= 0.0:
		return
	for k: int in range(_walkers.size()):
		if k % 3 == 1:
			var flicker := 0.9 + 0.1 * sin(_time * 11.0 + k * 3.0)
			_light_at(_walker_lamp(k), 18.0, Color(WARM, 0.55 * flicker), w)
	for p: Vector2 in _wisps:
		_light_at(p, 12.0, Color(WISP, 0.5), w)
	for k: int in range(_toro_fire.size()):
		var fire := _toro_fire[k]
		var flicker := 0.85 + 0.1 * sin(_time * 9.0 + k * 4.0) + 0.05 * sin(_time * 23.0)
		_light_at(fire, 34.0, Color(WARM, 0.5 * flicker), w)
		_light.draw_texture_rect(_glow, Rect2(fire.x - 46.0, fire.y + 30.0, 92.0, 22.0), false,
				Color(WARM, 0.3 * flicker))
	var pulse := 1.0 + 0.05 * sin(_time * 4.0)
	_light_at(_hero_lamp, 56.0 * pulse, Color(WARM, 0.42), w)
	_light_at(_hero_lamp, 14.0, Color(1.0, 0.85, 0.55, 0.7), w)
	_light.draw_texture_rect(_glow, Rect2(_hero_lamp.x - 84.0, _torii.end.y - 14.0, 168.0, 40.0), false,
			Color(WARM, 0.38 * pulse))
	for p: Vector3 in _flies:
		_light_at(Vector2(p.x, p.y), 5.0, Color(0.7, 1.0, 0.45, 0.45 * p.z), w)


func _light_at(p: Vector2, radius: float, c: Color, w: float) -> void:
	c.a *= lerpf(0.35, 1.0, smoothstep(w * 0.12, w * 0.45, p.x))
	_light.draw_texture_rect(_glow, Rect2(p.round() - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, c)


## Camada de sombra: vinheta e o lado esquerdo mais escuro para a lista do menu.
func _draw_shade() -> void:
	var w := _layout_size.x
	var h := _layout_size.y
	_shade.draw_texture_rect(_vignette, Rect2(0, 0, w, h), false)
	_shade.draw_texture_rect(_left_shade, Rect2(0, 0, maxf(w * 0.46, 250.0), h), false)


func _draw_stars() -> void:
	for star: Vector3 in _stars:
		var a := 0.3 + 0.5 * (0.5 + 0.5 * sin(_time * (1.3 + star.z * 2.0) + star.z * 40.0))
		var c := Color(0.85, 0.85, 1.0, a)
		draw_rect(Rect2(star.x, star.y, 1, 1), c)
		if star.z > 0.88:
			c.a *= 0.4
			draw_rect(Rect2(star.x - 1, star.y, 3, 1), c)
			draw_rect(Rect2(star.x, star.y - 1, 1, 3), c)


func _draw_moon(w: float, h: float) -> void:
	var c := Vector2(roundf(w * 0.78), roundf(h * 0.2))
	var r := 26.0
	draw_texture_rect(_glow, Rect2(c - Vector2(r, r) * 4.5, Vector2(r, r) * 9.0), false, Color(MOONLIGHT, 0.16))
	draw_texture_rect(_glow, Rect2(c - Vector2(r, r) * 2.0, Vector2(r, r) * 4.0), false, Color(MOONLIGHT, 0.28))
	draw_circle(c, r + 2.0, Color(MOON, 0.2), true, -1.0, false)
	draw_circle(c, r, MOON, true, -1.0, false)
	# Sombreado do lado oposto à luz e crateras discretas.
	draw_circle(c + Vector2(5, 4), r - 4.0, Color(0.86, 0.8, 0.72, 0.4), true, -1.0, false)
	draw_circle(c + Vector2(-8, -6), 4.0, Color(0.78, 0.73, 0.66, 0.6), true, -1.0, false)
	draw_circle(c + Vector2(7, 9), 3.0, Color(0.78, 0.73, 0.66, 0.5), true, -1.0, false)
	draw_circle(c + Vector2(10, -10), 2.0, Color(0.78, 0.73, 0.66, 0.5), true, -1.0, false)
	# Faixas finas de nuvem cruzando a lua devagar (sempre perto dela).
	for k: int in range(3):
		var band_w := 120.0 + k * 30.0
		var x := c.x - band_w * 0.5 + sin(_time * (0.05 + k * 0.02) + k * 2.0) * 90.0
		var y := roundf(c.y - 16.0 + k * 14.0)
		draw_texture_rect(_fog, Rect2(roundf(x), y, band_w, 6.0 + k * 2.0), false, Color(0.1, 0.08, 0.22, 0.8))


func _draw_fog_band(y: float, band_h: float, speed: float, tint: Color, w: float) -> void:
	var span := w * 0.75
	var x := -fposmod(_time * speed, span) - span * 0.5
	while x < w:
		draw_texture_rect(_fog, Rect2(roundf(x), y, span * 1.4, band_h), false, tint)
		x += span


func _walker_lamp(k: int) -> Vector2:
	var feet := _walkers[k]
	return Vector2(feet.x + 2.0, roundf(feet.y - 24.0 + sin(_time * 2.2 + k) * 2.0))


func _draw_procession(w: float) -> void:
	var span := w + 80.0
	var count := ceili(span / WALKER_SPACING)
	if _walkers.size() != count:
		_walkers.resize(count)
	var rim := Color(MOONLIGHT, 0.75)
	for k: int in range(count):
		var sheet := _walker_sheets[k % _walker_sheets.size()]
		var x := roundf(fposmod(_time * WALKER_SPEED + k * WALKER_SPACING, span) - 40.0)
		var frame := int(_time * 5.0 + k * 1.3)
		var feet := Vector2(x, ridge_y(x) + 1.0)
		_walkers[k] = feet
		var top := feet + Vector2(-8, -16 - (frame % 2))
		var src := sheet.region(frame, SpriteSheet.Dir.RIGHT)
		var flip := _walker_flip[k % _walker_flip.size()]
		# Contorno da lua (silhueta clara 1 px acima/à direita) e o corpo quase em sombra.
		_draw_sprite(sheet.flash_texture, top + Vector2(1, -1), src, flip, rim)
		_draw_sprite(sheet.texture, top, src, flip, WALKER_TINT)
		if k % 3 == 1:
			# Chōchin flutuando acima do yōkai (o halo fica na camada de luz).
			var lamp := _walker_lamp(k)
			draw_line(Vector2(lamp.x, lamp.y - 6.0), Vector2(lamp.x, lamp.y - 2.0), Color(0.1, 0.08, 0.16), 1.0)
			draw_rect(Rect2(lamp.x - 1, lamp.y - 2, 3, 4), Color(1.0, 0.55, 0.28))
			draw_rect(Rect2(lamp.x, lamp.y - 1, 1, 2), Color(1.0, 0.92, 0.6))
	# Hitodama: chamas azuladas com rastro, em volta da procissão.
	for k: int in range(_wisps.size()):
		var base_x := fposmod(_time * (WALKER_SPEED + 3.0) + k * span / _wisps.size() + 50.0, span) - 40.0
		var ground := ridge_y(base_x) - 32.0
		for t: int in range(5, -1, -1):
			var tt := _time - t * 0.08
			var p := Vector2(base_x - t * 2.0 + sin(tt * 1.7 + k) * 10.0, ground + sin(tt * 2.3 + k * 2.0) * 7.0).round()
			draw_circle(p, 2.5 - t * 0.35, Color(WISP, 0.85 * (1.0 - t / 6.0)), true, -1.0, false)
			if t == 0:
				_wisps[k] = p
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.95))


func _draw_sprite(tex: Texture2D, at: Vector2, src: Rect2, flip: bool, tint: Color) -> void:
	if flip:
		draw_set_transform(at + Vector2(16, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect_region(tex, Rect2(Vector2.ZERO, src.size), src, tint)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect_region(tex, Rect2(at, src.size), src, tint)


func _draw_ground(w: float, h: float) -> void:
	var ground := Rect2(0, _ground_y, w, h - _ground_y)
	draw_texture_rect(_grass, ground, true, GRASS_TINT)
	draw_texture_rect(_ground_shade, ground, false)
	_draw_fog_band(_ground_y - 14.0, 30.0, 5.0, Color(0.6, 0.5, 0.82, 0.16), w)
	# Caminho de lajes do pé da tela até o torii, estreitando com a distância.
	var cx := roundf(w * 0.5)
	var top_y := _torii.end.y
	var rows := 7
	for r: int in range(rows):
		var t0 := float(r) / rows
		var t1 := float(r + 1) / rows
		var y0 := roundf(lerpf(h + 2.0, top_y, t0))
		var y1 := roundf(lerpf(h + 2.0, top_y, t1))
		var half := roundf(lerpf(54.0, 22.0, t0))
		var slab := Rect2(cx - half, y1 + 1.0, half * 2.0, y0 - y1 - 1.0)
		var lit := 0.6 + 0.4 * t1
		draw_rect(slab, Color(0.1 * lit + 0.04, 0.09 * lit + 0.04, 0.16 * lit + 0.06))
		draw_rect(Rect2(slab.position, Vector2(slab.size.x, 1)), Color(0.5, 0.4, 0.42, 0.3 * lit))
		var seam := roundf(cx + (half * 0.3 if r % 2 == 0 else -half * 0.35))
		draw_rect(Rect2(seam, slab.position.y + 1.0, 1, slab.size.y - 1.0), Color(0.03, 0.02, 0.06, 0.7))


func _draw_torii_and_lanterns(w: float, h: float) -> void:
	draw_texture_rect_region(_house, _torii, Rect2(0, 80, 48, 32), TORII_TINT)
	var cx := roundf(w * 0.5)
	var feet := roundf(minf(h - 6.0, _torii.end.y + 62.0))
	for i: int in range(2):
		var side := -1.0 if i == 0 else 1.0
		var x := cx + side * 86.0 - 16.0
		draw_texture_rect_region(_element, Rect2(x, feet - 64.0, 32, 64), Rect2(0, 80, 16, 32), TORO_TINT)
		var fire := Vector2(x + 16.0, feet - 42.0)
		var flicker := 0.85 + 0.1 * sin(_time * 9.0 + i * 4.0) + 0.05 * sin(_time * 23.0)
		draw_rect(Rect2(fire.x - 5.0, fire.y - 4.0, 10, 8), Color(1.0, 0.62, 0.3, flicker))
		draw_rect(Rect2(fire.x - 2.0, fire.y - 2.0, 4, 4), Color(1.0, 0.9, 0.6, flicker))
		_toro_fire[i] = fire


func _draw_hero(w: float) -> void:
	var feet := Vector2(roundf(w * 0.5), _torii.end.y + 6.0)
	var bob := 1.0 if fposmod(_time, 1.0) >= 0.5 else 0.0
	var tex := _hero.texture
	var hand := feet + Vector2(12, -14)
	draw_texture_rect(_glow, Rect2(feet.x - 14.0, feet.y - 4.0, 28.0, 8.0), false, Color(0, 0, 0, 0.6))
	if _hero_side != Vector2.ZERO:
		var size2 := _hero_side * 2.0
		var frame := posmod(int(_time * 6.0), _hero_idle_frames)
		var src := Rect2(Vector2(frame * _hero_side.x, 0), _hero_side)
		var at := Vector2(feet.x - size2.x * 0.5, feet.y - size2.y + bob)
		# A folha "side" olha para a esquerda: espelha para olhar para a direita.
		draw_set_transform(at + Vector2(size2.x, 0), 0.0, Vector2(-2, 2))
		draw_texture_rect_region(tex, Rect2(Vector2.ZERO, _hero_side), src, HERO_TINT)
		draw_set_transform(Vector2.ZERO)
		hand = feet + Vector2(12, roundf(-size2.y * 0.42))
	else:
		draw_texture_rect_region(tex, Rect2(feet + Vector2(-16, -32 + bob), Vector2(32, 32)),
				_hero.region(0, SpriteSheet.Dir.DOWN), HERO_TINT)
	# Lanterna da guardiã: a chama (o halo fica na camada de luz).
	_hero_lamp = (hand + Vector2(0, bob)).round()
	draw_line(_hero_lamp + Vector2(0, -7), _hero_lamp + Vector2(0, -3), Color(0.12, 0.08, 0.1), 1.0)
	draw_rect(Rect2(_hero_lamp.x - 2, _hero_lamp.y - 3, 5, 6), Color(1.0, 0.6, 0.3))
	draw_rect(Rect2(_hero_lamp.x - 1, _hero_lamp.y - 2, 3, 4), Color(1.0, 0.95, 0.72))


func _draw_frame_trees(w: float, h: float) -> void:
	# Esquerda: árvore seca e pinheiros; direita: pinheiros. Cortados pela borda.
	draw_texture_rect_region(_nature, Rect2(-46, h - 150.0, 128, 96), Rect2(0, 32, 64, 48), TREE_FAR)
	draw_texture_rect_region(_nature, Rect2(-20, h - 104.0, 96, 96), Rect2(64, 0, 32, 32), TREE_NEAR)
	draw_texture_rect_region(_nature, Rect2(w - 84.0, h - 166.0, 128, 96), Rect2(0, 32, 64, 48), TREE_FAR)
	draw_texture_rect_region(_nature, Rect2(w - 56.0, h - 96.0, 96, 96), Rect2(32, 0, 32, 32), TREE_NEAR)
	draw_texture_rect_region(_nature, Rect2(w - 150.0, h - 60.0, 64, 64), Rect2(32, 0, 32, 32), TREE_NEAR)


func _draw_fireflies(w: float, h: float) -> void:
	for k: int in range(_flies.size()):
		var base := Vector2(fposmod(k * 97.0 + 260.0 + _time * (2.0 + k % 3), w),
				_ground_y + 6.0 + fposmod(k * 31.0, h - _ground_y - 10.0))
		var p := (base + Vector2(sin(_time * 0.9 + k) * 8.0, sin(_time * 1.3 + k * 2.0) * 5.0)).round()
		var a := 0.5 + 0.5 * sin(_time * 2.4 + k * 1.7)
		_flies[k] = Vector3(p.x, p.y, a)
		draw_rect(Rect2(p, Vector2(1, 1)), Color(0.85, 1.0, 0.55, 0.85 * a))
	# Pétalas de sakura caindo devagar diante de tudo.
	for k: int in range(6):
		var x := fposmod(k * 131.0 + _time * (7.0 + k), w + 20.0) - 10.0
		var y := fposmod(k * 47.0 + _time * (9.0 + k * 1.5), h + 10.0) - 5.0
		draw_rect(Rect2(roundf(x + sin(_time * 2.0 + k) * 4.0), roundf(y), 2, 1), Color(1.0, 0.72, 0.82, 0.5))
