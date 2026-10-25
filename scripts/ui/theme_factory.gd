class_name ThemeFactory
extends RefCounted
## Tema de madeira do Ninja Adventure (plano 7 e 12.2), montado em código a partir das
## texturas nine-patch do pacote, com a fonte pixel do idioma atual (plano 7.7.2).

const DIR := "res://assets/art/ui/theme_wood/"
const FONT_SIZE := 12
const TEXT := Color("fff4e0")
const TEXT_DARK := Color("3b2416")
const ACCENT := Color("ffd166")
## Laca e ouro das telas reformuladas (Guardiões, Opções, Diário, "voltar").
const LACQUER := Color("1d110c")
const LACQUER_LIGHT := Color("3a2317")
const LACQUER_INK := Color(0.05, 0.035, 0.07, 0.86)
const GOLD := Color("d9a441")
const GOLD_DIM := Color(0.85, 0.64, 0.25, 0.45)
const VERMILION := Color("b8322a")
const MUTED := Color("d9c3a0")
const PAPER := Color("eddcb4")
const PAPER_DARK := Color("d8c193")
const PAPER_INK := Color("2a1a10")
const PAPER_INK_SOFT := Color("5a4030")
const RED_INK := Color("9e2a1e")

static var _cache: Theme
static var _cache_lang: String = ""


