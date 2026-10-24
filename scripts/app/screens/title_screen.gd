extends Screen
## Título (plano 7.3): festival de yokai à noite. Coluna de menu à esquerda (Santuário,
## Loja, Diário, Opções e Créditos), saldo de ryō no alto à direita e o bloco de ação no
## canto inferior direito (Desafio Diário, Jogar e, com partida suspensa, Continuar).
## O centro fica livre para o torii e a guardiã do fundo (MenuBackdrop).

const JA_FONT := "res://assets/fonts/fusion_pixel_12_ja.woff2"
const COIN_SHEET := "res://assets/art/items/treasure/Coin2.png"
const ROW_SIZE := Vector2(200, 30)
const ROW_GAP := 1.0
const MENU_AT := Vector2(14, 90)
const CTA_WIDTH := 190.0
const PRIMARY_HEIGHT := 46.0
const CARD_HEIGHT := 30.0
const CTA_GAP := 6.0
const VERMILION := Color("c0392b")
const SEAL_RED := Color("b3261e")
const SHADOW := Color(0.08, 0.03, 0.03)
const MUTED := Color("d9c3a0")
const BADGE_RED := Color("e0403a")

var _shop_button: Button
var _ryo: Label
var _daily: Button
var _continue: Button
var _play: Button
var _title: Label
var _title_box: Control
var _chip: Control
var _shop_badge: Control
var _daily_done: Control
var _daily_new: Control
var _cta: Control
var _glow: TextureRect
var _rows: Array[Button] = []
var _row_base: Array[Vector2] = []
var _intro: Tween


func _ready() -> void:
	var shade := TextureRect.new()
	shade.texture = _gradient([Color(0, 0, 0, 0.62), Color(0, 0, 0, 0.42), Color(0, 0, 0, 0)],
			[0.0, 0.55, 1.0], Vector2(300, 1))
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 300
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_build_title()
	_build_menu()
	_build_chip()
	_build_cta()
	var version := label("v" + str(ProjectSettings.get_setting("application/config/version")))
	version.add_theme_color_override("font_color", Color(MUTED, 0.45))
	version.add_theme_constant_override("outline_size", 0)
	version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version.offset_left = 18
	version.offset_top = -20
	version.offset_bottom = -4
	add_child(version)
	_start_loops()


func on_show() -> void:
	_continue.visible = app.has_suspended_run()
	_ryo.text = Locale.format_number(SaveManager.ryo())
	_shop_badge.visible = ShopManager.any_ready()
	var done := String((SaveManager.data["daily"] as Dictionary)["date"]) == Time.get_date_string_from_system()
	_daily_done.visible = done
	_daily_new.visible = not done
	_daily.self_modulate = Color(1, 1, 1, 0.72) if done else Color.WHITE
	_layout_cta()
	_play_intro()
	_primary().grab_focus()


func on_back() -> void:
	SaveManager.save_profile()
	get_tree().quit()


## Botão principal do bloco de ação: Continuar quando há partida suspensa, senão Jogar.
func _primary() -> Button:
	return _continue if _continue.visible else _play


func _build_title() -> void:
	_title_box = Control.new()
	_title_box.position = Vector2(18, 8)
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_box)
	_title = label("HYAKKI", 48)
	_title.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	_title.add_theme_color_override("font_outline_color", SHADOW)
	_title.add_theme_constant_override("outline_size", 8)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_title.add_theme_constant_override("shadow_offset_x", 2)
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_title.add_theme_constant_override("shadow_outline_size", 8)
	_title_box.add_child(_title)
	var title_size := _title.get_minimum_size()
	_title.size = title_size
	var seal := PanelContainer.new()
	var seal_box := StyleBoxFlat.new()
	seal_box.bg_color = SEAL_RED
	seal_box.border_color = SEAL_RED.darkened(0.45)
	seal_box.set_border_width_all(1)
	seal_box.set_corner_radius_all(2)
	seal_box.content_margin_left = 3
	seal_box.content_margin_right = 2
	seal_box.content_margin_top = 1
	seal_box.content_margin_bottom = 2
	seal.add_theme_stylebox_override("panel", seal_box)
	var kanji := Label.new()
	kanji.text = "百\n鬼"
	kanji.add_theme_font_override("font", load(JA_FONT) as Font)
	kanji.add_theme_color_override("font_color", Color("fbe6cf"))
	kanji.add_theme_constant_override("outline_size", 0)
	kanji.add_theme_constant_override("line_spacing", -2)
	seal.add_child(kanji)
	seal.position = Vector2(title_size.x + 2, 12)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_box.add_child(seal)
	var caption := HBoxContainer.new()
	caption.add_theme_constant_override("separation", 5)
	caption.alignment = BoxContainer.ALIGNMENT_BEGIN
	caption.position = Vector2(2, title_size.y - 8)
	caption.add_child(_rule(14))
	var subtitle := label(tr("title.subtitle"))
	subtitle.add_theme_color_override("font_color", MUTED)
	subtitle.add_theme_color_override("font_outline_color", SHADOW)
	caption.add_child(subtitle)
	caption.add_child(_rule(28))
	_title_box.add_child(caption)
	_title_box.size = Vector2(maxf(title_size.x + 30, caption.get_combined_minimum_size().x),
			caption.position.y + caption.get_combined_minimum_size().y)


