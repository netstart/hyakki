class_name PauseMenu
extends Control
## Tela de pausa (plano 7.3). A partida recua sob um véu de noite com vinheta e fogos-fátuos
## (hitodama) subindo devagar. À esquerda: fase, título com ornamento dourado, a trilha da
## noite até o amanhecer, tempo/nível/abates/ryō e as ações — "Continuar" em destaque,
## velocidade e música em botões compactos que mostram o estado atual, a qualidade gráfica
## (ciclo Auto → Baixa → Média → Alta, com o nível efetivo em Auto) e "Desistir" discreto,
## com confirmação. À direita, o equipamento: armas e itens com ícone e nível em marcas, e os
## atributos numa grade alinhada (acima da base em verde-jade, abaixo em brasa).
## Se ajusta a 20:9 e 16:9 e às bordas seguras do aparelho; o painel rola se não couber.
## GameClock.paused não pausa a SceneTree: as animações e tweens seguem rodando aqui.

signal resume_pressed
signal speed_pressed
signal quit_pressed

const GOLD := Color("d9a441")
const VERMILION := Color("b23a26")
const DIM := Color(0.8, 0.76, 0.72)
const JADE := Color("9fe0a8")
const EMBER := Color("ff9b80")
const INK := Color(0.04, 0.032, 0.08, 0.92)
const DANGER_TEXT := Color("eba597")
const MOTE := Color(0.64, 0.88, 1.0)
## Entrada e saída (segundos) e deslocamento das colunas na entrada.
const OPEN_TIME := 0.22
const CLOSE_TIME := 0.14
const SHIFT := 10.0
## Margens: fora (até a borda segura), entre as colunas e dentro do painel.
const MARGIN := 10.0
const GAP := 12.0
const PANEL_PAD := Vector2(10, 8)
## Folga entre o conteúdo do painel e a barra de rolagem (fora a largura da barra).
const SCROLL_GAP := 6.0
const LEFT_MIN := 184.0
const LEFT_MAX := 212.0
const RESUME_HEIGHT := 40.0
const BADGE := 11.0
const TILE_HEIGHT := 34.0
const QUIT_HEIGHT := 22.0
## Barras do nível da qualidade gráfica no botão da pausa.
const QUALITY_BARS := Vector2(11, 10)
const RUN_TILE_HEIGHT := 20.0
## Linha de arma/item: caixa do ícone com 1 px de folga para ícones de até 24 px (escala inteira).
const ROW_HEIGHT := 26.0
const SLOT := 26.0
const PIP := Vector2(3, 6)
const PIP_STEP := 4.0
const MOTES := 26
## Larguras mínimas de cada célula das grades do painel (definem quantas colunas cabem).
const BUILD_CELL := 150.0
const STAT_CELL := 118.0
const RUN_ICONS := {
	"time": "res://assets/art/items/object/Hourglass.png",
	"level": "res://assets/art/ui/icons/spell/Upgrade.png",
	"kills": "res://assets/art/ui/icons/spell/Cut.png",
	"ryo": "res://assets/art/ui/icons/items/Money.png",
}
## Atributos mostrados, na ordem da grade (os mesmos da pausa antiga).
const STATS: Array[String] = ["max_hp", "regen", "armor", "speed", "might", "area", "cooldown",
		"amount", "duration", "magnet", "luck", "growth", "greed", "curse", "light"]
## Mostrados como número inteiro (os outros, "pct", em %).
const FLAT_STATS: Array[String] = ["max_hp", "speed", "magnet", "light"]


## Marcas de nível (uma por nível; acesas até o atual) ou "MÁX" no nível máximo.
class Pips:
	extends Control
	var level: int = 0
	var max_level: int = 1
	var color: Color = GOLD

	func setup(p_level: int, p_max: int, p_color: Color) -> void:
		level = p_level
		max_level = maxi(p_max, 1)
		color = p_color
		custom_minimum_size = Vector2(max_level * PIP_STEP - 1.0, PIP.y)
		queue_redraw()

	func _draw() -> void:
		var y := floorf((size.y - PIP.y) * 0.5)
		for i: int in range(max_level):
			var lit := i < level
			draw_rect(Rect2(Vector2(i * PIP_STEP, y), PIP), color if lit else Color(1, 1, 1, 0.14))
			if lit:
				draw_rect(Rect2(Vector2(i * PIP_STEP, y), Vector2(PIP.x, 1)), Color(1, 1, 1, 0.45))


var _open: bool = false
var _snapshot: Dictionary = {}
var _calm: bool = false
var _intro: float = 1.0
var _tween: Tween
var _left_rect := Rect2()
var _panel_rect := Rect2()

var _sky: Control
var _vignette: GradientTexture2D
var _shade: GradientTexture2D
var _motes: PackedVector2Array = []
var _mote_speed: PackedFloat32Array = []
var _mote_phase: PackedFloat32Array = []
var _rng := RandomNumberGenerator.new()

var _left: Control
var _menu: VBoxContainer
var _kicker: Label
var _title: Label
var _night: Control
var _run_grid: GridContainer
var _run_values: Dictionary = {}
var _resume: Button
var _speed: Button
var _speed_caption: Label
var _speed_value: Label
var _music: Button
var _music_icon: TextureRect
var _music_caption: Label
var _music_value: Label
var _quality: Button
var _quality_bars: Control
var _quality_caption: Label
var _quality_value: Label
var _quit: Button
## Qualidade + Desistir: 1 coluna (um embaixo do outro) ou 2 (lado a lado, telas baixas).
var _bottom: GridContainer
var _compact: bool = false

