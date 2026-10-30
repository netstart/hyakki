class_name MissionGoals
extends PanelContainer
## "Próximas metas": as 3 missões mais alcançáveis (MissionBook.next_goals), cada uma com ícone,
## nome, barra e "312 / 500".
## - Resultados (compact = false): o nome quebra em linhas e, depois de uma partida, a barra cresce
##   do progresso de antes até o de agora com o "+N" aparecendo (play); a parte que a partida somou
##   fica mais clara na barra.
## - Título (compact = true): bloco pequeno sob o saldo; nome numa linha (com reticências e o nome
##   inteiro na dica), fit_height esconde as últimas metas se a altura não der; tocar abre as
##   Missões no Diário (sinal `pressed` com o id da meta).
## As barras são retângulos (sem polígonos) e só redesenham quando o valor muda.

signal pressed(id: StringName)

const ICON := 16
const BAR_H := 5
const GROW_TIME := 0.7
const DELTA_DELAY := 0.25

var compact := false
## {id, before, after, target, row, bar, value, delta}
var rows: Array[Dictionary] = []

var _header: Label
var _empty: Label
var _list: VBoxContainer
var _tween: Tween


func _init(p_compact: bool = false) -> void:
	compact = p_compact
	name = "Goals"
	mouse_filter = Control.MOUSE_FILTER_STOP if compact else Control.MOUSE_FILTER_PASS
	tooltip_text = TranslationServer.translate("goals.hint") if compact else TranslationServer.translate("goals.title")
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2 if compact else 4)
	if compact:
		# Placa discreta como o saldo do título.
		add_theme_stylebox_override("panel", ThemeFactory.flat_box(Color(0.05, 0.03, 0.06, 0.62),
				Color(ThemeFactory.ACCENT, 0.3), 1, 4, Vector2(6, 3)))
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	_header = _text(TranslationServer.translate("goals.title"), ThemeFactory.ACCENT)
	_header.name = "GoalsTitle"
	_compact_text(_header)
	col.add_child(_header)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3 if compact else 5)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_list)
	_empty = _text(TranslationServer.translate("goals.empty"), ThemeFactory.TEXT)
	_compact_text(_empty)
	_empty.visible = false
	col.add_child(_empty)


