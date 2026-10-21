extends Screen
## Resultados (plano 7.4 e 15.5): tempo, nível, abates, ryō, tabela por arma (dano e DPS),
## conquistas novas, o próximo desbloqueio mais perto e "Dobrar ryō" por anúncio (17.6).

var _title: Label
var _summary: Label
var _table: GridContainer
var _news: Label
var _next: Label
var _double: Button


func _ready() -> void:
	var margin := content_box(10.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	row.add_child(left)
	_title = title_label("")
	left.add_child(_title)
	_summary = label("", 12, HORIZONTAL_ALIGNMENT_CENTER)
	left.add_child(_summary)
	var box := panel()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_table = GridContainer.new()
	_table.columns = 4
	_table.add_theme_constant_override("h_separation", 12)
	box.add_child(_table)
	left.add_child(box)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(220, 0)
	right.add_theme_constant_override("separation", 6)
	row.add_child(right)
	_news = wrap_label("", 220)
	_news.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	right.add_child(_news)
	_next = wrap_label("", 220)
	right.add_child(_next)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	_double = button(tr("results.double"), _on_double, Vector2(220, 30))
	right.add_child(_double)
	right.add_child(button(tr("results.again"), func() -> void: app.play_again(), Vector2(220, 34)))
	right.add_child(button(tr("results.menu"), func() -> void: app.go(&"title"), Vector2(220, 28)))


func on_show() -> void:
	var r := app.last_result
	if r.is_empty():
		return
	var victory := bool(r["victory"])
	_title.text = tr("results.victory") if victory else tr("results.defeat")
	_summary.text = tr("results.summary") % [format_time(float(r["time"])), int(r["level"]),
			Locale.format_number(int(r["kills"])), Locale.format_number(int(r.get("ryo_earned", 0)))]
	for child: Node in _table.get_children():
		child.queue_free()
	for header: String in ["results.weapon", "results.level", "results.damage", "results.dps"]:
		_table.add_child(label(tr(header), 12))
	for row: Dictionary in r["weapons"]:
		var name_box := HBoxContainer.new()
		name_box.add_child(icon_rect(String(DB.weapon(StringName(row["id"])).get("icon", "")), Vector2(14, 14)))
		name_box.add_child(label(tr("weapon.%s.name" % row["id"])))
		_table.add_child(name_box)
		_table.add_child(label(str(int(row["level"]))))
		_table.add_child(label(Locale.format_number(roundi(float(row["damage"])))))
		_table.add_child(label("%.1f" % float(row["dps"])))
	var news: PackedStringArray = []
	for id: Variant in r.get("new_achievements", []):
		news.append(tr("results.achievement") % tr("achievement.%s.name" % id))
	_news.text = "\n".join(news)
	# Jingle de conquista uma vez por resultado (o on_show roda de novo ao dobrar o ryō).
	if not news.is_empty() and not bool(r.get("achievement_sound_played", false)):
		r["achievement_sound_played"] = true
		AudioManager.play("achievement")
	_next.text = _next_unlock_text()
	_double.visible = int(r.get("ryo_earned", 0)) > 0 and not bool(r.get("doubled", false)) \
			and AdsManager.rewarded_available()
	_double.disabled = false


## Dobra só o ryō desta partida, uma vez (plano 17.6).
func _on_double() -> void:
	_double.disabled = true
	AdsManager.show_rewarded("double_ryo", func(rewarded: bool) -> void:
		if not rewarded:
			_double.disabled = false
			return
		var earned := int(app.last_result.get("ryo_earned", 0))
		SaveManager.add_ryo(earned)
		SaveManager.save_profile()
		app.last_result["ryo_earned"] = earned * 2
		app.last_result["doubled"] = true
		AudioManager.play("jingle_unlock")
		on_show())


## A conquista mais perto de ser completada, com barra de progresso (plano 15.5).
func _next_unlock_text() -> String:
	var stats: Dictionary = SaveManager.data["stats"]
	var best_id := ""
	var best_progress := -1.0
	var best_text := ""
	for id: StringName in DB.ids("achievements"):
		if (SaveManager.data["achievements"] as Dictionary).has(String(id)):
			continue
		var c: Dictionary = DB.achievements[id]["condition"]
		var progress := -1.0
		var detail := ""
		match String(c["type"]):
			"kills_total":
				progress = float(stats["kills"]) / float(c["count"])
				detail = tr("results.left_kills") % Locale.format_number(int(c["count"]) - int(stats["kills"]))
			"chests_total":
				progress = float(stats["chests"]) / float(c["count"])
				detail = tr("results.left_chests") % (int(c["count"]) - int(stats["chests"]))
			"ryo_total":
				progress = float(SaveManager.data["ryo_total"]) / float(c["count"])
				detail = tr("results.left_ryo") % Locale.format_number(int(c["count"]) - int(SaveManager.data["ryo_total"]))
			"evolve_count":
				progress = float((stats["evolved"] as Array).size()) / float(c["count"])
				detail = tr("results.left_evolutions") % (int(c["count"]) - (stats["evolved"] as Array).size())
		if progress > best_progress and progress < 1.0:
			best_progress = progress
			best_id = String(id)
			best_text = detail
	if best_id.is_empty():
		return ""
	var bar := ""
	for k: int in range(10):
		bar += "#" if k < roundi(best_progress * 10.0) else "-"
	return "%s\n%s\n[%s] %s" % [tr("results.next_unlock"), tr("achievement.%s.name" % best_id), bar, best_text]


func on_back() -> void:
	app.go(&"title")
