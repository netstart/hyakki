extends Screen
## Jornada do Guardião (seleção de fase, plano 3.3, 4.13 e 15.3): à esquerda o mapa do
## arquipélago com os pontos de luta (JourneyMap); à direita o pergaminho do ponto
## escolhido, com região, chefes, narrativa, recordes e as opções da partida: modo
## (Brisa / Normal), Lua Vermelha I–V (liberada vencendo a anterior) e Noite Sem Fim
## (depois de vencer a fase). Fases bloqueadas podem ser lidas, mas não começadas.

## Silhueta dos chefes ainda não derrotados.
const SILHOUETTE := Color(0.06, 0.05, 0.1)
const MAP_RECT := Rect2(6, 6, 396, 293)
const CARD_RECT := Rect2(406, 6, 266, 293)
const PAPER := Color("eddcb4")
const INK := Color("2a1a10")
const INK_SOFT := Color("5a4030")
const RED_INK := Color("9e2a1e")

var _map: JourneyMap
var _card: PanelContainer
var _region: Label
var _name: Label
var _cleared: Label
var _boss_icons: Array[TextureRect] = []
var _boss: Label
var _stats: Label
var _scroll: ScrollContainer
var _journey: Label
var _chronicle: Label
var _mode: OptionButton
var _moon: OptionButton
var _endless: CheckButton
var _bonus: Label
var _go: Button
var _suggest: Label
## Fase mostrada no cartão (pode ser bloqueada; app.selection só guarda fases liberadas).
var _viewing: StringName = &"village"


func _ready() -> void:
	_map = JourneyMap.new()
	_map.position = MAP_RECT.position
	_map.size = MAP_RECT.size
	_map.stage_selected.connect(_select)
	add_child(_map)
	_build_card()
	add_child(back_button())


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.position = CARD_RECT.position
	_card.size = CARD_RECT.size
	_card.custom_minimum_size = CARD_RECT.size
	var paper := StyleBoxFlat.new()
	paper.bg_color = PAPER
	paper.border_color = Color("6b4a2a")
	paper.set_border_width_all(1)
	paper.content_margin_left = 10
	paper.content_margin_right = 10
	paper.content_margin_top = 9
	paper.content_margin_bottom = 8
	_card.add_theme_stylebox_override("panel", paper)
	_card.draw.connect(_draw_scroll_ends)
	add_child(_card)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	_card.add_child(body)
	_region = _ink(label(""), RED_INK)
	_region.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_region)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	_name = _ink(label(""), INK)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name)
	_cleared = _ink(label(""), Color("fff1d6"))
	_cleared.add_theme_stylebox_override("normal", _stamp_box())
	_cleared.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	name_row.add_child(_cleared)
	body.add_child(name_row)
	var boss_row := HBoxContainer.new()
	boss_row.add_theme_constant_override("separation", 3)
	for k: int in range(2):
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(26, 26)
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		icon.draw.connect(_draw_boss_rim.bind(icon))
		boss_row.add_child(icon)
		_boss_icons.append(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	_boss = _ink(label(""), INK)
	# Uma linha só (nomes longos com reticências; o nome inteiro fica na dica).
	_boss.clip_text = true
	_boss.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_boss.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_child(_boss)
	_stats = _ink(label(""), INK_SOFT)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_stats)
	boss_row.add_child(info)
	body.add_child(boss_row)
	var rule := ColorRect.new()
	rule.color = Color(0.42, 0.29, 0.16, 0.45)
	rule.custom_minimum_size = Vector2(0, 1)
	body.add_child(rule)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Se a narrativa couber, fica centrada no espaço livre do pergaminho.
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 4)
	_scroll.add_child(text)
	_journey = _ink(label(""), INK)
	_journey.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_journey)
	_chronicle = _ink(label(""), RED_INK)
	_chronicle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_chronicle)
	body.add_child(_scroll)
	_bonus = _ink(label(""), Color("2f5a22"))
	_bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_bonus)
	_suggest = _ink(label(""), Color("1f5a5a"))
	_suggest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_suggest)
	_build_options(body)


