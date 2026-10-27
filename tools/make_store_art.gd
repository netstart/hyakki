extends Node
## Arte da Google Play feita só com os assets do jogo (Ninja Adventure, CC0; fonte Fusion
## Pixel, OFL) e com o próprio fundo animado dos menus (MenuBackdrop). Tudo é composto em
## resolução de pixel art e ampliado por vizinho mais próximo em escala inteira.
##
## Gera em docs/store/graphics/ (ou --out=DIR):
##   icon_512.png                          ícone da loja (512×512, 32 bits, opaco)
##   launcher/icon_192.png                 ícone legado do Android (192×192)
##   launcher/adaptive_{foreground,background,monochrome}_432.png   ícone adaptativo
##   feature_graphic_{pt-BR,en,notext}.png  gráfico de recursos (1024×500, sem alfa)
##   screenshots/{pt-BR,en}/NN_nome.png    capturas com legenda 1920×1080 (jogo 678×305 ×2)
##   tablet/{7in,10in}/{pt-BR,en}/         capturas com legenda 2560×1440 (jogo ×3)
##   screenshots/raw/<idioma>/             capturas puras 1356×610 (×2), só referência
## e copia o ícone adaptativo para assets/art/ui/app_icon/ (vai no jogo).
##
## Uso (precisa de janela; as capturas vêm de tools/store_capture.tscn):
##   Godot_v4.7.2-stable_win64.exe --path . res://tools/make_store_art.tscn -- \
##       --captures=DIR_COM_pt_BR_E_en [--out=DIR] [--only=icons,feature,screens]
## Ou tudo de uma vez: powershell -File tools\make_store_art.ps1

const LATIN_FONT := "res://assets/fonts/fusion_pixel_12_latin.woff2"
const JA_FONT := "res://assets/fonts/fusion_pixel_12_ja.woff2"
const FACESET := "res://assets/art/actors/heroes/aki/Faceset.png"
const HOUSE := "res://assets/art/tilesets/house.png"
const APP_ICON_DIR := "res://assets/art/ui/app_icon"

const SKY := [Color("0b0a1f"), Color("17123a"), Color("2a1636"), Color("4a2448")]
const SKY_STOPS := [0.0, 0.4, 0.78, 1.0]
const MOON := Color("f1e9d2")
const MOON_SHADE := Color("d8cdb0")
const MOONLIGHT := Color("b9b3e8")
const WARM := Color("ffb45a")
const INK := Color("0b0a1f")
const ACCENT := Color("ffd166")
const GOLD := Color("d9a441")
const MUTED := Color("d9c3a0")
const SEAL_RED := Color("b3261e")
const SHADOW := Color(0.08, 0.03, 0.03)
## Tela lógica real do jogo (aparelho alvo) e quadro lógico das peças 16:9.
const NATIVE := Vector2i(678, 305)
const CANVAS := Vector2i(640, 360)
## Telefone 1920×1080 e tablet 2560×1440: escala do quadro (k), da captura (m) e topo do painel.
const PHONE := {"k": 3, "m": 2, "top": 330}
const TABLET_LAYOUT := {"k": 4, "m": 3, "top": 400}
const PARADE := ["oni_red", "lantern_red", "kitsune", "skull", "ghost_monk", "spirit", "tengu_small",
		"kappa_green", "skeleton", "lantern_green", "oni_green", "bat_blue"]
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

