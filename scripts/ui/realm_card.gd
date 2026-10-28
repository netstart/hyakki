class_name RealmCard
extends Control
## Travessia para o Kakuriyo na HUD (criada pela Hud em realm_card(), conduzida pelo
## RiftPortal com o relógio parado, em tempo real):
## - entrada (RiftPortal.CROSS_IN): um redemoinho de tinta violeta fecha a tela num íris que
##   gira em volta do portal, com braços de espiral e almas sugadas;
## - título (CROSS_HOLD): com a tela fechada, o mundo é trocado por baixo; aparece a legenda
##   (隠世 e o "além do véu" traduzido), o nome do reino em kanji grande e o nome traduzido em
##   dourado entre filetes vermelhão;
## - saída (CROSS_OUT): o íris abre do centro (a guardiã) mostrando o outro mundo.
## Textos dentro da área segura (recorte da câmera); "Reduzir clarões" tira o clarão da troca e
## deixa o giro mais lento. Enquanto ativa, segura o toque (nada de pausa no meio).

const KANJI_SIZE := 36
const NAME_SIZE := 24
const SMALL_SIZE := 12
const REALM_GLYPHS := "隠世"
const GOLD := Color("ffd166")
const VERMILION := Color("c0392b")
const INK := Color("12061f")
const SWIRL := Color("b48cff")
const SWIRL_EDGE := Color("7ef0ff")
const JA_FONT := "res://assets/fonts/fusion_pixel_12_ja.woff2"
## Folga do texto até as bordas da área segura.
const MARGIN := 12.0

## Travessia em andamento (a Hud conta como tela sobreposta).
var active: bool = false
var kanji: String = ""
var title: String = ""
var caption: String = ""
## Ponto da tela onde o redemoinho fecha (o portal).
var origin := Vector2.ZERO
var t: float = 0.0

var _ja: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ja = load(JA_FONT) as Font


func begin(p_kanji: String, p_title: String, p_caption: String, at: Vector2) -> void:
	kanji = p_kanji
	title = p_title
	caption = p_caption
	origin = at
	t = 0.0
	active = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func set_time(value: float) -> void:
	t = value
	queue_redraw()


func close() -> void:
	active = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _font() -> Font:
	var locale := get_node_or_null(^"/root/Locale")
	return locale.get("font") if locale and locale.get("font") else ThemeDB.fallback_font


func _view() -> Vector2:
	return size if size.x > 1.0 else get_viewport_rect().size


## Retângulos do título na tela `view` com o recorte `insets` (esquerda, direita): "caption",
## "kanji", "name" e o tamanho da fonte do nome ("name_size": 24, ou 12 se não couber). Os testes
## de layout conferem; _draw desenha aqui.
func title_layout(view: Vector2, insets: Vector2) -> Dictionary:
	var font := _font()
	var ja := _ja if _ja != null else font
	var safe := Rect2(insets.x, 0.0, view.x - insets.x - insets.y, view.y)
	var cx := roundf(safe.get_center().x)
	var room := safe.size.x - MARGIN * 2.0
	var name_size := NAME_SIZE
	if font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x > room:
		name_size = SMALL_SIZE
	var cap_text := "%s · %s" % [REALM_GLYPHS, caption]
	var cap_w := ja.get_string_size(REALM_GLYPHS + " · ", HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE).x \
			+ font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE).x
	var kanji_w := ja.get_string_size(kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, KANJI_SIZE).x
	var name_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	var cap_h := font.get_height(SMALL_SIZE)
	var kanji_h := ja.get_height(KANJI_SIZE)
	var name_h := font.get_height(name_size)
	var total := cap_h + 6.0 + kanji_h + 4.0 + name_h
	var y := roundf(view.y * 0.5 - total * 0.5)
	var cap := Rect2(roundf(cx - cap_w * 0.5), y, cap_w, cap_h)
	y += cap_h + 6.0
	var big := Rect2(roundf(cx - kanji_w * 0.5), y, kanji_w, kanji_h)
	y += kanji_h + 4.0
	var name := Rect2(roundf(cx - name_w * 0.5), y, name_w, name_h)
	return {"caption": cap, "caption_text": cap_text, "kanji": big, "name": name, "name_size": name_size,
			"center_x": cx}


