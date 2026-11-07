class_name TerrainArt
extends RefCounted
## Arte do terreno montada uma vez por partida (data/biomes.json):
##   - atlas de materiais do chão (6 linhas de 256x80 px: 16 variações de 16 px ou um bloco), cada
##     variação de qualquer folha (um tile [x, y, peso, folha] sai de outra folha que a do material);
##   - atlas de decoração: todos os sprites do catálogo usados pelo bioma, recortados justos,
##     mais os gerados aqui (tufos de grama na paleta do bioma, sombras suave e dura);
##   - textura de halo (gradiente radial) para as luzes;
##   - ondulações animadas da água (4 quadros de 16 px do Water Ripples do pacote).
## Tudo vem dos tilesets do Ninja Adventure já no jogo (CC0) ou é desenhado aqui.

const TILE := 16
## Variações por material (o shader sorteia uma por célula, na proporção dos pesos).
const VARIATIONS := 16
const SLOT_W := VARIATIONS * TILE
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
	"field": "res://assets/art/tilesets/field.png",
	"water": "res://assets/art/tilesets/water.png",
	"relief_detail": "res://assets/art/tilesets/relief_detail.png",
	## Osorezan (恐山): cata-ventos, pilhas de pedras, sotoba, Jizō, rochas vulcânicas, enxofre e o
	## chão de cinza (tools/gen_osorezan_art.py, obra do projeto em CC0).
	"osorezan": "res://assets/art/tilesets/osorezan.png",
}
## Ondulações da água (Backgrounds/Animated/Water Ripples): 4 quadros de 16x16 lado a lado, no
## mesmo azul do miolo do TilesetWater.
const RIPPLES := "res://assets/art/tilesets/water_ripples.png"
const RIPPLE_FRAMES := 4
## Sprites desenhados aqui (não estão no catálogo de data/biomes.json).
const GENERATED := ["gen_tuft_a", "gen_tuft_b", "gen_tuft_c", "shadow_soft", "shadow_hard", "gen_step",
		"gen_bamboo_a", "gen_bamboo_b", "gen_bamboo_c", "gen_torii_side"]
## Torii visto de lado (caminhos leste-oeste do Tokoyo): largura, altura do pilar e deslocamento
## do pilar de trás (px); a altura total soma a distância entre os pés (TerrainLayout.TORII_SIDE_SPAN).
const TORII_SIDE_W := 26
const TORII_SIDE_TALL := 34
const TORII_SIDE_SHIFT := 12
## Bambu (gen_bamboo_*): recorte de 16x46 px do bambu do TilesetNature (canto em px) e as linhas de
## cada parte no recorte ([primeira, quantas]): copa com o 1º entrenó, nó, entrenó e pé.
const BAMBOO_W := 34
const BAMBOO_SRC := Vector2i(176, 128)
const BAMBOO_CROWN := 22
const BAMBOO_NODE := Vector2i(22, 5)
const BAMBOO_GAP := Vector2i(27, 8)
const BAMBOO_FOOT := Vector2i(35, 11)
## Cores do bambu do pacote: contorno, verde, luz e sombra.
const BAMBOO_PALETTE := {"c": Color("#141b1b"), "d": Color("#74a334"), "f": Color("#adbc3a"),
		"e": Color("#4a7f4b")}
## Colmo fino (gen_bamboo_b e _c): as 13 primeiras linhas do recorte (só a folhagem da copa) e o
## resto redesenhado com 7 px nas cores do pacote: nó (com o anel saliente), entrenó e pé.
const BAMBOO_SLIM_CROWN := 13
const BAMBOO_SLIM := {
	"node": [
		"...cdfdfdfdc....",
		"...cddffffdc....",
		"....cdfffdc.....",
		"....cedddec.....",
	],
	"gap": ["....cdffddc....."],
	"foot": [
		"...cdfdfdfdc....",
		"...cddffffdc....",
		"...cdedddedc....",
		"..cddffdddddc...",
		"..edffffdddde...",
		"...edfffddde....",
		"....edfddde.....",
		".....eddde......",
	],
}
## Raminhos com folhas (lado direito; a base do galho fica embaixo à esquerda).
const BAMBOO_SPRIGS := [
	[
		"...c.ccc.....",
		"..c.cffdcc...",
		".c..cdddddcc.",
		"c....cceeeddc",
		"c......ccccc.",
	],
	[
		"....cc.......",
		"...cfdc......",
		"..ccdcccc....",
		".c.cffdddcc..",
		"c...cdddeeec.",
		"c....ccccccc.",
	],
]

static var _data: Dictionary = {}
static var _images: Dictionary = {}
static var _halo: Texture2D

