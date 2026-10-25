class_name LevelCard
extends Button
## Carta de nova habilidade, no espírito de um ofuda/carta de tarô em laca:
## - moldura e cor por categoria (arma nova em vermelhão, melhoria em índigo, item em jade,
##   cura e ouro em tons quentes) e a LENDÁRIA (o nível que libera a evolução) em ouro, com
##   brilho correndo pela borda e faíscas subindo (conforme GfxQuality "ui_fx");
## - fita no topo com a categoria e um selo com kanji; ícone grande em escala inteira sobre
##   um halo da cor do elemento da arma;
## - nome, etiqueta ("Novo!" ou "Nv 3 → 4") com as marcas de nível (a nova pisca), descrição
##   com os números da melhoria em verde e, no rodapé, a sinergia ("Evolui com" + mini-ícone);
## - destaque ao passar/pressionar (a carta sobe e brilha) e, no modo banir, o carimbo 封.
## O texto do Button fica vazio: o roteiro E2E toca no centro da carta.

enum Cat { NEW, UP, LEGEND, PASSIVE, HEAL, RYO }

## [laca do topo, laca da base, destaque, kanji do selo]
const STYLE := {
	Cat.NEW: [Color("5c1913"), Color("220807"), Color("ff7a52"), "新"],
	Cat.UP: [Color("1f1d3d"), Color("0b0a19"), Color("8fb0ff"), "強"],
	Cat.LEGEND: [Color("4d3307"), Color("1a0f02"), Color("ffd166"), "極"],
	Cat.PASSIVE: [Color("0f3b31"), Color("051512"), Color("6fe0b0"), "宝"],
	Cat.HEAL: [Color("4d1426"), Color("1c0710"), Color("ff9db0"), "癒"],
	Cat.RYO: [Color("4d3a0e"), Color("1c1404"), Color("f0c050"), "両"],
}
const PAD := 6.0
const RIBBON_H := 13.0
const PIP := Vector2(3, 5)
const PIP_STEP := 5.0
const LIFT := 6.0
const STAMP_RED := Color("d0302a")

## Dados da carta (LevelUpSystem) e o que a tela calculou para ela.
var data: Dictionary = {}
var category: int = Cat.NEW
var element: Color = Color(1.0, 0.85, 0.55)
var level: int = 1
var max_level: int = 1
var evo_label: String = ""
var evo_name: String = ""
var evo_icon: Texture2D
var evo_ready: bool = false
## Posição de repouso (a tela anima a entrada; a carta sobe a partir dela ao ser destacada).
var base_position: Vector2 = Vector2.ZERO
## A carta está no lugar e reage ao toque (a tela libera depois da entrada e do bloqueio).
var settled: bool = false
var banish_mode: bool = false
## Carimbo de banir: 0 = nada, 1 = carimbado.
var stamp: float = 0.0
## Nível de efeitos de UI (GfxQuality "ui_fx": 0, 1 ou 2).
var fx_level: int = 2

var lift: float = 0.0
## A descrição foi encurtada com "…" por falta de espaço (só em telas e cartas muito pequenas).
var shortened: bool = false
var _time: float = 0.0
var _icon_tex: Texture2D
var _icon_scale: int = 2
## Lado do ícone na carta: 24 px nativos em escala inteira (24 ou 48).
var _icon_box: float = 24.0
var _icon_center: Vector2 = Vector2.ZERO
var _tag_y: float = 0.0
var _pips_y: float = -1.0
var _ornament_y: float = -1.0
var _footer_y: float = -1.0
var _footer_two_lines: bool = false
var _evo: Label
## Rodapé numa linha só, sem o rótulo: [ícone] Nome (cortado com "…" se preciso).
var _footer_compact: bool = false
var _name: Label
var _desc: RichTextLabel
var _plain: String = ""
var _sparks: PackedVector3Array = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	text = ""
	flat = true
	focus_mode = Control.FOCUS_NONE
	clip_contents = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.add_theme_constant_override("line_spacing", -1)
	add_child(_name)
	_evo = Label.new()
	_evo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_evo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_evo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_evo.add_theme_constant_override("line_spacing", -1)
	_evo.visible = false
	add_child(_evo)
	_desc = RichTextLabel.new()
	_desc.bbcode_enabled = true
	_desc.scroll_active = false
	_desc.fit_content = false
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desc.add_theme_constant_override("line_separation", -1)
	add_child(_desc)
	_rng.seed = 5


