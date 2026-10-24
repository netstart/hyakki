class_name Hud
extends CanvasLayer
## HUD e telas sobrepostas da partida (plano 7.1–7.4). Tudo nas bordas; o centro fica
## livre. Botões ≥ 48 dp (no Redmi, 1 pixel lógico = 4 pixels físicos ≈ 1,33 dp).

signal card_chosen(index: int)
signal reroll_pressed
signal skip_pressed
signal banish_pressed(index: int)
signal pause_pressed
signal resume_pressed
signal quit_pressed
signal speed_pressed
signal ultimate_pressed
signal kami_chosen(id: StringName)
signal chest_closed
signal revive_answered(accept: bool)

## Bloqueio após abrir o level-up, para não escolher sem querer (plano 7.4).
const CARD_LOCK_MS := 350
const CORNER_BUTTON := Vector2(38.0, 28.0)
const ULT_SIZE := 54.0
const CARD_SIZE := Vector2(150.0, 150.0)
const REVIVE_SECONDS := 8.0
const COUNTDOWN := 1.5
## Baú: duração de cada etapa (segundos), arco e brilho do ícone que voa para a lista.
const CHEST_SHAKE := 0.9
const CHEST_FLY := 0.4
const CHEST_FADE := 0.25
const CHEST_ARC := 36.0
const CHEST_GLOW := Color(1.8, 1.8, 1.5)
## Kami: o ícone fica no topo do cartão, numa caixa de 32 px; o texto começa abaixo dela.
const KAMI_ICON_TOP := 8.0
const KAMI_ICON_BOX := 32.0
const KAMI_TEXT_TOP := 46.0

var game: HyakkiGame
var joystick: TouchJoystick

var _root: Control
var _top: Control
var _speed_button: Button
var _pause_button: Button
var _ult_button: Button
var _toast: Label
var _toast_left: float = 0.0
var _debug: Label
var _flash: ColorRect
var _boss_label: Label
var _boss_line: Label
var _boss_line_left: float = 0.0
var _boss_fraction: float = -1.0
var _countdown_label: Label
var _countdown_left: float = 0.0
var _hint: Label
var _hint_step: int = 0

var _level_panel: Control
var _cards: Array[Button] = []
var _card_icons: Array[TextureRect] = []
var _reroll: Button
var _skip: Button
var _banish: Button
var _banish_mode: bool = false
var _opened_at: int = 0
var _chest_panel: Control
var _chest_image: TextureRect
var _chest_frame: AtlasTexture
## Explosão atrás do baú na abertura (uma só, reaproveitada a cada baú).
var _chest_burst: ChestBurst
var _chest_list: VBoxContainer
var _chest_close: Button
var _chest_rewards: Array[Dictionary] = []
var _chest_icons: Array[TextureRect] = []
var _chest_labels: Array[Label] = []
var _chest_flyers: Array[TextureRect] = []
var _chest_tween: Tween
var _chest_busy: bool = false
var _chest_run: int = 0
var _kami_panel: Control
var _kami_row: HBoxContainer
var _kami_ids: Array[StringName] = []
var _pause_panel: Control
var _pause_speed: Button
var _pause_stats: RichTextLabel
var _revive_panel: Control
var _revive_label: Label
var _revive_left: float = 0.0
var _icons: Dictionary = {}


