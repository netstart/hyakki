class_name MenuBackdrop
extends Control
## Fundo animado dos menus: "Hyakki Yagyō", o desfile noturno dos cem demônios. Um diorama
## em camadas, de trás para a frente: céu índigo com estrelas, lua com halo e nuvens, duas
## cordilheiras, a procissão de yōkai andando na crista do meio (com lanternas de papel e
## hitodama), o vale escuro, o caminho de pedra até o torii, os tōrō, a guardiã escolhida
## com a lanterna, árvores em silhueta nas bordas, névoa e vinheta. Só Ninja Adventure.
## A luz vem da paleta (sem véu preto por cima). O terço esquerdo fica escuro e calmo
## porque a lista do menu fica ali; o canto superior direito tem o chip de moedas.
## Custo: o diorama é dividido em camadas filhas, na ordem de trás para a frente, e só as
## animadas são redesenhadas, a REDRAW_HZ (o cenário anda devagar: procissão a 9 px/s, névoa a
## 4-6 px/s, tudo arredondado ao pixel; cada passo anda menos de 1 px). As fixas (lua, cordilheiras,
## chão, caminho, torii, tōrō, árvores e vinheta) só são refeitas quando o tamanho muda. Nenhuma
## camada animada usa polígono, linha ou círculo (cada um vira um buffer de vértices novo na GPU a
## cada redesenho, o que pesava 8-10 ms por quadro no celular): só retângulos e texturas; os
## hitodama (círculos) vêm de uma textura de discos já desenhados (StaticBake), com os mesmos
## pixels. Gradientes, polígonos e texturas são montados no _ready ou quando o tamanho muda, nunca
## a cada quadro. Escondido (história, resultados, partida), para.

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
## Redesenhos por segundo do cenário animado (fundo e camada de luz).
const REDRAW_HZ := 30.0
## Hitodama: pontos do rastro e célula de cada disco na textura de discos.
const WISP_TRAIL := 6
const DISC_CELL := 8

const SKY_TOP := Color("0b0a1f")
const SKY_HORIZON := Color("2a1636")
const FAR_RIDGE := Color("251c44")
const FAR_RIM := Color("43376a")
const MID_RIDGE := Color("110d20")
const MID_RIM := Color("332a58")
const WALKER_TINT := Color(0.2, 0.18, 0.32)
const GRASS_TINT := Color(0.17, 0.23, 0.33)
const TORII_TINT := Color(0.72, 0.5, 0.62)
const TORO_TINT := Color(0.36, 0.34, 0.48)
const HERO_TINT := Color(0.82, 0.78, 0.9)
const TREE_FAR := Color(0.06, 0.05, 0.11)
const TREE_NEAR := Color(0.035, 0.03, 0.07)
const NIGHT_SHADE := Color("05040c")
const MOON := Color("f1e9d2")
const MOON_RADIUS := 26.0
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
## Tempo até o próximo redesenho do cenário animado (REDRAW_HZ).
var _redraw_wait := 0.0

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
## Camadas na ordem de desenho e as animadas (redesenhadas a REDRAW_HZ).
var _layers: Array[Control] = []
var _dynamic: Array[Control] = []
## Discos brancos já rasterizados (um por raio dos hitodama), para desenhar sem polígonos.
var _discs: StaticBake


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Névoa e brilhos passam da borda: corta no próprio retângulo.
	clip_contents = true
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
	visibility_changed.connect(_on_visibility_changed)
	_discs = StaticBake.new(_paint_discs)
	_discs.name = "Discs"
	_discs.display = false
	_discs.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_discs.size = Vector2(DISC_CELL * WISP_TRAIL, DISC_CELL)
	add_child(_discs)
	# De trás para a frente: false = fixa (só refeita quando o tamanho muda), true = animada.
	_layer(_paint_sky_stars, true)
	_layer(_paint_moon, false)
	_layer(_paint_clouds, true)
	_layer(_paint_far_ridge, false)
	_layer(_paint_far_fog, true)
	_layer(_paint_mid_ridge, false)
	_layer(_paint_procession, true)
	_layer(_paint_ground, false)
	_layer(_paint_ground_fog, true)
	_layer(_paint_shrine, false)
	_layer(_paint_fire_and_hero, true)
	_layer(_paint_trees, false)
	_layer(_paint_front, true)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light = _layer(_draw_lights, true)
	_light.material = add
	_shade = _layer(_draw_shade, false)


