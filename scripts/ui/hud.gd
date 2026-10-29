class_name Hud
extends CanvasLayer
## HUD e telas sobrepostas da partida (plano 7.1–7.4). Tudo nas bordas; o centro fica
## livre. Botões ≥ 48 dp (no Redmi, 1 pixel lógico = 4 pixels físicos ≈ 1,33 dp).
## Textos, botões, joystick fixo e setas ficam fora do recorte da câmera
## (MenuKit.safe_insets): _layout refaz as posições ao redimensionar e quando o recorte muda
## (girar o aparelho troca o lado do furo).

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
## Sem a Ampulheta de Fūjin: "1x" esmaecido com cadeado no canto; o toque treme (negado).
const SPEED_LOCKED_ALPHA := 0.45
const LOCK_TINT := Color("e0b04a")
const DENY_TIME := 0.32
const DENY_SHAKE := 3.0
const ULT_SIZE := 54.0
const REVIVE_SECONDS := 8.0
const COUNTDOWN := 1.5
## Linha de base dos textos do topo e folga mínima entre eles.
const TOP_TEXT_Y := 24.0
const TOP_TEXT_GAP := 8.0
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

## Telas de nova habilidade, baú e pacto (scripts/ui/level_up_panel.gd, chest_panel.gd e
## kami_panel.gd).
var _level_panel: LevelUpPanel
var _chest_panel: ChestPanel
var _kami_panel: KamiPanel
## Ícones das recompensas voando até a guardiã (scripts/ui/reward_flight.gd), sobre as telas.
var _flight: RewardFlight
## Tela de pausa (scripts/ui/pause_menu.gd).
var _pause: PauseMenu
## Velocidade mostrada no botão do canto e o "soco" de escala do toque.
var _speed_shown: int = 1
var _speed_tween: Tween
## Velocidade bloqueada (sem a compra) e o tempo que falta da tremida de "negado".
var _speed_locked: bool = false
var _deny_left: float = 0.0
var _revive_panel: Control
var _revive_label: Label
var _revive_watch: Button
var _revive_left: float = 0.0
var _revive_bar: Control
## HUD de jogo que some na morte (joystick, topo, botões, chefe, avisos).
var _gameplay: Array[Control] = []
## Recorte da câmera (esquerda, direita) usado no último _layout.
var _insets := Vector2.ZERO
var _revive_top: Control
var _revive_bottom: Control
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
		if not _speed_locked:
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
	_build_flight()
	_gameplay = [joystick, _top, _pause_button, _speed_button, _ult_button, _boss_label, _boss_line,
			_toast, _hint]
	Settings.changed.connect(_on_setting)
	# Velocidade sem a Ampulheta de Fūjin (negado) e compra/reembolso no meio da partida.
	GameClock.speed_denied.connect(deny_speed)
	GameClock.speed_lock_changed.connect(refresh_speed)
	_apply_joystick_settings()
	_root.resized.connect(_layout)
	# Furo da câmera que troca de lado no meio da partida (giro de 180°).
	MenuKit.on_insets_change(self, _layout)
	_layout()
	start_run()


func start_run() -> void:
	_level_panel.close_now()
	_chest_panel.cancel()
	_kami_panel.close_now()
	_flight.clear()
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
	return _level_panel.is_open() or _chest_panel.is_open() or _kami_panel.is_open() \
			or _pause.is_open() or _revive_panel.visible or realm_active()


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


## Cartas visíveis do nível novo (os testes tocam nelas).
func level_cards() -> Array[Button]:
	return _level_panel.cards()


# --- Topo: XP, tempo, abates, ícones -------------------------------------------------

