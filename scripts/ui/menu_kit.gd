class_name MenuKit
extends RefCounted
## Peças premium das telas de menu (laca, ouro e selos 百鬼): o botão "voltar" único de todas
## as telas, o cabeçalho com selo, a chave de liga/desliga, o seletor segmentado, a barra de
## volume e o campo de partículas leves. Cores e caixas vêm de ThemeFactory.
##
## Efeitos seguem GfxQuality.budget("ui_fx"): 0 = estático, 1 = brilho leve, 2 = brilho e
## partículas. Quem usa reage à troca ao vivo por Settings.changed.

const JA_FONT := "res://assets/fonts/fusion_pixel_12_ja.woff2"
const SEAL_RED := Color("b3261e")
const SHADOW := Color(0.08, 0.03, 0.03)
## Altura do alvo de toque do "voltar" (≥ 48 dp no Redmi Note 14 Pro+: 1220 px / 305 ≈ 4 px
## por ponto e ~2,8 px por dp → 48 dp ≈ 34 pontos).
const BACK_HEIGHT := 36.0
const BACK_FACE_HEIGHT := 24.0
const BACK_MEDALLION := 9.0

static var _ja: Font
static var _textures: Dictionary = {}


static func ja_font() -> Font:
	if _ja == null:
		_ja = load(JA_FONT) as Font
	return _ja


## Nível dos efeitos de UI (0, 1 ou 2).
static func ui_fx() -> int:
	return int(GfxQuality.budget("ui_fx"))


## Área segura do Android (recorte da câmera, bordas curvas), em pontos da tela:
## (esquerda, direita). Zero no desktop.
static func safe_insets(node: Control) -> Vector2:
	if not OS.has_feature("mobile") or not node.is_inside_tree():
		return Vector2.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var screen := Vector2(DisplayServer.screen_get_size())
	var scale_x := node.get_viewport().get_final_transform().x.x
	if safe.size.x <= 0.0 or scale_x <= 0.0:
		return Vector2.ZERO
	return Vector2(maxf(safe.position.x, 0.0), maxf(screen.x - safe.end.x, 0.0)) / scale_x


## Liga `on_change` à troca de qualidade gráfica (ao vivo); desliga sozinho com o nó.
static func on_quality_change(node: Node, on_change: Callable) -> void:
	var settings := node.get_tree().root.get_node_or_null(^"Settings") if node.is_inside_tree() else null
	if settings == null:
		settings = Engine.get_main_loop().root.get_node_or_null(^"Settings") if Engine.get_main_loop() else null
	if settings == null:
		return
	var handler := func(key: String) -> void:
		if key == GfxQuality.changed_signal_key() and is_instance_valid(node):
			on_change.call()
	settings.connect("changed", handler)
	node.tree_exiting.connect(func() -> void:
		if settings.is_connected("changed", handler):
			settings.disconnect("changed", handler), CONNECT_ONE_SHOT)


## Rótulo com contorno escuro no padrão das telas.
static func text(value: String, size: int = 12, color: Color = ThemeFactory.TEXT) -> Label:
	var l := Label.new()
	l.text = value
	if size != 12:
		l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Selo vermelho com kanji (como o 百鬼 do título).
static func seal(kanji: String, vertical: bool = false) -> PanelContainer:
	var box := PanelContainer.new()
	var style := ThemeFactory.flat_box(SEAL_RED, SEAL_RED.darkened(0.45), 1, 2, Vector2(2, 0))
	style.content_margin_left = 3
	style.content_margin_bottom = 1
	box.add_theme_stylebox_override("panel", style)
	var l := Label.new()
	l.text = "\n".join(kanji.split("")) if vertical else kanji
	l.add_theme_font_override("font", ja_font())
	l.add_theme_color_override("font_color", Color("fbe6cf"))
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_constant_override("line_spacing", -2)
	box.add_child(l)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


