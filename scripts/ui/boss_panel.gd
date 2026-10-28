class_name BossPanel
extends Control
## Painel do chefe na HUD (criado pela Hud em show_boss):
## - entrada cinematográfica: a tela escurece (Média/Alta), faixas de cinema (Alta), uma
##   pincelada de tinta sumi cruza a tela com o nome em kanji grande, o nome traduzido em
##   dourado e a fala do chefe; em Baixa só a faixa, sem escurecer (sem pós);
## - barra de vida: moldura laqueada, selo vermelho com o kanji, vida com brilho, rastro claro
##   do dano recente, marcas das fases e da fúria; enfurecido, a vida pulsa em brasa;
## - clarão branco (fases e morte), que respeita "reduzir clarões" (quem chama confere).
## Tudo em tempo real e só desenho.

const INTRO := 3.4
const REVEAL := 0.35
const OUT_FROM := 2.7
const BAR_W := 230.0
const BAR_H := 6.0
const BAR_Y := 33.0
const SEAL := 15.0
const LAG_DELAY := 0.45
const LAG_SPEED := 0.35
const INK := Color(0.04, 0.03, 0.05, 0.92)
const GOLD := Color("ffd166")
const VERMILION := Color("c0392b")
const HP := Color("e63946")
const JA_FONT := "res://assets/fonts/fusion_pixel_12_ja.woff2"

var hud: Node
var title: String = ""
var line: String = ""
var kanji: String = ""
var color := Color(0.75, 0.4, 1.0)
var marks: Array[float] = []
var invincible: bool = false
## Ideograma do selo vermelho da faixa de entrada ("鬼"; "門" no Guardião do Limiar).
var seal_glyph: String = "鬼"
var fraction: float = -1.0
var enraged: bool = false
## Segundos desde a entrada (testes leem para saber se a faixa está na tela).
var intro_t: float = INTRO

var _lag: float = 1.0
var _lag_wait: float = 0.0
var _hit: float = 0.0
var _flash: float = 0.0
var _ja: Font
var _font: Font
var _brush := PackedVector2Array()
var _splats: Array[Vector3] = []
## Riscos de pincel seco dentro da faixa: (início, fim, altura), em frações.
var _streaks: Array[Vector3] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ja = load(JA_FONT) as Font
	var locale := get_node_or_null(^"/root/Locale")
	_font = locale.get("font") if locale and locale.get("font") else ThemeDB.fallback_font
	if _ja == null:
		_ja = _font


func open(p_title: String, p_line: String, info: Dictionary) -> void:
	title = p_title
	line = p_line
	kanji = String(info.get("kanji", ""))
	color = info.get("color", color)
	marks.assign(info.get("marks", []))
	invincible = bool(info.get("invincible", false))
	seal_glyph = String(info.get("seal", "鬼"))
	fraction = 1.0
	_lag = 1.0
	enraged = false
	intro_t = 0.0
	visible = true
	_make_brush(hash(p_title))


func close() -> void:
	# O clarão da morte ainda termina; depois o painel some sozinho.
	fraction = -1.0
	intro_t = INTRO
	visible = _flash > 0.0


func intro_active() -> bool:
	return visible and intro_t < INTRO


func set_fraction(value: float, is_enraged: bool) -> void:
	if value < fraction - 0.0001:
		_hit = 0.15
		_lag_wait = LAG_DELAY
	fraction = value
	enraged = is_enraged


func flash(strength: float) -> void:
	_flash = maxf(_flash, strength)


## Pincelada irregular (sementes fixas por chefe): borda de cima e de baixo serrilhadas.
func _make_brush(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_brush.clear()
	var steps := 36
	# Perfil de pincel: grosso no meio, afinando nas pontas, com a borda serrilhada.
	for k: int in range(steps + 1):
		var x := float(k) / steps
		var taper := 0.35 + 0.65 * sin(minf(x * 1.25, 1.0) * PI * 0.5) * sin(minf((1.0 - x) * 4.0, 1.0) * PI * 0.5)
		_brush.append(Vector2(x, -taper + rng.randf_range(-0.14, 0.1)))
	for k: int in range(steps, -1, -1):
		var x := float(k) / steps
		var taper := 0.45 + 0.55 * sin(minf(x * 2.0, 1.0) * PI * 0.5) * sin(minf((1.0 - x) * 1.6, 1.0) * PI * 0.5)
		_brush.append(Vector2(x, taper + rng.randf_range(-0.1, 0.16)))
	_streaks.clear()
	for _k: int in range(7):
		_streaks.append(Vector3(rng.randf_range(0.05, 0.5), rng.randf_range(0.55, 0.95), rng.randf_range(-0.7, 0.7)))
	_splats.clear()
	for _k: int in range(14):
		_splats.append(Vector3(rng.randf(), rng.randf_range(-1.6, 1.6), rng.randf_range(0.8, 2.6)))


func _process(delta: float) -> void:
	if not visible:
		return
	intro_t = minf(INTRO, intro_t + delta)
	_hit = maxf(0.0, _hit - delta)
	_flash = maxf(0.0, _flash - delta * 2.5)
	if _lag_wait > 0.0:
		_lag_wait -= delta
	elif _lag > fraction:
		_lag = maxf(fraction, _lag - LAG_SPEED * delta)
	if _lag < fraction:
		_lag = fraction
	if fraction < 0.0 and intro_t >= INTRO and _flash <= 0.0:
		visible = false
		return
	if hud and hud.has_method("gameplay_alpha"):
		modulate.a = float(hud.call("gameplay_alpha"))
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var view := size if size.x > 1.0 else get_viewport_rect().size
	var level := GfxQuality.level()
	if intro_t < INTRO:
		_draw_intro(view, level)
	if fraction >= 0.0:
		_draw_bar(view)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, view), Color(1, 1, 1, minf(0.85, _flash)))