func _draw_top() -> void:
	if game == null or game.tracker == null:
		return
	var seconds := floori(GameClock.game_time)
	var clock := "%02d:%02d" % [floori(seconds / 60.0), seconds % 60]
	var counters := "%s %s   %s %s" % [tr("hud.kills"), Locale.format_number(game.tracker.kills),
			tr("hud.ryo"), Locale.format_number(game.tracker.ryo)]
	var level := tr("hud.level") % game.level
	var layout := top_layout(level, clock, counters)
	var bar: Rect2 = layout["xp"]
	_top.draw_rect(bar, Color(0.05, 0.03, 0.08, 0.75))
	var fill := clampf(float(game.xp) / float(maxi(game.xp_needed, 1)), 0.0, 1.0)
	_top.draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), Color("6ab7ff"))
	_top.draw_rect(bar, Color(1, 1, 1, 0.35), false, 1.0)
	_text(layout["level_at"], level)
	_text(layout["clock_at"], clock, Color("ffd166") if game.endless_phase else Color.WHITE)
	_text(layout["counters_at"], counters)
	# Armas na 1ª fileira, passivas na 2ª: ícones 24x24 sem escala (pixel perfeito).
	var now := Time.get_ticks_msec() / 1000.0
	var step := SkillIconPainter.ICON + 3.0
	var at: Vector2 = layout["weapons_at"]
	for weapon: Weapon in game.weapons:
		_draw_icon(at, String(weapon.data.get("icon", "")), weapon.level, weapon.is_evolved(),
				"w:%s" % weapon.id, weapon.max_level, now)
		at.x += step
	at = layout["passives_at"]
	for id: StringName in game.level_up.passive_levels:
		_draw_icon(at, String(DB.passives[id]["icon"]),
				int(game.level_up.passive_levels[id]), false, "p:%s" % id, int(DB.passives[id].get("max", 5)), now)
		at.x += step
	_draw_offscreen_arrows()


