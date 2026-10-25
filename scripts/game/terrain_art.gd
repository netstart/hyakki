class_name TerrainArt
extends RefCounted
## Arte do terreno montada uma vez por partida (data/biomes.json):
##   - atlas de materiais do chão (6 linhas de 128x80 px: 8 variações de 16 px ou um bloco);
##   - atlas de decoração: todos os sprites do catálogo usados pelo bioma, recortados justos,
##     mais os gerados aqui (tufos de grama na paleta do bioma, sombras suave e dura);
##   - textura de halo (gradiente radial) para as luzes.
## Tudo vem dos tilesets do Ninja Adventure já no jogo (CC0) ou é desenhado aqui.

const TILE := 16
const SLOT_W := 128
const SLOT_H := 80
const MATERIALS := 6
const ATLAS_W := 512
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
## Sprites desenhados aqui (não estão no catálogo de data/biomes.json).
const GENERATED := ["gen_tuft_a", "gen_tuft_b", "gen_tuft_c", "shadow_soft", "shadow_hard", "gen_step",
		"gen_bamboo_a", "gen_bamboo_b", "gen_bamboo_c"]

static var _data: Dictionary = {}
static var _images: Dictionary = {}
static var _halo: Texture2D

## Atlas do chão e informações por material (para os uniforms do shader).
var materials_texture: ImageTexture
var mat_info: PackedVector4Array = []
var mat_tint: PackedVector4Array = []
var lava_slot: int = -1
## Atlas da decoração e o retângulo (px) de cada sprite.
var decor_texture: ImageTexture
var regions: Dictionary = {}


## Conteúdo de data/biomes.json (cacheado).
static func data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open("res://data/biomes.json", FileAccess.READ)
		if file != null:
			_data = JSON.parse_string(file.get_as_text())
	return _data


static func biome(id: String) -> Dictionary:
	var biomes: Dictionary = data().get("biomes", {})
	return biomes.get(id, biomes.get("village", {}))


## Tamanho aproximado (px) de um sprite do catálogo, sem abrir imagem (usado pelo layout).
static func sprite_size(sprite_name: String) -> Vector2:
	var entry: Array = (data().get("sprites", {}) as Dictionary).get(sprite_name, [])
	if entry.size() == 5:
		return Vector2(float(entry[3]) * TILE, float(entry[4]) * TILE)
	if sprite_name.begins_with("gen_bamboo"):
		return Vector2(15, 60)
	if sprite_name == "gen_step":
		return Vector2(48, 6)
	return Vector2(10, 8)


## Gradiente radial (64x64) usado pelos halos das luzes.
static func halo_texture() -> Texture2D:
	if _halo == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_halo = tex
	return _halo


static func tileset_image(tileset: String) -> Image:
	if not _images.has(tileset):
		var tex := load(TILESETS.get(tileset, TILESETS["floor"])) as Texture2D
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		_images[tileset] = img
	return _images[tileset]


func build(biome_data: Dictionary) -> void:
	_build_materials(biome_data.get("materials", []))
	_build_decor(biome_data)


# --- Chão ---------------------------------------------------------------------------

func _build_materials(mats: Array) -> void:
	var img := Image.create(SLOT_W, SLOT_H * MATERIALS, false, Image.FORMAT_RGBA8)
	mat_info.clear()
	mat_tint.clear()
	lava_slot = -1
	for k: int in range(MATERIALS):
		var m: Dictionary = mats[k] if k < mats.size() else (mats[0] if not mats.is_empty() else {})
		var y := k * SLOT_H
		var tint := Color(String(m.get("tint", "#ffffff")))
		var flags := (1.0 if bool(m.get("flip", false)) else 0.0) + (2.0 if bool(m.get("mono", false)) else 0.0)
		mat_tint.append(Vector4(tint.r, tint.g, tint.b, flags))
		if bool(m.get("lava", false)):
			lava_slot = k
			mat_info.append(Vector4(y, 1, 1, 1))
			continue
		var src := tileset_image(String(m.get("tileset", "floor")))
		if m.has("block"):
			var b: Array = m["block"]
			var bw := mini(int(b[2]), 5)
			var bh := mini(int(b[3]), 5)
			img.blit_rect(src, Rect2i(int(b[0]) * TILE, int(b[1]) * TILE, bw * TILE, bh * TILE), Vector2i(0, y))
			mat_info.append(Vector4(y, 0, bw, bh))
			continue
		# Variações repetidas na proporção dos pesos: o shader sorteia uma das 8 por célula.
		var slots := _weighted_slots(m.get("tiles", [[0, 12, 1]]), 8)
		for v: int in range(slots.size()):
			var t: Array = slots[v]
			img.blit_rect(src, Rect2i(int(t[0]) * TILE, int(t[1]) * TILE, TILE, TILE), Vector2i(v * TILE, y))
		mat_info.append(Vector4(y, slots.size(), 1, 1))
	materials_texture = ImageTexture.create_from_image(img)