## Atlas do chão e informações por material (para os uniforms do shader).
var materials_texture: ImageTexture
var mat_info: PackedVector4Array = []
var mat_tint: PackedVector4Array = []
var lava_slot: int = -1
## Material de água espelhada (material com "water": true; -1 = nenhum) e a cor do brilho dela.
var water_slot: int = -1
var water_glint := Color.WHITE
## Fração das células da água com a ondulação animada (material "ripple"; 0 = nenhuma).
var water_ripple := 0.0
## Barranco da margem (material "bank": [cor, força]; alfa 0 = sem barranco): a faixa de terra de
## 2 px por fora da água, como no autotile de margem do TilesetWater.
var water_bank := Color(0, 0, 0, 0)
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
		# Pegada do colmo no layout (a do desenho antigo): o sprite é mais largo só pelos raminhos.
		return Vector2(15, 60)
	if sprite_name == "gen_step":
		return Vector2(48, 6)
	if sprite_name == "gen_torii_side":
		return Vector2(TORII_SIDE_W, torii_side_height())
	return Vector2(10, 8)


static func torii_side_height() -> int:
	return int(TerrainLayout.TORII_SIDE_SPAN) + TORII_SIDE_TALL + 10


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


## Quadros da ondulação da água (64x16).
static func ripples_texture() -> Texture2D:
	return load(RIPPLES) as Texture2D


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
	water_slot = -1
	water_ripple = 0.0
	water_bank = Color(0, 0, 0, 0)
	for k: int in range(MATERIALS):
		var m: Dictionary = mats[k] if k < mats.size() else (mats[0] if not mats.is_empty() else {})
		var y := k * SLOT_H
		var tint := Color(String(m.get("tint", "#ffffff")))
		var flags := (1.0 if bool(m.get("flip", false)) else 0.0) + (2.0 if bool(m.get("mono", false)) else 0.0)
		mat_tint.append(Vector4(tint.r, tint.g, tint.b, flags))
		if bool(m.get("water", false)):
			water_slot = k
			water_glint = Color(String(m.get("glint", "#ffffff")))
			water_ripple = clampf(float(m.get("ripple", 0.0)), 0.0, 1.0)
			var bank: Array = m.get("bank", [])
			if bank.size() == 2:
				water_bank = Color(String(bank[0]))
				water_bank.a = clampf(float(bank[1]), 0.0, 1.0)
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
		# Variações repetidas na proporção dos pesos: o shader sorteia uma das 16 por célula.
		var tiles: Array = m.get("tiles", [[0, 12, 1]])
		var slots := _weighted_slots(tiles, VARIATIONS)
		var base_tile: Array = tiles[0]
		var base_rect := Rect2i(int(base_tile[0]) * TILE, int(base_tile[1]) * TILE, TILE, TILE)
		for v: int in range(slots.size()):
			var t: Array = slots[v]
			var sheet := tileset_image(String(t[3])) if t.size() > 3 else src
			var rect := Rect2i(int(t[0]) * TILE, int(t[1]) * TILE, TILE, TILE)
			if t.size() > 4 and String(t[4]) == "recolor":
				# Desenho de outra folha nas cores do 1º tile do material (terra marrom sem par no
				# TilesetField: o pontilhado do campo pintado com os marrons da terra).
				img.blit_rect(recolored(sheet.get_region(rect), src.get_region(base_rect)), Rect2i(0, 0, TILE, TILE),
						Vector2i(v * TILE, y))
				continue
			img.blit_rect(sheet, rect, Vector2i(v * TILE, y))
		mat_info.append(Vector4(y, slots.size(), 1, 1))
	materials_texture = ImageTexture.create_from_image(img)


## `tile` com as cores trocadas pelas de `ref`, na ordem da luz: a cor mais escura de um vira a mais
## escura do outro e assim por diante (quantidades diferentes de cores se espalham por igual).
## Transparência mantida.
static func recolored(tile: Image, ref: Image) -> Image:
	var from := _colors_by_light(tile)
	var to := _colors_by_light(ref)
	var out := tile.duplicate() as Image
	if from.is_empty() or to.is_empty():
		return out
	var map: Dictionary = {}
	for i: int in range(from.size()):
		var j := roundi(float(i) * float(to.size() - 1) / float(maxi(1, from.size() - 1)))
		map[(from[i] as Color).to_rgba32()] = to[j]
	for py: int in range(out.get_height()):
		for px: int in range(out.get_width()):
			var c := out.get_pixel(px, py)
			if c.a > 0.0:
				var dst: Color = map.get(Color(c.r, c.g, c.b).to_rgba32(), c)
				out.set_pixel(px, py, Color(dst.r, dst.g, dst.b, c.a))
	return out