func _rule(width: float) -> Control:
	var holder := CenterContainer.new()
	var line := ColorRect.new()
	line.color = Color(ThemeFactory.ACCENT, 0.5)
	line.custom_minimum_size = Vector2(width, 1)
	holder.add_child(line)
	return holder


func _build_menu() -> void:
	var menu := Control.new()
	menu.position = MENU_AT
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu)
	var items := [
		["res://assets/art/items/object/Gourd.png", tr("title.sanctuary"), func() -> void: app.go(&"sanctuary")],
		["res://assets/art/items/object/MoneyBag.png", tr("title.shop"), func() -> void: app.go(&"shop")],
		["res://assets/art/items/object/Book.png", tr("title.codex"), func() -> void: app.go(&"codex")],
		[_gear_icon(), tr("title.options"), func() -> void: app.go(&"options")],
		["res://assets/art/items/resource/feather.png", tr("title.credits"), func() -> void: app.go(&"credits")],
	]
	var y := 0.0
	for i: int in items.size():
		var item: Array = items[i]
		if i == items.size() - 1:
			var divider := ColorRect.new()
			divider.color = Color(ThemeFactory.ACCENT, 0.22)
			divider.position = Vector2(12, y + 2)
			divider.size = Vector2(ROW_SIZE.x - 40, 1)
			menu.add_child(divider)
			y += 5
		var row := _menu_item(item[0], item[1], item[2])
		row.position = Vector2(0, y)
		menu.add_child(row)
		_rows.append(row)
		_row_base.append(row.position)
		y += ROW_SIZE.y + ROW_GAP
	_rows[-1].add_theme_color_override("font_color", Color(ThemeFactory.TEXT, 0.72))
	_shop_button = _rows[1]
	_shop_badge = Dot.new()
	_shop_badge.color = BADGE_RED
	# Logo depois do texto "Loja", à altura do topo das letras.
	var shop_text := _shop_button.get_theme_font("font").get_string_size(_shop_button.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, _shop_button.get_theme_font_size("font_size")).x
	_shop_badge.position = Vector2(_row_box(0).content_margin_left + shop_text + 4, 7)
	_shop_badge.size = Vector2(8, 8)
	_shop_badge.pivot_offset = Vector2(4, 4)
	_shop_button.add_child(_shop_badge)
	for i: int in _rows.size():
		var row := _rows[i]
		row.focus_neighbor_top = row.get_path_to(_rows[maxi(i - 1, 0)])
		row.focus_neighbor_bottom = row.get_path_to(_rows[mini(i + 1, _rows.size() - 1)])
		row.focus_neighbor_left = row.get_path_to(row)