## Capturas da loja, na ordem da ficha. Legendas curtas (benefício) e linha de apoio.
const SHOTS := [
	{"id": "boss2", "pt": ["Sobreviva até o amanhecer", "Enfrente o desfile noturno dos cem yōkai"],
			"en": ["Survive until dawn", "Face the night parade of one hundred yōkai"]},
	{"id": "combat_dunes", "pt": ["Jogue com um dedo", "Os ataques são automáticos: você só se move"],
			"en": ["Play with one finger", "Attacks are automatic: you just move"]},
	{"id": "levelup", "pt": ["Monte sua build a cada nível", "Escolha armas, bênçãos e relíquias"],
			"en": ["Craft your build every level", "Pick weapons, blessings and relics"]},
	{"id": "ult", "pt": ["Golpe da Lanterna", "Encha a lanterna e limpe a tela"],
			"en": ["Lantern Strike", "Charge your lantern and clear the screen"]},
	{"id": "pause", "pt": ["Mais de 30 armas e evoluções", "15 armas, 15 evoluções e 2 uniões"],
			"en": ["30+ weapons and evolutions", "15 weapons, 15 evolutions and 2 unions"]},
	{"id": "boss", "pt": ["12 chefes lendários", "Do Rei Tengu Corvo à própria Izanami"],
			"en": ["12 legendary bosses", "From the Crow Tengu King to Izanami herself"]},
	{"id": "heroes", "pt": ["7 guardiões, 7 estilos", "Cada um com arma e Golpe da Lanterna próprios"],
			"en": ["7 guardians, 7 playstyles", "Each with their own weapon and Lantern Strike"]},
	{"id": "stages", "pt": ["Uma jornada pelo Japão mítico", "Fases, Lua Vermelha e Noite Sem Fim"],
			"en": ["A journey through mythic Japan", "Stages, Red Moon and Endless Night"]},
	{"id": "chest", "pt": ["Baús laqueados e evoluções", "Una arma e relíquia para evoluir"],
			"en": ["Lacquered chests and evolutions", "Pair a weapon with a relic to evolve it"]},
	{"id": "sanctuary", "pt": ["Fique mais forte a cada noite", "18 ofertas permanentes no Santuário"],
			"en": ["Grow stronger every night", "18 permanent offerings at the Sanctuary"]},
	{"id": "codex", "pt": ["Desvende o bestiário yōkai", "Lendas, chefes, armas e a história da Ordem"],
			"en": ["Uncover the yōkai bestiary", "Legends, bosses, weapons and the Order's story"]},
	{"id": "results", "pt": ["Chegue ao amanhecer", "Cada vitória abre novas fases e segredos"],
			"en": ["Make it to dawn", "Every victory opens new stages and secrets"]},
]
## Capturas extras só na pasta raw (alternativas para a ficha).
const EXTRA_RAW := ["combat", "combat_temple", "combat2", "boss3", "ult_b", "title", "dawn"]
## As 4 capturas dos tablets (7" e 10").
const TABLET := ["boss2", "combat_dunes", "levelup", "heroes"]
const LANGS := {"pt": "pt_BR", "en": "en"}
const LANG_DIRS := {"pt": "pt-BR", "en": "en"}

