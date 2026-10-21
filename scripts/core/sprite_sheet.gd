class_name SpriteSheet
extends RefCounted
## Recorte dos quadros das folhas do Ninja Adventure (plano 8.3).
## - "dir4": colunas = direção (baixo, cima, esquerda, direita), linhas = quadros (16×16).
## - "strip": quadros lado a lado numa linha; vira na horizontal para andar à esquerda.
## Também gera, uma vez por folha, as variantes "flash" (silhueta branca, 8.4) e
## "outline" (contorno dourado das elites), sem shader por inimigo.

enum Dir { DOWN, UP, LEFT, RIGHT }

static var _cache: Dictionary = {}

var texture: Texture2D
var flash_texture: Texture2D
var outline_texture: Texture2D
var layout: String = "dir4"
var frame_size := Vector2(16.0, 16.0)
var frames: int = 4
## Linha da folha onde começa a animação de andar (dir4).
var row_offset: int = 0
## true se o desenho original olha para a esquerda (só strip).
var faces_left: bool = false


static func load_sheet(path: String, p_layout: String = "dir4", size: Vector2 = Vector2(16, 16),
		p_frames: int = 0, p_faces_left: bool = false) -> SpriteSheet:
	var key := "%s|%s|%s|%d|%s" % [path, p_layout, size, p_frames, p_faces_left]
	if _cache.has(key):
		return _cache[key]
	var sheet := SpriteSheet.new()
	var image: Image = null
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		sheet.texture = tex
		image = tex.get_image()
	if image == null:
		push_error("SpriteSheet: não carregou " + path)
		image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color.MAGENTA)
		sheet.texture = ImageTexture.create_from_image(image)
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	sheet.layout = p_layout
	sheet.faces_left = p_faces_left
	if p_layout == "strip":
		if size.y <= 0.0:
			size.y = image.get_height()
		if size.x <= 0.0:
			size.x = size.y
	sheet.frame_size = size
	if p_frames > 0:
		sheet.frames = p_frames
	elif p_layout == "strip":
		sheet.frames = maxi(1, floori(image.get_width() / size.x))
	else:
		sheet.frames = mini(4, maxi(1, floori(image.get_height() / size.y)))
	sheet.flash_texture = ImageTexture.create_from_image(_silhouette(image, Color.WHITE))
	sheet.outline_texture = ImageTexture.create_from_image(_outline(image, Color("ffd166")))
	_cache[key] = sheet
	return sheet


func region(frame: int, dir: int) -> Rect2:
	var f := posmod(frame, frames)
	if layout == "dir4":
		return Rect2(Vector2(dir * frame_size.x, (f + row_offset) * frame_size.y), frame_size)
	return Rect2(Vector2(f * frame_size.x, 0.0), frame_size)


## Strip olha para um lado só: diz se precisa espelhar para a direção pedida.
func needs_flip(dir: int) -> bool:
	if layout == "dir4":
		return false
	var going_left := dir == Dir.LEFT
	return going_left != faces_left


static func dir_from_vector(v: Vector2, previous: int = Dir.DOWN) -> int:
	if v.length_squared() < 0.01:
		return previous
	if absf(v.x) > absf(v.y):
		return Dir.RIGHT if v.x > 0.0 else Dir.LEFT
	return Dir.DOWN if v.y > 0.0 else Dir.UP


static func _silhouette(source: Image, color: Color) -> Image:
	var out := Image.create_empty(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var a := source.get_pixel(x, y).a
			if a > 0.1:
				out.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	return out


## Cópia da folha com contorno de 1 px em volta das partes opacas.
static func _outline(source: Image, color: Color) -> Image:
	var w := source.get_width()
	var h := source.get_height()
	var out := source.duplicate() as Image
	for y: int in range(h):
		for x: int in range(w):
			if source.get_pixel(x, y).a > 0.1:
				continue
			var touches := false
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and source.get_pixel(nx, ny).a > 0.1:
					touches = true
					break
			if touches:
				out.set_pixel(x, y, color)
	return out