func _ready() -> void:
	layer = 10
	_root = _full_rect(Control.new())
	_root.theme = ThemeFactory.build()
	add_child(_root)

	joystick = TouchJoystick.new()
	_root.add_child(_full_rect(joystick))

	_top = _full_rect(Control.new())
	_top.draw.connect(_draw_top)
	_root.add_child(_top)

	_pause_button = _corner_button("II", 0)
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_speed_button = _corner_button("1x", 1)
	_speed_button.pressed.connect(func() -> void: speed_pressed.emit())

	_ult_button = Button.new()
	_ult_button.flat = true
	_ult_button.focus_mode = Control.FOCUS_NONE
	_ult_button.anchor_left = 1.0
	_ult_button.anchor_right = 1.0
	_ult_button.anchor_top = 1.0
	_ult_button.anchor_bottom = 1.0
	_ult_button.offset_left = -ULT_SIZE - 10.0
	_ult_button.offset_right = -10.0
	_ult_button.offset_top = -ULT_SIZE - 10.0
	_ult_button.offset_bottom = -10.0
	_ult_button.draw.connect(_draw_ultimate)
	_ult_button.pressed.connect(func() -> void: ultimate_pressed.emit())
	_root.add_child(_ult_button)

	_boss_label = _label("", HORIZONTAL_ALIGNMENT_CENTER)
	_boss_label.anchor_right = 1.0
	_boss_label.offset_top = 40.0
	_boss_label.visible = false
	_root.add_child(_boss_label)
	_boss_line = _label("", HORIZONTAL_ALIGNMENT_CENTER)
	_boss_line.anchor_right = 1.0
	_boss_line.offset_top = 64.0
	_boss_line.add_theme_color_override("font_color", Color("ffb3b3"))
	_boss_line.visible = false
	_root.add_child(_boss_line)

	_toast = _label("", HORIZONTAL_ALIGNMENT_CENTER)
	_toast.anchor_right = 1.0
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_top = -52.0
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.offset_left = 120.0
	_toast.offset_right = -120.0
	_toast.visible = false
	_root.add_child(_toast)

	_hint = _label("", HORIZONTAL_ALIGNMENT_CENTER)
	_hint.anchor_right = 1.0
	_hint.anchor_top = 0.5
	_hint.offset_top = 40.0
	_hint.add_theme_color_override("font_color", Color("fff3b0"))
	_hint.visible = false
	_root.add_child(_hint)

	_debug = _label("", HORIZONTAL_ALIGNMENT_LEFT)
	_debug.position = Vector2(4.0, 58.0)
	_debug.visible = false
	_root.add_child(_debug)

	_flash = ColorRect.new()
	_full_rect(_flash)
	_flash.color = Color(1, 1, 1, 0)
	_root.add_child(_flash)

	_countdown_label = _label("", HORIZONTAL_ALIGNMENT_CENTER)
	_countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	_countdown_label.add_theme_font_size_override("font_size", 36)
	_countdown_label.visible = false
	_root.add_child(_countdown_label)

	_build_level_panel()
	_build_chest_panel()
	_build_kami_panel()
	_build_pause_panel()
	_build_revive_panel()
	Settings.changed.connect(_on_setting)
	_apply_joystick_settings()
	start_run()


func start_run() -> void:
	_level_panel.visible = false
	_chest_cancel()
	_chest_panel.visible = false
	_kami_panel.visible = false
	_pause_panel.visible = false
	_revive_panel.visible = false
	_banish_mode = false
	_countdown_left = 0.0
	_countdown_label.visible = false
	hide_boss()
	refresh_speed()
	# Velocidade 2x/3x só a partir da 2ª partida (plano 4.14).
	_speed_button.visible = int(SaveManager.data["stats"]["runs"]) >= 1 or game == null or game.is_bot()
	_hint_step = 0 if not bool(SaveManager.data.get("tutorial_done", false)) else 99


func overlay_open() -> bool:
	return _level_panel.visible or _chest_panel.visible or _kami_panel.visible \
			or _pause_panel.visible or _revive_panel.visible


func pause_open() -> bool:
	return _pause_panel.visible


func level_up_open() -> bool:
	return _level_panel.visible


func chest_open() -> bool:
	return _chest_panel.visible


func revive_open() -> bool:
	return _revive_panel.visible


## Cartas visíveis do nível novo (o roteiro E2E toca nelas).
func level_cards() -> Array[Button]:
	return _cards.filter(func(b: Button) -> bool: return b.visible)


# --- Topo: XP, tempo, abates, ícones -------------------------------------------------

func _draw_top() -> void:
	if game == null or game.tracker == null:
		return
	var width := _top.size.x
	var bar := Rect2(4.0, 3.0, width - 8.0, 6.0)
	_top.draw_rect(bar, Color(0.05, 0.03, 0.08, 0.75))
	var fill := clampf(float(game.xp) / float(maxi(game.xp_needed, 1)), 0.0, 1.0)
	_top.draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), Color("6ab7ff"))
	_top.draw_rect(bar, Color(1, 1, 1, 0.35), false, 1.0)
	var seconds := floori(GameClock.game_time)
	_text(Vector2(6.0, 24.0), tr("hud.level") % game.level, HORIZONTAL_ALIGNMENT_LEFT, 80.0)
	var clock := "%02d:%02d" % [floori(seconds / 60.0), seconds % 60]
	_text(Vector2(width * 0.5 - 50.0, 24.0), clock, HORIZONTAL_ALIGNMENT_CENTER, 100.0,
			Color("ffd166") if game.endless_phase else Color.WHITE)
	var right := width - 2.0 * (CORNER_BUTTON.x + 4.0) - 12.0
	_text(Vector2(right - 170.0, 24.0), "%s %s   %s %s" % [tr("hud.kills"), Locale.format_number(game.tracker.kills),
			tr("hud.ryo"), Locale.format_number(game.tracker.ryo)], HORIZONTAL_ALIGNMENT_RIGHT, 170.0)
	var x := 6.0
	for weapon: Weapon in game.weapons:
		_draw_icon(Vector2(x, 30.0), String(weapon.data.get("icon", "")), weapon.level, weapon.is_evolved())
		x += 15.0
	x += 6.0
	for id: StringName in game.level_up.passive_levels:
		_draw_icon(Vector2(x, 30.0), String(DB.passives[id]["icon"]), int(game.level_up.passive_levels[id]), false)
		x += 15.0
	if _boss_fraction >= 0.0:
		var boss_bar := Rect2(width * 0.5 - 120.0, 34.0, 240.0, 5.0)
		_top.draw_rect(boss_bar, Color(0.1, 0.02, 0.05, 0.85))
		_top.draw_rect(Rect2(boss_bar.position, Vector2(boss_bar.size.x * _boss_fraction, boss_bar.size.y)), Color("e63946"))
		_top.draw_rect(boss_bar, Color(1, 1, 1, 0.4), false, 1.0)
	_draw_offscreen_arrows()