## Cabeçalho das telas: faixa escura no topo, título dourado centrado entre filetes e um selo
## com kanji. Fica atrás do "voltar" (que é posto por cima ao entrar na árvore).
static func header(parent: Control, title: String, kanji: String) -> Control:
	var band := Header.new()
	band.name = "Header"
	band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	band.offset_bottom = 40
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(band)
	var row := HBoxContainer.new()
	row.name = "TitleRow"
	row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.offset_top = 7
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(row)
	var l := text(title, 24, ThemeFactory.ACCENT)
	l.name = "Title"
	l.add_theme_color_override("font_outline_color", SHADOW)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	row.add_child(l)
	if kanji != "":
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(seal(kanji))
		row.add_child(holder)
	band.title = l
	row.resized.connect(band.queue_redraw)
	return band


static func apply_lacquer(b: Button) -> void:
	ThemeFactory.apply_button_boxes(b, ThemeFactory.lacquer_button_boxes())
	b.add_theme_color_override("font_color", ThemeFactory.TEXT)
	for state: String in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, ThemeFactory.ACCENT)
	b.add_theme_color_override("font_disabled_color", Color(0.7, 0.64, 0.58, 0.7))
	b.add_theme_constant_override("outline_size", 3)


static func apply_primary(b: Button, font_size: int = 16) -> void:
	ThemeFactory.apply_button_boxes(b, ThemeFactory.primary_button_boxes())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_color_override("font_outline_color", Color(0.25, 0.04, 0.03))
	for state: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color",
			"font_hover_pressed_color"]:
		b.add_theme_color_override(state, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.85, 0.78, 0.72, 0.75))


## Barra de volume de laca com puxador dourado.
static func apply_slider(s: HSlider) -> void:
	var boxes := ThemeFactory.slider_boxes()
	s.add_theme_stylebox_override("slider", boxes[0])
	s.add_theme_stylebox_override("grabber_area", boxes[1])
	s.add_theme_stylebox_override("grabber_area_highlight", boxes[2])
	s.add_theme_icon_override("grabber", knob_texture(false))
	s.add_theme_icon_override("grabber_highlight", knob_texture(true))
	s.add_theme_icon_override("grabber_disabled", knob_texture(false))
	s.add_theme_stylebox_override("focus", ThemeFactory.focus_ring())


## Lista suspensa de laca com o chevron dourado.
static func apply_option(o: OptionButton) -> void:
	apply_lacquer(o)
	o.add_theme_icon_override("arrow", chevron_texture())
	o.add_theme_constant_override("arrow_margin", 6)
	var popup := o.get_popup()
	popup.add_theme_stylebox_override("panel", ThemeFactory.lacquer_panel(0.97))
	popup.add_theme_stylebox_override("hover", ThemeFactory.flat_box(Color(0.55, 0.12, 0.08, 0.9),
			Color(ThemeFactory.ACCENT, 0.8), 1, 2, Vector2(4, 1)))
	popup.add_theme_color_override("font_color", ThemeFactory.TEXT)
	popup.add_theme_color_override("font_hover_color", ThemeFactory.ACCENT)
	popup.add_theme_constant_override("outline_size", 3)
	popup.add_theme_color_override("font_outline_color", SHADOW)
	popup.add_theme_constant_override("v_separation", 8)