func _draw() -> void:
	if not active:
		return
	var view := _view()
	var cross_in := RiftPortal.CROSS_IN
	var hold := RiftPortal.CROSS_HOLD
	var cross_out := RiftPortal.CROSS_OUT
	var calm := _calm()
	var reach := view.length()
	# Íris: fecha em volta do portal, depois abre do centro (a guardiã nasce no meio da tela).
	var hole := 0.0
	var center := origin
	if t < cross_in:
		hole = reach * (1.0 - _ease(t / cross_in))
	elif t > cross_in + hold:
		hole = reach * _ease((t - cross_in - hold) / cross_out)
		center = view * 0.5
	if hole > 0.5:
		_draw_iris(center, hole, view)
		draw_arc(center, hole, 0.0, TAU, 48, Color(SWIRL_EDGE, 0.7), 2.0)
	else:
		draw_rect(Rect2(Vector2.ZERO, view), INK)
	_draw_spiral(center, hole, reach, calm)
	# Clarão curto na troca do mundo (sem ele com "Reduzir clarões").
	var flash := 1.0 - absf(t - cross_in) / 0.12
	if flash > 0.0 and not calm:
		draw_rect(Rect2(Vector2.ZERO, view), Color(0.85, 0.75, 1.0, 0.5 * flash))
	var text_a := clampf((t - cross_in + 0.1) / 0.25, 0.0, 1.0) * (1.0 - clampf((t - cross_in - hold) / 0.3, 0.0, 1.0))
	if text_a > 0.0:
		_draw_title(view, text_a)


## Tinta fora do íris: um anel de quadriláteros entre o furo e um raio além do canto mais longe
## da tela (um draw_arc largo demais deixa frestas nas emendas).
func _draw_iris(center: Vector2, hole: float, view: Vector2) -> void:
	var far := 0.0
	for corner: Vector2 in [Vector2.ZERO, Vector2(view.x, 0.0), view, Vector2(0.0, view.y)]:
		far = maxf(far, center.distance_to(corner))
	var outer := maxf(far, hole) + 8.0
	var steps := 48
	for k: int in steps:
		var a0 := TAU * k / steps
		var a1 := TAU * (k + 1) / steps
		var d0 := Vector2.from_angle(a0)
		var d1 := Vector2.from_angle(a1)
		draw_colored_polygon(PackedVector2Array([center + d0 * hole, center + d0 * outer, center + d1 * outer,
				center + d1 * hole]), INK)


## Braços de espiral girando sobre a tinta (fora do íris) e almas puxadas para o centro.
func _draw_spiral(center: Vector2, hole: float, reach: float, calm: bool) -> void:
	var spin := t * (2.0 if calm else 4.5)
	for arm: int in 5:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for s: int in 24:
			var k := float(s) / 23.0
			var r := lerpf(reach * 0.75, maxf(hole, 6.0), k)
			var a := spin + arm * TAU / 5.0 + k * 3.4
			pts.append(center + Vector2.from_angle(a) * r)
			cols.append(Color(SWIRL.lerp(SWIRL_EDGE, k), 0.12 + 0.5 * k))
		draw_polyline_colors(pts, cols, 2.0)
	for i: int in 18:
		var phase := fmod(t * 1.3 + float(i) / 18.0, 1.0)
		var r := lerpf(reach * 0.6, maxf(hole, 4.0), phase)
		var a := i * 2.399 - spin * 0.6 + phase * 2.0
		draw_circle((center + Vector2.from_angle(a) * r).round(), 1.0 + phase, Color(1.0, 0.95, 1.0, 0.25 + 0.6 * phase))


func _draw_title(view: Vector2, a: float) -> void:
	var font := _font()
	var ja := _ja if _ja != null else font
	var insets := MenuKit.safe_insets(self)
	var layout := title_layout(view, insets)
	var cap: Rect2 = layout["caption"]
	var glyphs := REALM_GLYPHS + " · "
	var gw := ja.get_string_size(glyphs, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE).x
	var base := cap.position.y + font.get_ascent(SMALL_SIZE)
	draw_string(ja, Vector2(cap.position.x, base), glyphs, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE, Color(SWIRL_EDGE, a))
	_shadowed(font, Vector2(cap.position.x + gw, base), caption, SMALL_SIZE, Color(0.85, 0.8, 1.0, a))
	var big: Rect2 = layout["kanji"]
	_shadowed(ja, Vector2(big.position.x, big.position.y + ja.get_ascent(KANJI_SIZE)), kanji, KANJI_SIZE,
			Color(1.0, 0.97, 0.94, a))
	var name: Rect2 = layout["name"]
	var size_px := int(layout["name_size"])
	_shadowed(font, Vector2(name.position.x, name.position.y + font.get_ascent(size_px)), title, size_px, Color(GOLD, a))
	# Filetes vermelhão dos dois lados do kanji, crescendo com o texto.
	var line_y := roundf(big.get_center().y)
	var reach := minf(60.0, (view.x - insets.x - insets.y) * 0.5 - big.size.x * 0.5 - MARGIN - 8.0) * a
	if reach > 2.0:
		var ink := Color(VERMILION, a)
		draw_line(Vector2(big.position.x - 8.0 - reach, line_y), Vector2(big.position.x - 8.0, line_y), ink, 1.0)
		draw_line(Vector2(big.end.x + 8.0, line_y), Vector2(big.end.x + 8.0 + reach, line_y), ink, 1.0)


func _shadowed(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var p := at.round()
	draw_string(font, p + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, color.a * 0.9))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _calm() -> bool:
	var settings := get_node_or_null(^"/root/Settings")
	return settings != null and bool(settings.call("get_value", "reduce_flashes"))


static func _ease(x: float) -> float:
	var k := clampf(x, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)