static func _weighted_slots(tiles: Array, count: int) -> Array:
	var total := 0.0
	for t: Array in tiles:
		total += maxf(0.0, float(t[2]) if t.size() > 2 else 1.0)
	var out: Array = []
	var acc := 0.0
	for t: Array in tiles:
		acc += maxf(0.0, float(t[2]) if t.size() > 2 else 1.0)
		var want := roundi(acc / maxf(total, 0.001) * count)
		while out.size() < want:
			out.append(t)
	if out.is_empty():
		out.append(tiles[0])
	return out


# --- Decoração -------------------------------------------------------------------------

func _build_decor(biome_data: Dictionary) -> void:
	var catalog: Dictionary = data().get("sprites", {})
	var images: Dictionary = {}
	for sprite_name: String in catalog:
		var e: Array = catalog[sprite_name]
		var src := tileset_image(String(e[0]))
		var rect := Rect2i(int(e[1]) * TILE, int(e[2]) * TILE, int(e[3]) * TILE, int(e[4]) * TILE)
		rect = rect.intersection(Rect2i(Vector2i.ZERO, src.get_size()))
		var region := src.get_region(rect)
		var used := region.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			region = region.get_region(used)
		images[sprite_name] = region
	var tufts: Array = biome_data.get("tufts", ["#3d6b2c", "#5f9a38", "#9cc94c"])
	images["gen_tuft_a"] = _tuft(tufts, 9, 9, 5, 11)
	images["gen_tuft_b"] = _tuft(tufts, 12, 10, 7, 23)
	images["gen_tuft_c"] = _tuft(tufts, 7, 7, 4, 37)
	images["shadow_soft"] = _shadow(true)
	images["shadow_hard"] = _shadow(false)
	images["gen_bamboo_a"] = _bamboo(76, 3)
	images["gen_bamboo_b"] = _bamboo(62, 7)
	images["gen_bamboo_c"] = _bamboo(88, 13)
	images["gen_step"] = _step(Color(String(biome_data.get("step", "#a8a49a"))))
	# Empacota em prateleiras, do mais alto para o mais baixo.
	var names: Array = images.keys()
	names.sort_custom(func(a: String, b: String) -> bool:
			return (images[a] as Image).get_height() > (images[b] as Image).get_height())
	var x := 0
	var y := 0
	var shelf := 0
	var places: Dictionary = {}
	for sprite_name: String in names:
		var im: Image = images[sprite_name]
		if x + im.get_width() + 1 > ATLAS_W:
			x = 0
			y += shelf + 1
			shelf = 0
		places[sprite_name] = Vector2i(x, y)
		x += im.get_width() + 1
		shelf = maxi(shelf, im.get_height())
	var height := nearest_po2(y + shelf + 1)
	var atlas := Image.create(ATLAS_W, height, false, Image.FORMAT_RGBA8)
	regions.clear()
	for sprite_name: String in names:
		var im: Image = images[sprite_name]
		var at: Vector2i = places[sprite_name]
		atlas.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), at)
		regions[sprite_name] = Rect2(Vector2(at), Vector2(im.get_size()))
	decor_texture = ImageTexture.create_from_image(atlas)


