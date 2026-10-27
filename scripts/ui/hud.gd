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
const CARD_LOCK_MS := LevelUpPanel.CARD_LOCK_MS
const CORNER_BUTTON := Vector2(38.0, 28.0)
## Ícone de pausa (Kenney) no botão do canto e ícone + multiplicador no vizinho.
const PAUSE_ICON := 14
const SPEED_ICON := 12
## Cor do botão de velocidade em cada multiplicador: 1x calmo, 2x dourado, 3x vermelhão.
const SPEED_TINT := {1: Color("fff4e0"), 2: Color("ffd166"), 3: Color("ff8a5c")}
const ULT_SIZE := 54.0
const REVIVE_SECONDS := 8.0
const COUNTDOWN := 1.5
## Kami: o ícone fica no topo do cartão, numa caixa de 32 px; o texto começa abaixo dela.
const KAMI_ICON_TOP := 8.0
const KAMI_ICON_BOX := 32.0
const KAMI_TEXT_TOP := 46.0
## Oferta de reviver no clima da morte: tinta clara e fria sobre a cena escurecida.
const REVIVE_INK := Color(0.82, 0.86, 0.94)
const REVIVE_FADE := 0.35
const REVIVE_BAR := 120.0
## Botões da oferta na linguagem da tela de resultados: vermelhão com borda dourada (principal)
## e escuro discreto (secundário).
const VERMILION := Color("b23a26")
const REVIVE_DIM := Color(0.8, 0.76, 0.72)
const REVIVE_WATCH := Vector2(250.0, 42.0)

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

## Telas de nova habilidade e de baú (scripts/ui/level_up_panel.gd e chest_panel.gd).
var _level_panel: LevelUpPanel
var _chest_panel: ChestPanel
var _kami_panel: Control
var _kami_row: HBoxContainer
var _kami_ids: Array[StringName] = []
## Tela de pausa (scripts/ui/pause_menu.gd).
var _pause: PauseMenu
## Velocidade mostrada no botão do canto e o "soco" de escala do toque.
var _speed_shown: int = 1
var _speed_tween: Tween
var _revive_panel: Control
var _revive_label: Label
var _revive_watch: Button
var _revive_left: float = 0.0
var _revive_bar: Control
## HUD de jogo que some na morte (joystick, topo, botões, chefe, avisos).
var _gameplay: Array[Control] = []
var _gameplay_alpha: float = 1.0
var _icons: Dictionary = {}
var _skill_icons := SkillIconPainter.new()


func _ready() -> void:
	layer = 10
	_root = _full_rect(Control.new())
	_root.theme = ThemeFactory.build()
	add_child(_root)
	# Qualidade "auto": rebaixa os efeitos se o FPS da partida não aguentar (GfxQuality).
	add_child(GfxMonitor.new())

	joystick = TouchJoystick.new()
	_root.add_child(_full_rect(joystick))

	_top = _full_rect(Control.new())
	_top.draw.connect(_draw_top)
	_root.add_child(_top)

	_pause_button = _corner_button("", 0)
	_pause_button.icon = UiIcons.get_icon("pause", PAUSE_ICON)
	_pause_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_button.tooltip_text = tr("hud.pause")
	_pause_button.add_theme_color_override("icon_normal_color", ThemeFactory.TEXT)
	_pause_button.add_theme_color_override("icon_hover_color", Color.WHITE)
	_pause_button.add_theme_color_override("icon_pressed_color", ThemeFactory.ACCENT)
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_speed_button = _corner_button("", 1)
	_speed_button.pivot_offset = CORNER_BUTTON * 0.5
	_speed_button.draw.connect(_draw_speed)
	_speed_button.pressed.connect(func() -> void:
		_punch(_speed_button)
		speed_pressed.emit())

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
	_gameplay = [joystick, _top, _pause_button, _speed_button, _ult_button, _boss_label, _boss_line,
			_toast, _hint]
	Settings.changed.connect(_on_setting)
	_apply_joystick_settings()
	start_run()