var _panel: Control
var _scroll: ScrollContainer
var _build: VBoxContainer
var _fade: Control
var _weapons_head: Label
var _weapons_count: Label
var _weapons_grid: GridContainer
var _items_head: Label
var _items_count: Label
var _items_grid: GridContainer
var _no_items: Label
var _stats_head: Label
var _stats_grid: GridContainer

var _confirm: Control
var _confirm_card: PanelContainer
var _confirm_title: Label
var _confirm_body: Label
var _confirm_back: Button
var _confirm_quit: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_rng.seed = 11
	_build_sky()
	_build_left()
	_build_panel()
	_build_confirm()
	resized.connect(_layout)
	Settings.changed.connect(_on_setting)
	_seed_motes()


# --- API ---------------------------------------------------------------------------------

## Abre com os dados da partida (ver Hud.pause_snapshot): entrada com fade e deslize.
func open(snapshot: Dictionary) -> void:
	_snapshot = snapshot
	_calm = bool(Settings.get_value("reduce_flashes"))
	_apply_texts()
	_fill(snapshot)
	set_speed(int(snapshot.get("speed", GameClock.speed)))
	_refresh_music()
	_refresh_quality()
	_confirm.visible = false
	if not visible:
		_intro = 0.0
	_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layout()
	_scroll.scroll_vertical = 0
	_animate(1.0, OPEN_TIME, Tween.EASE_OUT)


## Fecha. Com animação, some em CLOSE_TIME, mas já conta como fechada (e ignora toques).
func close(animated: bool = true) -> void:
	_open = false
	_confirm.visible = false
	if not animated or not visible:
		_kill_tween()
		visible = false
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_animate(0.0, CLOSE_TIME, Tween.EASE_IN)


func is_open() -> bool:
	return _open


func set_speed(speed: int) -> void:
	_speed_value.text = "%dx" % speed


func confirm_open() -> bool:
	return _confirm.visible


## "Voltar" (Esc / botão do Android) com a confirmação aberta: só fecha a confirmação.
func back() -> bool:
	if _confirm.visible:
		_hide_confirm()
		return true
	return false


func music_on() -> bool:
	return float(Settings.get_value("music_volume")) > 0.0


# --- Ações -------------------------------------------------------------------------------

func _on_resume() -> void:
	if _open and not _confirm.visible:
		resume_pressed.emit()


func _on_speed() -> void:
	if _open and not _confirm.visible:
		speed_pressed.emit()


## Mesmo efeito da pausa antiga: só a música, entre 0 e 0,7.
func _on_music() -> void:
	if not _open or _confirm.visible:
		return
	Settings.set_value("music_volume", 0.0 if music_on() else 0.7)
	_refresh_music()


## Qualidade gráfica em ciclo: Auto → Baixa → Média → Alta → Auto (vale na hora).
func _on_quality() -> void:
	if not _open or _confirm.visible:
		return
	Settings.set_value(GfxQuality.changed_signal_key(), GfxQuality.next_mode(GfxQuality.mode()))
	_refresh_quality()


func _on_quit() -> void:
	if _open and not _confirm.visible:
		_show_confirm()


func _on_confirm_quit() -> void:
	if not _open:
		return
	close(false)
	quit_pressed.emit()


func _on_setting(key: String) -> void:
	if key == "music_volume" and is_instance_valid(_music_value):
		_refresh_music()
	elif key == GfxQuality.changed_signal_key() and is_instance_valid(_quality_value):
		_refresh_quality()


func _refresh_music() -> void:
	var on := music_on()
	_music_icon.texture = UiIcons.get_icon("music_on" if on else "music_off", 16)
	_music_icon.modulate = ThemeFactory.ACCENT if on else DIM.darkened(0.2)
	_music_value.text = tr("pause.on") if on else tr("pause.off")
	_music_value.add_theme_color_override("font_color", ThemeFactory.TEXT if on else DIM)


## Telas baixas (ex.: 16:9 com 270 de altura): Qualidade e Desistir dividem uma linha; a
## qualidade perde a legenda e, em Auto, mostra só "Auto" (as barras dão o nível efetivo).
func _set_compact(on: bool) -> void:
	_compact = on
	_bottom.columns = 2 if on else 1
	_quality_caption.visible = not on
	_refresh_quality()


## Mostra a opção e, em Auto, o nível que vale ("Auto (Alta)"); as barras acendem até ele.
func _refresh_quality() -> void:
	var mode := GfxQuality.mode()
	_quality_value.text = tr("options.gfx_auto") if _compact and mode == "auto" else GfxQuality.mode_label(mode)
	_quality_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _compact else Control.SIZE_FILL
	_quality_bars.queue_redraw()


