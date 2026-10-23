extends Screen
## Opções (plano 7.5 e 17.5): idioma (com o nome de cada idioma escrito nele mesmo),
## volumes, vibração, joystick, FPS, acessibilidade, privacidade e anúncios, compras,
## créditos, licenças e apagar o progresso.
##
## Layout compacto (viewport 678x305): as opções ficam em 4 seções curtas, cada uma com um
## título pequeno e uma grade de 2 colunas. Cada célula é rótulo + controle: chave
## (CheckButton), volume (barra + porcentagem), escolha (OptionButton) ou botões. Os rótulos
## quebram linha (sem reticências): a célula cresce na altura para o idioma mais longo.
## Controles com pelo menos ROW_HEIGHT de altura para o toque. O que não cabe rola com o
## dedo: rótulos, títulos e espaços entre os controles deixam o arrasto chegar à rolagem.
## Cada controle tem o nome "opt_<chave>" (os testes o acham por ele).

const CONTENT_TOP := 40.0
const ROW_HEIGHT := 28.0
const ROW_GAP := 4
const COLUMN_GAP := 12
const CELL_GAP := 6
const SECTION_TITLE_HEIGHT := 18.0
## Rótulo das escolhas e dos botões; quebra em 2 ou 3 linhas nos idiomas longos.
const LABEL_WIDTH := 104.0
const SLIDER_LABEL_WIDTH := 84.0
const PERCENT_WIDTH := 34.0
const SCROLL_DEADZONE := 8

var _scroll: ScrollContainer
var _content: VBoxContainer


func _ready() -> void:
	add_child(back_button())
	var title := title_label(tr("options.title"))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -150
	title.offset_right = 150
	title.offset_top = 6
	add_child(title)
	var margin := content_box(CONTENT_TOP)
	_scroll = ScrollContainer.new()
	_scroll.name = "opt_scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = SCROLL_DEADZONE
	margin.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", ROW_GAP)
	_scroll.add_child(_content)

	var audio := _section(tr("options.section_audio"))
	audio.add_child(_language_cell())
	for key: String in ["music_volume", "sfx_volume", "ui_volume"]:
		audio.add_child(_slider_cell(key))
	for key: String in ["damage_sounds", "hurt_sounds"]:
		audio.add_child(_toggle_cell(key))

	var controls := _section(tr("options.section_controls"))
	controls.add_child(_choice_cell("joystick_mode",
			[["floating", "options.joystick_floating"], ["fixed", "options.joystick_fixed"]]))
	controls.add_child(_choice_cell("joystick_side",
			[["left", "options.side_left"], ["right", "options.side_right"]]))
	controls.add_child(_toggle_cell("vibration"))
	controls.add_child(_choice_cell("fps",
			[[30, "options.fps30"], [60, "options.fps60"], [120, "options.fps120"]]))

	var display := _section(tr("options.section_display"))
	for key: String in ["colorblind", "reduce_flashes", "damage_numbers", "hp_bar_below"]:
		display.add_child(_toggle_cell(key))

	var account := _section(tr("options.section_account"))
	account.add_child(_toggle_cell("notifications"))
	account.add_child(_button_cell("privacy", tr("options.privacy"),
			[button(tr("options.privacy_open"), _open_privacy, Vector2(0, ROW_HEIGHT))]))
	account.add_child(_button_cell("restore", tr("options.purchases"),
			[button(tr("shop.restore"), func() -> void: PurchaseManager.restore(), Vector2(0, ROW_HEIGHT))]))
	var credits := button(tr("title.credits"), func() -> void: app.go(&"credits"), Vector2(0, ROW_HEIGHT))
	credits.name = "opt_credits"
	var licenses := button(tr("options.licenses"), func() -> void: app.go(&"licenses"), Vector2(0, ROW_HEIGHT))
	licenses.name = "opt_licenses"
	account.add_child(_button_cell("about", tr("options.about"), [credits, licenses]))
	_add_reset_row()


## Título pequeno da seção e a grade de 2 colunas onde vão as células.
func _section(text: String) -> GridContainer:
	var header := label(text, 12)
	header.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	header.custom_minimum_size.y = SECTION_TITLE_HEIGHT
	header.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(header)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", COLUMN_GAP)
	grid.add_theme_constant_override("v_separation", ROW_GAP)
	_content.add_child(grid)
	return grid