func _build_options(body: VBoxContainer) -> void:
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 4)
	_mode = OptionButton.new()
	_mode.add_item(tr("mode.normal"))
	_mode.add_item(tr("mode.brisa"))
	_mode.custom_minimum_size = Vector2(0, 28)
	_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode.clip_text = true
	_mode.fit_to_longest_item = false
	_mode.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_mode.item_selected.connect(func(index: int) -> void:
		app.selection["mode"] = "brisa" if index == 1 else "normal"
		_refresh())
	options.add_child(_mode)
	_moon = OptionButton.new()
	_moon.custom_minimum_size = Vector2(0, 28)
	_moon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_moon.clip_text = true
	_moon.fit_to_longest_item = false
	_moon.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_moon.item_selected.connect(func(index: int) -> void:
		app.selection["moon"] = index
		_refresh())
	options.add_child(_moon)
	body.add_child(options)
	var bottom := HFlowContainer.new()
	bottom.alignment = FlowContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("h_separation", 4)
	bottom.add_theme_constant_override("v_separation", 3)
	_endless = CheckButton.new()
	_endless.text = tr("stages.endless")
	_endless.custom_minimum_size = Vector2(0, 32)
	_endless.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_endless.toggled.connect(func(on: bool) -> void: app.selection["endless"] = on)
	bottom.add_child(_endless)
	_go = button(tr("stages.start"), func() -> void: app.start_run(), Vector2(96, 32))
	_go.add_theme_font_size_override("font_size", 24)
	bottom.add_child(_go)
	body.add_child(bottom)


func on_show() -> void:
	_map.refresh(StringName(String(app.selection.get("hero", "aki"))))
	_mode.selected = 1 if String(app.selection.get("mode", "normal")) == "brisa" else 0
	var current := StringName(String(app.selection.get("stage", "")))
	if current == &"" or not MetaProgress.is_stage_unlocked(current):
		current = first_open_stage()
	_map.select(current, false)
	_select(current)
	_map.focus_selected.call_deferred()


## Primeira fase liberada e ainda não vencida (na ordem da jornada); senão a última liberada.
static func first_open_stage() -> StringName:
	var last: StringName = &"village"
	for id: StringName in _ordered_stages():
		if not MetaProgress.is_stage_unlocked(id):
			continue
		if not bool(SaveManager.stage_best(id)["won"]):
			return id
		last = id
	return last


static func _ordered_stages() -> Array[StringName]:
	var ids := DB.ids("stages")
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return int(DB.stage(a)["order"]) < int(DB.stage(b)["order"]))
	return ids


func _select(id: StringName) -> void:
	_viewing = id
	var unlocked := MetaProgress.is_stage_unlocked(id)
	if unlocked:
		app.selection["stage"] = String(id)
	var best := SaveManager.stage_best(id)
	_moon.clear()
	_moon.add_item(tr("moon.none"))
	var max_moon := mini(5, int(best["max_moon"]) + 1) if bool(best["won"]) else 0
	for m: int in range(1, max_moon + 1):
		_moon.add_item(tr("moon.level") % _roman(m))
	var moon := mini(int(app.selection.get("moon", 0)), max_moon)
	_moon.selected = moon
	if unlocked:
		app.selection["moon"] = moon
	_endless.disabled = not bool(best["won"])
	if _endless.disabled:
		_endless.set_pressed_no_signal(false)
		if unlocked:
			app.selection["endless"] = false
	else:
		_endless.set_pressed_no_signal(bool(app.selection.get("endless", false)))
	_refresh()


func _refresh() -> void:
	var id := _viewing
	var best := SaveManager.stage_best(id)
	var unlocked := MetaProgress.is_stage_unlocked(id)
	var hidden := id == &"secret" and not unlocked
	_region.text = "???" if hidden else tr("stage.%s.region" % id)
	_name.text = "???" if hidden else tr("stage.%s.name" % id)
	_cleared.text = tr("stages.cleared") if bool(best["won"]) else ""
	_cleared.visible = bool(best["won"])
	_refresh_bosses(id)
	var lines: PackedStringArray = []
	if not unlocked:
		lines.append(tr("stages.locked"))
	else:
		if float(best["best_time"]) > 0.0:
			lines.append(tr("stages.best") % format_time(float(best["best_time"])))
		if int(best["max_moon"]) >= 0:
			lines.append(tr("stages.moon_best") % _roman(int(best["max_moon"])))
		var moon := int(app.selection.get("moon", 0))
		if moon > 0:
			lines.append(tr("moon.rule%d" % moon))
	_stats.text = "\n".join(lines)
	_journey.text = tr("stages.secret_hint") if hidden else tr("stage.%s.journey" % id)
	_chronicle.text = _format(tr("stages.chronicle"), tr("stage.%s.dawn" % id)) if bool(best["won"]) else ""
	_chronicle.visible = bool(best["won"])
	_scroll.scroll_vertical = 0
	_moon.disabled = String(app.selection.get("mode", "normal")) == "brisa" or not unlocked
	_endless.disabled = not bool(best["won"])
	_go.disabled = not unlocked
	var pending := ShopManager.pending_next_run()
	var names := pending.map(func(s: Variant) -> String: return tr("shop.%s.name" % s))
	_bonus.text = tr("stages.bonus") % ", ".join(names) if not pending.is_empty() else ""
	_bonus.visible = not _bonus.text.is_empty()
	# Depois de 5 derrotas seguidas na mesma fase, sugere o modo Brisa (plano 15.3).
	var streak := int((SaveManager.data["defeat_streak"] as Dictionary).get(String(id), 0))
	_suggest.text = tr("stages.suggest_brisa") if streak >= 5 and String(app.selection.get("mode", "")) != "brisa" else ""
	_suggest.visible = not _suggest.text.is_empty()


