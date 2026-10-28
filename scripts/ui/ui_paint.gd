class_name UiPaint
extends RefCounted
## Pincéis das telas de nova habilidade e baú, na linguagem das telas reformuladas (pausa,
## título, créditos): laca escura, filete dourado, cantoneiras, selo vermelho com kanji
## (fonte japonesa em qualquer idioma), texto pixel com contorno e glifos desenhados em
## pixels (sem ícones serrilhados por escala).

const GOLD := Color("d9a441")
const GOLD_HI := Color("ffe08a")
const VERMILION := Color("b23a26")
const SEAL_RED := Color("b3261e")
const SEAL_TEXT := Color("fbe6cf")
const PAPER := Color("fff1d6")
const DIM := Color(0.8, 0.76, 0.72)
const JADE := Color("9fe0a8")
const INK := Color(0.04, 0.032, 0.08, 0.92)
const OUTLINE := Color(0.1, 0.04, 0.04)
## Caixa do cadeado de padlock() (largura, altura).
const PADLOCK_SIZE := Vector2(7, 9)
const JA_FONT := "res://assets/fonts/fusion_pixel_12_ja.woff2"
## Números de melhoria (+5, -8%, +1,5) que ganham destaque na descrição.
const NUMBER_PATTERN := "[+\\-−]?\\d+(?:[.,]\\d+)?%?"

static var _ja: Font
static var _number_regex: RegEx


static func ja_font() -> Font:
	if _ja == null:
		_ja = load(JA_FONT) as Font if ResourceLoader.exists(JA_FONT) else Locale.font
	return _ja


## Texto com contorno, na base `at` (linha de base), alinhado em `width` se > 0.
static func text(ci: CanvasItem, at: Vector2, value: String, font_size: int = 12, color: Color = PAPER,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0,
		outline: int = 3, outline_color: Color = OUTLINE, font: Font = null) -> void:
	var f := font if font != null else Locale.font
	var p := at.round()
	if outline > 0:
		ci.draw_string_outline(f, p, value, align, width, font_size, outline, Color(outline_color, color.a))
	ci.draw_string(f, p, value, align, width, font_size, color)


static func text_width(value: String, font_size: int = 12, font: Font = null) -> float:
	var f := font if font != null else Locale.font
	return f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Selo vermelho (hanko) com kanji, centrado em `center`; `tilt` em radianos.
static func seal(ci: CanvasItem, center: Vector2, kanji: String, side: float = 15.0,
		fill: Color = SEAL_RED, ink: Color = SEAL_TEXT, tilt: float = 0.0, alpha: float = 1.0) -> void:
	ci.draw_set_transform(center.round(), tilt, Vector2.ONE)
	var half := floorf(side * 0.5)
	var r := Rect2(-half, -half, side, side)
	ci.draw_rect(r.grow(1.0), Color(fill.darkened(0.5), fill.a * alpha))
	ci.draw_rect(r, Color(fill, fill.a * alpha))
	ci.draw_rect(r.grow(-1.5), Color(ink, 0.35 * ink.a * alpha), false, 1.0)
	var f := ja_font()
	var font_size := 12 if side < 22.0 else 24
	var w := f.get_string_size(kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var asc := f.get_ascent(font_size)
	var h := f.get_height(font_size)
	ci.draw_string(f, Vector2(roundf(-w * 0.5), roundf(asc - h * 0.5)), kanji, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, Color(ink, ink.a * alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Retângulo com degradê vertical.
static func vgradient(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)]), PackedColorArray([top, top, bottom, bottom]))


## Cantoneiras douradas (L de `arm` pixels) nos quatro cantos de `r`.
static func corners(ci: CanvasItem, r: Rect2, color: Color, arm: float = 6.0) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x - 1.0
	var y1 := r.end.y - 1.0
	for c: Vector2 in [Vector2(x0, y0), Vector2(x1, y0), Vector2(x0, y1), Vector2(x1, y1)]:
		var sx := 1.0 if c.x <= x0 else -1.0
		var sy := 1.0 if c.y <= y0 else -1.0
		ci.draw_rect(Rect2(c.x if sx > 0 else c.x - arm + 1.0, c.y, arm, 1), color)
		ci.draw_rect(Rect2(c.x, c.y if sy > 0 else c.y - arm + 1.0, 1, arm), color)
		ci.draw_rect(Rect2(c + Vector2(sx, sy) * 2.0, Vector2.ONE), Color(color, color.a * 0.8))


## Fio dourado com losango vermelhão no meio (─── ◆ ───), mais forte perto do centro.
static func ornament(ci: CanvasItem, center: Vector2, reach: float, alpha: float = 1.0) -> void:
	var c := center.round()
	for i: int in range(int(reach)):
		var a := 0.9 * (1.0 - float(i) / reach) * alpha
		ci.draw_rect(Rect2(c.x - 6.0 - i, c.y, 1, 1), Color(GOLD, a))
		ci.draw_rect(Rect2(c.x + 6.0 + i, c.y, 1, 1), Color(GOLD, a))
	var d := PackedVector2Array([c + Vector2(0, -3), c + Vector2(3.5, 0.5), c + Vector2(0, 4), c + Vector2(-3.5, 0.5)])
	ci.draw_colored_polygon(d, Color(VERMILION, alpha))
	ci.draw_polyline(d + PackedVector2Array([d[0]]), Color(ThemeFactory.ACCENT, alpha), 1.0)