func _show_confirm() -> void:
	_confirm.visible = true
	_confirm.modulate.a = 0.0
	_confirm_card.pivot_offset = _confirm_card.size * 0.5
	_confirm_card.scale = Vector2.ONE * 0.94
	var tween := create_tween().set_parallel()
	tween.tween_property(_confirm, "modulate:a", 1.0, 0.14)
	tween.tween_property(_confirm_card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


func _hide_confirm() -> void:
	_confirm.visible = false


# --- Animação ----------------------------------------------------------------------------

func _animate(to: float, time: float, ease_type: Tween.EaseType) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_method(_set_intro, _intro if visible else 0.0, to, time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)
	if to <= 0.0:
		_tween.tween_callback(func() -> void:
			if not _open:
				visible = false)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


## 0 = fora (transparente, colunas afastadas), 1 = no lugar.
func _set_intro(t: float) -> void:
	_intro = t
	modulate.a = t
	var away := (1.0 - t) * SHIFT
	_left.position = _left_rect.position - Vector2(away, 0.0)
	_panel.position = _panel_rect.position + Vector2(away, 0.0)


func _process(delta: float) -> void:
	if not visible:
		return
	var view := size
	for i: int in range(_motes.size()):
		var p := _motes[i]
		p.y -= _mote_speed[i] * delta
		p.x += sin(_mote_phase[i] + p.y * 0.04) * 3.0 * delta
		if p.y < -4.0:
			p = Vector2(_rng.randf() * view.x, view.y + 4.0)
		_motes[i] = p
		_mote_phase[i] += delta * (0.6 if _calm else 1.6)
	_sky.queue_redraw()
	_fade.visible = _scroll.get_v_scroll_bar().visible \
			and _scroll.scroll_vertical < _scroll.get_v_scroll_bar().max_value - _scroll.size.y - 1.0


# --- Layout ------------------------------------------------------------------------------

## Bordas seguras (recorte da câmera, cantos) em pixels lógicos; zero fora do celular.
func _safe_insets() -> Vector2:
	if not OS.has_feature("mobile") or not is_inside_tree():
		return Vector2.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var screen := Vector2(DisplayServer.screen_get_size())
	var scale_x := get_viewport().get_final_transform().x.x
	if safe.size.x <= 0.0 or scale_x <= 0.0:
		return Vector2.ZERO
	return Vector2(maxf(safe.position.x, 0.0), maxf(screen.x - safe.end.x, 0.0)) / scale_x


func _layout() -> void:
	if _left == null:
		return
	var insets := _safe_insets()
	var view := size
	var left_w := clampf(roundf(view.x * 0.31), LEFT_MIN, LEFT_MAX)
	var x0 := MARGIN + insets.x
	_left_rect = Rect2(x0, MARGIN, left_w, view.y - MARGIN * 2.0)
	var px := _left_rect.end.x + GAP
	_panel_rect = Rect2(px, MARGIN, view.x - MARGIN - insets.y - px, view.y - MARGIN * 2.0)
	_left.size = _left_rect.size
	_set_compact(false)
	_set_compact(_menu.get_combined_minimum_size().y > _left_rect.size.y)
	_panel.size = _panel_rect.size
	_set_intro(_intro)
	var inner := _panel_rect.size.x - PANEL_PAD.x * 2.0 - 6.0
	_weapons_grid.columns = clampi(floori(inner / BUILD_CELL), 1, 3)
	_items_grid.columns = _weapons_grid.columns
	_stats_grid.columns = clampi(floori(inner / STAT_CELL), 1, 3)
	var font := get_theme_font("font", "Label")
	var room := left_w - BADGE * 2.0 - 30.0
	_resume.add_theme_font_size_override("font_size",
			24 if font.get_string_size(_resume.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x <= room else 12)
	_confirm_card.custom_minimum_size.x = minf(280.0, view.x - 40.0)


# --- Conteúdo ----------------------------------------------------------------------------

func _apply_texts() -> void:
	_title.text = tr("pause.title")
	_resume.text = tr("pause.resume")
	_resume.tooltip_text = _resume.text
	_speed_caption.text = tr("pause.speed_caption")
	_speed.tooltip_text = _speed_caption.text
	_music_caption.text = tr("options.music_volume")
	_music.tooltip_text = _music_caption.text
	_quality_caption.text = tr("pause.graphics")
	_quality.tooltip_text = tr("options.graphics_quality")
	_quit.text = tr("pause.quit")
	_weapons_head.text = tr("codex.weapons")
	_items_head.text = tr("pause.items")
	_stats_head.text = tr("pause.stats")
	_no_items.text = tr("pause.no_items")
	_confirm_title.text = tr("pause.quit_title")
	_confirm_body.text = tr("pause.quit_body")
	_confirm_back.text = tr("menu.back")
	_confirm_quit.text = tr("pause.quit_confirm")


func _fill(s: Dictionary) -> void:
	_kicker.text = String(s.get("subtitle", ""))
	_kicker.tooltip_text = _kicker.text
	var seconds := floori(float(s.get("time", 0.0)))
	_run_values["time"].text = "%02d:%02d" % [floori(seconds / 60.0), seconds % 60]
	_run_values["level"].text = tr("hud.level") % int(s.get("level", 1))
	_run_values["kills"].text = Locale.format_number(int(s.get("kills", 0)))
	_run_values["ryo"].text = Locale.format_number(int(s.get("ryo", 0)))
	_night.queue_redraw()
	var weapons: Array = s.get("weapons", [])
	_fill_grid(_weapons_grid, weapons, true)
	_weapons_count.text = "%d/%d" % [weapons.size(), int(s.get("weapon_cap", weapons.size()))]
	var items: Array = s.get("items", [])
	_fill_grid(_items_grid, items, false)
	_items_count.text = "%d/%d" % [items.size(), int(s.get("item_cap", items.size()))]
	_no_items.visible = items.is_empty()
	_items_grid.visible = not items.is_empty()
	_fill_stats(s.get("stats", {}))


func _fill_grid(grid: GridContainer, rows: Array, weapons: bool) -> void:
	_clear(grid)
	for row: Dictionary in rows:
		grid.add_child(_build_row(row, weapons))


func _build_row(row: Dictionary, weapon: bool) -> Control:
	var evolved := bool(row.get("evolved", false))
	var level := int(row.get("level", 1))
	var top := int(row.get("max", 1))
	var line := HBoxContainer.new()
	line.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation", 5)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.tooltip_text = String(row.get("name", ""))
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(SLOT, SLOT)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border := ThemeFactory.ACCENT if evolved else Color(GOLD, 0.45 if weapon else 0.3)
	slot.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, slot.size)
		slot.draw_rect(r, Color(0, 0, 0, 0.45))
		slot.draw_rect(r.grow(-0.5), border, false, 1.0))
	slot.add_child(_pixel_icon(_load(String(row.get("icon", ""))), SLOT - 2.0))
	line.add_child(slot)
	var name_label := _label(String(row.get("name", "")), 12, ThemeFactory.ACCENT if evolved else ThemeFactory.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.x = 30.0
	line.add_child(name_label)
	if level >= top:
		var max_label := _label(tr("pause.max"), 12, ThemeFactory.ACCENT)
		line.add_child(max_label)
	else:
		var pips := Pips.new()
		pips.setup(level, top, ThemeFactory.ACCENT if evolved else GOLD)
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(pips)
	return line


func _fill_stats(stats: Dictionary) -> void:
	_clear(_stats_grid)
	for stat: String in STATS:
		if not stats.has(stat):
			continue
		var value := float(stats[stat])
		var cell := HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 4)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := _label(tr("statname.%s" % stat), 12, DIM)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.custom_minimum_size.x = 24.0
		cell.add_child(name_label)
		var tone := stat_tone(stat, value)
		var color := ThemeFactory.TEXT if tone == 0 else (JADE if tone > 0 else EMBER)
		var value_label := _label(format_stat(stat, value), 12, color)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.name = "Value_" + stat
		cell.add_child(value_label)
		_stats_grid.add_child(cell)