## Preenche a carta. `info` vem de LevelUpPanel.card_info.
func setup(card: Dictionary, info: Dictionary) -> void:
	data = card
	category = int(info.get("category", Cat.NEW))
	element = info.get("element", element)
	level = int(card.get("level", 1))
	max_level = int(info.get("max_level", 1))
	evo_label = String(info.get("evo_label", ""))
	evo_name = String(info.get("evo_name", ""))
	evo_icon = info.get("evo_icon", null)
	evo_ready = bool(info.get("evo_ready", false))
	_icon_tex = info.get("icon", null)
	_evo.text = evo_name
	_name.text = String(card.get("title", ""))
	_name.add_theme_color_override("font_color", accent().lerp(Color.WHITE, 0.45))
	_plain = String(info.get("text", ""))
	_desc.text = "[center]%s[/center]" % UiPaint.highlight_numbers(_plain)
	stamp = 0.0
	lift = 0.0
	_sparks.clear()
	queue_redraw()


func accent() -> Color:
	return (STYLE[category] as Array)[2]


func category_text() -> String:
	match category:
		Cat.UP:
			return tr("lvchest.cat_up")
		Cat.LEGEND:
			return tr("lvchest.cat_legend")
		Cat.PASSIVE:
			return tr("lvchest.cat_passive")
		Cat.HEAL:
			return tr("lvchest.cat_heal")
		Cat.RYO:
			return tr("lvchest.cat_ryo")
	return tr("lvchest.cat_new")


## Texto da etiqueta: "Novo!" ou "Nv 3 → 4"; vazio para cura e ouro.
func tag_text() -> String:
	if category in [Cat.HEAL, Cat.RYO]:
		return ""
	if level <= 1:
		return tr("lvchest.new")
	return tr("lvchest.level_arrow") % [level - 1, level]


## Distribui o conteúdo na altura disponível; encolhe (ícone menor, sem ornamento, sem
## marcas) até a descrição caber. Devolve se coube inteira.
func layout_content(card_size: Vector2) -> bool:
	size = card_size
	custom_minimum_size = card_size
	pivot_offset = card_size * 0.5
	var attempts := [[3, true, true, false], [2, true, true, false], [2, false, true, false],
			[2, false, false, false], [2, false, false, true]]
	if card_size.y < 190.0:
		attempts.pop_front()
	var fits := false
	_desc.text = "[center]%s[/center]" % UiPaint.highlight_numbers(_plain)
	for attempt: Array in attempts:
		fits = _try_layout(card_size, int(attempt[0]), bool(attempt[1]), bool(attempt[2]), bool(attempt[3]))
		if fits:
			break
	shortened = false
	if not fits:
		_shorten_desc()
	queue_redraw()
	return fits


## Último recurso (carta estreita e baixa): corta a descrição em palavras e termina com "…".
func _shorten_desc() -> void:
	var words := _plain.split(" ", false)
	while words.size() > 1 and not desc_fits():
		words.resize(words.size() - 1)
		_desc.text = "[center]%s…[/center]" % UiPaint.highlight_numbers(" ".join(words).trim_suffix(",").trim_suffix(";"))
		shortened = true


## A descrição cabe inteira na sua caixa (testes de layout).
func desc_fits() -> bool:
	return _desc.get_content_height() <= _desc.size.y + 0.5


func name_fits() -> bool:
	return _text_lines(_name.text, _name.size.x) <= 2


## O nome da sinergia cabe (numa linha ao lado do rótulo ou quebrado em até 2 linhas).
func footer_fits() -> bool:
	if evo_name.is_empty():
		return true
	if not _evo.visible:
		return true if _footer_compact else UiPaint.text_width("%s %s" % [evo_label, evo_name]) + 17.0 <= size.x - PAD * 2.0
	return _text_lines(evo_name, _evo.size.x) <= 2