## Linha do menu: fundo transparente, ícone 16 px, faixa e marcador ao destacar.
func _menu_item(icon: Variant, text: String, action: Callable) -> Button:
	var b := button(text, action, ROW_SIZE)
	b.size = ROW_SIZE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for state: String in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, _row_box(0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", _row_box(1))
	b.add_theme_stylebox_override("hover_pressed", _row_box(1))
	b.add_theme_color_override("font_color", ThemeFactory.TEXT)
	for state: String in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, ThemeFactory.ACCENT)
	var band := TextureRect.new()
	band.name = "Band"
	band.texture = _gradient([Color(0.62, 0.1, 0.07, 0.7), Color(0.45, 0.06, 0.05, 0.35), Color(0.3, 0.02, 0.02, 0)],
			[0.0, 0.55, 1.0], Vector2(64, 1))
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.set_anchors_preset(Control.PRESET_FULL_RECT)
	band.show_behind_parent = true
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.visible = false
	var edge := ColorRect.new()
	edge.color = ThemeFactory.ACCENT
	edge.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	edge.offset_right = 2
	band.add_child(edge)
	b.add_child(band)
	var marker := Marker.new()
	marker.name = "Marker"
	marker.size = Vector2(4, 7)
	marker.position = Vector2(5, 12)
	marker.modulate.a = 0.0
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(marker)
	var rect := icon_rect(icon if icon is String else "", Vector2(16, 16))
	if icon is Texture2D:
		rect.texture = icon
	rect.name = "Icon"
	rect.position = Vector2(14, 7)
	rect.size = Vector2(16, 16)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(rect)
	b.focus_entered.connect(_highlight.bind(b, true))
	b.focus_exited.connect(_highlight.bind(b, false))
	b.mouse_entered.connect(b.grab_focus)
	return b


func _row_box(shift: int) -> StyleBoxEmpty:
	var box := StyleBoxEmpty.new()
	box.content_margin_left = 36 + shift
	box.content_margin_right = 22
	box.content_margin_top = shift
	return box


func _highlight(row: Button, on: bool) -> void:
	(row.get_node("Band") as CanvasItem).visible = on
	var marker := row.get_node("Marker") as Control
	var tween := marker.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(marker, "position:x", 5.0 if on else 1.0, 0.12).from(1.0 if on else 5.0)
	tween.tween_property(marker, "modulate:a", 1.0 if on else 0.0, 0.12)


func _build_chip() -> void:
	var chip := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.03, 0.06, 0.62)
	box.border_color = Color(ThemeFactory.ACCENT, 0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(9)
	box.content_margin_left = 6
	box.content_margin_right = 9
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", box)
	chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	chip.offset_right = -14
	chip.offset_top = 10
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var coin := AtlasTexture.new()
	coin.atlas = load(COIN_SHEET) as Texture2D
	coin.region = Rect2(0, 0, 10, 10)
	var icon := TextureRect.new()
	icon.texture = coin
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(10, 16)
	row.add_child(icon)
	_ryo = label("")
	_ryo.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	row.add_child(_ryo)
	chip.add_child(row)
	add_child(chip)
	_chip = chip


func _build_cta() -> void:
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	anchor.offset_left = -16 - CTA_WIDTH
	anchor.offset_right = -16
	anchor.offset_top = -14
	anchor.offset_bottom = -14
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)
	_cta = Control.new()
	_cta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(_cta)
	_glow = TextureRect.new()
	var glow := GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	glow.width = 64
	glow.height = 32
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1.0, 0.5, 0.2, 0.9), Color(1.0, 0.3, 0.1, 0.35), Color(1.0, 0.2, 0.05, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	glow.gradient = ramp
	_glow.texture = glow
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cta.add_child(_glow)
	_daily = button(tr("title.daily"), func() -> void: app.start_run(true), Vector2(CTA_WIDTH, CARD_HEIGHT))
	_daily.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_card(_daily)
	var daily_icon := icon_rect("res://assets/art/items/object/Hourglass.png", Vector2(16, 16))
	daily_icon.position = Vector2(8, 7)
	daily_icon.size = Vector2(16, 16)
	daily_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_daily.add_child(daily_icon)
	_daily_done = Check.new()
	_daily_new = Dot.new()
	(_daily_new as Dot).color = ThemeFactory.ACCENT
	for badge: Control in [_daily_done, _daily_new]:
		var half := 6.0 if badge == _daily_done else 3.0
		badge.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		badge.offset_left = -12 - half
		badge.offset_right = -12 + half
		badge.offset_top = -half
		badge.offset_bottom = half
		badge.pivot_offset = Vector2(half, half)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_daily.add_child(badge)
	_cta.add_child(_daily)
	_play = button(tr("title.play"), func() -> void: app.go(&"heroes"))
	_cta.add_child(_play)
	# Partida suspensa (plano 10.11): só aparece se o app foi fechado no meio de uma partida.
	_continue = button(tr("title.continue"), func() -> void: app.continue_run())
	_cta.add_child(_continue)
	for b: Button in [_play, _continue]:
		var shine := ColorRect.new()
		shine.name = "Shine"
		shine.color = Color(1.0, 0.78, 0.62, 0.4)
		shine.set_anchors_preset(Control.PRESET_TOP_WIDE)
		shine.offset_left = 3
		shine.offset_right = -3
		shine.offset_top = 2
		shine.offset_bottom = 3
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(shine)


## Posições do bloco de ação: o principal fica sempre no canto inferior direito.
func _layout_cta() -> void:
	var stack: Array[Button] = [_daily]
	if _continue.visible:
		_apply_card(_play)
		stack.append_array([_play, _continue])
	else:
		stack.append(_play)
	_apply_primary(_primary())
	# Largura única do bloco: CTA_WIDTH, ou o texto mais largo do idioma (ex.: "Tägliche
	# Herausforderung"). Cresce para a esquerda, então a borda direita fica sempre na tela.
	var width := CTA_WIDTH
	for b: Button in stack:
		b.custom_minimum_size = Vector2.ZERO
		width = maxf(width, ceilf(b.get_minimum_size().x))
	var y := 0.0
	for i: int in range(stack.size() - 1, -1, -1):
		var b := stack[i]
		var h := PRIMARY_HEIGHT if b == _primary() else CARD_HEIGHT
		y -= h
		b.custom_minimum_size = Vector2(width, h)
		b.size = b.custom_minimum_size
		b.position = Vector2(CTA_WIDTH - width, y)
		y -= CTA_GAP
	var main := _primary()
	_glow.position = main.position - Vector2(22, 14)
	_glow.size = main.size + Vector2(44, 28)
	for i: int in stack.size():
		var b := stack[i]
		b.focus_neighbor_top = b.get_path_to(stack[maxi(i - 1, 0)])
		b.focus_neighbor_bottom = b.get_path_to(stack[mini(i + 1, stack.size() - 1)])
		b.focus_neighbor_left = b.get_path_to(_rows[0])
		b.focus_neighbor_right = b.get_path_to(b)
	for row: Button in _rows:
		row.focus_neighbor_right = row.get_path_to(main)


func _apply_primary(b: Button) -> void:
	_set_boxes(b, _flat(VERMILION, ThemeFactory.ACCENT, 2, 0),
			_flat(VERMILION.lightened(0.14), ThemeFactory.ACCENT.lightened(0.3), 2, 0),
			_flat(VERMILION.darkened(0.25), ThemeFactory.ACCENT.darkened(0.15), 2, 1))
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_color_override("font_outline_color", Color(0.25, 0.04, 0.03))
	for state: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color",
			"font_hover_pressed_color"]:
		b.add_theme_color_override(state, Color.WHITE)
	(b.get_node("Shine") as CanvasItem).visible = true