var out_dir := ""
var captures_dir := ""
var only: PackedStringArray = []
var _latin: FontFile
var _ja: FontFile


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--captures="):
			captures_dir = arg.trim_prefix("--captures=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",", false)
	if out_dir.is_empty():
		out_dir = ProjectSettings.globalize_path("res://docs/store/graphics")
	_latin = _pixel_font(LATIN_FONT)
	_ja = _pixel_font(JA_FONT)
	if _wants("icons"):
		_make_icons()
	if _wants("feature"):
		await _make_feature()
	if _wants("screens"):
		await _make_screens()
	print("STORE ART DONE")
	get_tree().quit()


func _wants(part: String) -> bool:
	return only.is_empty() or only.has(part)


func _pixel_font(path: String) -> FontFile:
	var font := load(path) as FontFile
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.generate_mipmaps = false
	return font


func _save(img: Image, rel: String, alpha: bool = false) -> void:
	var path := out_dir.path_join(rel)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var copy := img.duplicate() as Image
	copy.convert(Image.FORMAT_RGBA8 if alpha else Image.FORMAT_RGB8)
	copy.save_png(path)
	print("ART %s %dx%d" % [rel, copy.get_width(), copy.get_height()])


static func _scaled(img: Image, k: int) -> Image:
	var copy := img.duplicate() as Image
	copy.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	return copy


static func _asset(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img


# --- Ícones ----------------------------------------------------------------------------

func _make_icons() -> void:
	var face := _keyed_face()
	# Loja: 128×128 ×4. Legado do Android: 96×96 ×2.
	_save(_scaled(_icon(128, face, true, true), 4), "icon_512.png", true)
	var legacy := _scaled(_icon(96, face, true, true), 2)
	_save(legacy, "launcher/icon_192.png", true)
	# Adaptativo: 108×108 dp ×4. O rosto fica no círculo seguro central (72 dp).
	var bg := _scaled(_icon(108, face, true, false), 4)
	var fg := _scaled(_icon(108, face, false, true), 4)
	var mono := _scaled(_monochrome(_icon(108, face, false, true)), 4)
	_save(bg, "launcher/adaptive_background_432.png", true)
	_save(fg, "launcher/adaptive_foreground_432.png", true)
	_save(mono, "launcher/adaptive_monochrome_432.png", true)
	var game_dir := ProjectSettings.globalize_path(APP_ICON_DIR)
	DirAccess.make_dir_recursive_absolute(game_dir)
	for pair: Array in [[legacy, "icon_192.png"], [bg, "adaptive_background_432.png"],
			[fg, "adaptive_foreground_432.png"], [mono, "adaptive_monochrome_432.png"]]:
		(pair[0] as Image).save_png(game_dir.path_join(String(pair[1])))
		print("ART %s/%s" % [APP_ICON_DIR, pair[1]])


## Rosto da Aki (Faceset 38×38) sem o fundo chapado e com contorno de 1 px.
func _keyed_face() -> Image:
	var img := _asset(FACESET)
	var bg := img.get_pixel(0, 0)
	var w := img.get_width()
	var h := img.get_height()
	var stack: Array[Vector2i] = []
	for x: int in range(w):
		stack.append(Vector2i(x, 0))
	for y: int in range(h):
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var c := img.get_pixelv(p)
		if c.a == 0.0 or not c.is_equal_approx(bg):
			continue
		img.set_pixelv(p, Color(0, 0, 0, 0))
		stack.append_array([p + Vector2i.LEFT, p + Vector2i.RIGHT, p + Vector2i.UP, p + Vector2i.DOWN])
	return _outlined(img, INK)


static func _outlined(img: Image, color: Color) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create_empty(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	for y: int in range(h + 2):
		for x: int in range(w + 2):
			var inside := false
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var q := Vector2i(x - 1, y - 1) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and img.get_pixelv(q).a > 0.5:
					inside = true
			if inside:
				out.set_pixel(x, y, color)
	out.blend_rect(img, Rect2i(0, 0, w, h), Vector2i(1, 1))
	return out


## Cena do ícone em `n`×`n`: céu índigo pontilhado, estrelas, lua com halo, torii e luz da
## lanterna (fundo) e o rosto da guardiã ×2 (frente).
func _icon(n: int, face: Image, with_bg: bool, with_face: bool) -> Image:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var s := n / 128.0
	var cx := n / 2
	if with_bg:
		_sky(img)
		_stars(img, 7 + n, int(28 * s * s) + 6)
		var moon_c := Vector2i(cx, roundi(n * 0.42))
		var moon_r := roundi(n * 0.27)
		_disc(img, moon_c, moon_r + roundi(9 * s), Color(MOONLIGHT, 0.10))
		_disc(img, moon_c, moon_r + roundi(5 * s), Color(MOONLIGHT, 0.16))
		_disc(img, moon_c, moon_r + roundi(2 * s), Color(MOON, 0.3))
		_moon(img, moon_c, moon_r)
		# Colinas escuras e névoa baixa.
		_hills(img)
		# Halo quente da lanterna aos pés.
		_glow(img, Vector2i(cx, n - roundi(n * 0.08)), roundi(n * 0.42), WARM, 0.32)
	if with_face:
		var f2 := _scaled(face, 2)
		var at := Vector2i(cx - f2.get_width() / 2, n - f2.get_height() + roundi(n * 0.02))
		if not with_bg:
			# Ícone adaptativo: centraliza a cabeça no círculo seguro (72 de 108).
			at.y = roundi(n * 0.5 - f2.get_height() * 0.46)
		img.blend_rect(f2, Rect2i(Vector2i.ZERO, f2.get_size()), at)
		if with_bg:
			# A lanterna da guardiã, à frente, no canto: a luz que segura a noite.
			var lamp := _scaled(_lantern(), 2)
			var lamp_at := Vector2i(n - lamp.get_width() - roundi(n * 0.07), n - lamp.get_height() - roundi(n * 0.05))
			_glow(img, lamp_at + lamp.get_size() / 2, roundi(n * 0.2), WARM, 0.55)
			img.blend_rect(lamp, Rect2i(Vector2i.ZERO, lamp.get_size()), lamp_at)
	return img


## Chōchin (lanterna de papel) em pixel art, 11×15, desenhada aqui mesmo.
static func _lantern() -> Image:
	var rows := [
		"....###....",
		"..#######..",
		".#rrrrrrr#.",
		"#rroyyyorr#",
		"#ddddddddd#",
		"#rroyyyorr#",
		"#rroyywyrr#",
		"#ddddddddd#",
		"#rroyyyorr#",
		"#rrooyoorr#",
		"#ddddddddd#",
		".#rrrrrrr#.",
		"..#######..",
		"....#t#....",
		".....t.....",
	]
	var palette := {"#": Color("2a1a10"), "r": Color("c0392b"), "d": Color("8e2a1e"), "o": Color("ff8a3a"),
			"y": Color("ffd166"), "w": Color("fff4e0"), "t": Color("e0403a")}
	var img := Image.create_empty(11, rows.size(), false, Image.FORMAT_RGBA8)
	for y: int in range(rows.size()):
		var line: String = rows[y]
		for x: int in range(line.length()):
			if palette.has(line[x]):
				img.set_pixel(x, y, palette[line[x]])
	return img


## Camada monocromática (ícone temático do Android 13+): só o alfa conta. Cabelo e
## contorno cheios; pele e roupa mais leves, para o rosto continuar legível.
static func _monochrome(src: Image) -> Image:
	var out := Image.create_empty(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
	for y: int in range(src.get_height()):
		for x: int in range(src.get_width()):
			var c := src.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var luma := c.get_luminance()
			var a := 1.0 if luma < 0.22 else (0.55 if luma < 0.6 else 0.8)
			out.set_pixel(x, y, Color(1, 1, 1, a))
	return out


## Degradê do céu com pontilhado ordenado (Bayer 4×4) entre as cores da paleta do menu.
static func _sky(img: Image) -> void:
	var h := img.get_height()
	for y: int in range(h):
		var t := float(y) / maxf(1.0, h - 1.0)
		var i := 0
		while i < SKY_STOPS.size() - 2 and t > SKY_STOPS[i + 1]:
			i += 1
		var k: float = (t - float(SKY_STOPS[i])) / (float(SKY_STOPS[i + 1]) - float(SKY_STOPS[i]))
		for x: int in range(img.get_width()):
			var threshold: float = (int(BAYER[(y % 4) * 4 + x % 4]) + 0.5) / 16.0
			img.set_pixel(x, y, SKY[i + 1] if k > threshold else SKY[i])


static func _stars(img: Image, seed_value: int, count: int, avoid: Rect2i = Rect2i()) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var w := img.get_width()
	var h := img.get_height()
	for k: int in range(count):
		var p := Vector2i(rng.randi_range(1, w - 2), rng.randi_range(1, int(h * 0.55)))
		if avoid.grow(2).has_point(p):
			continue
		var bright := k % 5 == 0
		img.set_pixelv(p, Color(1, 0.97, 0.88) if bright else Color(0.75, 0.72, 0.95, 0.8))
		if bright and w >= 96:
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				img.set_pixelv(p + d, Color(0.75, 0.72, 0.95, 0.55))


static func _disc(img: Image, c: Vector2i, r: int, color: Color) -> void:
	for y: int in range(c.y - r, c.y + r + 1):
		for x: int in range(c.x - r, c.x + r + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			if Vector2(x - c.x, y - c.y).length() <= r + 0.3:
				img.set_pixel(x, y, img.get_pixel(x, y).blend(color))


static func _moon(img: Image, c: Vector2i, r: int) -> void:
	_disc(img, c, r, MOON)
	# Mares da lua em tom mais escuro, fixos.
	for spot: Vector3 in [Vector3(-0.35, -0.2, 0.22), Vector3(0.28, 0.25, 0.16), Vector3(0.05, -0.45, 0.1),
			Vector3(-0.15, 0.4, 0.12)]:
		_disc(img, c + Vector2i(roundi(spot.x * r), roundi(spot.y * r)), maxi(1, roundi(spot.z * r)),
				Color(MOON_SHADE, 0.85))


static func _hills(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for x: int in range(w):
		var u := float(x) / w
		var far := roundi(h * (0.70 + 0.05 * sin(u * 7.0 + 1.2) + 0.03 * sin(u * 17.0)))
		var near := roundi(h * (0.80 + 0.04 * sin(u * 5.0 + 3.0) + 0.02 * sin(u * 13.0 + 1.0)))
		for y: int in range(far, h):
			img.set_pixel(x, y, img.get_pixel(x, y).blend(Color("251c44") if y < near else Color("110d20")))
		img.set_pixel(x, far, Color("43376a"))
		if near < h:
			img.set_pixel(x, near, Color("332a58"))


## Brilho em anéis duros (sem degradê suave), como as luzes do jogo.
static func _glow(img: Image, c: Vector2i, r: int, color: Color, strength: float) -> void:
	for ring: int in range(4):
		var rr := roundi(r * (1.0 - ring * 0.22))
		_disc(img, c, rr, Color(color, strength * 0.25 * (ring + 1) / 4.0))


# --- Gráfico de recursos ---------------------------------------------------------------

func _make_feature() -> void:
	for variant: String in ["pt", "en", "notext"]:
		var img := await _render_feature(variant)
		var name := "feature_graphic_%s.png" % (LANG_DIRS[variant] if LANG_DIRS.has(variant) else variant)
		_save(_scaled(img, 2), name)


## 512×250 ×2 = 1024×500. Fundo: o diorama do menu (MenuBackdrop). À direita, a horda de
## yōkai avança contra a guardiã; à esquerda, o logotipo como na tela de título.
func _render_feature(variant: String) -> Image:
	if LANGS.has(variant):
		Locale.set_language(LANGS[variant], false)
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 250)
	vp.disable_3d = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var root := Control.new()
	root.size = Vector2(vp.size)
	vp.add_child(root)
	# O diorama centraliza torii e guardiã: num quadro mais largo que a tela eles ficam a
	# ~59% da largura, deixando a esquerda para o logotipo e a direita para a horda.
	var stage := Control.new()
	stage.size = Vector2(604, 250)
	root.add_child(stage)
	var backdrop := MenuBackdrop.new()
	stage.add_child(backdrop)
	var horde := _Horde.new()
	horde.size = root.size
	root.add_child(horde)
	if variant != "notext":
		root.add_child(_logo(variant))
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


func _logo(variant: String) -> Control:
	var col := VBoxContainer.new()
	col.position = Vector2(24, 30)
	col.add_theme_constant_override("separation", -8)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	var title := _label("HYAKKI", 48, ACCENT, 8)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_constant_override("shadow_outline_size", 8)
	head.add_child(title)
	var seal := PanelContainer.new()
	seal.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var seal_box := StyleBoxFlat.new()
	seal_box.bg_color = SEAL_RED
	seal_box.border_color = SEAL_RED.darkened(0.45)
	seal_box.set_border_width_all(1)
	seal_box.set_corner_radius_all(2)
	seal_box.content_margin_left = 3
	seal_box.content_margin_right = 2
	seal_box.content_margin_top = 1
	seal_box.content_margin_bottom = 2
	seal.add_theme_stylebox_override("panel", seal_box)
	var kanji := Label.new()
	kanji.text = "百
鬼"
	kanji.add_theme_font_override("font", _ja)
	kanji.add_theme_font_size_override("font_size", 12)
	kanji.add_theme_color_override("font_color", Color("fbe6cf"))
	kanji.add_theme_constant_override("line_spacing", -2)
	seal.add_child(kanji)
	var seal_holder := MarginContainer.new()
	seal_holder.add_theme_constant_override("margin_top", 12)
	seal_holder.add_child(seal)
	head.add_child(seal_holder)
	col.add_child(head)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.add_child(_rule())
	row.add_child(_label("Até o Amanhecer" if variant == "pt" else "Until Dawn", 24, MUTED, 6))
	row.add_child(_rule())
	col.add_child(row)
	return col


func _label(text: String, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _latin)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", SHADOW)
	l.add_theme_constant_override("outline_size", outline)
	return l


## Horda em primeiro plano para o gráfico de recursos: yōkai do jogo em ×2, iluminados pela
## lanterna, marchando da direita para o torii; um chefe (Oni Vermelho) atrás.
class _Horde:
	extends Control
	const ENEMIES := ["oni_red", "kitsune", "ghost_monk", "skeleton", "lantern_red", "tengu_small",
			"kappa_green", "spirit", "oni_green", "skull", "lantern_green", "eye"]
	var _sheets: Array[Texture2D] = []
	var _glow: GradientTexture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for id: String in ENEMIES:
			var path := "res://assets/art/actors/enemies/%s/SpriteSheet.png" % id
			_sheets.append(load(path) as Texture2D if ResourceLoader.exists(path) else null)
		_glow = GradientTexture2D.new()
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 0.7, 0.35, 0.5), Color(1, 0.7, 0.35, 0.18), Color(1, 0.7, 0.35, 0)])
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 64
		_glow.height = 64

	func _draw() -> void:
		var w := size.x
		var h := size.y
		# Duas fileiras (16×16 ×2) marchando para a esquerda, rumo ao torii: a de trás na
		# penumbra, a da frente na luz das lanternas. Folha dir4: coluna 2 = esquerda.
		var rows := [[h - 76.0, 0.55, [1, 4, 7, 9]], [h - 46.0, 1.0, [0, 2, 3, 5]]]
		for r: int in range(rows.size()):
			var row: Array = rows[r]
			var y: float = row[0]
			var lit: float = row[1]
			var ids: Array = row[2]
			for k: int in range(ids.size()):
				var tex := _sheets[int(ids[k]) % _sheets.size()]
				if tex == null:
					continue
				var x := roundf(w - 44.0 - k * 36.0 - r * 18.0)
				var bob := float((k + r) % 2) * 2.0
				var src := Rect2(32, 16 * ((k + r) % 4), 16, 16)
				draw_texture_rect(_glow, Rect2(x - 6, y + 22, 44, 14), false, Color(0, 0, 0, 0.55))
				draw_texture_rect(_glow, Rect2(x - 14, y - 10, 60, 52), false, Color(1, 0.75, 0.45, 0.5 * lit))
				draw_texture_rect_region(tex, Rect2(x, y - bob, 32, 32), src, Color(lit, lit * 0.94, lit))


# --- Capturas ---------------------------------------------------------------------------

func _make_screens() -> void:
	if captures_dir.is_empty():
		push_error("make_store_art: falta --captures=DIR (rode tools/store_capture.tscn antes)")
		return
	for lang: String in LANGS:
		var src_dir := captures_dir.path_join(LANGS[lang])
		var n := 0
		for shot: Dictionary in SHOTS:
			n += 1
			var raw := Image.load_from_file(src_dir.path_join(String(shot["id"]) + ".png"))
			if raw == null:
				push_error("make_store_art: falta a captura %s/%s" % [src_dir, shot["id"]])
				continue
			raw.convert(Image.FORMAT_RGB8)
			if raw.get_size() != NATIVE:
				push_error("make_store_art: %s tem %s (esperado %s, a tela real do jogo)" % [shot["id"], raw.get_size(), NATIVE])
				continue
			var name := "%02d_%s.png" % [n, shot["id"]]
			# Referência (não enviar: 2,22:1 passa do limite de 2:1 da Play).
			_save(_scaled(raw, 2), "screenshots/raw/%s/%s" % [LANG_DIRS[lang], name])
			var text: Array = shot[lang]
			_save(await _framed(raw, PHONE, text), "screenshots/%s/%s" % [LANG_DIRS[lang], name])
			if String(shot["id"]) in TABLET:
				var t := TABLET.find(String(shot["id"])) + 1
				var tname := "%02d_%s.png" % [t, shot["id"]]
				var framed := await _framed(raw, TABLET_LAYOUT, text)
				for inch: String in ["7in", "10in"]:
					_save(framed, "tablet/%s/%s/%s" % [inch, LANG_DIRS[lang], tname])
		for id: String in EXTRA_RAW:
			var extra := Image.load_from_file(src_dir.path_join(id + ".png"))
			if extra:
				extra.convert(Image.FORMAT_RGB8)
				_save(_scaled(extra, 2), "screenshots/raw/%s/extra_%s.png" % [LANG_DIRS[lang], id])


## Captura com legenda em 16:9. O quadro inteiro é composto em 640×360 lógicos ×k (fundo e
## legenda); a captura, na tela real do jogo (678×305), entra ×m no painel com moldura
## dourada. Telefone: k = 3, m = 2 (1356×610 em 1920×1080). Tablet: k = 4, m = 3 (2034×915
## em 2560×1440). Embaixo do painel, o desfile de yōkai do jogo passa diante da guardiã.
func _framed(raw: Image, layout: Dictionary, text: Array) -> Image:
	var k: int = layout["k"]
	var m: int = layout["m"]
	var top: int = layout["top"]
	var w := CANVAS.x * k
	# Fundo: céu noturno do menu (pontilhado), estrelas, colinas e o desfile.
	var bg := Image.create_empty(CANVAS.x, CANVAS.y, false, Image.FORMAT_RGBA8)
	_sky(bg)
	# Sem estrelas atrás do texto da legenda.
	_stars(bg, 1234, 80, Rect2i(110, 14, CANVAS.x - 220, top / k - 14))
	_hills(bg)
	_glow(bg, Vector2i(CANVAS.x / 2, CANVAS.y - 30), 260, WARM, 0.18)
	_parade(bg, CANVAS.y - 8)
	var canvas := _scaled(bg, k)
	canvas.convert(Image.FORMAT_RGBA8)
	var shot := _scaled(raw, m)
	shot.convert(Image.FORMAT_RGBA8)
	var at := Vector2i((w - shot.get_width()) / 2, top)
	# Moldura: sombra, filete dourado e laca escura (cantos chanfrados).
	var frame := Rect2i(at - Vector2i(k * 2, k * 2), shot.get_size() + Vector2i(k * 4, k * 4))
	canvas.fill_rect(Rect2i(frame.position + Vector2i(k, k * 2), frame.size), Color(0, 0, 0))
	_bevel_rect(canvas, frame, GOLD, k)
	_bevel_rect(canvas, frame.grow(-k), Color("1d110c"), k)
	canvas.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), at)
	var caption := await _caption(String(text[0]), String(text[1]), Vector2i(CANVAS.x, top / k - 4))
	var big := _scaled(caption, k)
	canvas.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i.ZERO)
	return canvas