## Célula vazia com o rótulo (largura fixa, ou o que sobrar se width = 0).
func _cell(text: String, width: float) -> HBoxContainer:
	var cell := HBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.custom_minimum_size.y = ROW_HEIGHT
	cell.add_theme_constant_override("separation", CELL_GAP)
	var l := label(text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0.0:
		l.custom_minimum_size.x = width
	else:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_child(l)
	return cell


func _toggle_cell(key: String) -> HBoxContainer:
	var cell := _cell(tr("options.%s" % key), 0.0)
	var check := CheckButton.new()
	check.name = "opt_%s" % key
	check.custom_minimum_size.y = ROW_HEIGHT
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	check.button_pressed = bool(Settings.get_value(key))
	check.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	cell.add_child(check)
	return cell


func _slider_cell(key: String) -> HBoxContainer:
	var cell := _cell(tr("options.%s" % key), SLIDER_LABEL_WIDTH)
	var slider := HSlider.new()
	slider.name = "opt_%s" % key
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(Settings.get_value(key))
	slider.custom_minimum_size = Vector2(60, ROW_HEIGHT)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(slider)
	var percent := label("", 12, HORIZONTAL_ALIGNMENT_RIGHT)
	percent.name = "opt_%s_value" % key
	percent.custom_minimum_size.x = PERCENT_WIDTH
	percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	percent.size_flags_vertical = Control.SIZE_FILL
	percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	percent.text = "%d%%" % roundi(slider.value * 100.0)
	cell.add_child(percent)
	slider.value_changed.connect(func(v: float) -> void:
		percent.text = "%d%%" % roundi(v * 100.0)
		Settings.set_value(key, v))
	return cell


func _language_cell() -> HBoxContainer:
	var cell := _cell(tr("options.language"), LABEL_WIDTH)
	var lang := _option_button("language")
	for code: String in Locale.SUPPORTED:
		lang.add_item(Locale.NATIVE_NAMES[code])
		lang.set_item_metadata(lang.item_count - 1, code)
		if code == Locale.current:
			lang.selected = lang.item_count - 1
	lang.item_selected.connect(func(index: int) -> void: Locale.set_language(String(lang.get_item_metadata(index))))
	cell.add_child(lang)
	return cell


func _choice_cell(key: String, options: Array) -> HBoxContainer:
	var cell := _cell(tr("options.%s" % key), LABEL_WIDTH)
	var option := _option_button(key)
	for entry: Array in options:
		option.add_item(tr(String(entry[1])))
		option.set_item_metadata(option.item_count - 1, entry[0])
		if str(entry[0]) == str(Settings.get_value(key)):
			option.selected = option.item_count - 1
	option.item_selected.connect(func(index: int) -> void: Settings.set_value(key, option.get_item_metadata(index)))
	cell.add_child(option)
	return cell


func _option_button(key: String) -> OptionButton:
	var option := OptionButton.new()
	option.name = "opt_%s" % key
	option.custom_minimum_size.y = ROW_HEIGHT
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return option


## Rótulo + um ou mais botões dividindo o resto da célula.
func _button_cell(key: String, text: String, buttons: Array) -> HBoxContainer:
	var cell := _cell(text, LABEL_WIDTH)
	for b: Button in buttons:
		if not String(b.name).begins_with("opt_"):
			b.name = "opt_%s" % key
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(b)
	return cell


## Apagar o progresso (dois toques) e a versão, numa linha de largura inteira. O botão tem a
## largura do mais longo dos seus três textos (medidos já na árvore, com a fonte do tema),
## para não mudar de tamanho ao confirmar.
func _add_reset_row() -> void:
	var row := _cell(tr("options.reset"), LABEL_WIDTH)
	_content.add_child(row)
	var reset := button(tr("options.reset_button"), Callable(), Vector2(0, ROW_HEIGHT))
	reset.name = "opt_reset"
	reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(reset)
	var widest := 0.0
	for key: String in ["options.reset_confirm", "options.reset_done", "options.reset_button"]:
		reset.text = tr(key)
		widest = maxf(widest, reset.get_combined_minimum_size().x)
	reset.custom_minimum_size.x = widest
	reset.pressed.connect(func() -> void:
		if reset.has_meta("armed"):
			SaveManager.reset_profile()
			reset.text = tr("options.reset_done")
			reset.remove_meta("armed")
		else:
			reset.set_meta("armed", true)
			reset.text = tr("options.reset_confirm"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var version := label("%s %s" % [tr("options.version"),
			String(ProjectSettings.get_setting("application/config/version", "0.1.0"))])
	version.name = "opt_version"
	version.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	version.size_flags_vertical = Control.SIZE_FILL
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(version)


## AdMob: formulário de privacidade do Google (UMP); simulado: a tela própria.
func _open_privacy() -> void:
	if not AdsManager.open_privacy_options(func() -> void: pass):
		app.go(&"consent")
