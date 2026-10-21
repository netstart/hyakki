extends Screen
## Santuário (plano 4.10): power-ups permanentes com preço crescente (comprar qualquer um
## encarece os outros) e reembolso total gratuito.

var _grid: GridContainer
var _ryo: Label
var _info: Label


func _ready() -> void:
	add_child(back_button())
	var title := title_label(tr("sanctuary.title"))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -150
	title.offset_right = 150
	title.offset_top = 6
	add_child(title)
	_ryo = label("", 12, HORIZONTAL_ALIGNMENT_RIGHT)
	_ryo.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_ryo.offset_left = -220
	_ryo.offset_right = -12
	_ryo.offset_top = 12
	add_child(_ryo)
	var margin := content_box(44.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_grid)
	row.add_child(scroll)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(170, 0)
	_info = wrap_label(tr("sanctuary.hint"), 170)
	side.add_child(_info)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	side.add_child(button(tr("sanctuary.refund"), func() -> void:
		var refunded := MetaProgress.refund_all()
		_info.text = tr("sanctuary.refunded") % Locale.format_number(refunded)
		on_show(), Vector2(170, 30)))
	row.add_child(side)


func on_show() -> void:
	_ryo.text = "%s %s" % [tr("hud.ryo"), Locale.format_number(SaveManager.ryo())]
	for child: Node in _grid.get_children():
		child.queue_free()
	for id: StringName in DB.ids("powerups"):
		var data: Dictionary = DB.powerups[id]
		var level := SaveManager.powerup_level(id)
		var maxed := level >= int(data["max"])
		var b := Button.new()
		b.custom_minimum_size = Vector2(66, 62)
		b.icon = load(String(data["icon"])) as Texture2D
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		var price := tr("sanctuary.max") if maxed else Locale.format_number(MetaProgress.powerup_price(id))
		b.text = "%d/%d\n%s" % [level, int(data["max"]), price]
		b.disabled = maxed
		b.add_theme_font_size_override("font_size", 12)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_buy.bind(id))
		b.mouse_entered.connect(_describe.bind(id))
		b.focus_entered.connect(_describe.bind(id))
		_grid.add_child(b)


func _describe(id: StringName) -> void:
	var data: Dictionary = DB.powerups[id]
	_info.text = "%s\n%s" % [tr("powerup.%s.name" % id),
			LevelUpSystem.describe_stats({String(data["stat"]): data["per_level"]}) + " " + tr("sanctuary.per_level")]


func _buy(id: StringName) -> void:
	_describe(id)
	if MetaProgress.buy(id):
		AudioManager.play("coin2")
		on_show()
	else:
		AudioManager.play_ui("ui_cancel")
		_info.text += "\n" + tr("sanctuary.not_enough")