## Dados da partida para a tela: contexto, armas, itens e atributos.
static func snapshot_of(game: HyakkiGame) -> Dictionary:
	var weapons: Array[Dictionary] = []
	for weapon: Weapon in game.weapons:
		weapons.append({"id": weapon.id, "name": _tr("weapon.%s.name" % weapon.id),
				"icon": String(weapon.data.get("icon", "")), "level": weapon.level, "max": weapon.max_level,
				"evolved": weapon.is_evolved()})
	var items: Array[Dictionary] = []
	for id: StringName in game.level_up.passive_levels:
		var data: Dictionary = DB.passives[id]
		items.append({"id": id, "name": _tr("passive.%s.name" % id), "icon": String(data.get("icon", "")),
				"level": int(game.level_up.passive_levels[id]), "max": int(data.get("max", 5))})
	var stats := {}
	for stat: String in STATS:
		stats[stat] = game.player.stats.get_stat(stat)
	return {"time": GameClock.game_time, "run_length": HyakkiGame.RUN_LENGTH, "endless": game.endless_phase,
			"level": game.level, "kills": game.tracker.kills, "ryo": game.tracker.ryo,
			"subtitle": run_subtitle(game), "weapons": weapons, "items": items, "stats": stats,
			"weapon_cap": LevelUpSystem.MAX_WEAPONS, "item_cap": LevelUpSystem.MAX_PASSIVES,
			"speed": GameClock.speed}


## "Fase · modo · Lua", como nos Resultados (o modo só quando não é o normal).
static func run_subtitle(game: HyakkiGame) -> String:
	var parts: PackedStringArray = [_tr("stage.%s.name" % String(game.stage.get("id", "")))]
	if bool(game.config.get("daily", false)):
		parts.append(_tr("title.daily"))
	elif game.mode != "normal":
		parts.append(_tr("mode.%s" % game.mode))
	if game.endless_phase:
		parts.append(_tr("stages.endless"))
	if game.moon > 0:
		parts.append(_tr("moon.level") % ["0", "I", "II", "III", "IV", "V"][clampi(game.moon, 0, 5)])
	return " · ".join(parts)


static func _tr(key: String) -> String:
	return TranslationServer.translate(key)


## Mesmo formato da pausa antiga: inteiro para os "flat" e vida/velocidade/ímã/luz; % no resto.
static func format_stat(stat: String, value: float) -> String:
	var mode: String = StatBlock.DEFS[stat][1]
	if mode == "flat" or stat in FLAT_STATS:
		return "%d" % roundi(value)
	return "%d%%" % roundi(value * 100.0)


## 1 = melhor que a base, -1 = pior (ou Maldição acima da base), 0 = igual à base.
static func stat_tone(stat: String, value: float) -> int:
	var base: float = StatBlock.DEFS[stat][0]
	if absf(value - base) < 0.005:
		return 0
	if stat == "curse":
		return -1 if value > base else 1
	if stat == "cooldown":
		return 1 if value < base else -1
	return 1 if value > base else -1