func start_run() -> void:
	_level_panel.close_now()
	_chest_panel.cancel()
	_kami_panel.visible = false
	_pause.close(false)
	_show_play_hud(true)
	_revive_panel.visible = false
	set_gameplay_alpha(1.0)
	_countdown_left = 0.0
	_countdown_label.visible = false
	hide_boss()
	refresh_speed()
	# Velocidade 2x/3x só a partir da 2ª partida (plano 4.14).
	_speed_button.visible = int(SaveManager.data["stats"]["runs"]) >= 1 or game == null or game.is_bot()
	_hint_step = 0 if not bool(SaveManager.data.get("tutorial_done", false)) else 99


func overlay_open() -> bool:
	return _level_panel.is_open() or _chest_panel.is_open() or _kami_panel.visible \
			or _pause.is_open() or _revive_panel.visible


func pause_open() -> bool:
	return _pause.is_open()


## A tela de pausa (testes e capturas).
func pause_menu() -> PauseMenu:
	return _pause


## "Voltar" com a pausa aberta: true se só fechou a confirmação de desistir.
func pause_back() -> bool:
	return _pause.back()


func level_up_open() -> bool:
	return _level_panel.is_open()


func chest_open() -> bool:
	return _chest_panel.is_open()


## As telas (testes e capturas).
func level_up_panel() -> LevelUpPanel:
	return _level_panel


func chest_panel() -> ChestPanel:
	return _chest_panel


func revive_open() -> bool:
	return _revive_panel.visible


## Cartas visíveis do nível novo (o roteiro E2E toca nelas).
func level_cards() -> Array[Button]:
	return _level_panel.cards()


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
	# Armas na 1ª fileira, passivas na 2ª: ícones 24x24 sem escala (pixel perfeito).
	var now := Time.get_ticks_msec() / 1000.0
	var x := 5.0
	for weapon: Weapon in game.weapons:
		_draw_icon(Vector2(x, 28.0), String(weapon.data.get("icon", "")), weapon.level, weapon.is_evolved(),
				"w:%s" % weapon.id, weapon.max_level, now)
		x += SkillIconPainter.ICON + 3.0
	x = 5.0
	for id: StringName in game.level_up.passive_levels:
		_draw_icon(Vector2(x, 28.0 + SkillIconPainter.ICON + 3.0), String(DB.passives[id]["icon"]),
				int(game.level_up.passive_levels[id]), false, "p:%s" % id, int(DB.passives[id].get("max", 5)), now)
		x += SkillIconPainter.ICON + 3.0
	_draw_offscreen_arrows()


## Ícone de habilidade com moldura, selo de nível e (Média/Alta) brilho das evoluídas e
## lampejo ao subir de nível: scripts/ui/skill_icon_painter.gd.
func _draw_icon(at: Vector2, path: String, lvl: int, evolved: bool, key: String, max_level: int,
		now: float) -> void:
	_skill_icons.draw(_top, at, _icon(path), key, lvl, max_level, evolved, now)


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


# --- Nova habilidade e baú (as telas ficam em level_up_panel.gd e chest_panel.gd) ------

func show_level_up(cards: Array[Dictionary], rerolls: int, skips: int, banishes: int) -> void:
	joystick.release()
	_level_panel.show_cards(cards, rerolls, skips, banishes, game.level if game else 0, game)


func hide_level_up() -> void:
	_level_panel.hide_panel()


## Onde o ícone da carta escolhida pousa na barra do topo (mesma grade do _draw_top).
func skill_slot(card: Dictionary) -> Vector2:
	var step := SkillIconPainter.ICON + 3.0
	var half := SkillIconPainter.ICON * 0.5
	if game == null:
		return Vector2(5.0 + half, 28.0 + half)
	var id := StringName(card.get("id", &""))
	match String(card.get("kind", "")):
		"weapon_new", "weapon_up":
			for i: int in range(game.weapons.size()):
				if game.weapons[i].id == id:
					return Vector2(5.0 + i * step + half, 28.0 + half)
		"passive":
			var i := game.level_up.passive_levels.keys().find(id)
			return Vector2(5.0 + maxi(i, 0) * step + half, 28.0 + step + half)
		"ryo":
			return Vector2(_top.size.x - 2.0 * (CORNER_BUTTON.x + 4.0) - 40.0, 20.0)
	return game.player.get_global_transform_with_canvas().origin if game.player else Vector2(339, 152)