## Camada animada: um Control redesenhado a REDRAW_HZ. Camada fixa: um StaticBake (o desenho
## vira uma textura, refeita só quando o tamanho muda), que a tela desenha com um retângulo só.
func _layer(painter: Callable, animated: bool) -> Control:
	var layer: Control
	if animated:
		layer = Control.new()
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.draw.connect(painter.bind(layer))
	else:
		var bake := StaticBake.new(func(canvas: CanvasItem) -> void: painter.call(canvas))
		bake.repeat = true
		layer = bake
	add_child(layer)
	_layers.append(layer)
	if animated:
		_dynamic.append(layer)
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
	# Lista rolando pelo dedo (TouchScroll.busy): o cenário é só decorativo e espera parado, sem
	# redesenhar; o quadro fica só com a lista andando e volta de onde parou, sem salto.
	if TouchScroll.busy():
		return
	_time += delta
	_hero_check += delta
	if _hero_check >= HERO_CHECK_INTERVAL:
		_hero_check = 0.0
		_refresh_hero()
	_redraw_wait -= delta
	if _redraw_wait > 0.0:
		return
	# Sem acumular atraso: um quadro longo não gera redesenhos seguidos depois.
	_redraw_wait = maxf(_redraw_wait + 1.0 / REDRAW_HZ, 0.0)
	for layer: Control in _dynamic:
		layer.queue_redraw()


## Escondido (tela da história, partida com a camada dos menus oculta): não anima nem redesenha.
## Ao voltar, redesenha na hora e confere o herói escolhido.
func _on_visibility_changed() -> void:
	var shown := is_visible_in_tree()
	set_process(shown)
	if shown:
		_redraw_wait = 0.0
		_refresh_hero()


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


## Área do diorama. Sob um pai que não é Control as âncoras não dão tamanho: usa a tela
## inteira. Refaz a geometria fixa quando o tamanho muda.
func _ensure_layout() -> Vector2:
	var area := size if size.x > 1.0 and size.y > 1.0 else get_viewport_rect().size
	if area != _layout_size:
		_layout(area)
	return area


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		# As camadas fixas também dependem da geometria do tamanho novo.
		for layer: Control in _layers:
			if layer is StaticBake:
				(layer as StaticBake).invalidate()
			else:
				layer.queue_redraw()


# --- Camadas (de trás para a frente) -----------------------------------------------------

func _paint_sky_stars(c: Control) -> void:
	_ensure_layout()
	c.draw_texture_rect(_sky, Rect2(0, 0, _layout_size.x, _ground_y), false)
	for star: Vector3 in _stars:
		var a := 0.3 + 0.5 * (0.5 + 0.5 * sin(_time * (1.3 + star.z * 2.0) + star.z * 40.0))
		var color := Color(0.85, 0.85, 1.0, a)
		c.draw_rect(Rect2(star.x, star.y, 1, 1), color)
		if star.z > 0.88:
			color.a *= 0.4
			c.draw_rect(Rect2(star.x - 1, star.y, 3, 1), color)
			c.draw_rect(Rect2(star.x, star.y - 1, 1, 3), color)