## Metas atuais do perfil, sem diferença (antes = agora).
static func live_goals(count: int = 3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in MissionBook.next_goals(count):
		var p := MissionBook.progress(id)
		out.append({"id": String(id), "before": p.x, "after": p.x, "target": p.y})
	return out


## Mostra `goals` ([{id, before, after, target}]) já no estado final (play anima).
func set_goals(goals: Array) -> void:
	_kill()
	rows.clear()
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for g: Variant in goals:
		var goal: Dictionary = g
		var id := StringName(String(goal["id"]))
		if not MissionBook.has(id):
			continue
		rows.append(_make_row(id, float(goal["before"]), float(goal["after"]), float(goal["target"])))
	_empty.visible = rows.is_empty()
	finish()


## Barras crescem do "antes" ao "agora" e o "+N" aparece (sem animação com ui_fx 0 ou "Reduzir
## flashes"). `delay` em segundos.
func play(delay: float = 0.0) -> void:
	_kill()
	var calm := MenuKit.ui_fx() == 0 or bool(Settings.get_value("reduce_flashes"))
	var moving := rows.filter(func(r: Dictionary) -> bool: return float(r["after"]) > float(r["before"]))
	if calm or moving.is_empty() or not is_inside_tree():
		finish()
		return
	_tween = create_tween().set_parallel()
	for row: Dictionary in moving:
		var bar := row["bar"] as GoalBar
		bar.set_fill(_ratio(row, "before"))
		var delta := row["delta"] as Label
		delta.modulate.a = 0.0
		_tween.tween_method(bar.set_fill, _ratio(row, "before"), _ratio(row, "after"), GROW_TIME).set_delay(delay) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(delta, "modulate:a", 1.0, 0.3).set_delay(delay + DELTA_DELAY)


## Estado final na hora (testes, pular a entrada).
func finish() -> void:
	_kill()
	for row: Dictionary in rows:
		(row["bar"] as GoalBar).set_fill(_ratio(row, "after"))
		(row["delta"] as Label).modulate.a = 1.0


## Título: esconde as últimas metas até caber em `max_h`; sem espaço nem para uma, esconde tudo.
## Devolve quantas ficaram.
func fit_height(max_h: float) -> int:
	for row: Dictionary in rows:
		(row["row"] as Control).visible = true
	var shown := rows.size()
	while shown > 0 and get_combined_minimum_size().y > max_h:
		shown -= 1
		(rows[shown]["row"] as Control).visible = false
	visible = shown > 0 or (rows.is_empty() and get_combined_minimum_size().y <= max_h)
	size = get_combined_minimum_size()
	return shown


func visible_rows() -> int:
	return rows.filter(func(r: Dictionary) -> bool: return (r["row"] as Control).visible).size()


func _gui_input(event: InputEvent) -> void:
	if not compact:
		return
	var tap := event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if tap or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		accept_event()
		AudioManager.play_ui("ui_accept")
		pressed.emit(StringName(String(rows[0]["id"])) if not rows.is_empty() else &"")


func _make_row(id: StringName, before: float, after: float, target: float) -> Dictionary:
	var row := HBoxContainer.new()
	row.name = "Goal_%s" % id
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.tooltip_text = "%s\n%s" % [MissionBook.title(id), MissionBook.description(id)]
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = CodexMissions.reward_chip(MissionBook.icon(id), MissionBook.icon_is_face(id))
	icon.custom_minimum_size = Vector2(ICON + 2, ICON + 2)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 1)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(body)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(top)
	var title := _text(MissionBook.title(id), ThemeFactory.TEXT)
	title.name = "Name"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compact_text(title)
	top.add_child(title)
	var delta := _text(_delta_text(id, after - before), ThemeFactory.ACCENT)
	delta.name = "Delta"
	delta.visible = after > before
	top.add_child(delta)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(bottom)
	var bar := GoalBar.new()
	bar.name = "Bar"
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(20, BAR_H)
	bar.ghost = clampf(before / target, 0.0, 1.0) if target > 0.0 else 0.0
	bottom.add_child(bar)
	var value := _text(MissionBook.format_progress(id, after, target), Color(0.8, 0.76, 0.72))
	value.name = "Value"
	if compact:
		# Título: "312 / 500" na linha do nome e a barra fina embaixo (3 metas cabem em 270 de altura).
		bar.custom_minimum_size.y = 3
		top.add_child(value)
	else:
		# Resultados (coluna estreita): o "312 / 500" numa linha própria, à direita, sob a barra.
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		body.add_child(value)
	_list.add_child(row)
	return {"id": String(id), "before": before, "after": after, "target": target, "row": row, "bar": bar,
			"value": value, "delta": delta, "title": title}


static func _delta_text(id: StringName, amount: float) -> String:
	if MissionBook.TIME_TYPES.has(String(MissionBook.condition(id).get("type", ""))):
		return "+" + Screen.format_time(amount)
	return "+" + Locale.format_number(floori(amount))


static func _ratio(row: Dictionary, key: String) -> float:
	var target := float(row["target"])
	return clampf(float(row[key]) / target, 0.0, 1.0) if target > 0.0 else 0.0


## Título: uma linha, cortada com reticências (o texto inteiro fica na dica); Resultados: quebra.
func _compact_text(l: Label) -> void:
	if compact:
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size.x = 24
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _text(value: String, color: Color) -> Label:
	var l := Label.new()
	l.text = value
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", color)
	return l


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


## Barra da meta: fundo, o progresso de antes da partida (ghost, mais escuro) e o atual (fill).
class GoalBar extends Control:
	const BACK := Color(0, 0, 0, 0.55)
	const RIM := Color(0.85, 0.64, 0.25, 0.45)
	const OLD := Color(0.62, 0.45, 0.16)
	const NEW := Color(1.0, 0.82, 0.4)

	var ghost := 0.0
	var fill := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_fill(value: float) -> void:
		if not is_equal_approx(value, fill):
			fill = value
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, BACK)
		draw_rect(r, RIM, false, 1.0)
		var inner := r.grow(-1.0)
		var now := floorf(inner.size.x * fill)
		var old := floorf(inner.size.x * minf(ghost, fill))
		if now > 0.0:
			draw_rect(Rect2(inner.position, Vector2(now, inner.size.y)), NEW)
		if old > 0.0:
			draw_rect(Rect2(inner.position, Vector2(old, inner.size.y)), OLD)