## Tremor, abertura, itens voando um a um (cada um com som) e o cartão de cada item.
func show_chest(rewards: Array[Dictionary]) -> void:
	joystick.release()
	_chest_panel.show_chest(rewards)


func chest_animating() -> bool:
	return _chest_panel.animating()


## A explosão atrás do baú está tocando (aparece na abertura e some sozinha, ao pular ou fechar).
func chest_burst_active() -> bool:
	return _chest_panel.burst_active()


## Cartões com o item pousado (o roteiro E2E confere depois de pular ou esperar a animação).
func chest_lines_shown() -> int:
	return _chest_panel.lines_shown()


func chest_lines_total() -> int:
	return _chest_panel.lines_total()


## Pular: mostra o estado final de uma vez.
func _chest_skip() -> void:
	_chest_panel.skip()


func _build_level_panel() -> void:
	_level_panel = LevelUpPanel.new()
	_root.add_child(_level_panel)
	_level_panel.slot_target = skill_slot
	_level_panel.card_chosen.connect(func(i: int) -> void: card_chosen.emit(i))
	_level_panel.reroll_pressed.connect(func() -> void: reroll_pressed.emit())
	_level_panel.skip_pressed.connect(func() -> void: skip_pressed.emit())
	_level_panel.banish_pressed.connect(func(i: int) -> void: banish_pressed.emit(i))


func _build_chest_panel() -> void:
	_chest_panel = ChestPanel.new()
	_root.add_child(_chest_panel)
	_chest_panel.closed.connect(func() -> void: chest_closed.emit())


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
	joystick.release()
	_pause.open(pause_snapshot())
	_show_play_hud(false)


func hide_pause() -> void:
	_pause.close()
	_show_play_hud(true)


## A HUD de jogo (barra, ícones, botões do canto, avisos) some sob a pausa, para não brigar
## com o título; volta com a opacidade da sequência de morte.
func _show_play_hud(shown: bool) -> void:
	for control: Control in _gameplay:
		if control != joystick:
			control.modulate.a = _gameplay_alpha if shown else 0.0


## Dados da partida para a tela de pausa (ver PauseMenu.snapshot_of).
func pause_snapshot() -> Dictionary:
	return PauseMenu.snapshot_of(game)


func _build_pause_panel() -> void:
	_pause = PauseMenu.new()
	_root.add_child(_pause)
	_pause.resume_pressed.connect(func() -> void: resume_pressed.emit())
	_pause.speed_pressed.connect(func() -> void: speed_pressed.emit())
	_pause.quit_pressed.connect(func() -> void: quit_pressed.emit())


# --- Reviver por anúncio (plano 17.6) --------------------------------------------------

func show_revive_offer() -> void:
	_revive_panel.visible = true
	_revive_watch.text = revive_text()
	_fit_revive_font(_revive_watch)
	_revive_left = REVIVE_SECONDS
	joystick.release()
	# Surge devagar sobre a cena da morte.
	_revive_panel.modulate.a = 0.0
	create_tween().tween_property(_revive_panel, "modulate:a", 1.0, REVIVE_FADE)


## "Reviver (anúncio)" ou, sem anúncios (AdsManager.ads_enabled = false), "(presente)".
func revive_text() -> String:
	return tr("revive.watch") if AdsManager.ads_enabled else tr("revive.free")