## Lua fixa: halo e disco com sombreado e crateras (as nuvens que passam são outra camada).
func _paint_moon(c: Control) -> void:
	_ensure_layout()
	var center := _moon_center()
	var r := MOON_RADIUS
	c.draw_texture_rect(_glow, Rect2(center - Vector2(r, r) * 4.5, Vector2(r, r) * 9.0), false,
			Color(MOONLIGHT, 0.16))
	c.draw_texture_rect(_glow, Rect2(center - Vector2(r, r) * 2.0, Vector2(r, r) * 4.0), false,
			Color(MOONLIGHT, 0.28))
	c.draw_circle(center, r + 2.0, Color(MOON, 0.2), true, -1.0, false)
	c.draw_circle(center, r, MOON, true, -1.0, false)
	# Sombreado do lado oposto à luz e crateras discretas.
	c.draw_circle(center + Vector2(5, 4), r - 4.0, Color(0.86, 0.8, 0.72, 0.4), true, -1.0, false)
	c.draw_circle(center + Vector2(-8, -6), 4.0, Color(0.78, 0.73, 0.66, 0.6), true, -1.0, false)
	c.draw_circle(center + Vector2(7, 9), 3.0, Color(0.78, 0.73, 0.66, 0.5), true, -1.0, false)
	c.draw_circle(center + Vector2(10, -10), 2.0, Color(0.78, 0.73, 0.66, 0.5), true, -1.0, false)


## Faixas finas de nuvem cruzando a lua devagar (sempre perto dela).
func _paint_clouds(c: Control) -> void:
	_ensure_layout()
	var center := _moon_center()
	for k: int in range(3):
		var band_w := 120.0 + k * 30.0
		var x := center.x - band_w * 0.5 + sin(_time * (0.05 + k * 0.02) + k * 2.0) * 90.0
		var y := roundf(center.y - 16.0 + k * 14.0)
		c.draw_texture_rect(_fog, Rect2(roundf(x), y, band_w, 6.0 + k * 2.0), false, Color(0.1, 0.08, 0.22, 0.8))


## Montes ao longe, com a borda tocada pela lua.
func _paint_far_ridge(c: Control) -> void:
	_ensure_layout()
	c.draw_colored_polygon(_far_poly, FAR_RIDGE)
	c.draw_polyline(_far_line, FAR_RIM, 1.0)


func _paint_far_fog(c: Control) -> void:
	var area := _ensure_layout()
	_draw_fog_band(c, roundf(area.y * 0.37), 30.0, 4.0, Color(0.55, 0.42, 0.72, 0.13), area.x)


## Crista do meio (onde a procissão anda).
func _paint_mid_ridge(c: Control) -> void:
	_ensure_layout()
	c.draw_colored_polygon(_mid_poly, MID_RIDGE)
	c.draw_polyline(_mid_line, MID_RIM, 1.0)


func _paint_procession(c: Control) -> void:
	var area := _ensure_layout()
	_draw_procession(c, area.x)


## Vale: grama em silhueta e a sombra do chão.
func _paint_ground(c: Control) -> void:
	var area := _ensure_layout()
	var ground := Rect2(0, _ground_y, area.x, area.y - _ground_y)
	c.draw_texture_rect(_grass, ground, true, GRASS_TINT)
	c.draw_texture_rect(_ground_shade, ground, false)


func _paint_ground_fog(c: Control) -> void:
	var area := _ensure_layout()
	_draw_fog_band(c, _ground_y - 22.0, 48.0, 5.0, Color(0.6, 0.5, 0.82, 0.12), area.x)


## Caminho de lajes do pé da tela até o torii (estreitando com a distância), o torii e os dois
## tōrō (o fogo deles anima, na camada seguinte).
func _paint_shrine(c: Control) -> void:
	var area := _ensure_layout()
	var w := area.x
	var h := area.y
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
		c.draw_rect(slab, Color(0.1 * lit + 0.04, 0.09 * lit + 0.04, 0.16 * lit + 0.06))
		c.draw_rect(Rect2(slab.position, Vector2(slab.size.x, 1)), Color(0.5, 0.4, 0.42, 0.3 * lit))
		var seam := roundf(cx + (half * 0.3 if r % 2 == 0 else -half * 0.35))
		c.draw_rect(Rect2(seam, slab.position.y + 1.0, 1, slab.size.y - 1.0), Color(0.03, 0.02, 0.06, 0.7))
	c.draw_texture_rect_region(_house, _torii, Rect2(0, 80, 48, 32), TORII_TINT)
	for i: int in range(2):
		var x := _toro_x(i, w)
		c.draw_texture_rect_region(_element, Rect2(x, _toro_feet(h) - 64.0, 32, 64), Rect2(0, 80, 16, 32), TORO_TINT)