## Puxador 12x16: disco de ouro com brilho e contorno escuro (pixel art).
static func knob_texture(hot: bool) -> Texture2D:
	var key := "knob%s" % hot
	if _textures.has(key):
		return _textures[key]
	var img := Image.create_empty(12, 16, false, Image.FORMAT_RGBA8)
	var c := Vector2(5.5, 7.5)
	for y: int in 16:
		for x: int in 12:
			var d := (Vector2(x, y) - c) / Vector2(5.6, 7.4)
			var r := d.length()
			if r > 1.0:
				continue
			var color := Color("3a1f0c")
			if r < 0.8:
				var light := clampf(0.5 - d.y * 0.6 - d.x * 0.2, 0.0, 1.0)
				color = Color("b8862a").lerp(Color("ffe9a8"), light)
				if hot:
					color = color.lightened(0.15)
			img.set_pixel(x, y, color)
	img.set_pixel(4, 4, Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex


## Chevron dourado 8x5 das listas suspensas.
static func chevron_texture() -> Texture2D:
	if _textures.has("chevron"):
		return _textures["chevron"]
	var img := Image.create_empty(9, 6, false, Image.FORMAT_RGBA8)
	for i: int in 5:
		for t: int in 2:
			img.set_pixel(i + t, i, ThemeFactory.ACCENT if t == 0 else Color("8a6020"))
			img.set_pixel(8 - i - t, i, ThemeFactory.ACCENT if t == 0 else Color("8a6020"))
	var tex := ImageTexture.create_from_image(img)
	_textures["chevron"] = tex
	return tex


## Cadeado 9x11 desenhado (fechado), para guardiões e entradas bloqueadas.
static func draw_lock(ci: CanvasItem, at: Vector2, color: Color = ThemeFactory.ACCENT) -> void:
	var dark := Color(0.12, 0.06, 0.04)
	ci.draw_rect(Rect2(at + Vector2(1, 0), Vector2(7, 6)), dark)
	ci.draw_rect(Rect2(at + Vector2(2, 1), Vector2(5, 5)), color)
	ci.draw_rect(Rect2(at + Vector2(3, 2), Vector2(3, 4)), dark)
	ci.draw_rect(Rect2(at + Vector2(0, 5), Vector2(9, 7)), dark)
	ci.draw_rect(Rect2(at + Vector2(1, 6), Vector2(7, 5)), color)
	ci.draw_rect(Rect2(at + Vector2(4, 7), Vector2(1, 3)), dark)
	ci.draw_rect(Rect2(at + Vector2(1, 6), Vector2(7, 1)), color.lightened(0.4))


## Contorno de 1 px de uma textura (silhuetas de bloqueados): devolve [silhueta, aro].
static func silhouette_pair(tex: Texture2D, fill: Color, rim: Color) -> Array[Texture2D]:
	var key := "%s|%s|%s" % [tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id()), fill, rim]
	if _textures.has(key):
		return _textures[key]
	var src := tex.get_image()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width()
	var h := src.get_height()
	var body := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var edge := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			if src.get_pixel(x, y).a > 0.3:
				body.set_pixel(x, y, fill)
				continue
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p := Vector2i(x, y) + o
				if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and src.get_pixelv(p).a > 0.3:
					edge.set_pixel(x, y, rim)
					break
	var pair: Array[Texture2D] = [ImageTexture.create_from_image(body), ImageTexture.create_from_image(edge)]
	_textures[key] = pair
	return pair


## Brilho radial (branco → transparente), para auras e halos com modulate.
static func glow_texture() -> Texture2D:
	if _textures.has("glow"):
		return _textures["glow"]
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.42), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
	tex.gradient = ramp
	_textures["glow"] = tex
	return tex


static func add_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


# --- Cabeçalho ---------------------------------------------------------------------

## Faixa do topo: degradê de tinta e filetes dourados dos lados do título.
class Header extends Control:
	var title: Label

	func _draw() -> void:
		var w := size.x
		for i: int in 8:
			var a := 0.5 * (1.0 - i / 8.0)
			draw_rect(Rect2(0, i * 5, w, 5), Color(0.02, 0.015, 0.04, a))
		if title == null:
			return
		var row := title.get_parent() as Control
		var y := row.position.y + title.size.y * 0.55
		var left := row.position.x - 10.0
		var right := row.position.x + row.size.x + 10.0
		var span := minf(70.0, maxf(0.0, left - 110.0))
		if span > 8.0:
			draw_rect(Rect2(left - span, y, span, 1), Color(ThemeFactory.ACCENT, 0.45))
			draw_rect(Rect2(left - 3, y - 1, 3, 3), Color(ThemeFactory.ACCENT, 0.7))
		var span_r := minf(70.0, maxf(0.0, w - right - 16.0))
		if span_r > 8.0:
			draw_rect(Rect2(right, y, span_r, 1), Color(ThemeFactory.ACCENT, 0.45))
			draw_rect(Rect2(right, y - 1, 3, 3), Color(ThemeFactory.ACCENT, 0.7))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


