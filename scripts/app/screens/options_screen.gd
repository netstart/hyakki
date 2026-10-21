extends Screen
## Opções (plano 7.5 e 17.5): idioma (com o nome de cada idioma escrito nele mesmo),
## volumes, vibração, joystick, FPS, acessibilidade, privacidade e anúncios, compras,
## créditos, licenças e apagar o progresso.


func _ready() -> void:
	add_child(back_button())
	var title := title_label(tr("options.title"))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -150
	title.offset_right = 150
	title.offset_top = 6
	add_child(title)
	var margin := content_box(44.0)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	grid.add_child(label(tr("options.language")))
	var lang := OptionButton.new()
	lang.custom_minimum_size = Vector2(220, 28)
	for code: String in Locale.SUPPORTED:
		lang.add_item(Locale.NATIVE_NAMES[code])
		lang.set_item_metadata(lang.item_count - 1, code)
		if code == Locale.current:
			lang.selected = lang.item_count - 1
	lang.item_selected.connect(func(index: int) -> void: Locale.set_language(String(lang.get_item_metadata(index))))
	grid.add_child(lang)

	for key: String in ["music_volume", "sfx_volume", "ui_volume"]:
		grid.add_child(label(tr("options.%s" % key)))
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(Settings.get_value(key))
		slider.custom_minimum_size = Vector2(220, 24)
		slider.value_changed.connect(func(v: float) -> void: Settings.set_value(key, v))
		grid.add_child(slider)

	_choice(grid, "joystick_mode", [["floating", "options.joystick_floating"], ["fixed", "options.joystick_fixed"]])
	_choice(grid, "joystick_side", [["left", "options.side_left"], ["right", "options.side_right"]])
	_choice(grid, "fps", [[30, "options.fps30"], [60, "options.fps60"], [120, "options.fps120"]])
	for key: String in ["vibration", "colorblind", "reduce_flashes", "damage_numbers", "hp_bar_below", "notifications"]:
		grid.add_child(label(tr("options.%s" % key)))
		var check := CheckButton.new()
		check.button_pressed = bool(Settings.get_value(key))
		check.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
		grid.add_child(check)

	grid.add_child(label(tr("options.privacy")))
	grid.add_child(button(tr("options.privacy_open"), func() -> void: app.go(&"consent"), Vector2(220, 28)))
	grid.add_child(label(tr("options.purchases")))
	grid.add_child(button(tr("shop.restore"), func() -> void: PurchaseManager.restore(), Vector2(220, 28)))
	grid.add_child(label(tr("options.about")))
	var about := HBoxContainer.new()
	about.add_child(button(tr("title.credits"), func() -> void: app.go(&"credits"), Vector2(108, 28)))
	about.add_child(button(tr("options.licenses"), func() -> void: app.go(&"licenses"), Vector2(108, 28)))
	grid.add_child(about)
	grid.add_child(label(tr("options.reset")))
	var reset := button(tr("options.reset_button"), Callable(), Vector2(220, 28))
	reset.pressed.connect(func() -> void:
		if reset.has_meta("armed"):
			SaveManager.reset_profile()
			reset.text = tr("options.reset_done")
			reset.remove_meta("armed")
		else:
			reset.set_meta("armed", true)
			reset.text = tr("options.reset_confirm"))
	grid.add_child(reset)
	grid.add_child(label(tr("options.version")))
	grid.add_child(label(String(ProjectSettings.get_setting("application/config/version", "0.1.0"))))


func _choice(grid: GridContainer, key: String, options: Array) -> void:
	grid.add_child(label(tr("options.%s" % key)))
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(220, 28)
	for entry: Array in options:
		option.add_item(tr(String(entry[1])))
		option.set_item_metadata(option.item_count - 1, entry[0])
		if str(entry[0]) == str(Settings.get_value(key)):
			option.selected = option.item_count - 1
	option.item_selected.connect(func(index: int) -> void: Settings.set_value(key, option.get_item_metadata(index)))
	grid.add_child(option)