## Os dois chefes da fase: coloridos se já derrotados, senão em silhueta.
func _refresh_bosses(id: StringName) -> void:
	var defeated: Dictionary = SaveManager.data["stats"]["bosses_defeated"]
	var bosses: Array = DB.stage(id).get("bosses", [])
	for k: int in range(_boss_icons.size()):
		var icon := _boss_icons[k]
		icon.visible = k < bosses.size()
		if not icon.visible:
			continue
		var boss := StringName(String((bosses[k] as Dictionary)["id"]))
		var known := defeated.has(String(boss))
		icon.set_meta("face", JourneyMap.face_texture(boss, 24))
		icon.set_meta("shape", JourneyMap.silhouette_texture(boss, 18))
		icon.tooltip_text = tr("boss.%s.name" % boss) if known else "???"
		icon.set_meta("known", known)
		icon.queue_redraw()
	# Nomes dos chefes já derrotados ("???" para os outros); nenhum conhecido: "Chefe: ???".
	var names: PackedStringArray = []
	for boss_data: Dictionary in bosses:
		var boss := String(boss_data["id"])
		names.append(tr("boss.%s.name" % boss) if defeated.has(boss) else "???")
	var known_count := names.size() - names.count("???")
	_boss.text = tr("stages.boss") % ", ".join(names) if known_count > 0 else tr("stages.boss_unknown")
	_boss.tooltip_text = _boss.text


func boss_icon_known(index: int) -> bool:
	return _boss_icons[index].visible and bool(_boss_icons[index].get_meta("known", false))


## Retrato redondo do chefe no cartão: colorido e com aro dourado se ele já caiu; senão
## silhueta com "?".
func _draw_boss_rim(icon: TextureRect) -> void:
	var c := icon.size * 0.5
	var known := bool(icon.get_meta("known", false))
	icon.draw_circle(c, 13.0, Color("3a2a12"))
	icon.draw_circle(c, 12.0, Color("f6ead0") if known else Color("e9dcb8"))
	var image := icon.get_meta("face" if known else "shape") as Texture2D if icon.has_meta("shape") else null
	if image:
		var side := image.get_size()
		icon.draw_texture_rect(image, Rect2(c - side * 0.5, side), false, Color.WHITE if known else SILHOUETTE)
	icon.draw_arc(c, 13.0, 0.0, TAU, 28, Color("b8862a") if known else Color("6a5a4a"), 1.5)


func _ink(l: Label, color: Color) -> Label:
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	return l


func _stamp_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("b8322a")
	box.border_color = Color("6e1a12")
	box.set_border_width_all(1)
	box.content_margin_left = 3
	box.content_margin_right = 3
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box


## Pontas do pergaminho (bastões de madeira em cima e embaixo) e fibras do papel.
func _draw_scroll_ends() -> void:
	var w := _card.size.x
	var h := _card.size.y
	for k: int in range(9):
		var y := 14.0 + k * 31.0 + (k % 3) * 5.0
		_card.draw_line(Vector2(6, y), Vector2(w - 6, y + 1), Color(0.55, 0.42, 0.25, 0.08), 1.0)
	for y: float in [0.0, h - 4.0]:
		_card.draw_rect(Rect2(-1, y, w + 2, 4), Color("4a2e1a"))
		_card.draw_rect(Rect2(-1, y, w + 2, 1), Color("7a5232"))
		_card.draw_rect(Rect2(-1, y, 3, 4), ThemeFactory.ACCENT)
		_card.draw_rect(Rect2(w - 2, y, 3, 4), ThemeFactory.ACCENT)


## "%s" com o texto, ou os dois juntos se a tradução ainda não tem marcador.
static func _format(template: String, value: String) -> String:
	return template % value if template.contains("%s") else "%s %s" % [template, value]


static func _roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]
