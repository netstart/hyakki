class_name UiIcons
extends RefCounted
## Ícones de interface da Kenney ("Game Icons", CC0) em assets/art/ui/icons/kenney/.
## O original tem 50x50 e a tela tem 678x305 pixels lógicos: reduzir 50 → 14 com filtro
## "nearest" serrilha os traços. Aqui o ícone é reduzido uma vez por tamanho (Lanczos) e a
## borda é endurecida, ficando um ícone pixel art nítido no tamanho exato em que aparece.

const DIR := "res://assets/art/ui/icons/kenney/"
## Ícones de habilidade 24x24 (moldura própria), gerados por tools/gen_skill_icons.gd.
## Grupos: "weapons", "passives", "powerups", "kami". Caminho estável: <grupo>/<id>.png.
const SKILL_DIR := "res://assets/art/ui/skill_icons/"
const SKILL_SIZE := 24
## Abaixo disso o pixel some; acima, fica opaco (borda limpa, sem halo borrado).
const ALPHA_FLOOR := 0.22
const ALPHA_FULL := 0.62

static var _cache: Dictionary = {}


## Ícone `name` (sem extensão) reduzido para `px` x `px`; null se o arquivo não existir.
static func get_icon(name: String, px: int) -> Texture2D:
	var key := "%s@%d" % [name, px]
	if _cache.has(key):
		return _cache[key]
	var path := DIR + name + ".png"
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	var result: Texture2D = null
	if tex != null:
		var image := tex.get_image()
		if image != null and not image.is_empty():
			if image.is_compressed():
				image.decompress()
			image.convert(Image.FORMAT_RGBA8)
			image.resize(px, px, Image.INTERPOLATE_LANCZOS)
			_harden(image)
			result = ImageTexture.create_from_image(image)
	_cache[key] = result
	return result


## Endurece a borda: alfa baixo vira 0, alfa alto vira 1, o meio fica com um degrau só.
## O ícone é branco; a cor vem do modulate de quem desenha.
static func _harden(image: Image) -> void:
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var a := image.get_pixel(x, y).a
			var out := 0.0
			if a >= ALPHA_FULL:
				out = 1.0
			elif a >= ALPHA_FLOOR:
				out = 0.55
			image.set_pixel(x, y, Color(1, 1, 1, out))


## Caminho do ícone de habilidade `id` do grupo `group` ("weapons", "passives", "powerups", "kami").
static func skill_path(group: String, id: String) -> String:
	return "%s%s/%s.png" % [SKILL_DIR, group, id]


## Textura do ícone de habilidade (24x24, desenhar em escala inteira); null se não existir.
static func skill_icon(group: String, id: String) -> Texture2D:
	var path := skill_path(group, id)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