# --- Construção --------------------------------------------------------------------------

func _build_sky() -> void:
	_vignette = GradientTexture2D.new()
	_vignette.width = 256
	_vignette.height = 128
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.5)
	_vignette.fill_to = Vector2(1.05, 1.05)
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0.0, 0.0, 0.02, 0.7))
	g.add_point(0.45, Color(0, 0, 0, 0.05))
	_vignette.gradient = g
	_shade = GradientTexture2D.new()
	_shade.width = 128
	_shade.height = 4
	_shade.fill_from = Vector2(0, 0)
	_shade.fill_to = Vector2(1, 0)
	var s := Gradient.new()
	s.set_color(0, Color(0.01, 0.005, 0.03, 0.55))
	s.set_color(1, Color(0.01, 0.005, 0.03, 0.0))
	_shade.gradient = s
	_sky = Control.new()
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Gradientes suaves (o resto da tela é "nearest").
	_sky.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sky.draw.connect(_draw_sky)
	add_child(_sky)


func _draw_sky() -> void:
	var r := Rect2(Vector2.ZERO, _sky.size)
	_sky.draw_rect(r, Color(0.02, 0.014, 0.05, 0.55))
	_sky.draw_texture_rect(_vignette, r, false)
	_sky.draw_texture_rect(_shade, Rect2(0, 0, r.size.x * 0.6, r.size.y), false)
	for i: int in range(_motes.size()):
		var p := _motes[i].floor()
		var flicker := 0.5 + 0.5 * sin(_mote_phase[i] * 2.3)
		var a := (0.25 + 0.45 * flicker) * (0.6 if _calm else 1.0)
		_sky.draw_circle(p + Vector2(0.5, 0.5), 2.5, Color(MOTE, a * 0.16))
		var dot := Vector2(2, 2) if i % 4 == 0 else Vector2(1, 1)
		_sky.draw_rect(Rect2(p, dot), Color(MOTE, a))


func _seed_motes() -> void:
	var view := size if size.x > 0.0 else Vector2(678, 305)
	_motes.resize(MOTES)
	_mote_speed.resize(MOTES)
	_mote_phase.resize(MOTES)
	for i: int in range(MOTES):
		_motes[i] = Vector2(_rng.randf() * view.x, _rng.randf() * view.y)
		_mote_speed[i] = _rng.randf_range(4.0, 11.0)
		_mote_phase[i] = _rng.randf() * TAU


func _build_left() -> void:
	_left = Control.new()
	_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_left)
	_menu = VBoxContainer.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_theme_constant_override("separation", 4)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left.add_child(_menu)
	_kicker = _label("", 12, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_kicker.clip_text = true
	_kicker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_menu.add_child(_kicker)
	_title = _label("", 24, Color("fff1d6"), HORIZONTAL_ALIGNMENT_CENTER)
	_title.add_theme_constant_override("outline_size", 4)
	_title.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.03))
	_menu.add_child(_title)
	var ornament := Control.new()
	ornament.custom_minimum_size = Vector2(0, 7)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornament.draw.connect(_draw_ornament.bind(ornament))
	_menu.add_child(ornament)
	_night = Control.new()
	_night.custom_minimum_size = Vector2(0, 9)
	_night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_night.draw.connect(_draw_night)
	_menu.add_child(_night)
	_run_grid = GridContainer.new()
	_run_grid.columns = 2
	_run_grid.add_theme_constant_override("h_separation", 4)
	_run_grid.add_theme_constant_override("v_separation", 4)
	_run_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for kind: String in ["time", "level", "kills", "ryo"]:
		_run_grid.add_child(_run_tile(kind))
	_menu.add_child(_run_grid)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(spacer)
	_resume = _button("", _on_resume, Vector2(0, RESUME_HEIGHT))
	_style_resume()
	_menu.add_child(_resume)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed = _button("", _on_speed, Vector2(0, TILE_HEIGHT))
	var speed_parts := _tile_content(_speed, UiIcons.get_icon("fast_forward", 16))
	_speed_caption = speed_parts[1]
	_speed_value = speed_parts[2]
	_speed_value.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	row.add_child(_speed)
	_music = _button("", _on_music, Vector2(0, TILE_HEIGHT))
	var music_parts := _tile_content(_music, null)
	_music_icon = music_parts[0]
	_music_caption = music_parts[1]
	_music_value = music_parts[2]
	row.add_child(_music)
	for b: Button in [_speed, _music]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_tile(b)
	_menu.add_child(row)
	_build_quality()
	_quit = _button("", _on_quit, Vector2(0, QUIT_HEIGHT))
	_quit.icon = UiIcons.get_icon("exit", 12)
	_quit.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_quit()
	_quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom.add_child(_quit)


