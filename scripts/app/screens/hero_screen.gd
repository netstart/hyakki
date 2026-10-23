extends Screen
## Seleção de herói (plano 3.4): retrato, arma inicial, bônus e Golpe da Lanterna.
## Heróis bloqueados mostram como desbloquear.

var _grid: GridContainer
var _info: Label
var _face: TextureRect
var _go: Button
var _cosmetic: OptionButton


func _ready() -> void:
	add_child(back_button())
	var title := title_label(tr("heroes.title"))
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
	# 4 colunas: 7 heróis em 2 linhas, sobrando largura para o painel.
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	row.add_child(_grid)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	row.add_child(side)
	var box := panel()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inner := HBoxContainer.new()
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	_face = icon_rect("", Vector2(48, 48))
	inner.add_child(_face)
	# Texto em rolagem vertical: textos longos (ru, de, fr, id) rolam dentro do painel
	# e não empurram a linha de botões para fora da tela.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(scroll)
	_info = wrap_label("", 0)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_info)
	box.add_child(inner)
	side.add_child(box)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 8)
	_cosmetic = OptionButton.new()
	_cosmetic.custom_minimum_size = Vector2(150, 30)
	_cosmetic.item_selected.connect(func(index: int) -> void:
		app.selection["cosmetic"] = String(_cosmetic.get_item_metadata(index)))
	bottom.add_child(_cosmetic)
	_go = button(tr("heroes.next"), func() -> void: app.go(&"stages"), Vector2(150, 36))
	bottom.add_child(_go)
	side.add_child(bottom)


func on_show() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()
	for id: StringName in DB.ids("heroes"):
		var unlocked := MetaProgress.is_hero_unlocked(id)
		var data: Dictionary = DB.heroes[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(60, 60)
		b.icon = load(String(data["face"])) as Texture2D
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.modulate = Color.WHITE if unlocked else Color(0.35, 0.35, 0.4)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_select.bind(id))
		_grid.add_child(b)
	_cosmetic.clear()
	_cosmetic.add_item(tr("cosmetic.default"))
	_cosmetic.set_item_metadata(0, "")
	for c: Variant in SaveManager.data["unlocked"]["cosmetics"]:
		_cosmetic.add_item(tr("cosmetic.%s" % c))
		_cosmetic.set_item_metadata(_cosmetic.item_count - 1, String(c))
	var current := String(app.selection.get("hero", "aki"))
	_select(StringName(current) if MetaProgress.is_hero_unlocked(StringName(current)) else &"aki")


func _select(id: StringName) -> void:
	var data: Dictionary = DB.heroes[id]
	var unlocked := MetaProgress.is_hero_unlocked(id)
	_face.texture = load(String(data["face"])) as Texture2D
	_face.modulate = Color.WHITE if unlocked else Color(0.3, 0.3, 0.35)
	var lines: PackedStringArray = [
		tr("hero.%s.name" % id), tr("hero.%s.role" % id),
		tr("heroes.weapon") % tr("weapon.%s.name" % data["weapon"]),
		tr("heroes.bonus") % _bonus_text(id, data),
		tr("heroes.ultimate") % tr("ultimate.%s.name" % data["ultimate"]["type"]),
		tr("ultimate.%s.desc" % data["ultimate"]["type"]),
	]
	if not unlocked:
		lines.append(tr("heroes.locked") % tr("achievement.%s.desc" % data["unlock"]))
	_info.text = "\n".join(lines)
	_go.disabled = not unlocked
	if unlocked:
		app.selection["hero"] = String(id)


## Bônus do herói: os modificadores em texto ("+10% Área") ou a descrição própria.
func _bonus_text(id: StringName, data: Dictionary) -> String:
	var mods: Dictionary = data.get("modifiers", {})
	return LevelUpSystem.describe_stats(mods) if not mods.is_empty() else tr("hero.%s.bonus" % id)