## Sem a tela escura das outras: a cena da morte já vem cinza e escura, e o corpo da guardiã
## fica à vista no centro, entre o título e a contagem (em cima) e os botões (embaixo).
func _build_revive_panel() -> void:
	_revive_panel = Control.new()
	_revive_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_revive_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_revive_panel.visible = false
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.02, 0.05, 0.28)
	_revive_panel.add_child(_full_rect(veil))
	var top := VBoxContainer.new()
	top.anchor_right = 1.0
	top.offset_top = 30.0
	top.add_theme_constant_override("separation", 2)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_revive_panel.add_child(top)
	var title := _label(tr("revive.title"), HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_color", REVIVE_INK)
	top.add_child(title)
	_revive_label = _label("", HORIZONTAL_ALIGNMENT_CENTER)
	_revive_label.add_theme_font_size_override("font_size", 24)
	_revive_label.add_theme_color_override("font_color", REVIVE_INK)
	top.add_child(_revive_label)
	# Traço de tinta que encolhe com o tempo da oferta.
	_revive_bar = Control.new()
	_revive_bar.custom_minimum_size = Vector2(0.0, 3.0)
	_revive_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_revive_bar.draw.connect(_draw_revive_bar)
	top.add_child(_revive_bar)
	var bottom := CenterContainer.new()
	bottom.anchor_top = 1.0
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -92.0
	bottom.offset_bottom = -12.0
	_revive_panel.add_child(bottom)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	bottom.add_child(box)
	_revive_watch = _menu_button(revive_text(), func() -> void:
		_revive_panel.visible = false
		revive_answered.emit(true), REVIVE_WATCH)
	_revive_watch.name = "ReviveWatch"
	box.add_child(_revive_watch)
	var results := _menu_button(tr("revive.results"), func() -> void:
		_revive_panel.visible = false
		revive_answered.emit(false), Vector2(200, 26))
	box.add_child(results)
	_root.add_child(_revive_panel)
	_style_revive_buttons(_revive_watch, results)


func _style_revive_buttons(watch: Button, results: Button) -> void:
	var main := _flat(VERMILION, ThemeFactory.ACCENT, 2, 6)
	main.shadow_size = 3
	main.shadow_color = Color(ThemeFactory.ACCENT, 0.3)
	_button_styles(watch, main, _flat(VERMILION.lightened(0.12), Color.WHITE, 2, 6),
			_flat(VERMILION.darkened(0.25), ThemeFactory.ACCENT, 2, 6))
	watch.add_theme_color_override("font_color", ThemeFactory.TEXT)
	_fit_revive_font(watch)
	_button_styles(results, _flat(Color(0, 0, 0, 0.3), Color(REVIVE_DIM, 0.45), 1, 4),
			_flat(Color(0, 0, 0, 0.45), ThemeFactory.ACCENT.darkened(0.2), 1, 4),
			_flat(Color(0, 0, 0, 0.55), ThemeFactory.ACCENT, 1, 4))
	results.add_theme_color_override("font_color", REVIVE_DIM)


## Fonte 24 (2× da pixel) quando o texto cabe; senão a de 12, para não cortar em idioma longo.
func _fit_revive_font(watch: Button) -> void:
	var font := _root.theme.default_font
	var fits := font.get_string_size(watch.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x <= REVIVE_WATCH.x - 16.0
	watch.add_theme_font_size_override("font_size", 24 if fits else 12)


func _button_styles(button: Button, normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat) -> void:
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0), Color.WHITE, 1, 6))