## Desfile na faixa de baixo (pés em `feet`): a guardiã com a lanterna à esquerda, de frente
## para a fila de yōkai que vem da direita (folhas dir4 do Ninja Adventure, ×1 lógico).
static func _parade(img: Image, feet: int) -> void:
	var aki := _asset("res://assets/art/actors/heroes/aki/SpriteSheet.png").get_region(Rect2i(48, 0, 16, 16))
	_glow(img, Vector2i(30, feet - 8), 22, WARM, 0.5)
	img.blend_rect(aki, Rect2i(0, 0, 16, 16), Vector2i(20, feet - 16))
	var lamp := _lantern()
	img.blend_rect(lamp, Rect2i(Vector2i.ZERO, lamp.get_size()), Vector2i(36, feet - 17))
	var x := 70
	var i := 0
	while x < CANVAS.x - 12:
		var id: String = PARADE[i % PARADE.size()]
		var sheet := _asset("res://assets/art/actors/enemies/%s/SpriteSheet.png" % id)
		var frame := sheet.get_region(Rect2i(32, 16 * (i % 2), 16, 16))
		# Na penumbra: só a luz da lanterna e das hitodama.
		for py: int in range(16):
			for px: int in range(16):
				var c := frame.get_pixel(px, py)
				if c.a > 0.0:
					frame.set_pixel(px, py, Color(c.r * 0.62, c.g * 0.58, c.b * 0.72, c.a))
		var y := feet - 16 - (i % 2)
		img.blend_rect(frame, Rect2i(0, 0, 16, 16), Vector2i(x, y))
		if i % 3 == 1:
			_disc(img, Vector2i(x + 8, y - 6), 1, Color(0.75, 0.9, 1.0, 0.9))
		x += 22 + (i * 7) % 9
		i += 1


static func _bevel_rect(img: Image, r: Rect2i, color: Color, k: int) -> void:
	img.fill_rect(Rect2i(r.position + Vector2i(k, 0), Vector2i(r.size.x - 2 * k, r.size.y)), color)
	img.fill_rect(Rect2i(r.position + Vector2i(0, k), Vector2i(r.size.x, r.size.y - 2 * k)), color)


## Legenda em resolução lógica (transparente): título em 24 px e linha de apoio em 12 px,
## com os filetes e o losango dos títulos do jogo.
func _caption(head: String, sub: String, size: Vector2i) -> Image:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size = Vector2(size)
	vp.add_child(col)
	var title := _label(head, 24, ACCENT, 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.add_theme_constant_override("shadow_outline_size", 6)
	col.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.add_child(_rule())
	var line := _label(sub, 12, MUTED, 3)
	row.add_child(line)
	row.add_child(_rule())
	col.add_child(row)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _rule() -> Control:
	var holder := CenterContainer.new()
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var line := ColorRect.new()
	line.color = Color(ACCENT, 0.55)
	line.custom_minimum_size = Vector2(22, 1)
	box.add_child(line)
	holder.add_child(box)
	return holder