func _draw_icon(at: Vector2, path: String, lvl: int, evolved: bool) -> void:
	var tex := _icon(path)
	if tex:
		var size := tex.get_size()
		var s := 12.0 / maxf(size.x, size.y)
		_top.draw_rect(Rect2(at - Vector2(1, 1), Vector2(14, 14)), Color(0, 0, 0, 0.45))
		_top.draw_texture_rect(tex, Rect2(at + (Vector2(12, 12) - size * s) * 0.5, size * s), false)
		if evolved:
			_top.draw_rect(Rect2(at - Vector2(1, 1), Vector2(14, 14)), Color("ffd166"), false, 1.0)
	_top.draw_string_outline(Locale.font, at + Vector2(8, 14), str(lvl), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 2, Color.BLACK)
	_top.draw_string(Locale.font, at + Vector2(8, 14), str(lvl), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


## Seta na borda para santuários e baús fora da tela (plano 7.2).
func _draw_offscreen_arrows() -> void:
	var targets: Array[Array] = []
	if game.kami.has_shrine():
		targets.append([game.kami.shrine_pos, Color("ffd166")])
	for item: Dictionary in game.pickups.items:
		if String(item["effect"]) == "chest":
			targets.append([item["pos"], Color("ff9f43")])
	var view := game.view_size()
	var center := view * 0.5
	for entry: Array in targets:
		var rel: Vector2 = (entry[0] as Vector2) - game.player.position
		if absf(rel.x) < view.x * 0.5 - 10.0 and absf(rel.y) < view.y * 0.5 - 10.0:
			continue
		var dir := rel.normalized()
		var edge := center + dir * minf((view.x * 0.5 - 18.0) / maxf(absf(dir.x), 0.001),
				(view.y * 0.5 - 18.0) / maxf(absf(dir.y), 0.001))
		var color: Color = entry[1]
		var tip := edge + dir * 7.0
		var side := dir.orthogonal() * 5.0
		_top.draw_colored_polygon(PackedVector2Array([tip, edge - dir * 3.0 + side, edge - dir * 3.0 - side]), color)


func _text(at: Vector2, value: String, align: HorizontalAlignment, width: float, color: Color = Color.WHITE) -> void:
	_top.draw_string_outline(Locale.font, at, value, align, width, 12, 3, Color(0.0, 0.0, 0.0, 0.85))
	_top.draw_string(Locale.font, at, value, align, width, 12, color)


func _icon(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not _icons.has(path):
		_icons[path] = load(path) if ResourceLoader.exists(path) else null
	return _icons[path]


# --- Golpe da Lanterna ----------------------------------------------------------

func _draw_ultimate() -> void:
	if game == null:
		return
	var r := ULT_SIZE * 0.5
	var c := Vector2(r, r)
	var charge := game.ultimate.charge / UltimateSystem.FULL
	var ready := game.ultimate.is_ready()
	_ult_button.draw_circle(c, r - 2.0, Color(0.08, 0.05, 0.1, 0.7))
	_ult_button.draw_arc(c, r - 3.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 32,
			Color("ffd166") if ready else Color("b07b3a"), 4.0)
	var sun := _icon("res://assets/art/ui/icons/meteo/Sun.png")
	if sun:
		var pulse := 1.0 + (0.08 * sin(GameClock.game_time * 6.0) if ready else 0.0)
		var s := sun.get_size() * pulse
		_ult_button.draw_texture_rect(sun, Rect2(c - s * 0.5, s), false,
				Color.WHITE if ready else Color(0.6, 0.6, 0.6, 0.8))


# --- Level-up ---------------------------------------------------------------------

func show_level_up(cards: Array[Dictionary], rerolls: int, skips: int, banishes: int) -> void:
	_level_panel.visible = true
	_opened_at = Time.get_ticks_msec()
	_banish_mode = false
	joystick.release()
	for i: int in range(_cards.size()):
		var button := _cards[i]
		button.visible = i < cards.size()
		if not button.visible:
			continue
		var card := cards[i]
		button.text = "\n\n%s\n%s\n\n%s" % [card["tag"], card["title"], card["text"]]
		_card_icons[i].texture = _icon(String(card.get("icon", "")))
	_reroll.text = tr("levelup.reroll") % rerolls
	_reroll.visible = rerolls > 0
	_skip.text = tr("levelup.skip") % skips
	_skip.visible = skips > 0
	_banish.text = tr("levelup.banish") % banishes
	_banish.visible = banishes > 0


func hide_level_up() -> void:
	_level_panel.visible = false


func _on_card(index: int) -> void:
	if Time.get_ticks_msec() - _opened_at < CARD_LOCK_MS:
		return
	if _banish_mode:
		_banish_mode = false
		banish_pressed.emit(index)
		return
	card_chosen.emit(index)


func _build_level_panel() -> void:
	var box := _overlay_box()
	_level_panel = box.get_parent().get_parent() as Control
	box.add_child(_label(tr("levelup.title"), HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i: int in range(4):
		var button := Button.new()
		button.custom_minimum_size = CARD_SIZE * Vector2(0.82, 1.0)
		button.focus_mode = Control.FOCUS_NONE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_stylebox_override("normal", ThemeFactory.card_box())
		button.add_theme_stylebox_override("hover", ThemeFactory.card_box_hover())
		button.add_theme_stylebox_override("pressed", ThemeFactory.card_box_hover())
		button.pressed.connect(_on_card.bind(i))
		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_CENTER_TOP)
		icon.offset_left = -10
		icon.offset_right = 10
		icon.offset_top = 8
		icon.offset_bottom = 28
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		row.add_child(button)
		_cards.append(button)
		_card_icons.append(icon)
	box.add_child(row)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	_reroll = _menu_button("", func() -> void: reroll_pressed.emit(), Vector2(110, 26))
	_skip = _menu_button("", func() -> void: skip_pressed.emit(), Vector2(110, 26))
	_banish = _menu_button("", func() -> void:
		_banish_mode = not _banish_mode
		toast(tr("levelup.banish_hint") if _banish_mode else ""), Vector2(110, 26))
	actions.add_child(_reroll)
	actions.add_child(_skip)
	actions.add_child(_banish)
	box.add_child(actions)


# --- Baú -------------------------------------------------------------------------------

## Tremor, abertura, itens voando um a um (cada um com som) e texto ao lado de cada ícone.
func show_chest(rewards: Array[Dictionary]) -> void:
	_chest_cancel()
	_chest_rewards = rewards
	_chest_panel.visible = true
	joystick.release()
	for child: Node in _chest_list.get_children():
		_chest_list.remove_child(child)
		child.queue_free()
	_chest_icons.clear()
	_chest_labels.clear()
	# As linhas já ocupam o espaço, com ícone e texto transparentes até o item pousar.
	for reward: Dictionary in rewards:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var icon := TextureRect.new()
		icon.texture = _icon(String(reward.get("icon", "")))
		icon.custom_minimum_size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate.a = 0.0
		line.add_child(icon)
		var text := String(reward.get("title", ""))
		if reward.has("text") and String(reward["kind"]) in ["evolution", "union"]:
			text += " — " + String(reward["text"])
		elif reward.has("tag"):
			text = "%s (%s)" % [text, reward["tag"]]
		var label := _label(text, HORIZONTAL_ALIGNMENT_LEFT)
		label.modulate.a = 0.0
		line.add_child(label)
		_chest_list.add_child(line)
		_chest_icons.append(icon)
		_chest_labels.append(label)
	_chest_busy = true
	_chest_close.text = tr("chest.skip")
	_chest_run += 1
	_chest_begin(_chest_run)


func chest_animating() -> bool:
	return _chest_busy


## A explosão atrás do baú está tocando (aparece na abertura e some sozinha, ao pular ou fechar).
func chest_burst_active() -> bool:
	return _chest_burst.active()


## Linhas com texto visível (o roteiro E2E confere depois de pular ou esperar a animação).
func chest_lines_shown() -> int:
	var shown := 0
	for label: Label in _chest_labels:
		if label.modulate.a >= 1.0:
			shown += 1
	return shown


func chest_lines_total() -> int:
	return _chest_labels.size()


func _chest_begin(run: int) -> void:
	# Duas esperas de quadro: o VBox precisa calcular as posições das linhas (alvos dos ícones).
	await get_tree().process_frame
	await get_tree().process_frame
	if run != _chest_run or not _chest_busy:
		return
	var from := _chest_image.get_global_rect().get_center()
	var tween := create_tween()
	_chest_tween = tween
	tween.tween_method(_chest_shake, 0.0, 1.0, CHEST_SHAKE)
	tween.tween_callback(_chest_open)
	tween.tween_property(_chest_image, "scale", Vector2.ONE * 1.35, 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_chest_image, "modulate", Color.WHITE, 0.2)
	tween.tween_property(_chest_image, "scale", Vector2.ONE, 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i: int in _chest_icons.size():
		var to := _chest_icons[i].get_global_rect().get_center()
		tween.tween_callback(_chest_spawn.bind(i))
		tween.parallel().tween_method(_chest_fly.bind(i, from, to), 0.0, 1.0, CHEST_FLY)
		tween.parallel().tween_callback(_chest_land.bind(i)).set_delay(CHEST_FLY)
		# O texto do item anterior surge enquanto o próximo sai do baú.
		if i > 0:
			tween.parallel().tween_property(_chest_labels[i - 1], "modulate:a", 1.0, CHEST_FADE)
	if not _chest_labels.is_empty():
		tween.tween_property(_chest_labels[-1], "modulate:a", 1.0, CHEST_FADE)
	tween.tween_callback(_chest_settle)


## Balança cada vez mais forte até abrir.
func _chest_shake(t: float) -> void:
	_chest_image.rotation = sin(t * 60.0) * 0.16 * t


## Abertura: quadro aberto, pop de escala, brilho e som.
func _chest_open() -> void:
	_chest_frame.region = Rect2(16, 0, 16, 14)
	_chest_image.rotation = 0.0
	_chest_image.modulate = Color(2.2, 2.2, 1.8)
	# Em paralelo ao pop: a explosão tem relógio próprio e não atrasa os itens.
	_chest_burst.play()
	AudioManager.play("k_wood_0", 1.0, 0.05)
	AudioManager.play("chest_open")
	AudioManager.play("magic1", 1.0, 0.0, -8.0)


## O item sai do baú: ícone pequeno e um ding com tom subindo (especiais têm fanfarra).
func _chest_spawn(i: int) -> void:
	var flyer := TextureRect.new()
	flyer.texture = _chest_icons[i].texture
	flyer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flyer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.size = Vector2(16, 16)
	flyer.pivot_offset = Vector2(8, 8)
	flyer.scale = Vector2.ONE * 0.4
	flyer.modulate = CHEST_GLOW
	_root.add_child(flyer)
	_chest_flyers.append(flyer)
	var kind := String(_chest_rewards[i].get("kind", ""))
	if kind in ["evolution", "union"]:
		AudioManager.play("powerup")
		AudioManager.play("j_temple_bell", 1.0, 0.0, -2.0)
	else:
		AudioManager.play("coin", pow(1.12, i))


## Trajeto em arco do baú até a linha; cresce e perde o brilho no caminho.
func _chest_fly(t: float, i: int, from: Vector2, to: Vector2) -> void:
	var flyer := _chest_flyers[i]
	if not is_instance_valid(flyer):
		return
	var at := from.lerp(to, t) - Vector2(0.0, sin(t * PI) * CHEST_ARC)
	flyer.global_position = at - Vector2(8.0, 8.0)
	flyer.scale = Vector2.ONE * lerpf(0.4, 1.0, t)
	flyer.modulate = Color.WHITE.lerp(CHEST_GLOW, 1.0 - t)


## O ícone pousou na linha: some o voador e mostra o ícone da linha.
func _chest_land(i: int) -> void:
	if is_instance_valid(_chest_flyers[i]):
		_chest_flyers[i].queue_free()
	_chest_icons[i].modulate.a = 1.0


## Estado final: baú aberto, todas as linhas com texto. Usado no fim natural e ao pular.
func _chest_settle() -> void:
	_chest_busy = false
	_chest_clear_flyers()
	_chest_burst.stop()
	_chest_frame.region = Rect2(16, 0, 16, 14)
	_chest_image.rotation = 0.0
	_chest_image.scale = Vector2.ONE
	_chest_image.modulate = Color.WHITE
	for i: int in _chest_icons.size():
		_chest_icons[i].modulate = Color.WHITE
		_chest_labels[i].modulate = Color.WHITE
	_chest_close.text = tr("chest.close")
	AudioManager.play("jingle_chest_big" if _chest_rewards.size() >= 4 else "jingle_success")


## Pular: mata a animação e mostra o estado final de uma vez.
func _chest_skip() -> void:
	if _chest_tween != null and _chest_tween.is_valid():
		_chest_tween.kill()
	_chest_settle()


## Para tudo quando o painel fecha no meio da animação (bot, troca de tela, nova partida).
func _chest_cancel() -> void:
	_chest_busy = false
	if _chest_tween != null and _chest_tween.is_valid():
		_chest_tween.kill()
	_chest_clear_flyers()
	_chest_burst.stop()


func _chest_clear_flyers() -> void:
	for flyer: TextureRect in _chest_flyers:
		if is_instance_valid(flyer):
			flyer.queue_free()
	_chest_flyers.clear()


func _build_chest_panel() -> void:
	var box := _overlay_box()
	_chest_panel = box.get_parent().get_parent() as Control
	box.add_child(_label(tr("chest.title"), HORIZONTAL_ALIGNMENT_CENTER))
	_chest_image = TextureRect.new()
	# A imagem tem dois quadros (fechado | aberto): começa com o baú fechado.
	_chest_frame = AtlasTexture.new()
	_chest_frame.atlas = _icon("res://assets/art/items/treasure/BigTreasureChest.png")
	_chest_frame.region = Rect2(0, 0, 16, 14)
	_chest_image.texture = _chest_frame
	_chest_image.custom_minimum_size = Vector2(48, 48)
	_chest_image.pivot_offset = Vector2(24, 24)
	_chest_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_chest_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Só 48 px de largura: o pivô (24, 24) fica no centro do baú para o pop e a explosão.
	_chest_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_chest_image)
	_chest_burst = ChestBurst.new()
	_chest_image.add_child(_chest_burst)
	_chest_list = VBoxContainer.new()
	box.add_child(_chest_list)
	_chest_close = _menu_button(tr("chest.skip"), func() -> void:
		if _chest_busy:
			_chest_skip()
		else:
			_chest_panel.visible = false
			chest_closed.emit())
	box.add_child(_chest_close)


# --- Kami ----------------------------------------------------------------------------

## Marca cada linha com + ou -, sem duplicar quando o valor já vem com sinal ("+25% ...").
static func _signed_lines(text: String, sign: String) -> String:
	var lines: PackedStringArray = []
	for line: String in text.split("\n", false):
		lines.append(line if line.begins_with("+") or line.begins_with("-") else "%s %s" % [sign, line])
	return "\n".join(lines)


func show_kami(offer: Array[StringName]) -> void:
	_kami_ids = offer
	_kami_panel.visible = true
	joystick.release()
	for child: Node in _kami_row.get_children():
		child.queue_free()
	for id: StringName in offer:
		var data: Dictionary = DB.kami[id]
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 150)
		button.focus_mode = Control.FOCUS_NONE
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Moldura com um leve tom da cor do Kami e margem no topo para o ícone.
		var normal := ThemeFactory.card_box()
		var hover := ThemeFactory.card_box_hover()
		var tint := Color(String(data["color"])).lerp(Color.WHITE, 0.6)
		for box: StyleBoxTexture in [normal, hover]:
			box.set_content_margin(SIDE_TOP, KAMI_TEXT_TOP)
			box.modulate_color = tint
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_child(_kami_icon(data))
		var blessing := LevelUpSystem.describe_stats(data.get("blessing", {}))
		if data.has("special"):
			blessing = (blessing + "\n" if not blessing.is_empty() else "") + tr("kami.%s.special" % id)
		var cost := LevelUpSystem.describe_stats(data.get("cost", {}))
		if cost.is_empty() and data.has("special"):
			cost = tr("kami.%s.cost" % id)
		button.text = "%s\n\n%s\n\n%s" % [tr("kami.%s.name" % id), _signed_lines(blessing, "+"),
				_signed_lines(cost, "-")]
		button.add_theme_color_override("font_color", Color(String(data["color"])).lightened(0.4))
		button.pressed.connect(func() -> void:
			_kami_panel.visible = false
			kami_chosen.emit(id))
		_kami_row.add_child(button)


## Ícone do Kami em escala inteira (pixel-perfect), centralizado na faixa do topo do cartão.
func _kami_icon(data: Dictionary) -> TextureRect:
	var tex := _icon(String(data.get("icon", "")))
	var icon := TextureRect.new()
	icon.texture = tex
	icon.set_anchors_preset(Control.PRESET_CENTER_TOP)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex:
		var size := tex.get_size()
		var factor := maxi(1, floori(KAMI_ICON_BOX / maxf(size.x, size.y)))
		var shown := size * factor
		icon.offset_left = floorf(-shown.x * 0.5)
		icon.offset_right = icon.offset_left + shown.x
		icon.offset_top = KAMI_ICON_TOP + floorf((KAMI_ICON_BOX - shown.y) * 0.5)
		icon.offset_bottom = icon.offset_top + shown.y
	return icon


func _build_kami_panel() -> void:
	var box := _overlay_box()
	_kami_panel = box.get_parent().get_parent() as Control
	box.add_child(_label(tr("kami.title"), HORIZONTAL_ALIGNMENT_CENTER))
	_kami_row = HBoxContainer.new()
	_kami_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_kami_row.add_theme_constant_override("separation", 6)
	box.add_child(_kami_row)
	box.add_child(_menu_button(tr("kami.ignore"), func() -> void:
		_kami_panel.visible = false
		kami_chosen.emit(&"")))


# --- Pausa ----------------------------------------------------------------------------

func show_pause() -> void:
	refresh_speed()
	_pause_panel.visible = true
	joystick.release()
	var stats := game.player.stats
	var lines: PackedStringArray = []
	for weapon: Weapon in game.weapons:
		lines.append("%s  %s" % [tr("weapon.%s.name" % weapon.id), tr("hud.level") % weapon.level])
	for id: StringName in game.level_up.passive_levels:
		lines.append("%s  %s" % [tr("passive.%s.name" % id), tr("hud.level") % int(game.level_up.passive_levels[id])])
	lines.append("")
	for stat: String in ["max_hp", "regen", "armor", "speed", "might", "area", "cooldown", "amount",
			"duration", "magnet", "luck", "growth", "greed", "curse", "light"]:
		var value := stats.get_stat(stat)
		var mode: String = StatBlock.DEFS[stat][1]
		var shown := ("%d" % roundi(value)) if mode == "flat" or stat in ["max_hp", "speed", "magnet", "light"] \
				else ("%d%%" % roundi(value * 100.0))
		lines.append("%s: %s" % [tr("statname.%s" % stat), shown])
	_pause_stats.text = "\n".join(lines)


func hide_pause() -> void:
	_pause_panel.visible = false


func _build_pause_panel() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.08, 0.75)
	overlay.add_child(_full_rect(dim))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 30
	row.offset_right = -30
	row.offset_top = 20
	row.offset_bottom = -20
	row.add_theme_constant_override("separation", 16)
	overlay.add_child(row)
	var menu := VBoxContainer.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 6)
	menu.custom_minimum_size = Vector2(190, 0)
	menu.add_child(_label(tr("pause.title"), HORIZONTAL_ALIGNMENT_CENTER))
	menu.add_child(_menu_button(tr("pause.resume"), func() -> void: resume_pressed.emit()))
	_pause_speed = _menu_button("", func() -> void: speed_pressed.emit())
	menu.add_child(_pause_speed)
	var sound := _menu_button(tr("pause.sound"), func() -> void:
		var muted := float(Settings.get_value("music_volume")) <= 0.0
		Settings.set_value("music_volume", 0.7 if muted else 0.0))
	menu.add_child(sound)
	menu.add_child(_menu_button(tr("pause.quit"), func() -> void:
		_pause_panel.visible = false
		quit_pressed.emit()))
	row.add_child(menu)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	_pause_stats = RichTextLabel.new()
	_pause_stats.fit_content = true
	_pause_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_pause_stats)
	panel.add_child(scroll)
	row.add_child(panel)
	overlay.visible = false
	_root.add_child(overlay)
	_pause_panel = overlay