static func _flat(bg: Color, border: Color, width: int, pad: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(3)
	box.anti_aliasing = false
	box.set_content_margin_all(pad)
	return box


func _draw_revive_bar() -> void:
	var k := clampf(_revive_left / REVIVE_SECONDS, 0.0, 1.0)
	var width := REVIVE_BAR * k
	var at := Vector2(roundf((_revive_bar.size.x - width) * 0.5), 1.0)
	_revive_bar.draw_rect(Rect2(at, Vector2(roundf(width), 1.0)), Color(REVIVE_INK.r, REVIVE_INK.g, REVIVE_INK.b, 0.7))


# --- Sequência de morte -----------------------------------------------------------------

## Some com a HUD de jogo na morte e a traz de volta no reviver. Abaixo de 1, os botões não
## recebem toque e o joystick solta e para de ler o polegar.
func set_gameplay_alpha(alpha: float) -> void:
	_gameplay_alpha = alpha
	var live := alpha >= 0.999
	for control: Control in _gameplay:
		control.modulate.a = alpha
	for button: Button in [_pause_button, _speed_button, _ult_button]:
		button.mouse_filter = Control.MOUSE_FILTER_STOP if live else Control.MOUSE_FILTER_IGNORE
	if not live:
		joystick.release()
	joystick.set_process_input(live)


func gameplay_alpha() -> float:
	return _gameplay_alpha


# --- Chefe ----------------------------------------------------------------------------

## Painel do chefe (scripts/ui/boss_panel.gd): faixa com o kanji e barra de vida. Os rótulos
## antigos ficam só com o texto (testes e leitores de tela), escondidos.
func show_boss(name_text: String, line: String, info: Dictionary = {}) -> void:
	_boss_label.text = name_text
	_boss_line.text = "“%s”" % line
	_boss_fraction = 1.0
	boss_panel().open(name_text, line, info)


func boss_panel() -> BossPanel:
	var panel := _root.get_node_or_null(^"BossPanel") as BossPanel
	if panel == null:
		panel = BossPanel.new()
		panel.name = "BossPanel"
		panel.hud = self
		panel.visible = false
		_root.add_child(panel)
		_root.move_child(panel, _flash.get_index())
	return panel


func boss_flash(strength: float) -> void:
	boss_panel().flash(strength)


func update_boss(fraction: float, enraged: bool = false) -> void:
	_boss_fraction = fraction
	if fraction >= 0.0:
		boss_panel().set_fraction(fraction, enraged)
	if fraction < 0.0:
		_boss_label.visible = false


func hide_boss() -> void:
	_boss_fraction = -1.0
	_boss_label.visible = false
	_boss_line.visible = false
	if _root.get_node_or_null(^"BossPanel"):
		boss_panel().close()


# --- Utilidades -----------------------------------------------------------------------

func refresh_speed() -> void:
	_speed_shown = GameClock.speed
	_speed_button.tooltip_text = "%s %dx" % [tr("pause.speed_caption"), _speed_shown]
	_speed_button.queue_redraw()
	if _pause:
		_pause.set_speed(_speed_shown)


## Velocidade mostrada no botão do canto (testes).
func speed_shown() -> int:
	return _speed_shown


## Cor atual do ícone e do multiplicador no botão de velocidade.
func speed_tint() -> Color:
	return SPEED_TINT.get(_speed_shown, SPEED_TINT[3])


## Mesma moldura do botão de pausa (o par se lê como um conjunto): ícone de avanço rápido e o
## multiplicador. Em 1x, claro como o ícone de pausa; acelerado, vai para um selo escuro
## embutido, na cor da velocidade, com aro que respira (parado com "Reduzir flashes").
func _draw_speed() -> void:
	var b := _speed_button
	var tint := speed_tint()
	var fast := _speed_shown > 1
	var icon := UiIcons.get_icon("fast_forward", SPEED_ICON)
	var font := Locale.font
	var label := "%dx" % _speed_shown
	var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var total := SPEED_ICON + 2.0 + text_w
	var x := floorf((b.size.x - total) * 0.5)
	var cy := floorf(b.size.y * 0.5)
	if fast:
		var pulse := 1.0 if bool(Settings.get_value("reduce_flashes")) \
				else 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.006)
		var chip := Rect2(x - 3.0, cy - 8.0, total + 6.0, 16.0)
		b.draw_rect(chip, Color(0.14, 0.05, 0.03, 0.92))
		b.draw_rect(chip.grow(-0.5), Color(tint, 0.45 + 0.5 * pulse), false, 1.0)
	if icon:
		b.draw_texture(icon, Vector2(x, cy - SPEED_ICON * 0.5), tint)
	var base := Vector2(x + SPEED_ICON + 2.0, cy + 5.0)
	b.draw_string_outline(font, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0.1, 0.05, 0.05))
	b.draw_string(font, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)


## "Soco" de escala no toque: encolhe e volta com um leve quique.
func _punch(control: Control) -> void:
	if _speed_tween != null and _speed_tween.is_valid():
		_speed_tween.kill()
	control.scale = Vector2.ONE * 0.86
	_speed_tween = create_tween()
	_speed_tween.tween_property(control, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


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
	if _level_panel.is_open():
		_level_panel.close_now()
		card_chosen.emit(0)
	elif _chest_panel.is_open():
		_chest_panel.cancel()
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
	if _speed_shown > 1 and _speed_button.visible:
		_speed_button.queue_redraw()
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.visible = _toast_left > 0.0
	if _boss_line_left > 0.0:
		_boss_line_left -= delta
		_boss_line.visible = _boss_line_left > 0.0
	if _revive_panel.visible:
		_revive_left -= delta
		_revive_label.text = tr("revive.countdown") % ceili(maxf(_revive_left, 0.0))
		_revive_bar.queue_redraw()
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