## Botão compacto de largura inteira da qualidade gráfica: barras de nível, legenda e valor.
func _build_quality() -> void:
	_quality = _button("", _on_quality, Vector2(0, QUIT_HEIGHT))
	_quality.name = "PauseQuality"
	_style_tile(_quality)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 6)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quality_bars = Control.new()
	_quality_bars.custom_minimum_size = QUALITY_BARS
	_quality_bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_quality_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quality_bars.draw.connect(_draw_quality_bars)
	line.add_child(_quality_bars)
	_quality_caption = _label("", 12, DIM)
	_quality_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quality_caption.clip_text = true
	_quality_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(_quality_caption)
	_quality_value = _label("", 12, ThemeFactory.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	line.add_child(_quality_value)
	margin.add_child(line)
	_quality.add_child(margin)
	_quality.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom = GridContainer.new()
	_bottom.columns = 1
	_bottom.add_theme_constant_override("h_separation", 4)
	_bottom.add_theme_constant_override("v_separation", 4)
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_child(_quality)
	_menu.add_child(_bottom)


## Três barras crescentes; acesas até o nível efetivo (douradas), as outras apagadas.
func _draw_quality_bars() -> void:
	var lit := GfxQuality.level()
	var w := 3.0
	for i: int in range(3):
		var h := 4.0 + i * 3.0
		var rect := Rect2(Vector2(i * (w + 1.0), QUALITY_BARS.y - h), Vector2(w, h))
		_quality_bars.draw_rect(rect, ThemeFactory.ACCENT if i <= lit else Color(1, 1, 1, 0.16))


func _run_tile(kind: String) -> Control:
	var tile := PanelContainer.new()
	var box := _flat(Color(0, 0, 0, 0.38), Color(GOLD, 0.22), 1, 2)
	box.content_margin_left = 5
	box.content_margin_right = 5
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	tile.add_theme_stylebox_override("panel", box)
	tile.custom_minimum_size = Vector2(0, RUN_TILE_HEIGHT)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := _texture_rect(_load(String(RUN_ICONS[kind])), Vector2(16, 16))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(icon)
	var value := _label("", 12, ThemeFactory.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.name = "Run_" + kind
	line.add_child(value)
	tile.add_child(line)
	_run_values[kind] = value
	return tile


## Conteúdo de um botão compacto: ícone à esquerda, legenda (apagada) e valor (claro).
func _tile_content(button: Button, icon_tex: Texture2D) -> Array:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 4)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := _texture_rect(icon_tex, Vector2(16, 16))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = ThemeFactory.ACCENT
	line.add_child(icon)
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption := _label("", 12, DIM)
	var value := _label("", 12, ThemeFactory.TEXT)
	texts.add_child(caption)
	texts.add_child(value)
	line.add_child(texts)
	margin.add_child(line)
	button.add_child(margin)
	return [icon, caption, value]


func _build_panel() -> void:
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_draw_panel)
	add_child(_panel)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = PANEL_PAD.x
	_scroll.offset_right = -6.0
	_scroll.offset_top = PANEL_PAD.y
	_scroll.offset_bottom = -PANEL_PAD.y
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scrollbar(_scroll.get_v_scroll_bar())
	_panel.add_child(_scroll)
	_build = VBoxContainer.new()
	_build.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build.add_theme_constant_override("separation", 3)
	# Reserva a barra de rolagem e uma folga: nada encosta nela nem na moldura.
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", int(_scroll.get_v_scroll_bar().custom_minimum_size.x + SCROLL_GAP))
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(_build)
	_scroll.add_child(pad)
	var weapons := _section()
	_weapons_head = weapons[0]
	_weapons_count = weapons[1]
	_weapons_grid = _grid()
	_build.add_child(_weapons_grid)
	_build.add_child(_gap(4))
	var items := _section()
	_items_head = items[0]
	_items_count = items[1]
	_items_grid = _grid()
	_build.add_child(_items_grid)
	_no_items = _label("", 12, Color(DIM, 0.7))
	_no_items.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	_no_items.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_build.add_child(_no_items)
	_build.add_child(_gap(4))
	var stats := _section()
	_stats_head = stats[0]
	stats[1].visible = false
	_stats_grid = GridContainer.new()
	_stats_grid.add_theme_constant_override("h_separation", 14)
	_stats_grid.add_theme_constant_override("v_separation", 1)
	_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build.add_child(_stats_grid)
	# Indica que há mais embaixo quando o conteúdo rola.
	_fade = Control.new()
	_fade.anchor_left = 0.0
	_fade.anchor_right = 1.0
	_fade.anchor_top = 1.0
	_fade.anchor_bottom = 1.0
	_fade.offset_left = 2.0
	_fade.offset_right = -2.0
	_fade.offset_top = -PANEL_PAD.y - 14.0
	_fade.offset_bottom = -2.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.draw.connect(func() -> void:
		var h := int(_fade.size.y)
		for y: int in range(h):
			_fade.draw_rect(Rect2(0, y, _fade.size.x, 1), Color(INK, INK.a * float(y + 1) / h)))
	_fade.visible = false
	_panel.add_child(_fade)


## Cabeçalho de seção: nome dourado, fio que se estende e contagem à direita.
func _section() -> Array:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := _label("", 12, GOLD.lightened(0.15))
	line.add_child(head)
	var rule := Control.new()
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.draw.connect(func() -> void:
		var y := floorf(rule.size.y * 0.5) + 1.0
		var w := rule.size.x
		for i: int in range(int(w)):
			var a := 0.5 * (1.0 - float(i) / maxf(w, 1.0))
			rule.draw_rect(Rect2(i, y, 1, 1), Color(GOLD, a)))
	line.add_child(rule)
	var count := _label("", 12, Color(DIM, 0.75))
	line.add_child(count)
	_build.add_child(line)
	return [head, count]


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 3)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return grid