## Tufo de grama em pixel art: folhas finas em leque com 3 tons do bioma e ponta clara.
static func _tuft(colors: Array, w: int, h: int, blades: int, salt: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var dark := Color(String(colors[0]))
	var mid := Color(String(colors[1]))
	var light := Color(String(colors[2]))
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	for b: int in range(blades):
		var base_x := float(w) * 0.5 + rng.randf_range(-w * 0.22, w * 0.22)
		var lean := (float(b) / maxf(1.0, blades - 1.0) - 0.5) * 2.0 * rng.randf_range(0.5, 1.0)
		var tall := rng.randi_range(int(h * 0.55), h)
		for s: int in range(tall):
			var k := float(s) / float(tall)
			var px := int(round(base_x + lean * k * k * float(w) * 0.42))
			var py := h - 1 - s
			if px < 0 or px >= w:
				continue
			var c := dark if k < 0.3 else (mid if k < 0.75 else light)
			img.set_pixel(px, py, c)
	# Contorno escuro de 1 px na base, como os sprites do pacote.
	for px: int in range(1, w - 1):
		if img.get_pixel(px, h - 1).a > 0.0:
			img.set_pixel(px, h - 1, dark.darkened(0.35))
	return img


## Sombra elíptica 32x12: suave (degradê) ou dura (2 tons de pixel art).
static func _shadow(soft: bool) -> Image:
	var w := 32
	var h := 12
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for py: int in range(h):
		for px: int in range(w):
			var dx := (float(px) + 0.5 - w * 0.5) / (w * 0.5)
			var dy := (float(py) + 0.5 - h * 0.5) / (h * 0.5)
			var d := sqrt(dx * dx + dy * dy)
			var a := 0.0
			if soft:
				a = clampf(1.0 - d, 0.0, 1.0)
				a = a * a * (3.0 - 2.0 * a)
			elif d < 0.72:
				a = 1.0
			elif d < 1.0:
				a = 0.55
			img.set_pixel(px, py, Color(0, 0, 0, a))
	return img


## Degrau de pedra (48x6) para escadarias: aresta clara, face e sombra embaixo.
static func _step(stone: Color) -> Image:
	var w := 48
	var img := Image.create(w, 6, false, Image.FORMAT_RGBA8)
	for px: int in range(w):
		var edge := px == 0 or px == w - 1
		img.set_pixel(px, 0, stone.lightened(0.35) if not edge else stone.darkened(0.3))
		img.set_pixel(px, 1, stone.lightened(0.12))
		img.set_pixel(px, 2, stone if px % 11 != 0 else stone.darkened(0.2))
		img.set_pixel(px, 3, stone.darkened(0.18))
		img.set_pixel(px, 4, Color(0, 0, 0, 0.5))
		img.set_pixel(px, 5, Color(0, 0, 0, 0.22))
	return img


## Colmo de bambu alto (pixel art): caule de 3 px com nós, folhas finas em leque no alto e
## alguns ramos nos nós. 15 px de largura.
static func _bamboo(h: int, salt: int) -> Image:
	var w := 15
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var outline := Color("#1b2e1a")
	var dark := Color("#3f7a33")
	var mid := Color("#6aa845")
	var light := Color("#a7d46a")
	var leaf_dark := Color("#2d5e2c")
	var leaf := Color("#4e9440")
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var cx := 7
	var node := rng.randi_range(9, 13)
	for y: int in range(h):
		img.set_pixel(cx - 2, y, outline)
		img.set_pixel(cx - 1, y, dark)
		img.set_pixel(cx, y, mid)
		img.set_pixel(cx + 1, y, light if y % 5 != 0 else mid)
		img.set_pixel(cx + 2, y, outline)
		if (h - y) % node == 0 and y < h - 3:
			for x: int in range(cx - 2, cx + 3):
				img.set_pixel(x, y, outline)
			img.set_pixel(cx, y + 1, light)
	# Folhas: pinceladas inclinadas saindo dos nós de cima.
	var tufts := rng.randi_range(4, 6)
	for t: int in range(tufts):
		var y0 := rng.randi_range(0, int(h * 0.45))
		var side := -1 if t % 2 == 0 else 1
		var length := rng.randi_range(4, 7)
		for k: int in range(length):
			var x := cx + side * (2 + k)
			var y := y0 + k / 2 + (1 if side > 0 else 0)
			if x < 0 or x >= w or y >= h:
				continue
			img.set_pixel(x, y, leaf if k < length - 1 else leaf_dark)
			if y + 1 < h:
				img.set_pixel(x, y + 1, leaf_dark)
	return img