## Cores opacas distintas da imagem (sem o alfa), da mais escura para a mais clara.
static func _colors_by_light(img: Image) -> Array:
	var seen: Dictionary = {}
	for py: int in range(img.get_height()):
		for px: int in range(img.get_width()):
			var c := img.get_pixel(px, py)
			if c.a > 0.0:
				seen[Color(c.r, c.g, c.b).to_rgba32()] = Color(c.r, c.g, c.b)
	var out: Array = seen.values()
	out.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	return out


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
	images["gen_bamboo_b"] = _bamboo(62, 7, true)
	images["gen_bamboo_c"] = _bamboo(88, 13, true)
	images["gen_step"] = _step(Color(String(biome_data.get("step", "#a8a49a"))))
	images["gen_torii_side"] = _torii_side()
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


## Colmo de bambu alto emendado do bambu do TilesetNature (Ninja Adventure, 16x48 px em
## BAMBOO_SRC): a copa com o 1º entrenó, depois nó + entrenó repetidos até a altura pedida (cada
## entrenó com 6 a 11 px, sorteados pela semente, para os nós não ficarem alinhados entre colmos) e o
## pé com a touceira de raízes; nos nós de cima saem raminhos com folhas na paleta do pacote,
## alternando os lados (o de baixo da copa sempre). `slim`: o mesmo colmo redesenhado com 7 px
## (BAMBOO_SLIM, só a folhagem da copa vem do recorte), para os colmos de trás da touceira não
## virarem uma parede. BAMBOO_W px de largura, colmo no meio. O layout continua com a pegada antiga
## (sprite_size), então a posição e a colisão das touceiras não mudam.
static func _bamboo(h: int, salt: int, slim: bool = false) -> Image:
	var src := tileset_image("nature")
	var img := Image.create(BAMBOO_W, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var dx := (BAMBOO_W - TILE) / 2
	# Cada parte é uma lista de linhas: int = linha do recorte, String = linha desenhada (16 px).
	var crown: Array = range(BAMBOO_SLIM_CROWN if slim else BAMBOO_CROWN)
	var node: Array = BAMBOO_SLIM["node"] if slim else range(BAMBOO_NODE.x, BAMBOO_NODE.x + BAMBOO_NODE.y)
	var gap: Array = BAMBOO_SLIM["gap"] if slim else range(BAMBOO_GAP.x, BAMBOO_GAP.x + BAMBOO_GAP.y)
	var foot: Array = BAMBOO_SLIM["foot"] if slim else range(BAMBOO_FOOT.x, BAMBOO_FOOT.x + BAMBOO_FOOT.y)
	var room := h - crown.size() - foot.size()
	var period := node.size() + BAMBOO_GAP.y
	var count := maxi(1, roundi(float(room) / float(period)))
	var gaps: Array[int] = []
	gaps.resize(count)
	gaps.fill(BAMBOO_GAP.y)
	var extra := room - period * count
	var tries := 0
	while extra != 0 and tries < 200:
		tries += 1
		var i := rng.randi_range(0, count - 1)
		if extra > 0 and gaps[i] < 11:
			gaps[i] += 1
			extra -= 1
		elif extra < 0 and gaps[i] > 6:
			gaps[i] -= 1
			extra += 1
	var y := 0
	for r: Variant in crown:
		y = _bamboo_row(img, src, r, y, dx)
	var nodes: Array[int] = []
	for g: int in gaps:
		nodes.append(y)
		for r: Variant in node:
			y = _bamboo_row(img, src, r, y, dx)
		for k: int in range(g):
			y = _bamboo_row(img, src, gap[k % gap.size()], y, dx)
	for r: Variant in foot:
		y = _bamboo_row(img, src, r, y, dx)
	# Raminhos: logo abaixo da copa e nos nós (menos o de baixo), lados alternados.
	var side := 1 if rng.randf() < 0.5 else -1
	var tops: Array[int] = [crown.size() - (2 if slim else 8)]
	tops.append_array(nodes.slice(0, nodes.size() - 1))
	for i: int in range(tops.size()):
		if i == 0 or rng.randf() < 0.85:
			var x0 := dx + ((11 if slim else 13) if side > 0 else (4 if slim else 2))
			_bamboo_sprig(img, x0, tops[i] + 1, side, BAMBOO_SPRIGS[(i + salt) % BAMBOO_SPRIGS.size()])
		side = -side
	return img


## Linha `r` do colmo na linha `y` (se couber): int copia a linha do recorte, String desenha com
## BAMBOO_PALETTE. Devolve a próxima linha.
static func _bamboo_row(img: Image, src: Image, r: Variant, y: int, dx: int) -> int:
	if y >= img.get_height():
		return y + 1
	if r is String:
		var line := String(r)
		for i: int in range(line.length()):
			if line[i] != ".":
				img.set_pixel(dx + i, y, BAMBOO_PALETTE[line[i]])
	else:
		img.blend_rect(src, Rect2i(BAMBOO_SRC.x, BAMBOO_SRC.y + int(r), TILE, 1), Vector2i(dx, y))
	return y + 1


## Raminho com folhas (desenho do lado direito; `side` -1 espelha) com a base em (x0, y0).
static func _bamboo_sprig(img: Image, x0: int, y0: int, side: int, pattern: Array) -> void:
	var h := pattern.size()
	for j: int in range(h):
		var line := String(pattern[j])
		for i: int in range(line.length()):
			var key := line[i]
			if key == ".":
				continue
			var x := x0 + side * i
			var y := y0 - (h - 1) + j
			if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
				img.set_pixel(x, y, BAMBOO_PALETTE[key])


## Torii visto de lado em 3/4 (pixel art só com fill_rect): o pilar de trás mais alto e à direita,
## as duas vigas (kasagi escura com as pontas viradas e nuki vermelha) descendo em diagonal até o
## pilar da frente. A base do pilar da frente fica no meio de baixo do sprite.
static func _torii_side() -> Image:
	var w := TORII_SIDE_W
	var h := torii_side_height()
	var span := int(TerrainLayout.TORII_SIDE_SPAN)
	var tall := TORII_SIDE_TALL
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	# Paleta do torii de frente do TilesetHouse (o "torii" do catálogo): pilares e nuki vermelhos com
	# luz laranja, kasagi de madeira marrom com o veio escuro em cima, base marrom, contorno do pacote.
	var outline := Color("#141b1b")
	var red := Color("#e0394c")
	var lit := Color("#e66a3a")
	var dark_red := red.darkened(0.25)
	var wood := Color("#965340")
	var grain := Color("#61372e")
	var stone := wood
	var front_x := w / 2 - TORII_SIDE_SHIFT / 2
	var back_x := front_x + TORII_SIDE_SHIFT
	var front_base := h - 1
	var back_base := h - 1 - span
	# Pilar de trás (um tom mais escuro: está mais longe da luz).
	_torii_pillar(img, back_x, back_base, tall, outline, red.darkened(0.14), lit.darkened(0.18), dark_red, stone)
	# Nuki: travessa vermelha a 10 px do topo, em diagonal entre os pilares, passando um pouco deles.
	_torii_beam(img, back_x + 3, back_base - tall + 9, front_x - 3, front_base - tall + 9, 4, outline, red, lit)
	_torii_pillar(img, front_x, front_base, tall, outline, red, lit, dark_red, stone)
	# Kasagi: viga de madeira por cima (face marrom e veio escuro no topo), com as pontas viradas.
	_torii_beam(img, back_x + 5, back_base - tall - 4, front_x - 5, front_base - tall - 2, 5, outline, wood,
			wood.lightened(0.12))
	_torii_beam(img, back_x + 5, back_base - tall - 6, front_x - 5, front_base - tall - 4, 2, outline, grain, wood)
	for tip: Vector2i in [Vector2i(back_x + 6, back_base - tall - 8), Vector2i(front_x - 6, front_base - tall - 6)]:
		img.fill_rect(Rect2i(tip.x - 2, tip.y, 5, 3), outline)
		img.fill_rect(Rect2i(tip.x - 1, tip.y + 1, 3, 1), wood)
	return img


## Pilar do torii: contorno, face vermelha com luz à esquerda e sombra à direita, pé de pedra.
static func _torii_pillar(img: Image, cx: int, base: int, tall: int, outline: Color, red: Color, lit: Color,
		dark: Color, stone: Color) -> void:
	img.fill_rect(Rect2i(cx - 3, base - tall, 6, tall + 1), outline)
	img.fill_rect(Rect2i(cx - 2, base - tall + 1, 4, tall - 1), red)
	img.fill_rect(Rect2i(cx - 2, base - tall + 1, 1, tall - 1), lit)
	img.fill_rect(Rect2i(cx + 1, base - tall + 1, 1, tall - 1), dark)
	img.fill_rect(Rect2i(cx - 3, base - 3, 6, 4), outline)
	img.fill_rect(Rect2i(cx - 2, base - 2, 4, 2), stone)


## Viga em diagonal de (x0, y0) a (x1, y1): uma linha de `thick` px por fileira, com contorno.
static func _torii_beam(img: Image, x0: int, y0: int, x1: int, y1: int, thick: int, outline: Color, face: Color,
		lit: Color) -> void:
	var rows := maxi(1, y1 - y0)
	for y: int in range(y0 - 1, y1 + thick + 1):
		var t := clampf(float(y - y0 - thick * 0.5) / float(rows), 0.0, 1.0)
		var cx := roundi(lerpf(float(x0), float(x1), t))
		img.fill_rect(Rect2i(cx - 3, y, 7, 1), outline)
		if y >= y0 and y < y1 + thick:
			img.fill_rect(Rect2i(cx - 2, y, 5, 1), face)
			img.set_pixel(clampi(cx - 2, 0, img.get_width() - 1), y, lit)