func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm.visible = false
	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.01, 0.005, 0.03, 0.6)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(center)
	_confirm_card = PanelContainer.new()
	var card := _flat(INK, Color(VERMILION, 0.9), 1, 12)
	card.content_margin_top = 10
	card.content_margin_bottom = 10
	card.shadow_color = Color(0, 0, 0, 0.5)
	card.shadow_size = 6
	_confirm_card.add_theme_stylebox_override("panel", card)
	center.add_child(_confirm_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_confirm_card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var warn := _texture_rect(UiIcons.get_icon("warning", 16), Vector2(16, 16))
	warn.modulate = ThemeFactory.ACCENT
	warn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(warn)
	_confirm_title = _label("", 12, ThemeFactory.ACCENT)
	_confirm_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_confirm_title)
	box.add_child(head)
	_confirm_body = _label("", 12, DIM)
	_confirm_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_confirm_body)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	_confirm_back = _button("", _hide_confirm, Vector2(0, 26))
	_confirm_quit = _button("", _on_confirm_quit, Vector2(0, 26))
	for b: Button in [_confirm_back, _confirm_quit]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)
	_style_tile(_confirm_back)
	_style_danger(_confirm_quit)
	box.add_child(buttons)
	add_child(_confirm)


# --- Desenho -----------------------------------------------------------------------------

## Fio dourado com losango vermelhão no meio (─── ◆ ───), mais forte perto do centro.
func _draw_ornament(control: Control) -> void:
	var w := control.size.x
	var c := floorf(w * 0.5)
	var y := 3.0
	var reach := minf(w * 0.5 - 8.0, 70.0)
	for i: int in range(int(reach)):
		var a := 0.9 * (1.0 - float(i) / reach)
		control.draw_rect(Rect2(c - 6.0 - i, y, 1, 1), Color(GOLD, a))
		control.draw_rect(Rect2(c + 6.0 + i, y, 1, 1), Color(GOLD, a))
	var diamond := PackedVector2Array([Vector2(c, y - 3.0), Vector2(c + 3.5, y + 0.5), Vector2(c, y + 4.0),
			Vector2(c - 3.5, y + 0.5)])
	control.draw_colored_polygon(diamond, VERMILION)
	control.draw_polyline(diamond + PackedVector2Array([diamond[0]]), ThemeFactory.ACCENT, 1.0)
	for side: float in [-1.0, 1.0]:
		control.draw_rect(Rect2(c + side * 9.0 - 0.5, y - 1.0, 2, 2), Color(GOLD, 0.9))


## Trilha da noite: da lua (início) ao sol (amanhecer); a parte vivida acende em dourado.
func _draw_night() -> void:
	var w := _night.size.x
	var y := floorf(_night.size.y * 0.5)
	var x0 := 18.0
	var x1 := w - 18.0
	var length := float(_snapshot.get("run_length", 900.0))
	var endless := bool(_snapshot.get("endless", false))
	var k := 1.0 if endless else clampf(float(_snapshot.get("time", 0.0)) / maxf(length, 1.0), 0.0, 1.0)
	_night.draw_rect(Rect2(x0, y, x1 - x0, 1), Color(1, 1, 1, 0.16))
	var lit := Color(VERMILION.lightened(0.2)) if endless else GOLD
	_night.draw_rect(Rect2(x0, y, roundf((x1 - x0) * k), 1), lit)
	# Lua crescente no começo, sol no fim, e a chama da guardiã no ponto atual.
	_night.draw_circle(Vector2(x0 - 7.0, y + 0.5), 3.0, Color(0.85, 0.88, 1.0, 0.9))
	_night.draw_circle(Vector2(x0 - 5.5, y - 0.5), 2.6, Color(0.02, 0.014, 0.05, 1.0))
	var sun := Vector2(x1 + 7.0, y + 0.5)
	_night.draw_circle(sun, 2.5, ThemeFactory.ACCENT if k >= 1.0 and not endless else Color(ThemeFactory.ACCENT, 0.55))
	for i: int in range(8):
		var dir := Vector2.from_angle(TAU * i / 8.0)
		_night.draw_rect(Rect2((sun + dir * 4.5).floor(), Vector2.ONE), Color(ThemeFactory.ACCENT, 0.5))
	var at := Vector2(roundf(x0 + (x1 - x0) * k), y)
	_night.draw_circle(at + Vector2(0.5, 0.5), 3.0, Color(lit, 0.3))
	_night.draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), Color("fff1d6"))


## Painel de laca: fundo escuro, moldura dupla dourada e cantoneiras.
func _draw_panel() -> void:
	var r := Rect2(Vector2.ZERO, _panel.size)
	_panel.draw_rect(r, INK)
	_panel.draw_rect(r.grow(-0.5), Color(GOLD, 0.55), false, 1.0)
	_panel.draw_rect(r.grow(-3.5), Color(GOLD, 0.16), false, 1.0)
	var arm := 7.0
	var c := ThemeFactory.ACCENT
	for corner: Vector2 in [Vector2.ZERO, Vector2(r.size.x - 1.0, 0), Vector2(0, r.size.y - 1.0), r.size - Vector2.ONE]:
		var sx := 1.0 if corner.x < 1.0 else -1.0
		var sy := 1.0 if corner.y < 1.0 else -1.0
		_panel.draw_rect(Rect2(corner.x if sx > 0 else corner.x - arm + 1.0, corner.y, arm, 1), c)
		_panel.draw_rect(Rect2(corner.x, corner.y if sy > 0 else corner.y - arm + 1.0, 1, arm), c)
		_panel.draw_rect(Rect2(corner + Vector2(sx, sy) * 2.0, Vector2.ONE), Color(c, 0.8))