# --- Reviver por anúncio (plano 17.6) --------------------------------------------------

func show_revive_offer() -> void:
	_revive_panel.visible = true
	_revive_left = REVIVE_SECONDS
	joystick.release()


func _build_revive_panel() -> void:
	var box := _overlay_box()
	_revive_panel = box.get_parent().get_parent() as Control
	box.add_child(_label(tr("revive.title"), HORIZONTAL_ALIGNMENT_CENTER))
	_revive_label = _label("", HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_revive_label)
	box.add_child(_menu_button(tr("revive.watch"), func() -> void:
		_revive_panel.visible = false
		revive_answered.emit(true), Vector2(200, 34)))
	box.add_child(_menu_button(tr("revive.results"), func() -> void:
		_revive_panel.visible = false
		revive_answered.emit(false), Vector2(200, 30)))


# --- Chefe ----------------------------------------------------------------------------

func show_boss(name_text: String, line: String) -> void:
	_boss_label.text = name_text
	_boss_label.visible = true
	_boss_line.text = "“%s”" % line
	_boss_line.visible = true
	_boss_line_left = 2.5
	_boss_fraction = 1.0


func update_boss(fraction: float) -> void:
	_boss_fraction = fraction
	if fraction < 0.0:
		_boss_label.visible = false


func hide_boss() -> void:
	_boss_fraction = -1.0
	_boss_label.visible = false
	_boss_line.visible = false