# --- Botão "voltar" ----------------------------------------------------------------

## Botão "voltar" único de todas as telas: placa de laca com filete de ouro e um medalhão
## vermelhão com a seta, à esquerda do texto. O alvo de toque (MenuKit.BACK_HEIGHT) é maior que a
## placa desenhada. Toque: placa afunda, a seta recua e (ui_fx ≥ 1) um anel dourado se abre.
class BackButton extends Button:
	var face: Control
	var _press := 0.0
	var _hover := 0.0
	var _ring := 1.0
	var _tween: Tween

	func _init(label_text: String) -> void:
		name = "BackButton"
		text = label_text
		focus_mode = Control.FOCUS_ALL
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		custom_minimum_size = Vector2(0, MenuKit.BACK_HEIGHT)
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var pad := StyleBoxEmpty.new()
			pad.content_margin_left = 30
			pad.content_margin_right = 12
			pad.content_margin_top = 1 if state.contains("pressed") else 0
			pad.content_margin_bottom = 0
			add_theme_stylebox_override(state, pad)
		add_theme_color_override("font_color", ThemeFactory.TEXT)
		for state: String in ["font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
			add_theme_color_override(state, ThemeFactory.ACCENT)
		add_theme_color_override("font_pressed_color", Color("ffe9a8"))
		add_theme_constant_override("outline_size", 3)
		add_theme_color_override("font_outline_color", MenuKit.SHADOW)
		face = Control.new()
		face.name = "Face"
		face.show_behind_parent = true
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.draw.connect(_draw_face)
		add_child(face)
		button_down.connect(_animate.bind(true))
		button_up.connect(_animate.bind(false))
		mouse_entered.connect(_set_hover.bind(true))
		mouse_exited.connect(_set_hover.bind(false))
		focus_entered.connect(face.queue_redraw)
		focus_exited.connect(face.queue_redraw)
		pressed.connect(func() -> void: AudioManager.play_ui("ui_cancel"))

	func _set_hover(on: bool) -> void:
		_hover = 1.0 if on else 0.0
		face.queue_redraw()

	func _animate(down: bool) -> void:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_method(_set_press, _press, 1.0 if down else 0.0, 0.08 if down else 0.16)
		if down and MenuKit.ui_fx() >= 1:
			_tween.tween_method(_set_ring, 0.0, 1.0, 0.45)

	func _set_press(v: float) -> void:
		_press = v
		face.queue_redraw()

	func _set_ring(v: float) -> void:
		_ring = v
		face.queue_redraw()

	## Retângulo da placa desenhada (centrada na altura do alvo de toque).
	func plate_rect() -> Rect2:
		var h := MenuKit.BACK_FACE_HEIGHT
		return Rect2(2, roundf((size.y - h) * 0.5) + roundf(_press), size.x - 4, h)

	func _draw_face() -> void:
		var r := plate_rect()
		var hot := _hover > 0.0 or has_focus()
		var bg := Color(0.06, 0.03, 0.05, 0.86).lerp(Color(0.2, 0.06, 0.05, 0.92), maxf(_press, 0.6 if hot else 0.0))
		var plate := ThemeFactory.flat_box(bg, Color(ThemeFactory.ACCENT, 0.95 if hot else 0.6), 1, 4)
		plate.shadow_color = Color(0, 0, 0, 0.5)
		plate.shadow_size = 1
		plate.shadow_offset = Vector2(0, 2.0 - _press)
		face.draw_style_box(plate, r)
		# Brilho do alto da placa (laca envernizada).
		face.draw_rect(Rect2(r.position + Vector2(4, 1), Vector2(r.size.x - 8, 1)), Color(1, 0.85, 0.6, 0.16))
		var c := Vector2(r.position.x + 12, r.get_center().y)
		var rad := MenuKit.BACK_MEDALLION
		face.draw_circle(c + Vector2(0, 1), rad + 1, Color(0, 0, 0, 0.55))
		face.draw_circle(c, rad + 1, Color("3a1208"))
		face.draw_circle(c, rad, ThemeFactory.ACCENT if hot else ThemeFactory.GOLD)
		face.draw_circle(c, rad - 1.5, Color("c0392b").lerp(Color("8e2219"), _press))
		face.draw_circle(c + Vector2(-2, -3), 2.0, Color(1, 0.7, 0.55, 0.35))
		# Seta: ponta para a esquerda, recua um pouco ao tocar.
		var shift := -1.0 * _press - (1.0 if hot else 0.0)
		var tip := c + Vector2(-4 + shift, 0).round()
		var arrow := PackedVector2Array([tip, tip + Vector2(4, -4), tip + Vector2(4, -2), tip + Vector2(8, -2),
				tip + Vector2(8, 2), tip + Vector2(4, 2), tip + Vector2(4, 4)])
		face.draw_colored_polygon(arrow, Color("fff4e0"))
		if _ring < 1.0:
			var a := 1.0 - _ring
			face.draw_arc(c, rad + 2.0 + _ring * 10.0, 0.0, TAU, 24, Color(ThemeFactory.ACCENT, a * 0.8), 1.0)
		if has_focus():
			face.draw_style_box(ThemeFactory.focus_ring(), r)


# --- Chave liga/desliga -------------------------------------------------------------

## Chave de laca: trilho escuro (desligado) ou vermelhão (ligado), puxador de ouro que
## desliza. Continua sendo um CheckButton (button_pressed, toggled).
class Toggle extends CheckButton:
	const TRACK := Vector2(30, 14)
	var _t := 0.0
	var _tween: Tween
	var _knob: Control

	func _init() -> void:
		text = ""
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(TRACK.x + 8, 28)
		var blank := ImageTexture.create_from_image(Image.create_empty(int(TRACK.x), int(TRACK.y), false,
				Image.FORMAT_RGBA8))
		for icon: String in ["checked", "unchecked", "checked_disabled", "unchecked_disabled",
				"checked_mirrored", "unchecked_mirrored"]:
			add_theme_icon_override(icon, blank)
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		_knob = Control.new()
		_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_knob.set_anchors_preset(Control.PRESET_FULL_RECT)
		_knob.draw.connect(_draw_switch)
		add_child(_knob)
		toggled.connect(_on_toggled)
		focus_entered.connect(_knob.queue_redraw)
		focus_exited.connect(_knob.queue_redraw)

	func _ready() -> void:
		_t = 1.0 if button_pressed else 0.0

	func _on_toggled(on: bool) -> void:
		AudioManager.play_ui("ui_move")
		if _tween != null and _tween.is_valid():
			_tween.kill()
		if MenuKit.ui_fx() == 0 or not is_visible_in_tree():
			_set_t(1.0 if on else 0.0)
			return
		_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_method(_set_t, _t, 1.0 if on else 0.0, 0.18)

	func _set_t(v: float) -> void:
		_t = v
		_knob.queue_redraw()

	func set_pressed_silently(on: bool) -> void:
		set_pressed_no_signal(on)
		_set_t(1.0 if on else 0.0)

	func _draw_switch() -> void:
		var at := Vector2(size.x - TRACK.x - 2, roundf((size.y - TRACK.y) * 0.5))
		var r := Rect2(at, TRACK)
		var on := clampf(_t, 0.0, 1.0)
		var bg := Color(0.04, 0.025, 0.04, 0.95).lerp(Color("b8322a"), on)
		var track := ThemeFactory.flat_box(bg, Color(ThemeFactory.ACCENT, 0.4 + 0.5 * on), 1, 7)
		_knob.draw_style_box(track, r)
		_knob.draw_rect(Rect2(at + Vector2(4, 1), Vector2(TRACK.x - 8, 1)), Color(1, 1, 1, 0.08 + 0.12 * on))
		var kx := lerpf(at.x + 7.0, at.x + TRACK.x - 7.0, _t)
		var c := Vector2(roundf(kx), at.y + TRACK.y * 0.5)
		if on > 0.5 and MenuKit.ui_fx() >= 1:
			_knob.draw_circle(c, 8.0, Color(1.0, 0.8, 0.4, 0.18))
		_knob.draw_circle(c + Vector2(0, 1), 6.0, Color(0, 0, 0, 0.5))
		_knob.draw_circle(c, 6.0, Color("3a1f0c"))
		_knob.draw_circle(c, 5.0, Color("d9a441").lerp(Color("ffe08a"), on))
		_knob.draw_circle(c + Vector2(-1.5, -1.5), 1.5, Color(1, 1, 1, 0.7))
		if has_focus():
			_knob.draw_style_box(ThemeFactory.focus_ring(), r)


# --- Seletor segmentado -------------------------------------------------------------

## Botões lado a lado, um escolhido (vermelhão com ouro), os outros em laca. Emite
## value_changed(valor). Cada segmento quebra linha se o texto não couber.
class Segmented extends HBoxContainer:
	signal value_changed(value: Variant)

	var buttons: Array[Button] = []
	var values: Array = []
	var _group := ButtonGroup.new()

	func _init() -> void:
		add_theme_constant_override("separation", 2)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func setup(options: Array, current: Variant) -> void:
		for entry: Array in options:
			var b := Button.new()
			b.text = String(entry[1])
			b.toggle_mode = true
			b.button_group = _group
			b.focus_mode = Control.FOCUS_ALL
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size = Vector2(30, 26)
			b.clip_text = false
			var value: Variant = entry[0]
			b.pressed.connect(func() -> void:
				AudioManager.play_ui("ui_move")
				value_changed.emit(value))
			add_child(b)
			buttons.append(b)
			values.append(value)
		set_value(current)

	func set_value(current: Variant) -> void:
		for i: int in buttons.size():
			var on := str(values[i]) == str(current)
			buttons[i].set_pressed_no_signal(on)
			_style(buttons[i], on, i)

	func selected_index() -> int:
		for i: int in buttons.size():
			if buttons[i].button_pressed:
				return i
		return -1

	func _style(b: Button, on: bool, i: int) -> void:
		var last := buttons.size() - 1 if not buttons.is_empty() else 0
		var boxes: Array[StyleBoxFlat] = []
		if on:
			var lit := ThemeFactory.flat_box(Color("b8322a"), ThemeFactory.ACCENT, 1, 3, Vector2(4, 2))
			boxes = [lit, lit, lit, lit]
		else:
			boxes = ThemeFactory.lacquer_button_boxes()
			for box: StyleBoxFlat in boxes:
				box.content_margin_left = 4
				box.content_margin_right = 4
		for box: StyleBoxFlat in boxes:
			box.corner_radius_top_left = 4 if i == 0 else 1
			box.corner_radius_bottom_left = 4 if i == 0 else 1
			box.corner_radius_top_right = 4 if i == last else 1
			box.corner_radius_bottom_right = 4 if i == last else 1
		ThemeFactory.apply_button_boxes(b, boxes)
		b.add_theme_color_override("font_color", Color.WHITE if on else ThemeFactory.MUTED)
		for state: String in ["font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(state, Color.WHITE if on else ThemeFactory.ACCENT)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_constant_override("outline_size", 3)
		b.add_theme_color_override("font_outline_color", Color(0.2, 0.04, 0.03) if on else MenuKit.SHADOW)


# --- Partículas leves -------------------------------------------------------------

## Campo de partículas desenhado num só _draw (sem um nó por partícula). Tipos: "ember"
## (sobe e cintila), "petal" (cai balançando), "snow" (cai devagar), "wisp" (sobe, halo),
## "leaf" (vento de lado), "smoke" (sobe e se abre), "spark" (estrelas que piscam).
class Motes extends Control:
	var kind := "ember"
	var color := Color(1.0, 0.75, 0.4)
	var count := 0
	var _p := PackedVector4Array()
	var _rng := RandomNumberGenerator.new()
	var _time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rng.seed = 7

	func configure(p_kind: String, p_color: Color, p_count: int) -> void:
		kind = p_kind
		color = p_color
		count = p_count
		_p.resize(count)
		for i: int in count:
			_p[i] = _spawn(true)
		set_process(count > 0)
		queue_redraw()

	func _spawn(anywhere: bool) -> Vector4:
		var w := maxf(size.x, 1.0)
		var h := maxf(size.y, 1.0)
		var falls := kind in ["petal", "snow", "leaf"]
		var y := _rng.randf() * h if anywhere else (-4.0 if falls else h + 4.0)
		return Vector4(_rng.randf() * w, y, _rng.randf(), _rng.randf_range(0.6, 1.4))

	func _process(delta: float) -> void:
		_time += delta
		var h := size.y
		for i: int in count:
			var p := _p[i]
			match kind:
				"petal", "snow":
					p.y += delta * (10.0 if kind == "snow" else 14.0) * p.w
					p.x += sin(_time * 1.6 + p.z * 9.0) * delta * 8.0
				"leaf":
					p.y += delta * 9.0 * p.w
					p.x += delta * 18.0 * p.w
				_:
					p.y -= delta * (9.0 if kind == "smoke" else 13.0) * p.w
					p.x += sin(_time * 1.3 + p.z * 7.0) * delta * 4.0
			if p.y < -6.0 or p.y > h + 6.0 or p.x > size.x + 6.0:
				p = _spawn(false)
				if kind == "leaf":
					p.x = -4.0
					p.y = _rng.randf() * h
			_p[i] = p
		queue_redraw()

	func _draw() -> void:
		for i: int in count:
			var p := _p[i]
			var at := Vector2(roundf(p.x), roundf(p.y))
			var tw := 0.55 + 0.45 * sin(_time * 4.0 + p.z * 20.0)
			match kind:
				"petal":
					draw_rect(Rect2(at, Vector2(2, 1)), Color(color, 0.85))
					draw_rect(Rect2(at + Vector2(1, 1), Vector2(1, 1)), Color(color.darkened(0.2), 0.85))
				"snow":
					draw_rect(Rect2(at, Vector2(1, 1)), Color(color, 0.9))
					if p.z > 0.6:
						draw_rect(Rect2(at + Vector2(-1, 0), Vector2(3, 1)), Color(color, 0.35))
						draw_rect(Rect2(at + Vector2(0, -1), Vector2(1, 3)), Color(color, 0.35))
				"leaf":
					draw_rect(Rect2(at, Vector2(2, 1)), Color(color, 0.8))
					draw_rect(Rect2(at + Vector2(1, -1), Vector2(1, 1)), Color(color.lightened(0.2), 0.8))
				"smoke":
					var life := clampf(p.y / maxf(size.y, 1.0), 0.0, 1.0)
					draw_circle(at, 1.5 + (1.0 - life) * 3.0, Color(color, 0.12 * life))
				"wisp":
					draw_circle(at, 2.5, Color(color, 0.18 * tw))
					draw_rect(Rect2(at, Vector2(1, 1)), Color(color.lightened(0.5), 0.9 * tw))
				"spark":
					draw_rect(Rect2(at, Vector2(1, 1)), Color(color, tw))
					if tw > 0.9:
						draw_rect(Rect2(at + Vector2(-1, 0), Vector2(3, 1)), Color(color, 0.4))
				_:
					var a := clampf(p.y / maxf(size.y, 1.0), 0.0, 1.0)
					draw_rect(Rect2(at, Vector2(1, 1 + int(p.z > 0.7))), Color(color, a * tw))
