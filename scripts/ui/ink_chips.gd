class_name InkChips
extends RefCounted
## Chips de tinta das páginas de papel (Diário do Guardião e Guia): o ícone 1:1 de um item
## dentro do texto, da altura da linha da fonte 12 (16 px) mais a moldura.
## - recipe_chip: miolo 16x16 do ícone de habilidade 24x24 com a moldura de 1 px do bisel dele
##   (cor da categoria: arma, relíquia, evolução, união, Kami, Santuário);
## - face_chip: os 16x16 centrais de um retrato (Faceset) com aro de tinta;
## - desconhecido (ou sem ícone): silhueta de papel escuro com "?" (as cores dos cartões do Diário).
## Texturas em cache por caminho e estado; geradas com as operações nativas de Image.
## add_ref escreve num RichTextLabel o chip e o nome do item num link só (meta {category, id}).

const CHIP := 18
const UNKNOWN_FILL := Color(0.3, 0.2, 0.13)
const UNKNOWN_RIM := Color(0.55, 0.38, 0.24)
const UNKNOWN_INK := Color("f0d9a8")
const FACE_RIM := Color("6b4a2a")
const QUESTION: Array[String] = [".###.", "#...#", "....#", "..##.", "..#..", ".....", "..#.."]

static var _cache: Dictionary = {}


## Textura do chip de um ícone de habilidade (em cache): conhecido, miolo 16x16 do ícone com a
## moldura do bisel dele e os cantos vazados; desconhecido (ou sem ícone), silhueta com "?".
static func recipe_chip(path: String, known: bool) -> Texture2D:
	var key := "r|%s|%s" % [path, known]
	if _cache.has(key):
		return _cache[key]
	var src := _image(path) if known else null
	var img := _unknown() if src == null else Image.create_empty(CHIP, CHIP, false, Image.FORMAT_RGBA8)
	if src != null:
		var last := CHIP - 1
		for y: int in CHIP:
			for x: int in CHIP:
				if (x == 0 or x == last) and (y == 0 or y == last):
					continue
				img.set_pixel(x, y, src.get_pixel(_chip_src(x, src.get_width()), _chip_src(y, src.get_height())))
	var out := ImageTexture.create_from_image(img)
	_cache[key] = out
	return out


## Retrato (Faceset) em chip: os 16x16 centrais com aro de tinta e cantos vazados; desconhecido,
## a mesma silhueta com "?" dos outros chips.
static func face_chip(path: String, known: bool) -> Texture2D:
	var key := "f|%s|%s" % [path, known]
	if _cache.has(key):
		return _cache[key]
	var src := _image(path) if known else null
	var img: Image
	if src == null:
		img = _unknown()
	else:
		var inner := CHIP - 2
		var at := Vector2i(maxi(0, (src.get_width() - inner) / 2), maxi(0, (src.get_height() - inner) / 2))
		var crop := src.get_region(Rect2i(at, Vector2i(mini(inner, src.get_width()), mini(inner, src.get_height()))))
		img = Image.create_empty(CHIP, CHIP, false, Image.FORMAT_RGBA8)
		img.fill(Color("f6ead0"))
		img.blend_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(1, 1))
		img.fill_rect(Rect2i(0, 0, CHIP, 1), FACE_RIM)
		img.fill_rect(Rect2i(0, CHIP - 1, CHIP, 1), FACE_RIM)
		img.fill_rect(Rect2i(0, 0, 1, CHIP), FACE_RIM)
		img.fill_rect(Rect2i(CHIP - 1, 0, 1, CHIP), FACE_RIM)
		for c: Vector2i in [Vector2i(0, 0), Vector2i(CHIP - 1, 0), Vector2i(0, CHIP - 1), Vector2i(CHIP - 1, CHIP - 1)]:
			img.set_pixelv(c, Color(0, 0, 0, 0))
	var out := ImageTexture.create_from_image(img)
	_cache[key] = out
	return out


## Ícone comum (itens do chão, baú) até 18 px de altura, sem moldura; desconhecido, o chip "?".
static func plain_icon(path: String, known: bool = true) -> Texture2D:
	if not known or not ResourceLoader.exists(path):
		return recipe_chip("", false)
	return load(path) as Texture2D


## Chip + nome do item num link só (meta {category, id}): ícone centrado na linha e o nome em
## tinta vermelha (marrom se desconhecido). `ref` = {category, id, known, icon, name} e, para
## retratos, "face": true.
static func add_ref(rtl: RichTextLabel, ref: Dictionary) -> void:
	var known := bool(ref["known"])
	var label := String(ref["name"])
	var linked := String(ref.get("category", "")) != ""
	if linked:
		rtl.push_meta({"category": ref["category"], "id": ref["id"]}, RichTextLabel.META_UNDERLINE_NEVER, label)
	var tex := face_chip(String(ref["icon"]), known) if bool(ref.get("face", false)) \
			else recipe_chip(String(ref["icon"]), known)
	rtl.add_image(tex, CHIP, CHIP, Color.WHITE, INLINE_ALIGNMENT_CENTER, Rect2(), null, false, label)
	rtl.push_color(ThemeFactory.RED_INK if known else ThemeFactory.PAPER_INK_SOFT)
	# Espaço fino inquebrável: o nome não se separa do ícone na quebra de linha.
	rtl.add_text(" " + label)
	rtl.pop()
	if linked:
		rtl.pop()


static func _image(path: String) -> Image:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	var src := tex.get_image() if tex != null else null
	if src == null:
		return null
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	return src


## Silhueta de papel escuro com "?" no meio.
static func _unknown() -> Image:
	var img := Image.create_empty(CHIP, CHIP, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(1, 0, CHIP - 2, CHIP), UNKNOWN_RIM)
	img.fill_rect(Rect2i(0, 1, CHIP, CHIP - 2), UNKNOWN_RIM)
	img.fill_rect(Rect2i(1, 1, CHIP - 2, CHIP - 2), UNKNOWN_FILL)
	var at := Vector2i((CHIP - QUESTION[0].length()) / 2, (CHIP - QUESTION.size()) / 2)
	for row: int in QUESTION.size():
		for col: int in QUESTION[row].length():
			if QUESTION[row][col] == "#":
				img.set_pixel(at.x + col, at.y + row, UNKNOWN_INK)
	return img


## Pixel do ícone (lado `side`, 24) para a coordenada `c` do chip: a borda pega o bisel (1 px
## para dentro da borda do ícone) e o miolo 1..16 pega os 16 pixels centrais (4..19).
static func _chip_src(c: int, side: int) -> int:
	if c == 0:
		return 1
	if c == CHIP - 1:
		return side - 2
	return clampi(c + (side - CHIP) / 2, 0, side - 1)