func _apply_card(b: Button) -> void:
	var bg := Color(0.07, 0.04, 0.07, 0.74)
	_set_boxes(b, _flat(bg, Color(ThemeFactory.ACCENT, 0.5), 1, 0),
			_flat(Color(0.2, 0.07, 0.07, 0.85), Color(ThemeFactory.ACCENT, 0.9), 1, 0),
			_flat(Color(0.04, 0.02, 0.03, 0.9), Color(ThemeFactory.ACCENT, 0.7), 1, 1))
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_constant_override("outline_size", 3)
	b.add_theme_color_override("font_color", ThemeFactory.TEXT)
	for state: String in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, ThemeFactory.ACCENT)
	if b == _daily:
		for box: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var style := b.get_theme_stylebox(box) as StyleBoxFlat
			style.content_margin_left += 22
			style.content_margin_right += 16
	if b.has_node("Shine"):
		(b.get_node("Shine") as CanvasItem).visible = false


func _set_boxes(b: Button, normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat) -> void:
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = Color(1.0, 0.93, 0.75, 0.85)
	ring.set_border_width_all(1)
	ring.set_corner_radius_all(4)
	ring.set_expand_margin_all(2)
	b.add_theme_stylebox_override("focus", ring)


func _flat(bg: Color, border: Color, width: int, shift: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(3)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 1 + shift
	box.content_margin_bottom = 1 - shift
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 1
	box.shadow_offset = Vector2(0, 2 - shift)
	return box


## Entrada: título desce, linhas do menu entram da esquerda em cascata e o bloco de ação
## da direita. Volta tudo às posições de base antes, então chamar de novo não acumula.
func _play_intro() -> void:
	if _intro and _intro.is_valid():
		_intro.kill()
	_title_box.position = Vector2(18, 8)
	_cta.position = Vector2.ZERO
	for i: int in _rows.size():
		_rows[i].position = _row_base[i]
	_intro = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro.tween_property(_title_box, "position:y", 8.0, 0.3).from(2.0)
	_intro.tween_property(_title_box, "modulate:a", 1.0, 0.3).from(0.0)
	_intro.tween_property(_chip, "modulate:a", 1.0, 0.3).from(0.0)
	for i: int in _rows.size():
		var row := _rows[i]
		var delay := 0.08 + i * 0.04
		_intro.tween_property(row, "position:x", _row_base[i].x, 0.22).from(_row_base[i].x - 8).set_delay(delay)
		_intro.tween_property(row, "modulate:a", 1.0, 0.22).from(0.0).set_delay(delay)
	_intro.tween_property(_cta, "position:x", 0.0, 0.28).from(8.0).set_delay(0.12)
	_intro.tween_property(_cta, "modulate:a", 1.0, 0.28).from(0.0).set_delay(0.12)


## Termina a entrada na hora (testes e capturas).
func _finish_intro() -> void:
	if _intro and _intro.is_valid():
		_intro.custom_step(1.0)


## Brilho do título, respiração do Jogar e pulso dos selos; "reduzir flashes" deixa parado.
func _start_loops() -> void:
	if bool(Settings.get_value("reduce_flashes")):
		_glow.modulate.a = 0.35
		return
	var shimmer := create_tween().set_loops()
	shimmer.tween_interval(3.5)
	shimmer.tween_property(_title, "modulate", Color(1.35, 1.25, 1.05), 0.35).set_trans(Tween.TRANS_SINE)
	shimmer.tween_property(_title, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)
	var breath := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	breath.tween_property(_glow, "modulate:a", 0.5, 1.3).from(0.25)
	breath.tween_property(_glow, "modulate:a", 0.25, 1.3)
	for badge: Control in [_shop_badge, _daily_new]:
		var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		pulse.tween_property(badge, "scale", Vector2(1.3, 1.3), 0.5).from(Vector2.ONE)
		pulse.tween_property(badge, "scale", Vector2.ONE, 0.5)


static func _gradient(colors: Array[Color], offsets: Array[float], size_px: Vector2) -> GradientTexture2D:
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray(colors)
	ramp.offsets = PackedFloat32Array(offsets)
	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.width = int(size_px.x)
	texture.height = int(size_px.y)
	return texture


## Engrenagem 14x14 no estilo dos itens do Ninja Adventure (o pacote não tem uma).
static func _gear_icon() -> Texture2D:
	var n := 14
	var mask: Array[bool] = []
	var center := Vector2(6.5, 6.5)
	for y: int in n:
		for x: int in n:
			var d := Vector2(x, y) - center
			var phase := fposmod(d.angle() + PI / 8.0, TAU / 8.0) / (TAU / 8.0)
			var outer := 6.8 if phase > 0.3 and phase < 0.7 else 5.0
			mask.append(d.length() <= outer and d.length() >= 1.9)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y: int in n:
		for x: int in n:
			if not mask[y * n + x]:
				continue
			var edge := false
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p := Vector2i(x, y) + o
				if p.x < 0 or p.y < 0 or p.x >= n or p.y >= n or not mask[p.y * n + p.x]:
					edge = true
			var color := Color("4a3a36") if edge else (Color("f0e6d6") if x + y < 12 else Color("b9ab9a"))
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


## Marcador dourado que entra pela esquerda da linha destacada.
class Marker extends Control:
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(4, 3.5), Vector2(0, 7)]), ThemeFactory.ACCENT)


## Selo redondo de aviso (Loja pronta, Desafio Diário novo).
class Dot extends Control:
	var color := Color.RED

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, Color(0.12, 0.03, 0.03))
		draw_circle(c, r - 1.0, color)
		draw_rect(Rect2(c + Vector2(-r * 0.5, -r * 0.5), Vector2(1, 1)), Color(1, 1, 1, 0.7))


## Selo de "feito hoje" do Desafio Diário: quadradinho dourado com o visto desenhado.
class Check extends Control:
	func _draw() -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("2f7d4a")
		box.border_color = ThemeFactory.ACCENT
		box.set_border_width_all(1)
		box.set_corner_radius_all(2)
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		draw_polyline(PackedVector2Array([Vector2(3, 6), Vector2(5, 8.5), Vector2(9, 3.5)]), Color.WHITE, 1.5)
