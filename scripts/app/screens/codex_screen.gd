extends Screen
## Diário do Guardião (plano 3.2 e 3.6.8): bestiário (lore liberada com 100 abates),
## chefes (liberados ao vencer), armas e evoluções, heróis, conquistas e história.

var _tabs: TabContainer


func _ready() -> void:
	add_child(back_button())
	var title := title_label(tr("codex.title"))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -150
	title.offset_right = 150
	title.offset_top = 6
	add_child(title)
	var margin := content_box(42.0)
	_tabs = TabContainer.new()
	margin.add_child(_tabs)


func on_show() -> void:
	for child: Node in _tabs.get_children():
		child.queue_free()
	_tabs.add_child(_enemy_tab())
	_tabs.add_child(_boss_tab())
	_tabs.add_child(_weapon_tab())
	_tabs.add_child(_hero_tab())
	_tabs.add_child(_achievement_tab())
	_tabs.add_child(_story_tab())


func _list_tab(name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	scroll.set_meta("list", list)
	return list


func _entry(icon: String, title: String, text: String, locked: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var rect := icon_rect(icon, Vector2(28, 28))
	if locked:
		rect.modulate = Color(0.1, 0.1, 0.12)
	row.add_child(rect)
	var label_text := wrap_label("%s\n%s" % [title, text], 520)
	if locked:
		label_text.modulate = Color(0.7, 0.7, 0.75)
	row.add_child(label_text)
	return row


func _enemy_tab() -> Control:
	var list := _list_tab(tr("codex.enemies"))
	var kills: Dictionary = SaveManager.data["stats"]["kills_by_enemy"]
	for id: StringName in DB.ids("enemies"):
		var data := DB.enemy(id)
		if not bool(data.get("codex", true)) or String(data.get("archetype", "")) == "prop":
			continue
		var count := int(kills.get(String(id), 0))
		var unlocked := MetaProgress.is_enemy_entry_unlocked(id)
		var face := String(data["sprite"]).get_base_dir().path_join("Faceset.png")
		var text := tr("enemy.%s.lore" % id) if unlocked else tr("codex.kill_more") % [count, MetaProgress.CODEX_KILLS]
		list.add_child(_entry(face, tr("enemy.%s.name" % id) if count > 0 else "???", text, count == 0))
	return list.get_parent()


func _boss_tab() -> Control:
	var list := _list_tab(tr("codex.bosses"))
	var defeated: Dictionary = SaveManager.data["stats"]["bosses_defeated"]
	for id: StringName in DB.ids("bosses"):
		if id == &"shinigami":
			continue
		var path := String(DB.bosses[id]["sprite"]["path"]).get_base_dir().path_join("Faceset.png")
		var won := defeated.has(String(id))
		list.add_child(_entry(path, tr("boss.%s.name" % id) if won else "???",
				tr("boss.%s.lore" % id) if won else tr("codex.boss_locked"), not won))
	return list.get_parent()


func _weapon_tab() -> Control:
	var list := _list_tab(tr("codex.weapons"))
	var evolved: Array = SaveManager.data["stats"]["evolved"]
	for id: StringName in DB.ids("weapons"):
		var data := DB.weapon(id)
		var kind := String(data.get("kind", "base"))
		var unions: Array = SaveManager.data["stats"].get("unions", [])
		var known := kind == "base" or evolved.has(String(id)) or unions.has(String(id))
		var text := tr("weapon.%s.desc" % id)
		if kind == "base":
			text += "\n" + tr("codex.evolves") % [tr("passive.%s.name" % data.get("evolves_with", "")),
					tr("weapon.%s.name" % data.get("evolution", "")) if evolved.has(String(data.get("evolution", ""))) else "???"]
		list.add_child(_entry(String(data.get("icon", "")), tr("weapon.%s.name" % id) if known else "???",
				text if known else tr("codex.weapon_locked"), not known))
	return list.get_parent()


func _hero_tab() -> Control:
	var list := _list_tab(tr("codex.heroes"))
	for id: StringName in DB.ids("heroes"):
		var data: Dictionary = DB.heroes[id]
		var unlocked := MetaProgress.is_hero_unlocked(id)
		list.add_child(_entry(String(data["face"]), tr("hero.%s.name" % id),
				tr("hero.%s.story" % id) if unlocked else tr("heroes.locked") % tr("achievement.%s.desc" % data["unlock"]),
				not unlocked))
	return list.get_parent()


func _achievement_tab() -> Control:
	var list := _list_tab(tr("codex.achievements"))
	var done: Dictionary = SaveManager.data["achievements"]
	var total := DB.ids("achievements").size()
	list.add_child(label(tr("codex.achievements_count") % [done.size(), total]))
	for id: StringName in DB.ids("achievements"):
		var data: Dictionary = DB.achievements[id]
		var ok := done.has(String(id))
		list.add_child(_entry(String(data["icon"]), ("[OK] " if ok else "") + tr("achievement.%s.name" % id),
				tr("achievement.%s.desc" % id), not ok))
	return list.get_parent()


func _story_tab() -> Control:
	var list := _list_tab(tr("codex.story"))
	var story: Dictionary = SaveManager.data["story"]
	list.add_child(button(tr("codex.replay_intro"), _replay.bind(&"intro"), Vector2(220, 28)))
	if bool(story["ending_seen"]):
		list.add_child(button(tr("codex.replay_ending"), _replay.bind(&"ending"), Vector2(220, 28)))
	if bool(story["secret_ending_seen"]):
		list.add_child(button(tr("codex.replay_secret"), _replay.bind(&"secret_ending"), Vector2(220, 28)))
	for id: StringName in DB.ids("stages"):
		if bool(SaveManager.stage_best(id)["won"]):
			list.add_child(_entry("res://assets/art/ui/icons/meteo/Sun.png", tr("stage.%s.name" % id),
					tr("stage.%s.dawn" % id), false))
	return list.get_parent()


func _replay(story_id: StringName) -> void:
	app.play_story(story_id, func() -> void: app.go(&"codex"))