## Fogo dos tōrō e a guardiã escolhida com a lanterna.
func _paint_fire_and_hero(c: Control) -> void:
	var area := _ensure_layout()
	for i: int in range(2):
		var fire := Vector2(_toro_x(i, area.x) + 16.0, _toro_feet(area.y) - 42.0)
		var flicker := 0.85 + 0.1 * sin(_time * 9.0 + i * 4.0) + 0.05 * sin(_time * 23.0)
		c.draw_rect(Rect2(fire.x - 5.0, fire.y - 4.0, 10, 8), Color(1.0, 0.62, 0.3, flicker))
		c.draw_rect(Rect2(fire.x - 2.0, fire.y - 2.0, 4, 4), Color(1.0, 0.9, 0.6, flicker))
		_toro_fire[i] = fire
	_draw_hero(c, area.x)


## Árvores em silhueta nas bordas, cortadas pela borda. Esquerda: árvore seca e pinheiros;
## direita: pinheiros.
func _paint_trees(c: Control) -> void:
	var area := _ensure_layout()
	var w := area.x
	var h := area.y
	c.draw_texture_rect_region(_nature, Rect2(-46, h - 150.0, 128, 96), Rect2(0, 32, 64, 48), TREE_FAR)
	c.draw_texture_rect_region(_nature, Rect2(-20, h - 104.0, 96, 96), Rect2(64, 0, 32, 32), TREE_NEAR)
	c.draw_texture_rect_region(_nature, Rect2(w - 84.0, h - 166.0, 128, 96), Rect2(0, 32, 64, 48), TREE_FAR)
	c.draw_texture_rect_region(_nature, Rect2(w - 56.0, h - 96.0, 96, 96), Rect2(32, 0, 32, 32), TREE_NEAR)
	c.draw_texture_rect_region(_nature, Rect2(w - 150.0, h - 60.0, 64, 64), Rect2(32, 0, 32, 32), TREE_NEAR)


## Névoa da frente, vaga-lumes e pétalas.
func _paint_front(c: Control) -> void:
	var area := _ensure_layout()
	_draw_fog_band(c, area.y - 40.0, 48.0, 6.0, Color(0.58, 0.5, 0.82, 0.12), area.x)
	_draw_fireflies(c, area.x, area.y)


## Camada aditiva: halos das lanternas, hitodama, vaga-lumes e poças de luz no chão.
## Mais fraca no terço esquerdo, onde fica a lista do menu.
func _draw_lights(c: Control) -> void:
	var w := _layout_size.x
	if w <= 0.0:
		return
	for k: int in range(_walkers.size()):
		if k % 3 == 1:
			var flicker := 0.9 + 0.1 * sin(_time * 11.0 + k * 3.0)
			_light_at(c, _walker_lamp(k), 26.0, Color(WARM, 0.8 * flicker), w)
	for p: Vector2 in _wisps:
		_light_at(c, p, 16.0, Color(WISP, 0.7), w)
	for k: int in range(_toro_fire.size()):
		var fire := _toro_fire[k]
		var flicker := 0.85 + 0.1 * sin(_time * 9.0 + k * 4.0) + 0.05 * sin(_time * 23.0)
		_light_at(c, fire, 44.0, Color(WARM, 0.75 * flicker), w)
		c.draw_texture_rect(_glow, Rect2(fire.x - 46.0, fire.y + 30.0, 92.0, 22.0), false,
				Color(WARM, 0.45 * flicker))
	var pulse := 1.0 + 0.05 * sin(_time * 4.0)
	_light_at(c, _hero_lamp, 72.0 * pulse, Color(WARM, 0.6), w)
	_light_at(c, _hero_lamp, 14.0, Color(1.0, 0.85, 0.55, 0.7), w)
	c.draw_texture_rect(_glow, Rect2(_hero_lamp.x - 84.0, _torii.end.y - 14.0, 168.0, 40.0), false,
			Color(WARM, 0.55 * pulse))
	for p: Vector3 in _flies:
		_light_at(c, Vector2(p.x, p.y), 5.0, Color(0.7, 1.0, 0.45, 0.45 * p.z), w)