## Selo do botão Continuar: círculo com aro dourado e o ícone de play.
func _draw_resume_badge() -> void:
	var c := Vector2(8.0 + BADGE, floorf(_resume.size.y * 0.5))
	_resume.draw_circle(c, BADGE, VERMILION.darkened(0.35))
	_resume.draw_arc(c, BADGE - 0.5, 0.0, TAU, 32, ThemeFactory.ACCENT, 1.0)
	var play := UiIcons.get_icon("play", 12)
	if play:
		_resume.draw_texture(play, c - Vector2(5.0, 6.0), Color("fff1d6"))


# --- Estilos -----------------------------------------------------------------------------

func _style_resume() -> void:
	var normal := _flat(VERMILION, ThemeFactory.ACCENT, 2, 6)
	normal.shadow_color = Color(ThemeFactory.ACCENT, 0.28)
	normal.shadow_size = 3
	normal.content_margin_left = 8.0 + BADGE * 2.0 + 4.0
	normal.content_margin_right = 10.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = VERMILION.lightened(0.12)
	hover.border_color = Color.WHITE
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = VERMILION.darkened(0.25)
	_styles(_resume, normal, hover, pressed)
	_resume.add_theme_color_override("font_color", Color("fff1d6"))
	_resume.add_theme_color_override("font_hover_color", Color.WHITE)
	_resume.add_theme_color_override("font_pressed_color", ThemeFactory.ACCENT)
	_resume.add_theme_constant_override("outline_size", 4)
	_resume.add_theme_color_override("font_outline_color", Color(0.25, 0.04, 0.02))
	_resume.draw.connect(_draw_resume_badge)


func _style_tile(button: Button) -> void:
	var normal := _flat(Color(0.05, 0.04, 0.09, 0.88), Color(GOLD, 0.45), 1, 6)
	var hover := _flat(Color(0.08, 0.06, 0.12, 0.92), ThemeFactory.ACCENT, 1, 6)
	var pressed := _flat(Color(0.02, 0.015, 0.04, 0.95), ThemeFactory.ACCENT, 1, 6)
	_styles(button, normal, hover, pressed)


func _style_quit() -> void:
	var normal := _flat(Color(0.1, 0.02, 0.02, 0.35), Color(VERMILION, 0.6), 1, 6)
	var hover := _flat(Color(0.2, 0.04, 0.03, 0.55), VERMILION.lightened(0.3), 1, 6)
	var pressed := _flat(Color(0.25, 0.05, 0.03, 0.7), VERMILION.lightened(0.3), 1, 6)
	_styles(_quit, normal, hover, pressed)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_quit.add_theme_color_override(key, DANGER_TEXT)
	for key: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		_quit.add_theme_color_override(key, DANGER_TEXT)


func _style_danger(button: Button) -> void:
	var normal := _flat(VERMILION, ThemeFactory.ACCENT, 1, 6)
	var hover := _flat(VERMILION.lightened(0.12), Color.WHITE, 1, 6)
	var pressed := _flat(VERMILION.darkened(0.25), ThemeFactory.ACCENT, 1, 6)
	_styles(button, normal, hover, pressed)
	button.add_theme_color_override("font_color", Color("fff1d6"))


func _style_scrollbar(bar: VScrollBar) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.06)
	track.content_margin_left = 1
	track.content_margin_right = 1
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(GOLD, 0.7)
	grab.content_margin_left = 1
	grab.content_margin_right = 1
	var grab_hot := grab.duplicate() as StyleBoxFlat
	grab_hot.bg_color = ThemeFactory.ACCENT
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", grab_hot)
	bar.add_theme_stylebox_override("grabber_pressed", grab_hot)
	bar.custom_minimum_size.x = 3


func _styles(button: Button, normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat) -> void:
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func _flat(bg: Color, border: Color, width: int, pad: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(3)
	box.anti_aliasing = false
	box.set_content_margin_all(pad)
	return box


# --- Utilidades --------------------------------------------------------------------------

func _label(text: String, font_size: int = 12, color: Color = ThemeFactory.TEXT,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font_size != 12:
		label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, on_press: Callable, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_press)
	button.pressed.connect(func() -> void: AudioManager.play_ui("ui_accept"))
	return button


func _texture_rect(tex: Texture2D, box: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = box
	rect.size = box
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Ícone pixel art em escala inteira (1x, 2x...), centrado numa caixa quadrada de `box`.
func _pixel_icon(tex: Texture2D, box: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex:
		var native := tex.get_size()
		var factor := floorf(box / maxf(native.x, native.y))
		var shown := native * factor if factor >= 1.0 else native * (box / maxf(native.x, native.y))
		rect.size = shown.floor()
		rect.position = ((Vector2(box, box) - rect.size) * 0.5).floor() + Vector2.ONE
	return rect


func _load(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
