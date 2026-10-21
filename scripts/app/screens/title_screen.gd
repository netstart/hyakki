extends Screen
## Título (plano 7.3): Jogar, Desafio Diário, Santuário, Loja, Diário, Opções e Créditos.

var _shop_button: Button
var _ryo: Label
var _daily: Button
var _continue: Button


func _ready() -> void:
	var title := title_label("HYAKKI")
	title.add_theme_font_size_override("font_size", 48)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 14
	title.offset_left = -200
	title.offset_right = 200
	add_child(title)
	var subtitle := label(tr("title.subtitle"), 12, HORIZONTAL_ALIGNMENT_CENTER)
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.offset_top = 70
	subtitle.offset_left = -200
	subtitle.offset_right = 200
	add_child(subtitle)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 5)
	left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left.offset_left = 14
	left.offset_top = -160
	left.offset_bottom = -12
	left.offset_right = 170
	left.alignment = BoxContainer.ALIGNMENT_END
	add_child(left)
	left.add_child(button(tr("title.sanctuary"), func() -> void: app.go(&"sanctuary")))
	_shop_button = button(tr("title.shop"), func() -> void: app.go(&"shop"))
	left.add_child(_shop_button)
	left.add_child(button(tr("title.codex"), func() -> void: app.go(&"codex")))
	left.add_child(button(tr("title.options"), func() -> void: app.go(&"options")))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right.offset_left = -190
	right.offset_right = -14
	right.offset_top = -120
	right.offset_bottom = -12
	right.alignment = BoxContainer.ALIGNMENT_END
	add_child(right)
	# Partida suspensa (plano 10.11): só aparece se o app foi fechado no meio de uma partida.
	_continue = button(tr("title.continue"), func() -> void: app.continue_run(), Vector2(176, 30))
	right.add_child(_continue)
	_daily = button(tr("title.daily"), func() -> void: app.start_run(true), Vector2(176, 30))
	right.add_child(_daily)
	var play := button(tr("title.play"), func() -> void: app.go(&"heroes"), Vector2(176, 44))
	play.add_theme_font_size_override("font_size", 24)
	right.add_child(play)
	_ryo = label("", 12, HORIZONTAL_ALIGNMENT_RIGHT)
	_ryo.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_ryo.offset_left = -200
	_ryo.offset_right = -12
	_ryo.offset_top = 10
	add_child(_ryo)
	var credits := button(tr("title.credits"), func() -> void: app.go(&"credits"), Vector2(90, 26))
	credits.set_anchors_preset(Control.PRESET_TOP_LEFT)
	credits.position = Vector2(10, 10)
	add_child(credits)


func on_show() -> void:
	_continue.visible = app.has_suspended_run()
	_ryo.text = "%s %s" % [tr("hud.ryo"), Locale.format_number(SaveManager.ryo())]
	_shop_button.text = tr("title.shop") + (" (!)" if ShopManager.any_ready() else "")
	var daily: Dictionary = SaveManager.data["daily"]
	_daily.text = tr("title.daily") + ("  (OK)" if String(daily["date"]) == Time.get_date_string_from_system() else "")


func on_back() -> void:
	SaveManager.save_profile()
	get_tree().quit()