func name_label() -> Label:
	return _name


func desc_label() -> RichTextLabel:
	return _desc


func icon_scale() -> int:
	return _icon_scale


func icon_center() -> Vector2:
	return _icon_center


func icon_texture() -> Texture2D:
	return _icon_tex


func footer_text() -> String:
	return "" if evo_name.is_empty() else "%s %s" % [evo_label, evo_name]


func _line_h() -> float:
	return Locale.font.get_height(12) - 1.0


func _try_layout(s: Vector2, scale: int, ornament: bool, pips: bool, compact: bool) -> bool:
	_icon_scale = scale
	var inner := s.x - PAD * 2.0
	var y := 4.0 + RIBBON_H + 4.0
	var box := 24.0 * maxf(1.0, floorf(16.0 * scale / 24.0))
	if _icon_tex != null:
		# Ícone nativo (24 px) em escala inteira: 1x na carta baixa, 2x na alta.
		var native := maxf(_icon_tex.get_width(), _icon_tex.get_height())
		box = native * maxf(1.0, floorf(16.0 * scale / native))
	_icon_box = box
	_icon_center = Vector2(floorf(s.x * 0.5), y + floorf(box * 0.5) + 2.0)
	y += box + (3.0 if compact else 6.0)
	var name_lines := clampi(_text_lines(_name.text, inner), 1, 2)
	_name.position = Vector2(PAD, y - 1.0)
	_name.size = Vector2(inner, name_lines * _line_h() + 2.0)
	y += name_lines * _line_h() + 2.0
	_tag_y = -1.0
	_pips_y = -1.0
	if not tag_text().is_empty():
		_tag_y = y
		y += _line_h() + 1.0
		if pips:
			_pips_y = y
			y += PIP.y + 3.0
	_ornament_y = -1.0
	if ornament:
		_ornament_y = y + 2.0
		y += 7.0
	# Rodapé de sinergia: "Evolui com [ícone] Nome" numa linha; se não couber, o rótulo com o
	# ícone numa linha e o nome embaixo (quebrando em até 2 linhas).
	var bottom := s.y - PAD
	_footer_y = -1.0
	_footer_two_lines = false
	_evo.visible = false
	_footer_compact = false
	if not evo_name.is_empty():
		var one := UiPaint.text_width("%s %s" % [evo_label, evo_name]) + 17.0
		var footer_h := _line_h() + 2.0
		_footer_compact = compact and one > inner
		if one > inner and not _footer_compact:
			_footer_two_lines = true
			var lines := clampi(_text_lines(evo_name, inner), 1, 2)
			footer_h += lines * _line_h()
			_evo.visible = true
			_evo.size = Vector2(inner, lines * _line_h() + 2.0)
		bottom -= footer_h
		_footer_y = bottom + 2.0
		_evo.position = Vector2(PAD, _footer_y + _line_h() - 1.0)
	_desc.position = Vector2(PAD - 1.0, y)
	_desc.size = Vector2(inner + 2.0, maxf(bottom - y, 0.0))
	return desc_fits() and footer_fits()


func _text_lines(value: String, width: float) -> int:
	var h := Locale.font.get_multiline_string_size(value, HORIZONTAL_ALIGNMENT_CENTER, width, 12).y
	return maxi(1, roundi(h / Locale.font.get_height(12)))


func _process(delta: float) -> void:
	_time += delta
	var hot := settled and not disabled and get_draw_mode() != DRAW_NORMAL
	lift = move_toward(lift, 1.0 if hot else 0.0, delta * 8.0)
	if settled:
		position = base_position - Vector2(0.0, roundf(LIFT * lift))
		scale = Vector2.ONE * (1.0 + 0.03 * lift)
	_update_sparks(delta)
	queue_redraw()