func _light_at(c: Control, p: Vector2, radius: float, color: Color, w: float) -> void:
	color.a *= lerpf(0.35, 1.0, smoothstep(w * 0.12, w * 0.45, p.x))
	c.draw_texture_rect(_glow, Rect2(p.round() - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false,
			color)


## Camada de sombra: vinheta e o lado esquerdo mais escuro para a lista do menu. Fixa.
func _draw_shade(c: Control) -> void:
	var area := _ensure_layout()
	c.draw_texture_rect(_vignette, Rect2(0, 0, area.x, area.y), false)
	c.draw_texture_rect(_left_shade, Rect2(0, 0, maxf(area.x * 0.46, 250.0), area.y), false)


## Discos brancos dos hitodama (um por ponto do rastro), cada um na sua célula, desenhados pelo
## mesmo draw_circle de antes: a camada animada copia o disco com a cor, sem criar polígonos.
func _paint_discs(c: CanvasItem) -> void:
	for t: int in range(WISP_TRAIL):
		var center := Vector2(t * DISC_CELL + DISC_CELL * 0.5, DISC_CELL * 0.5)
		c.draw_circle(center, wisp_radius(t), Color.WHITE, true, -1.0, false)


## Raio do disco `t` do rastro de um hitodama (0 = a cabeça).
static func wisp_radius(t: int) -> float:
	return 2.5 - t * 0.35


func _moon_center() -> Vector2:
	return Vector2(roundf(_layout_size.x * 0.78), roundf(_layout_size.y * 0.2))


func _toro_x(i: int, w: float) -> float:
	return roundf(w * 0.5) + (-1.0 if i == 0 else 1.0) * 86.0 - 16.0


func _toro_feet(h: float) -> float:
	return roundf(minf(h - 6.0, _torii.end.y + 62.0))


func _draw_fog_band(c: Control, y: float, band_h: float, speed: float, tint: Color, w: float) -> void:
	var span := w * 0.75
	var x := -fposmod(_time * speed, span) - span * 0.5
	while x < w:
		c.draw_texture_rect(_fog, Rect2(roundf(x), y, span * 1.4, band_h), false, tint)
		x += span


func _walker_lamp(k: int) -> Vector2:
	var feet := _walkers[k]
	return Vector2(feet.x + 2.0, roundf(feet.y - 24.0 + sin(_time * 2.2 + k) * 2.0))


func _draw_procession(c: Control, w: float) -> void:
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
		_draw_sprite(c, sheet.flash_texture, top + Vector2(1, -1), src, flip, rim)
		_draw_sprite(c, sheet.texture, top, src, flip, WALKER_TINT)
		if k % 3 == 1:
			# Chōchin flutuando acima do yōkai (o halo fica na camada de luz).
			var lamp := _walker_lamp(k)
			c.draw_line(Vector2(lamp.x, lamp.y - 6.0), Vector2(lamp.x, lamp.y - 2.0), Color(0.1, 0.08, 0.16), 1.0)
			c.draw_rect(Rect2(lamp.x - 1, lamp.y - 2, 3, 4), Color(1.0, 0.55, 0.28))
			c.draw_rect(Rect2(lamp.x, lamp.y - 1, 1, 2), Color(1.0, 0.92, 0.6))
	# Hitodama: chamas azuladas com rastro, em volta da procissão (discos da textura de discos).
	var discs := _discs.texture()
	var half := Vector2(DISC_CELL, DISC_CELL) * 0.5
	for k: int in range(_wisps.size()):
		var base_x := fposmod(_time * (WALKER_SPEED + 3.0) + k * span / _wisps.size() + 50.0, span) - 40.0
		var ground := ridge_y(base_x) - 32.0
		for t: int in range(WISP_TRAIL - 1, -1, -1):
			var tt := _time - t * 0.08
			var p := Vector2(base_x - t * 2.0 + sin(tt * 1.7 + k) * 10.0, ground + sin(tt * 2.3 + k * 2.0) * 7.0).round()
			c.draw_texture_rect_region(discs, Rect2(p - half, half * 2.0), Rect2(Vector2(t * DISC_CELL, 0), half * 2.0),
					Color(WISP, 0.85 * (1.0 - t / 6.0)))
			if t == 0:
				_wisps[k] = p
				c.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.95))