# --- Utilidades -----------------------------------------------------------------------

func refresh_speed() -> void:
	var label := "%dx" % GameClock.speed
	_speed_button.text = label
	if _pause_speed:
		_pause_speed.text = tr("pause.speed") % label


func toast(text: String, seconds: float = 2.5) -> void:
	_toast.text = text
	_toast.visible = not text.is_empty()
	_toast_left = seconds


func flash_screen(color: Color) -> void:
	color.a = 0.25 if bool(Settings.get_value("reduce_flashes")) else 0.7
	_flash.color = color
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.5)


## Ao voltar de uma tela, 1,5 s de contagem para o jogador reposicionar o polegar (15.2).
func countdown() -> void:
	if game and game.is_bot():
		return
	_countdown_left = COUNTDOWN
	_countdown_label.visible = true
	GameClock.paused = true


func toggle_debug() -> void:
	_debug.visible = not _debug.visible


## Respostas automáticas do bot de testes.
func bot_answer() -> void:
	if _level_panel.visible:
		_level_panel.visible = false
		card_chosen.emit(0)
	elif _chest_panel.visible:
		_chest_cancel()
		_chest_panel.visible = false
		chest_closed.emit()
	elif _kami_panel.visible and not _kami_ids.is_empty():
		_kami_panel.visible = false
		kami_chosen.emit(_kami_ids[0])
	elif _revive_panel.visible:
		_revive_panel.visible = false
		revive_answered.emit(false)