func _update_sparks(delta: float) -> void:
	var wanted := 0
	if category == Cat.LEGEND:
		wanted = [0, 5, 12][fx_level]
	elif lift > 0.5:
		wanted = [0, 0, 4][fx_level]
	while _sparks.size() < wanted:
		_sparks.append(Vector3(_rng.randf_range(4.0, size.x - 4.0), size.y - _rng.randf_range(0.0, size.y * 0.6),
				_rng.randf_range(0.0, 1.0)))
	if _sparks.size() > wanted:
		_sparks.resize(wanted)
	for i: int in range(_sparks.size()):
		var s := _sparks[i]
		s.y -= delta * (14.0 + 10.0 * fmod(i * 0.37, 1.0))
		s.z += delta * 0.7
		if s.z >= 1.0 or s.y < -8.0:
			s = Vector3(_rng.randf_range(4.0, size.x - 4.0), size.y - _rng.randf_range(0.0, 10.0), 0.0)
		_sparks[i] = s


func _draw() -> void:
	var s := size
	var style: Array = STYLE[category]
	var acc: Color = style[2]
	var r := Rect2(Vector2.ZERO, s)
	var hot := lift
	# Sombra e brilho externo ao destacar.
	draw_rect(Rect2(Vector2(2, 3), s), Color(0, 0, 0, 0.45))
	if hot > 0.0:
		for k: int in range(3):
			draw_rect(r.grow(1.0 + k), Color(acc, 0.22 * hot / (k + 1)), false, 1.0)
	# Corpo de laca com brilho diagonal.
	UiPaint.vgradient(self, r, style[0], style[1])
	draw_colored_polygon(PackedVector2Array([Vector2(s.x * 0.55, 0), Vector2(s.x * 0.8, 0),
			Vector2(s.x * 0.3, s.y), Vector2(s.x * 0.05, s.y)]), Color(1, 1, 1, 0.025))
	# Papel da descrição (ofuda).
	var paper := Rect2(_desc.position + Vector2(-1, -2), _desc.size + Vector2(0, 3))
	if paper.size.y > 4.0:
		draw_rect(paper, Color(0, 0, 0, 0.22))
	# Moldura: escuro, destaque, filete interno e cantoneiras.
	draw_rect(r, Color(0.05, 0.02, 0.02), false, 1.0)
	var border := acc.lerp(Color.WHITE, 0.35 * hot)
	draw_rect(r.grow(-1.0), border, false, 1.0)
	draw_rect(r.grow(-3.0), Color(acc, 0.28), false, 1.0)
	UiPaint.corners(self, r.grow(-3.0), acc.lerp(UiPaint.GOLD_HI, 0.5), 7.0)
	if category == Cat.LEGEND:
		_draw_legend_shimmer(r)
	# Fita da categoria e selo.
	var ribbon := Rect2(4.0, 4.0, s.x - 8.0, RIBBON_H)
	UiPaint.vgradient(self, ribbon, acc.darkened(0.15), acc.darkened(0.55))
	draw_rect(Rect2(ribbon.position, Vector2(ribbon.size.x, 1)), Color(1, 1, 1, 0.3))
	var cat := category_text()
	var room := ribbon.size.x - 16.0
	var font_y := ribbon.position.y + 10.0
	UiPaint.text(self, Vector2(ribbon.position.x + 2.0, font_y), cat, 12, UiPaint.PAPER,
			HORIZONTAL_ALIGNMENT_CENTER, room, 2, Color(0.08, 0.02, 0.02))
	UiPaint.seal(self, Vector2(s.x - 11.0, 10.0), String(style[3]), 13.0, UiPaint.SEAL_RED, UiPaint.SEAL_TEXT, 0.12)
	_draw_icon()
	if _tag_y >= 0.0:
		_draw_tag(acc)
	if _ornament_y >= 0.0:
		UiPaint.ornament(self, Vector2(s.x * 0.5, _ornament_y), minf(s.x * 0.5 - 12.0, 40.0), 0.8)
	if _footer_y >= 0.0:
		_draw_footer()
	for sp: Vector3 in _sparks:
		var a := sin(sp.z * PI)
		var c := UiPaint.GOLD_HI if category == Cat.LEGEND else acc
		draw_rect(Rect2(Vector2(sp.x, sp.y).floor(), Vector2.ONE * (2.0 if int(sp.x) % 3 == 0 else 1.0)), Color(c, a))
	if banish_mode:
		draw_rect(r, Color(STAMP_RED, 0.08 + 0.1 * hot))
		draw_rect(r.grow(-1.0), Color(STAMP_RED, 0.55 + 0.4 * hot), false, 1.0)
		if stamp <= 0.0 and hot > 0.0:
			UiPaint.seal(self, s * 0.5, "封", 34.0, Color(STAMP_RED, 0.0), Color(STAMP_RED, 0.5 * hot), -0.2, 1.0)
	if stamp > 0.0:
		_draw_stamp()