func _draw_sprite(c: Control, tex: Texture2D, at: Vector2, src: Rect2, flip: bool, tint: Color) -> void:
	if flip:
		c.draw_set_transform(at + Vector2(16, 0), 0.0, Vector2(-1, 1))
		c.draw_texture_rect_region(tex, Rect2(Vector2.ZERO, src.size), src, tint)
		c.draw_set_transform(Vector2.ZERO)
	else:
		c.draw_texture_rect_region(tex, Rect2(at, src.size), src, tint)


func _draw_hero(c: Control, w: float) -> void:
	var feet := Vector2(roundf(w * 0.5), _torii.end.y + 6.0)
	var bob := 1.0 if fposmod(_time, 1.0) >= 0.5 else 0.0
	var tex := _hero.texture
	var hand := feet + Vector2(12, -14)
	c.draw_texture_rect(_glow, Rect2(feet.x - 14.0, feet.y - 4.0, 28.0, 8.0), false, Color(0, 0, 0, 0.6))
	if _hero_side != Vector2.ZERO:
		var size2 := _hero_side * 2.0
		var frame := posmod(int(_time * 6.0), _hero_idle_frames)
		var src := Rect2(Vector2(frame * _hero_side.x, 0), _hero_side)
		var at := Vector2(feet.x - size2.x * 0.5, feet.y - size2.y + bob)
		# A folha "side" olha para a esquerda: espelha para olhar para a direita.
		c.draw_set_transform(at + Vector2(size2.x, 0), 0.0, Vector2(-2, 2))
		c.draw_texture_rect_region(tex, Rect2(Vector2.ZERO, _hero_side), src, HERO_TINT)
		c.draw_set_transform(Vector2.ZERO)
		hand = feet + Vector2(12, roundf(-size2.y * 0.42))
	else:
		c.draw_texture_rect_region(tex, Rect2(feet + Vector2(-16, -32 + bob), Vector2(32, 32)),
				_hero.region(0, SpriteSheet.Dir.DOWN), HERO_TINT)
	# Lanterna da guardiã: a chama (o halo fica na camada de luz).
	_hero_lamp = (hand + Vector2(0, bob)).round()
	c.draw_line(_hero_lamp + Vector2(0, -7), _hero_lamp + Vector2(0, -3), Color(0.12, 0.08, 0.1), 1.0)
	c.draw_rect(Rect2(_hero_lamp.x - 2, _hero_lamp.y - 3, 5, 6), Color(1.0, 0.6, 0.3))
	c.draw_rect(Rect2(_hero_lamp.x - 1, _hero_lamp.y - 2, 3, 4), Color(1.0, 0.95, 0.72))


func _draw_fireflies(c: Control, w: float, h: float) -> void:
	for k: int in range(_flies.size()):
		var base := Vector2(fposmod(k * 97.0 + 260.0 + _time * (2.0 + k % 3), w),
				_ground_y + 6.0 + fposmod(k * 31.0, h - _ground_y - 10.0))
		var p := (base + Vector2(sin(_time * 0.9 + k) * 8.0, sin(_time * 1.3 + k * 2.0) * 5.0)).round()
		var a := 0.5 + 0.5 * sin(_time * 2.4 + k * 1.7)
		_flies[k] = Vector3(p.x, p.y, a)
		c.draw_rect(Rect2(p, Vector2(1, 1)), Color(0.85, 1.0, 0.55, 0.85 * a))
	# Pétalas de sakura caindo devagar diante de tudo.
	for k: int in range(6):
		var x := fposmod(k * 131.0 + _time * (7.0 + k), w + 20.0) - 10.0
		var y := fposmod(k * 47.0 + _time * (9.0 + k * 1.5), h + 10.0) - 5.0
		c.draw_rect(Rect2(roundf(x + sin(_time * 2.0 + k) * 4.0), roundf(y), 2, 1), Color(1.0, 0.72, 0.82, 0.5))
