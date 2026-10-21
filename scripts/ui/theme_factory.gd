class_name ThemeFactory
extends RefCounted
## Tema de madeira do Ninja Adventure (plano 7 e 12.2), montado em código a partir das
## texturas nine-patch do pacote, com a fonte pixel do idioma atual (plano 7.7.2).

const DIR := "res://assets/art/ui/theme_wood/"
const FONT_SIZE := 12
const TEXT := Color("fff4e0")
const TEXT_DARK := Color("3b2416")
const ACCENT := Color("ffd166")

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