func _draw_icon() -> void:
	var c := _icon_center
	var box := _icon_box
	var pulse := 0.5 + 0.5 * sin(_time * 2.4)
	var halo := box * 0.5 + 8.0
	if fx_level >= 1:
		# Raios curtos girando atrás do ícone.
		var n := 8
		for i: int in range(n):
			var a := _time * 0.5 + TAU * i / n
			var p1 := c + Vector2.from_angle(a - 0.12) * (halo + 6.0)
			var p2 := c + Vector2.from_angle(a + 0.12) * (halo + 6.0)
			draw_polygon(PackedVector2Array([c, p1, p2]),
					PackedColorArray([Color(element, 0.22), Color(element, 0.0), Color(element, 0.0)]))
	draw_circle(c, halo, Color(element, 0.1 + 0.05 * pulse))
	draw_circle(c, halo * 0.72, Color(element, 0.16))
	draw_circle(c, halo * 0.45, Color(element.lerp(Color.WHITE, 0.4), 0.18))
	draw_arc(c, halo, 0.0, TAU, 32, Color(element, 0.55), 1.0)
	if _icon_tex == null:
		return
	var native := _icon_tex.get_size()
	var k := floorf(box / maxf(native.x, native.y))
	var shown := native * maxf(k, 1.0)
	var at := (c - shown * 0.5).floor()
	draw_texture_rect(_icon_tex, Rect2(at + Vector2(1, 2), shown), false, Color(0, 0, 0, 0.5))
	draw_texture_rect(_icon_tex, Rect2(at - Vector2(0, roundf(lift * 1.0)), shown), false)


func _draw_tag(acc: Color) -> void:
	var w := size.x
	var tag := tag_text()
	var base := _tag_y + 10.0
	if level <= 1:
		# Pílula "Novo!" em vermelhão com texto dourado.
		var tw := UiPaint.text_width(tag)
		var pill := Rect2(floorf((w - tw) * 0.5) - 5.0, _tag_y, tw + 10.0, _line_h())
		draw_rect(pill, UiPaint.VERMILION)
		draw_rect(pill, ThemeFactory.ACCENT, false, 1.0)
		UiPaint.text(self, Vector2(pill.position.x + 5.0, base), tag, 12, Color("fff1d6"),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 2, Color(0.25, 0.04, 0.02))
	else:
		UiPaint.text(self, Vector2(0, base), tag, 12, ThemeFactory.ACCENT, HORIZONTAL_ALIGNMENT_CENTER, w)
	if _pips_y < 0.0:
		return
	var total := maxi(max_level, 1)
	var step := PIP_STEP if total * PIP_STEP <= w - 16.0 else 4.0
	var x0 := floorf((w - (total * step - (step - PIP.x))) * 0.5)
	var blink := 0.5 + 0.5 * sin(_time * 6.0)
	for i: int in range(total):
		var p := Rect2(x0 + i * step, _pips_y, PIP.x, PIP.y)
		if i < level - 1:
			draw_rect(p, acc)
			draw_rect(Rect2(p.position, Vector2(PIP.x, 1)), Color(1, 1, 1, 0.45))
		elif i == level - 1:
			draw_rect(p.grow(1.0), Color(UiPaint.GOLD_HI, 0.35 * blink))
			draw_rect(p, UiPaint.GOLD_HI.lerp(Color.WHITE, blink * 0.5))
		else:
			draw_rect(p, Color(1, 1, 1, 0.14))