func _draw_intro(view: Vector2, level: int) -> void:
	var t := intro_t
	var fade_out := 1.0 - clampf((t - OUT_FROM) / (INTRO - OUT_FROM), 0.0, 1.0)
	var fade_in := clampf(t / 0.3, 0.0, 1.0)
	var k := fade_in * fade_out
	if level >= GfxQuality.MEDIUM:
		draw_rect(Rect2(Vector2.ZERO, view), Color(0.0, 0.0, 0.02, 0.42 * k))
	if level >= GfxQuality.HIGH:
		var bar := 22.0 * k
		draw_rect(Rect2(0, 0, view.x, bar), Color(0, 0, 0, 0.95))
		draw_rect(Rect2(0, view.y - bar, view.x, bar), Color(0, 0, 0, 0.95))
	# Pincelada: entra da esquerda em REVEAL s e some no fim.
	var center := Vector2(view.x * 0.5, view.y * 0.36)
	var half_h := 30.0
	var width := view.x * 0.86
	var reveal := clampf(t / REVEAL, 0.0, 1.0)
	var left := center.x - width * 0.5
	var poly := PackedVector2Array()
	for p: Vector2 in _brush:
		poly.append(Vector2(left + p.x * width * reveal, center.y + p.y * half_h))
	draw_colored_polygon(poly, Color(INK, INK.a * fade_out))
	if level >= GfxQuality.MEDIUM:
		for s: Vector3 in _streaks:
			var x1 := minf(s.y, reveal)
			if x1 > s.x:
				draw_line(Vector2(left + s.x * width, center.y + s.z * half_h),
						Vector2(left + x1 * width, center.y + s.z * half_h), Color(0.16, 0.14, 0.18, 0.7 * fade_out), 1.0)
	if level >= GfxQuality.HIGH:
		for s: Vector3 in _splats:
			if s.x <= reveal:
				draw_circle(Vector2(left + s.x * width, center.y + s.y * half_h), s.z, Color(INK, 0.8 * fade_out))
	# Filetes finos dentro da faixa: vermelhão embaixo, a cor do chefe em cima.
	var x0 := left + width * 0.14
	var x1 := left + width * minf(reveal, 0.86)
	if x1 > x0:
		draw_line(Vector2(x0, center.y + half_h * 0.62), Vector2(x1, center.y + half_h * 0.62),
				Color(VERMILION, 0.9 * fade_out), 1.0)
		draw_line(Vector2(x0, center.y - half_h * 0.62), Vector2(x1, center.y - half_h * 0.62),
				Color(color, 0.7 * fade_out), 1.0)
	if reveal < 1.0:
		return
	var text_a := clampf((t - REVEAL) / 0.3, 0.0, 1.0) * fade_out
	var y := center.y + 2.0
	if kanji != "":
		var big := 36
		var w := _ja.get_string_size(kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
		var kx := center.x - w * 0.5
		# Selo vermelho à direita do kanji, com o primeiro ideograma.
		var seal := Rect2(Vector2(kx + w + 6.0, y - 26.0), Vector2(16, 16))
		draw_string(_ja, Vector2(kx + 2.0, y + 2.0), kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(0, 0, 0, text_a))
		draw_string(_ja, Vector2(kx, y), kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(1.0, 0.97, 0.92, text_a))
		draw_rect(seal, Color(VERMILION, text_a))
		draw_rect(seal.grow(-1.0), Color(1, 0.8, 0.7, 0.35 * text_a), false, 1.0)
		draw_string(_ja, seal.position + Vector2(2, 13), seal_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
				Color(1.0, 0.95, 0.9, text_a))
		y += 16.0
	_centered(title, Vector2(center.x, y + 2.0), 12, Color(GOLD, text_a))
	var quote_a := clampf((t - REVEAL - 0.4) / 0.3, 0.0, 1.0) * fade_out
	_centered("“%s”" % line, Vector2(center.x, center.y + half_h + 14.0), 12, Color(1.0, 0.75, 0.75, quote_a))


func _centered(text: String, at: Vector2, font_size: int, c: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var p := Vector2(roundf(at.x - w * 0.5), roundf(at.y))
	draw_string(_font, p + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, c.a * 0.9))
	draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c)