static func build() -> Theme:
	if _cache and _cache_lang == Locale.current:
		return _cache
	var theme := Theme.new()
	theme.default_font = Locale.font
	theme.default_font_size = FONT_SIZE
	var button := _box("button_normal.png", 4, 3)
	var hover := _box("button_hover.png", 4, 3)
	var pressed := _box("button_pressed.png", 4, 3)
	var disabled := _box("button_disabled.png", 4, 3)
	for type: String in ["Button", "OptionButton", "CheckButton"]:
		theme.set_stylebox("normal", type, button)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("disabled", type, disabled)
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, ACCENT)
		theme.set_color("font_disabled_color", type, Color(0.75, 0.7, 0.65))
		theme.set_constant("outline_size", type, 3)
		theme.set_color("font_outline_color", type, Color(0.15, 0.08, 0.05))
	theme.set_stylebox("panel", "Panel", _box("nine_path_bg.png", 5, 5))
	theme.set_stylebox("panel", "PanelContainer", _box("nine_path_bg.png", 5, 6))
	theme.set_color("font_color", "Label", TEXT)
	theme.set_constant("outline_size", "Label", 3)
	theme.set_color("font_outline_color", "Label", Color(0.1, 0.05, 0.05))
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_constant("outline_size", "RichTextLabel", 2)
	theme.set_color("font_outline_color", "RichTextLabel", Color(0.1, 0.05, 0.05))
	theme.set_font("normal_font", "RichTextLabel", Locale.font)
	theme.set_font_size("normal_font_size", "RichTextLabel", FONT_SIZE)
	theme.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	var progress_bg := _box("nine_path_bg_2.png", 3, 0)
	var progress_fill := _box("slider_progress.png", 3, 0)
	theme.set_stylebox("background", "ProgressBar", progress_bg)
	theme.set_stylebox("fill", "ProgressBar", progress_fill)
	theme.set_stylebox("slider", "HSlider", progress_bg)
	theme.set_stylebox("grabber_area", "HSlider", progress_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", progress_fill)
	theme.set_icon("grabber", "HSlider", load(DIR + "h_slidder_grabber.png") as Texture2D)
	theme.set_icon("grabber_highlight", "HSlider", load(DIR + "h_slidder_grabber_hover.png") as Texture2D)
	theme.set_stylebox("panel", "TabContainer", _box("nine_path_bg.png", 5, 5))
	# A textura da aba selecionada tem miolo branco, que some com o texto claro: aba
	# selecionada lisa e escura com borda de destaque; o texto claro lê bem em qualquer
	# estado (no Android a aba tocada pode ficar com a cor de "não selecionada").
	var tab_on := StyleBoxFlat.new()
	tab_on.bg_color = Color("7a3b1c")
	tab_on.border_color = ACCENT
	tab_on.set_border_width_all(1)
	tab_on.border_width_bottom = 0
	tab_on.content_margin_left = 6
	tab_on.content_margin_right = 6
	tab_on.content_margin_top = 3
	tab_on.content_margin_bottom = 3
	theme.set_stylebox("tab_selected", "TabContainer", tab_on)
	theme.set_stylebox("tab_unselected", "TabContainer", _box("tab_unselected.png", 4, 3))
	theme.set_stylebox("tab_hovered", "TabContainer", _box("tab_hover.png", 4, 3))
	theme.set_color("font_selected_color", "TabContainer", ACCENT)
	theme.set_color("font_hovered_color", "TabContainer", Color.WHITE)
	theme.set_color("font_unselected_color", "TabContainer", TEXT)
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	theme.set_icon("checked", "CheckBox", load(DIR + "checked.png") as Texture2D)
	theme.set_icon("unchecked", "CheckBox", load(DIR + "unchecked.png") as Texture2D)
	theme.set_icon("checked", "CheckButton", load(DIR + "button_checked.png") as Texture2D)
	theme.set_icon("unchecked", "CheckButton", load(DIR + "button_unchecked.png") as Texture2D)
	theme.set_color("font_color", "CheckBox", TEXT)
	theme.set_color("font_color", "CheckButton", TEXT)
	_cache = theme
	_cache_lang = Locale.current
	return theme


static func card_box() -> StyleBoxTexture:
	return _box("nine_path_panel.png", 6, 6)


static func card_box_hover() -> StyleBoxTexture:
	return _box("nine_path_panel_3.png", 6, 6)


static func dark_box() -> StyleBoxTexture:
	return _box("nine_path_bg_2.png", 5, 5)


static func _box(file: String, margin: int, content: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(DIR + file) as Texture2D
	box.texture_margin_left = margin
	box.texture_margin_right = margin
	box.texture_margin_top = margin
	box.texture_margin_bottom = margin
	box.content_margin_left = margin + content
	box.content_margin_right = margin + content
	box.content_margin_top = margin + maxi(0, content - 2)
	box.content_margin_bottom = margin + maxi(0, content - 2)
	return box


# --- Laca e ouro (Guardiões, Opções, Diário e botão "voltar") ---------------------------
# Estilos acrescentados para as telas reformuladas; não mudam o tema base acima.


## Caixa lisa com borda, cantos e margens (base de todos os estilos de laca).
static func flat_box(bg: Color, border: Color, width: int = 1, radius: int = 3, pad: Vector2 = Vector2(6, 2)
		) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad.x
	box.content_margin_right = pad.x
	box.content_margin_top = pad.y
	box.content_margin_bottom = pad.y
	box.anti_aliasing = false
	return box


## Painel de laca escura com filete dourado e sombra curta.
static func lacquer_panel(alpha: float = 0.9) -> StyleBoxFlat:
	var box := flat_box(Color(LACQUER_INK, alpha), Color(GOLD, 0.55), 1, 4, Vector2(8, 6))
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 2
	box.shadow_offset = Vector2(0, 2)
	return box


## Página de pergaminho (Diário): papel claro, borda de madeira.
static func paper_panel() -> StyleBoxFlat:
	var box := flat_box(PAPER, Color("6b4a2a"), 1, 2, Vector2(8, 6))
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 3
	box.shadow_offset = Vector2(0, 2)
	return box


## Botão secundário de laca: [normal, hover, pressed, disabled].
static func lacquer_button_boxes() -> Array[StyleBoxFlat]:
	var normal := flat_box(Color(0.09, 0.05, 0.06, 0.88), Color(GOLD, 0.6), 1, 3, Vector2(8, 2))
	var hover := flat_box(Color(0.22, 0.08, 0.07, 0.92), Color(ACCENT, 0.95), 1, 3, Vector2(8, 2))
	var pressed := flat_box(Color(0.05, 0.02, 0.03, 0.95), Color(ACCENT, 0.8), 1, 3, Vector2(8, 2))
	pressed.content_margin_top = 3
	pressed.content_margin_bottom = 1
	var disabled := flat_box(Color(0.08, 0.06, 0.07, 0.6), Color(GOLD, 0.22), 1, 3, Vector2(8, 2))
	for box: StyleBoxFlat in [normal, hover]:
		box.shadow_color = Color(0, 0, 0, 0.4)
		box.shadow_size = 1
		box.shadow_offset = Vector2(0, 2)
	return [normal, hover, pressed, disabled]


## Botão principal vermelhão com borda de ouro: [normal, hover, pressed, disabled].
static func primary_button_boxes() -> Array[StyleBoxFlat]:
	var normal := flat_box(Color("c0392b"), ACCENT, 2, 3, Vector2(10, 1))
	var hover := flat_box(Color("c0392b").lightened(0.14), ACCENT.lightened(0.3), 2, 3, Vector2(10, 1))
	var pressed := flat_box(Color("c0392b").darkened(0.25), ACCENT.darkened(0.15), 2, 3, Vector2(10, 1))
	pressed.content_margin_top = 2
	pressed.content_margin_bottom = 0
	var disabled := flat_box(Color(0.25, 0.16, 0.15, 0.9), Color(GOLD, 0.35), 2, 3, Vector2(10, 1))
	for box: StyleBoxFlat in [normal, hover, disabled]:
		box.shadow_color = Color(0, 0, 0, 0.5)
		box.shadow_size = 1
		box.shadow_offset = Vector2(0, 2)
	return [normal, hover, pressed, disabled]


## Aplica [normal, hover, pressed, disabled] e o anel de foco num botão.
static func apply_button_boxes(b: Button, boxes: Array[StyleBoxFlat]) -> void:
	b.add_theme_stylebox_override("normal", boxes[0])
	b.add_theme_stylebox_override("hover", boxes[1])
	b.add_theme_stylebox_override("pressed", boxes[2])
	b.add_theme_stylebox_override("hover_pressed", boxes[2])
	b.add_theme_stylebox_override("disabled", boxes[3])
	b.add_theme_stylebox_override("focus", focus_ring())


static func focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = Color(1.0, 0.93, 0.75, 0.85)
	ring.set_border_width_all(1)
	ring.set_corner_radius_all(4)
	ring.set_expand_margin_all(2)
	return ring


## Trilho de laca e preenchimento vermelhão→ouro das barras de volume.
static func slider_boxes() -> Array[StyleBoxFlat]:
	var track := flat_box(Color(0.03, 0.02, 0.03, 0.95), Color(GOLD, 0.45), 1, 3, Vector2(0, 3))
	var fill := flat_box(Color("c0392b"), Color(ACCENT, 0.9), 1, 3, Vector2(0, 3))
	var fill_hot := flat_box(Color("d9452f"), ACCENT, 1, 3, Vector2(0, 3))
	return [track, fill, fill_hot]


## Barra de rolagem fina dourada.
static func style_scrollbar(bar: ScrollBar) -> void:
	bar.add_theme_stylebox_override("scroll", flat_box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 2, Vector2(2, 2)))
	var grab := flat_box(Color(GOLD, 0.55), Color(0, 0, 0, 0), 0, 2, Vector2(2, 8))
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", flat_box(Color(ACCENT, 0.8), Color(0, 0, 0, 0), 0, 2,
			Vector2(2, 8)))
	bar.add_theme_stylebox_override("grabber_pressed", flat_box(ACCENT, Color(0, 0, 0, 0), 0, 2, Vector2(2, 8)))
	bar.custom_minimum_size.x = 4