func _process(delta: float) -> void:
	_top.queue_redraw()
	_ult_button.queue_redraw()
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.visible = _toast_left > 0.0
	if _boss_line_left > 0.0:
		_boss_line_left -= delta
		_boss_line.visible = _boss_line_left > 0.0
	if _revive_panel.visible:
		_revive_left -= delta
		_revive_label.text = tr("revive.countdown") % ceili(maxf(_revive_left, 0.0))
		if _revive_left <= 0.0:
			_revive_panel.visible = false
			revive_answered.emit(false)
	if _countdown_left > 0.0:
		_countdown_left -= delta
		_countdown_label.text = str(ceili(_countdown_left / COUNTDOWN * 3.0))
		if _countdown_left <= 0.0:
			_countdown_label.visible = false
			if game and game.running and not overlay_open():
				GameClock.paused = false
	_update_hint()
	if _debug.visible and game:
		_debug.text = "FPS %d | inimigos %d | proj %d/%d | brasas %d | áreas %d\nsim %.2f ms (%d passos) | %dx" % [
			Engine.get_frames_per_second(), game.enemies.count_alive, game.projectiles.count_alive,
			game.enemy_shots.count_alive, game.pickups.count_alive, game.areas.count(),
			GameClock.last_sim_ms, GameClock.last_frame_steps, GameClock.speed,
		]