func _draw_bar(view: Vector2) -> void:
	# Barra entra deslizando quando a faixa começa a sumir.
	var appear := clampf((intro_t - (OUT_FROM - 0.3)) / 0.4, 0.0, 1.0)
	if appear <= 0.0:
		return
	var time := Time.get_ticks_msec() / 1000.0
	var bar := Rect2(Vector2(roundf(view.x * 0.5 - BAR_W * 0.5 + SEAL * 0.5), BAR_Y - (1.0 - appear) * 12.0),
			Vector2(BAR_W, BAR_H))
	var a := appear
	var frame := bar.grow(2.0)
	draw_rect(frame.grow(1.0), Color(0, 0, 0, 0.75 * a))
	draw_rect(frame, Color(0.16, 0.05, 0.06, 0.95 * a))
	draw_rect(frame, Color(GOLD, (0.55 + 0.45 * _hit / 0.15) * a), false, 1.0)
	# Cantos dourados.
	for corner: Vector2 in [frame.position, Vector2(frame.end.x - 3, frame.position.y),
			Vector2(frame.position.x, frame.end.y - 3), frame.end - Vector2(3, 3)]:
		draw_rect(Rect2(corner, Vector2(3, 3)), Color(GOLD, a))
	draw_rect(bar, Color(0.05, 0.01, 0.02, a))
	var shown := 1.0 if invincible else fraction
	if _lag > shown:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * _lag, bar.size.y)), Color(1.0, 0.85, 0.7, 0.8 * a))
	var fill := HP
	if enraged:
		fill = HP.lerp(Color(1.0, 0.55, 0.1), 0.5 + 0.5 * sin(time * 10.0))
	if invincible:
		fill = Color(0.35, 0.3, 0.5)
	var w := roundf(bar.size.x * shown)
	draw_rect(Rect2(bar.position, Vector2(w, bar.size.y)), Color(fill, a))
	draw_rect(Rect2(bar.position, Vector2(w, 1.0)), Color(fill.lightened(0.45), a))
	draw_rect(Rect2(bar.position + Vector2(0, bar.size.y - 1.0), Vector2(w, 1.0)), Color(fill.darkened(0.4), a))
	if enraged:
		for k: int in range(int(w / 6.0)):
			var h := 1.0 + 2.0 * absf(sin(time * 9.0 + k * 1.7))
			draw_rect(Rect2(bar.position + Vector2(k * 6.0 + 2.0, -h), Vector2(2, h)), Color(1.0, 0.5, 0.1, 0.8 * a))
	for mark: float in marks:
		var x := roundf(bar.position.x + bar.size.x * mark)
		draw_rect(Rect2(Vector2(x, bar.position.y - 1.0), Vector2(1, bar.size.y + 2.0)), Color(GOLD, 0.9 * a))
	# Selo com o kanji (primeiro ideograma) à esquerda da barra.
	var seal := Rect2(Vector2(frame.position.x - SEAL - 3.0, bar.position.y + BAR_H * 0.5 - SEAL * 0.5),
			Vector2(SEAL, SEAL))
	draw_rect(seal.grow(1.0), Color(0, 0, 0, 0.8 * a))
	draw_rect(seal, Color(VERMILION if not enraged else Color(0.9, 0.2, 0.1), a))
	var glyph := kanji.substr(0, 1) if kanji != "" else "鬼"
	draw_string(_ja, seal.position + Vector2(1.5, 12.5), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(1.0, 0.95, 0.88, a))
	var label := title if kanji == "" else "%s  %s" % [kanji, title]
	_centered_mixed(label, Vector2(bar.position.x + bar.size.x * 0.5, bar.end.y + 13.0), Color(1, 0.93, 0.85, a))


## Nome sob a barra: o kanji na fonte japonesa e o nome traduzido na fonte do idioma.
func _centered_mixed(text: String, at: Vector2, c: Color) -> void:
	if kanji == "" or not text.begins_with(kanji):
		_centered(text, at, 12, c)
		return
	var rest := text.substr(kanji.length())
	var w1 := _ja.get_string_size(kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var w2 := _font.get_string_size(rest, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var x := roundf(at.x - (w1 + w2) * 0.5)
	draw_string(_ja, Vector2(x + 1, at.y + 1), kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, c.a))
	draw_string(_ja, Vector2(x, at.y), kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(GOLD, c.a))
	draw_string(_font, Vector2(x + w1 + 1, at.y + 1), rest, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, c.a))
	draw_string(_font, Vector2(x + w1, at.y), rest, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)