## Glifos de pixel (brancos; a cor vem de `color`) numa caixa de 12x12 com canto em `at`.
## "reroll" (setas em círculo), "skip" (avançar), "banish" (selo riscado), "coin" (moeda).
static func glyph(ci: CanvasItem, kind: String, at: Vector2, color: Color) -> void:
	var o := at.round()
	match kind:
		"reroll":
			ci.draw_arc(o + Vector2(6, 6), 4.5, 0.4, PI - 0.2, 12, color, 1.0)
			ci.draw_arc(o + Vector2(6, 6), 4.5, PI + 0.4, TAU - 0.2, 12, color, 1.0)
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(0, 5), o + Vector2(4, 5), o + Vector2(2, 8)]), color)
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(8, 7), o + Vector2(12, 7), o + Vector2(10, 4)]), color)
		"skip":
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(1, 2), o + Vector2(6, 6), o + Vector2(1, 10)]), color)
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(5, 2), o + Vector2(10, 6), o + Vector2(5, 10)]), color)
			ci.draw_rect(Rect2(o + Vector2(10, 2), Vector2(2, 9)), color)
		"banish":
			ci.draw_rect(Rect2(o + Vector2(1, 1), Vector2(10, 10)), color, false, 1.0)
			ci.draw_rect(Rect2(o + Vector2(3, 3), Vector2(6, 6)), Color(color, 0.35))
			ci.draw_line(o + Vector2(1, 11), o + Vector2(11, 1), color, 1.0)
		"coin":
			ci.draw_circle(o + Vector2(6, 6), 5.0, Color("8a5a12"))
			ci.draw_circle(o + Vector2(6, 6), 4.0, Color("f0c050"))
			ci.draw_rect(Rect2(o + Vector2(5, 4), Vector2(2, 4)), Color("8a5a12"))
			ci.draw_rect(Rect2(o + Vector2(4, 3), Vector2(1, 1)), Color(1, 1, 0.85))


## Cadeado de pixel numa caixa de PADLOCK_SIZE com canto em `at`: alça em arco, corpo cheio
## e o buraco da chave, com contorno. Marca o que está bloqueado até uma compra (ex.: velocidade
## 2x/3x sem a Ampulheta de Fūjin).
static func padlock(ci: CanvasItem, at: Vector2, color: Color, outline: Color = OUTLINE) -> void:
	var o := at.round()
	ci.draw_arc(o + Vector2(3.5, 4.0), 2.0, PI, TAU, 8, outline, 3.0)
	ci.draw_rect(Rect2(o + Vector2(0, 4), Vector2(7, 5)), outline)
	ci.draw_arc(o + Vector2(3.5, 4.0), 2.0, PI, TAU, 8, color, 1.0)
	ci.draw_rect(Rect2(o + Vector2(1, 5), Vector2(5, 3)), color)
	ci.draw_rect(Rect2(o + Vector2(3, 6), Vector2(1, 1)), outline)


## Põe um cadeado (escondido de início) logo depois do texto, na mesma linha: o texto passa
## para uma HBox no lugar dele. Devolve o controle do cadeado.
static func padlock_beside(text: Label, color: Color) -> Control:
	var parent := text.get_parent()
	var at := text.get_index()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.remove_child(text)
	row.add_child(text)
	var lock := Control.new()
	lock.name = "Padlock"
	lock.custom_minimum_size = PADLOCK_SIZE
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.visible = false
	lock.draw.connect(func() -> void: padlock(lock, Vector2.ZERO, color))
	row.add_child(lock)
	parent.add_child(row)
	parent.move_child(row, at)
	return lock


## Tremida de "negado" na horizontal (amplitude que cai até parar), voltando a x = 0.
static func shake_x(node: Control, amplitude: float = 3.0, time: float = 0.32) -> Tween:
	var tween := node.create_tween()
	for i: int in 4:
		var side := amplitude * (1.0 - i / 4.0) * (1.0 if i % 2 == 0 else -1.0)
		tween.tween_property(node, "position:x", roundf(side), time / 5.0)
	tween.tween_property(node, "position:x", 0.0, time / 5.0)
	return tween


## Texto pronto para RichTextLabel com os números destacados em `color` (BBCode seguro).
static func highlight_numbers(value: String, color: Color = JADE) -> String:
	if _number_regex == null:
		_number_regex = RegEx.create_from_string(NUMBER_PATTERN)
	var safe := value.replace("[", "[lb]")
	var out := ""
	var last := 0
	for m: RegExMatch in _number_regex.search_all(safe):
		out += safe.substr(last, m.get_start() - last)
		out += "[color=#%s]%s[/color]" % [color.to_html(false), m.get_string()]
		last = m.get_end()
	return out + safe.substr(last)