## Posições do topo dentro da área segura: barra de XP ("xp"), retângulos dos textos de nível,
## relógio e abates/ryō ("level", "clock", "counters"), a base onde cada um é escrito ("*_at")
## e o início das fileiras de ícones ("weapons_at", "passives_at"). O relógio fica no centro
## da tela; se o nível ou os contadores chegarem nele (tela estreita com recorte), vai para o
## meio do vão entre os dois, e se nem assim couber os contadores descem para baixo dos botões
## do canto. _draw_top desenha aqui; os testes de layout conferem.
func top_layout(level_text: String, clock_text: String, counters_text: String) -> Dictionary:
	var width := _top.size.x
	var left := _insets.x
	var right := width - _insets.y
	var font := Locale.font
	var ascent := font.get_ascent(12)
	var height := font.get_height(12)
	var level_w := font.get_string_size(level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var clock_w := font.get_string_size(clock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var counters_w := font.get_string_size(counters_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var level := Rect2(left + 6.0, TOP_TEXT_Y - ascent, level_w, height)
	var counters_end := right - 2.0 * (CORNER_BUTTON.x + 4.0) - 12.0
	var counters := Rect2(counters_end - counters_w, TOP_TEXT_Y - ascent, counters_w, height)
	var clock := Rect2(roundf(width * 0.5 - clock_w * 0.5), TOP_TEXT_Y - ascent, clock_w, height)
	if clock.position.x < level.end.x + TOP_TEXT_GAP or clock.end.x > counters.position.x - TOP_TEXT_GAP:
		clock.position.x = roundf((level.end.x + counters.position.x - clock_w) * 0.5)
	if clock.position.x < level.end.x + TOP_TEXT_GAP or clock.end.x > counters.position.x - TOP_TEXT_GAP:
		clock.position.x = roundf(width * 0.5 - clock_w * 0.5)
		counters = Rect2(right - 4.0 - counters_w, 12.0 + CORNER_BUTTON.y + 4.0, counters_w, height)
	return {
		"xp": Rect2(left + 4.0, 3.0, right - left - 8.0, 6.0),
		"level": level, "level_at": Vector2(level.position.x, TOP_TEXT_Y),
		"clock": clock, "clock_at": Vector2(clock.position.x, TOP_TEXT_Y),
		"counters": counters, "counters_at": Vector2(counters.position.x, counters.position.y + ascent),
		"weapons_at": Vector2(left + 5.0, 28.0),
		"passives_at": Vector2(left + 5.0, 28.0 + SkillIconPainter.ICON + 3.0),
	}


## Ícone de habilidade com moldura, selo de nível e (Média/Alta) brilho das evoluídas e
## lampejo ao subir de nível: scripts/ui/skill_icon_painter.gd.
func _draw_icon(at: Vector2, path: String, lvl: int, evolved: bool, key: String, max_level: int,
		now: float) -> void:
	_skill_icons.draw(_top, at, _icon(path), key, lvl, max_level, evolved, now)


## Seta na borda para santuários e baús fora da tela (plano 7.2) e a do portal do Kakuriyo
## (RiftPortal.draw_arrow: chevron violeta com um vórtice atrás).
func _draw_offscreen_arrows() -> void:
	var targets: Array[Array] = []
	if game.kami.has_shrine():
		targets.append([game.kami.shrine_pos, Color("ffd166")])
	for item: Dictionary in game.pickups.items:
		if String(item["effect"]) == "chest":
			targets.append([item["pos"], Color("ff9f43")])
	var view := game.view_size()
	for entry: Array in targets:
		var rel: Vector2 = (entry[0] as Vector2) - game.player.position
		if absf(rel.x) < view.x * 0.5 - 10.0 and absf(rel.y) < view.y * 0.5 - 10.0:
			continue
		var dir := rel.normalized()
		var edge := arrow_point(dir, view)
		var color: Color = entry[1]
		var tip := edge + dir * 7.0
		var side := dir.orthogonal() * 5.0
		Stroke.convex(_top, PackedVector2Array([tip, edge - dir * 3.0 + side, edge - dir * 3.0 - side]), color)
	if game.rift != null and game.rift.is_open():
		var to: Vector2 = game.rift.portal_pos - game.player.position
		if absf(to.x) >= view.x * 0.5 - 10.0 or absf(to.y) >= view.y * 0.5 - 10.0:
			RiftPortal.draw_arrow(_top, arrow_point(to.normalized(), view), to.normalized(), Time.get_ticks_msec() / 1000.0)


## Base da seta que aponta na direção `dir`: na borda da tela, com 18 px de folga, e do lado
## de dentro do recorte da câmera.
func arrow_point(dir: Vector2, view: Vector2) -> Vector2:
	var center := view * 0.5
	var edge := center + dir * minf((view.x * 0.5 - 18.0) / maxf(absf(dir.x), 0.001),
			(view.y * 0.5 - 18.0) / maxf(absf(dir.y), 0.001))
	edge.x = clampf(edge.x, _insets.x + 18.0, view.x - _insets.y - 18.0)
	return edge


func _text(at: Vector2, value: String, color: Color = Color.WHITE) -> void:
	_top.draw_string_outline(Locale.font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0.0, 0.0, 0.0, 0.85))
	_top.draw_string(Locale.font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)


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
	Stroke.arc(_ult_button, c, r - 3.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 32,
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


## Cartões com o item pousado (os testes conferem depois de pular ou esperar a animação).
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
	_level_panel.claimed.connect(fly_rewards)
	_level_panel.card_chosen.connect(func(i: int) -> void: card_chosen.emit(i))
	_level_panel.reroll_pressed.connect(func() -> void: reroll_pressed.emit())
	_level_panel.skip_pressed.connect(func() -> void: skip_pressed.emit())
	_level_panel.banish_pressed.connect(func(i: int) -> void: banish_pressed.emit(i))


func _build_chest_panel() -> void:
	_chest_panel = ChestPanel.new()
	_root.add_child(_chest_panel)
	_chest_panel.closed.connect(func() -> void: chest_closed.emit())
	_chest_panel.claimed.connect(fly_rewards)


# --- Voo das recompensas até a guardiã ---------------------------------------------------

## Solta os ícones ganhos (ver RewardFlight.launch); cada um que chega acende o encaixe dele
## na barra do topo. Também para quem mais der itens à guardiã (ex.: recompensas do Kakuriyo).
func fly_rewards(items: Array[Dictionary]) -> void:
	_flight.launch(items)


func reward_flight() -> RewardFlight:
	return _flight


## Onde a guardiã está na tela agora (segue a câmera); o centro da tela sem partida.
func guardian_point() -> Vector2:
	if game == null or game.player == null or not game.player.is_inside_tree():
		return _root.size * 0.5
	return game.player.get_global_transform_with_canvas().origin


func _build_flight() -> void:
	_flight = RewardFlight.new()
	_flight.name = "RewardFlight"
	_flight.target = guardian_point
	# Com a pausa aberta o voo congela e some; volta de onde parou.
	_flight.hold = func() -> bool: return _pause.is_open()
	_flight.landed.connect(func(item: Dictionary) -> void:
		_skill_icons.pulse(String(item.get("key", "")), Time.get_ticks_msec() / 1000.0))
	_root.add_child(_flight)


# --- Kami ----------------------------------------------------------------------------

## Placas votivas dos Kami em oferta (scripts/ui/kami_panel.gd).
func show_kami(offer: Array[StringName]) -> void:
	joystick.release()
	_kami_panel.open(offer)


func kami_open() -> bool:
	return _kami_panel.is_open()


func kami_panel() -> KamiPanel:
	return _kami_panel


func _build_kami_panel() -> void:
	_kami_panel = KamiPanel.new()
	_kami_panel.name = "KamiPanel"
	_root.add_child(_kami_panel)
	_kami_panel.chosen.connect(func(id: StringName) -> void: kami_chosen.emit(id))
	_kami_panel.claimed.connect(fly_rewards)


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


## "Reviver (anúncio)" ou, de presente (sem anúncios ou com "Apoie o jogo",
## AdsManager.rewards_are_gifts()), "(presente)".
func revive_text() -> String:
	return tr("revive.free") if AdsManager.rewards_are_gifts() else tr("revive.watch")


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
	_revive_top = top
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
	_revive_bottom = bottom
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	bottom.add_child(box)
	_revive_watch = _menu_button(revive_text(), _answer_revive.bind(true), REVIVE_WATCH)
	_revive_watch.name = "ReviveWatch"
	box.add_child(_revive_watch)
	var results := _menu_button(tr("revive.results"), _answer_revive.bind(false), Vector2(200, 26))
	box.add_child(results)
	_root.add_child(_revive_panel)
	_style_revive_buttons(_revive_watch, results)


## Responde a oferta uma vez só: o painel fecha antes de emitir, e qualquer toque, clique ou
## tempo esgotado que chegue depois (no mesmo quadro ou no seguinte) é ignorado.
func _answer_revive(accept: bool) -> void:
	if not _revive_panel.visible:
		return
	_revive_panel.visible = false
	revive_answered.emit(accept)


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


## Travessia para o Kakuriyo (scripts/ui/realm_card.gd), por cima de toda a HUD.
func realm_card() -> RealmCard:
	var card := _root.get_node_or_null(^"RealmCard") as RealmCard
	if card == null:
		card = RealmCard.new()
		card.name = "RealmCard"
		card.visible = false
		_root.add_child(card)
	return card


func realm_card_exists() -> bool:
	return _root != null and _root.get_node_or_null(^"RealmCard") != null


func realm_active() -> bool:
	return realm_card_exists() and realm_card().active


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
	_speed_locked = GameClock.max_speed <= 1
	var caption := "%s %dx" % [tr("pause.speed_caption"), _speed_shown]
	_speed_button.tooltip_text = tr("speed.locked") if _speed_locked else caption
	_speed_button.queue_redraw()
	if _pause:
		_pause.set_speed(_speed_shown, _speed_locked)


## Velocidade presa em 1x até a compra da Ampulheta de Fūjin (botão com cadeado).
func speed_locked() -> bool:
	return _speed_locked


## Toque na velocidade sem a compra: som de negado, tremida curta (no botão do canto ou no da
## pausa) e o aviso de onde liberar. A partida segue; nenhuma tela abre.
func deny_speed() -> void:
	refresh_speed()
	AudioManager.play_ui("ui_cancel")
	if _pause.is_open():
		_pause.deny_speed(tr("speed.locked"))
		return
	_deny_left = DENY_TIME
	_speed_button.scale = Vector2.ONE
	_speed_button.queue_redraw()
	toast(tr("speed.locked"), 3.0)


## Tremida em andamento (testes).
func speed_denied() -> bool:
	return _deny_left > 0.0


## Velocidade mostrada no botão do canto (testes).
func speed_shown() -> int:
	return _speed_shown


## Cor atual do ícone e do multiplicador no botão de velocidade.
func speed_tint() -> Color:
	return SPEED_TINT.get(_speed_shown, SPEED_TINT[3])


## Mesma moldura do botão de pausa (o par se lê como um conjunto): ícone de avanço rápido e o
## multiplicador. Em 1x, claro como o ícone de pausa; acelerado, vai para um selo escuro
## embutido, na cor da velocidade, com aro que respira (parado com "Reduzir flashes").
## Bloqueado (sem a Ampulheta de Fūjin): "1x" esmaecido e o cadeado no canto de cima, à direita
## do texto; o "negado" treme só o conteúdo, sem mexer no botão.
func _draw_speed() -> void:
	var b := _speed_button
	var tint := speed_tint()
	var fast := _speed_shown > 1 and not _speed_locked
	if _speed_locked:
		tint = Color(tint, SPEED_LOCKED_ALPHA)
	var parts := speed_parts()
	var shake := Vector2.ZERO
	if _deny_left > 0.0:
		shake.x = roundf(sin(_deny_left * 70.0) * DENY_SHAKE * _deny_left / DENY_TIME)
	var icon_at := (parts["icon"] as Rect2).position + shake
	var label_rect: Rect2 = parts["label"]
	var label := "%dx" % _speed_shown
	if fast:
		var calm := bool(Settings.get_value("reduce_flashes"))
		var pulse := 1.0 if calm else 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.006)
		var cy := floorf(b.size.y * 0.5)
		var chip := Rect2(icon_at.x - 3.0, cy - 8.0, label_rect.end.x - icon_at.x + 6.0, 16.0)
		b.draw_rect(chip, Color(0.14, 0.05, 0.03, 0.92))
		b.draw_rect(chip.grow(-0.5), Color(tint, 0.45 + 0.5 * pulse), false, 1.0)
	var icon := UiIcons.get_icon("fast_forward", SPEED_ICON)
	if icon:
		b.draw_texture(icon, icon_at, tint)
	var font := Locale.font
	var base := Vector2(label_rect.position.x, float(parts["baseline"])) + shake
	b.draw_string_outline(font, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0.1, 0.05, 0.05))
	b.draw_string(font, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)
	if _speed_locked:
		var lock_color := LOCK_TINT if _deny_left <= 0.0 else SPEED_TINT[3]
		UiPaint.padlock(b, (parts["lock"] as Rect2).position + shake, lock_color)


## Peças do botão de velocidade, no espaço do botão: "icon", "label" (caixa do texto, da
## ascendente à descendente), "baseline" e, bloqueado, "lock" (caixa do cadeado). Testes de layout.
func speed_parts() -> Dictionary:
	var b := _speed_button
	var font := Locale.font
	var label := "%dx" % _speed_shown
	var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var lock_w := UiPaint.PADLOCK_SIZE.x + 1.0 if _speed_locked else 0.0
	var total := SPEED_ICON + 2.0 + text_w + lock_w
	var x := floorf((b.size.x - total) * 0.5)
	var cy := floorf(b.size.y * 0.5)
	var baseline := cy + 5.0
	var label_rect := Rect2(x + SPEED_ICON + 2.0, baseline - font.get_ascent(12), text_w,
			font.get_ascent(12) + font.get_descent(12))
	var parts := {"icon": Rect2(x, cy - SPEED_ICON * 0.5, SPEED_ICON, SPEED_ICON), "label": label_rect,
			"baseline": baseline}
	if _speed_locked:
		parts["lock"] = Rect2(Vector2(label_rect.end.x + 1.0, label_rect.position.y), UiPaint.PADLOCK_SIZE)
	return parts


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
	elif _kami_panel.is_open():
		kami_chosen.emit(_kami_panel.bot_choose())
	elif _revive_panel.visible:
		_answer_revive(false)


func _process(delta: float) -> void:
	_top.queue_redraw()
	_ult_button.queue_redraw()
	if (_speed_shown > 1 or _deny_left > 0.0) and _speed_button.visible:
		_speed_button.queue_redraw()
	if _deny_left > 0.0:
		_deny_left = maxf(0.0, _deny_left - delta)
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
			_answer_revive(false)
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
	_layout_ultimate()


## Botão do golpe no canto oposto ao joystick (canhotos, plano 4.1), fora do recorte da câmera.
func _layout_ultimate() -> void:
	if joystick.left_side:
		_ult_button.anchor_left = 1.0
		_ult_button.anchor_right = 1.0
		_ult_button.offset_left = -ULT_SIZE - 10.0 - _insets.y
		_ult_button.offset_right = -10.0 - _insets.y
	else:
		_ult_button.anchor_left = 0.0
		_ult_button.anchor_right = 0.0
		_ult_button.offset_left = 10.0 + _insets.x
		_ult_button.offset_right = ULT_SIZE + 10.0 + _insets.x


## Posições que dependem da área segura (recorte da câmera): botões dos cantos, golpe,
## joystick fixo, textos de largura cheia, faixas do reviver e o topo (as telas de nova
## habilidade, baú e Kami refazem o próprio layout).
func _layout() -> void:
	_insets = MenuKit.safe_insets(_root)
	for slot: int in 2:
		var button := _pause_button if slot == 0 else _speed_button
		var right := -4.0 - slot * (CORNER_BUTTON.x + 4.0) - _insets.y
		button.offset_right = right
		button.offset_left = right - CORNER_BUTTON.x
	_layout_ultimate()
	joystick.insets = _insets
	joystick.queue_redraw()
	var wide: Array[Control] = [_boss_label, _boss_line, _hint, _revive_top, _revive_bottom]
	for control: Control in wide:
		control.offset_left = _insets.x
		control.offset_right = -_insets.y
	_debug.position.x = 4.0 + _insets.x
	_top.queue_redraw()


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