func _draw_footer() -> void:
	var w := size.x
	var color := ThemeFactory.ACCENT if evo_ready else UiPaint.DIM
	var y := _footer_y
	draw_rect(Rect2(PAD, y - 2.0, w - PAD * 2.0, 1.0), Color(color, 0.3))
	_evo.add_theme_color_override("font_color", color)
	if _footer_compact:
		var room := w - PAD * 2.0 - 15.0
		var shown := evo_name
		while shown.length() > 1 and UiPaint.text_width(shown + "…") > room and UiPaint.text_width(shown) > room:
			shown = shown.left(shown.length() - 1)
		if shown != evo_name:
			shown += "…"
		var cx := floorf((w - (15.0 + UiPaint.text_width(shown))) * 0.5)
		if evo_icon != null:
			var nat := evo_icon.get_size()
			draw_texture_rect(evo_icon, Rect2(Vector2(cx, y), nat * (12.0 / maxf(nat.x, nat.y))), false)
		UiPaint.text(self, Vector2(cx + 15.0, y + 10.0), shown, 12, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		return
	var label_w := UiPaint.text_width(evo_label)
	var name_w := 0.0 if _footer_two_lines else UiPaint.text_width(evo_name) + 3.0
	var icon_w := 15.0 if evo_icon != null else 0.0
	var total := label_w + 3.0 + icon_w + name_w
	var x := floorf((w - total) * 0.5)
	if _footer_two_lines and total > w - PAD * 2.0:
		x = PAD
	UiPaint.text(self, Vector2(x, y + 10.0), evo_label, 12, Color(color, 0.8), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	x += label_w + 3.0
	if evo_icon != null:
		var native := evo_icon.get_size()
		var k := 12.0 / maxf(native.x, native.y)
		draw_texture_rect(evo_icon, Rect2(Vector2(x, y), native * k), false)
		x += icon_w
	if not _footer_two_lines:
		UiPaint.text(self, Vector2(x, y + 10.0), evo_name, 12, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)


## Borda dourada viva: um brilho percorre o contorno e a moldura respira.
func _draw_legend_shimmer(r: Rect2) -> void:
	var breathe := 0.5 + 0.5 * sin(_time * 3.0)
	draw_rect(r.grow(-1.0), Color(UiPaint.GOLD_HI, 0.35 + 0.4 * breathe), false, 1.0)
	if fx_level <= 0:
		return
	var perimeter := (r.size.x + r.size.y) * 2.0
	for head: float in [fmod(_time * 90.0, perimeter), fmod(_time * 90.0 + perimeter * 0.5, perimeter)]:
		for k: int in range(18):
			var d := fmod(head - k * 1.5 + perimeter, perimeter)
			var p := _perimeter_point(r.grow(-1.0), d)
			draw_rect(Rect2(p.floor(), Vector2.ONE * (2.0 if k < 4 else 1.0)), Color(1, 1, 0.85, 1.0 - k / 18.0))


func _perimeter_point(r: Rect2, d: float) -> Vector2:
	var w := r.size.x
	var h := r.size.y
	if d < w:
		return r.position + Vector2(d, 0)
	if d < w + h:
		return r.position + Vector2(w - 1.0, d - w)
	if d < w * 2.0 + h:
		return r.position + Vector2(w - (d - w - h), h - 1.0)
	return r.position + Vector2(0, h - (d - w * 2.0 - h))


func _draw_stamp() -> void:
	var k := clampf(stamp / 0.45, 0.0, 1.0)
	var zoom := lerpf(2.4, 1.0, 1.0 - pow(1.0 - k, 3.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.0, 0.0, 0.45 * k))
	UiPaint.seal(self, size * 0.5, "封", 34.0 * zoom, Color(STAMP_RED, 0.85 * k), Color(1, 0.92, 0.85, k), -0.2, 1.0)