## Tutorial implícito da primeira partida (plano 13, Fase 4).
func _update_hint() -> void:
	if game == null or _hint_step >= 99 or game.is_bot():
		_hint.visible = false
		return
	var t := GameClock.game_time
	match _hint_step:
		0:
			_hint.text = tr("tutorial.move")
			_hint.visible = true
			if game.player.velocity.length() > 10.0 and t > 2.0:
				_hint_step = 1
		1:
			_hint.text = tr("tutorial.embers")
			if game.level >= 2:
				_hint_step = 2
		2:
			_hint.visible = game.ultimate.is_ready()
			_hint.text = tr("tutorial.ultimate")
			if game.ultimate.uses > 0 or t > 120.0:
				_hint_step = 99
				SaveManager.data["tutorial_done"] = true
				SaveManager.save_profile()


func _on_setting(key: String) -> void:
	if key.begins_with("joystick"):
		_apply_joystick_settings()


func _apply_joystick_settings() -> void:
	joystick.fixed = String(Settings.get_value("joystick_mode")) == "fixed"
	joystick.left_side = String(Settings.get_value("joystick_side")) == "left"
	# Botão do golpe vai para o lado oposto do joystick (canhotos, plano 4.1).
	if joystick.left_side:
		_ult_button.anchor_left = 1.0
		_ult_button.anchor_right = 1.0
		_ult_button.offset_left = -ULT_SIZE - 10.0
		_ult_button.offset_right = -10.0
	else:
		_ult_button.anchor_left = 0.0
		_ult_button.anchor_right = 0.0
		_ult_button.offset_left = 10.0
		_ult_button.offset_right = ULT_SIZE + 10.0


## Tela escura por cima do jogo com uma coluna centralizada; devolve a coluna.
func _overlay_box() -> VBoxContainer:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.08, 0.72)
	overlay.add_child(_full_rect(dim))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)
	overlay.visible = false
	_root.add_child(overlay)
	return box


func _label(text: String, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _menu_button(text: String, on_press: Callable, min_size: Vector2 = Vector2(180, 30)) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_press)
	button.pressed.connect(func() -> void: AudioManager.play_ui("ui_accept"))
	return button


func _corner_button(text: String, slot: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	var right := -4.0 - slot * (CORNER_BUTTON.x + 4.0)
	button.offset_right = right
	button.offset_left = right - CORNER_BUTTON.x
	button.offset_top = 12.0
	button.offset_bottom = 12.0 + CORNER_BUTTON.y
	_root.add_child(button)
	return button


func _full_rect(control: Control) -> Control:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control
