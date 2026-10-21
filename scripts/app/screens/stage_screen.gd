extends Screen
## Seleção de fase (plano 3.3, 4.13 e 15.3): fase, modo (Brisa / Normal), Lua Vermelha
## I–V (liberada vencendo a anterior) e Noite Sem Fim (depois de vencer a fase).

var _list: VBoxContainer
var _info: Label
var _mode: OptionButton
var _moon: OptionButton
var _endless: CheckButton
var _bonus: Label
var _go: Button
var _suggest: Label


func _ready() -> void:
	add_child(back_button())
	var title := title_label(tr("stages.title"))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -150
	title.offset_right = 150
	title.offset_top = 6
	add_child(title)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.offset_top = 44
	row.offset_bottom = -12
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(220, 0)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 5)
	scroll.add_child(_list)
	row.add_child(scroll)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	row.add_child(side)
	var box := panel()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info = wrap_label("", 360)
	box.add_child(_info)
	side.add_child(box)
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 6)
	_mode = OptionButton.new()
	_mode.add_item(tr("mode.normal"))
	_mode.add_item(tr("mode.brisa"))
	_mode.custom_minimum_size = Vector2(110, 30)
	_mode.item_selected.connect(func(index: int) -> void:
		app.selection["mode"] = "brisa" if index == 1 else "normal"
		_refresh())
	options.add_child(_mode)
	_moon = OptionButton.new()
	_moon.custom_minimum_size = Vector2(120, 30)
	_moon.item_selected.connect(func(index: int) -> void:
		app.selection["moon"] = index
		_refresh())
	options.add_child(_moon)
	_endless = CheckButton.new()
	_endless.text = tr("stages.endless")
	_endless.toggled.connect(func(on: bool) -> void: app.selection["endless"] = on)
	options.add_child(_endless)
	side.add_child(options)
	_bonus = label("", 12)
	side.add_child(_bonus)
	_suggest = wrap_label("", 360)
	_suggest.add_theme_color_override("font_color", Color("b8f2e6"))
	side.add_child(_suggest)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	_go = button(tr("stages.start"), func() -> void: app.start_run(), Vector2(170, 38))
	_go.add_theme_font_size_override("font_size", 24)
	bottom.add_child(_go)
	side.add_child(bottom)


func on_show() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	for id: StringName in DB.ids("stages"):
		var unlocked := MetaProgress.is_stage_unlocked(id)
		var best := SaveManager.stage_best(id)
		var mark := "  *" if bool(best["won"]) else ""
		var b := button(("%d. " % int(DB.stage(id)["order"])) + tr("stage.%s.name" % id) + mark,
				_select.bind(id), Vector2(210, 30))
		b.disabled = not unlocked
		_list.add_child(b)
	var current := StringName(String(app.selection.get("stage", "village")))
	if not MetaProgress.is_stage_unlocked(current):
		current = &"village"
	_mode.selected = 1 if String(app.selection.get("mode", "normal")) == "brisa" else 0
	_select(current)


func _select(id: StringName) -> void:
	app.selection["stage"] = String(id)
	var best := SaveManager.stage_best(id)
	_moon.clear()
	_moon.add_item(tr("moon.none"))
	var max_moon := mini(5, int(best["max_moon"]) + 1) if bool(best["won"]) else 0
	for m: int in range(1, max_moon + 1):
		_moon.add_item(tr("moon.level") % _roman(m))
	var moon := mini(int(app.selection.get("moon", 0)), max_moon)
	_moon.selected = moon
	app.selection["moon"] = moon
	_endless.disabled = not bool(best["won"])
	if _endless.disabled:
		_endless.button_pressed = false
		app.selection["endless"] = false
	else:
		_endless.button_pressed = bool(app.selection.get("endless", false))
	_refresh()


func _refresh() -> void:
	var id := StringName(String(app.selection["stage"]))
	var best := SaveManager.stage_best(id)
	var lines: PackedStringArray = [tr("stage.%s.name" % id), tr("stage.%s.desc" % id), "",
			tr("stages.best") % format_time(float(best["best_time"]))]
	if int(best["max_moon"]) >= 0:
		lines.append(tr("stages.moon_best") % _roman(int(best["max_moon"])))
	var moon := int(app.selection.get("moon", 0))
	if moon > 0:
		lines.append(tr("moon.rule%d" % moon))
	_info.text = "\n".join(lines)
	_moon.disabled = String(app.selection.get("mode", "normal")) == "brisa"
	var pending := ShopManager.pending_next_run()
	var names := pending.map(func(s: Variant) -> String: return tr("shop.%s.name" % s))
	_bonus.text = tr("stages.bonus") % ", ".join(names) if not pending.is_empty() else ""
	# Depois de 5 derrotas seguidas na mesma fase, sugere o modo Brisa (plano 15.3).
	var streak := int((SaveManager.data["defeat_streak"] as Dictionary).get(String(id), 0))
	_suggest.text = tr("stages.suggest_brisa") if streak >= 5 and String(app.selection.get("mode", "")) != "brisa" else ""


static func _roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]
