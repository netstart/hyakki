extends Screen
## Resultados (plano 7.4 e 15.5): a "tela de escolha" depois da morte ou do amanhecer.
##
## Três colunas proporcionais à tela (678x305 é a referência), fora do recorte da câmera e sem
## nada cortado:
## - esquerda: retrato do herói (apagado e riscado de tinta vermelha na derrota, aceso com
##   brilho no amanhecer), título, fase/modo/lua, selo de recorde e o golpe final;
## - centro: 4 blocos de números (tempo, nível, abates, ryō) que contam do zero e o painel de
##   dano por arma (barras proporcionais à melhor arma, que ganha o selo MVP; rola se precisar);
## - direita: conquistas novas, o próximo desbloqueio com barra de progresso, uma dica na
##   derrota e os botões: "Jogar de novo" em destaque, "Dobrar ryō" por anúncio (17.6) e "Menu".
## O céu do fundo é desenhado em código (cinzas caindo na derrota, aurora e pétalas na vitória).
## A entrada é escalonada (~0,6 s) e os botões só aceitam toque depois de INPUT_GUARD, para o
## toque que fechou o aviso de morte não cair num botão. "Reduzir flashes" desliga os pulsos.

## Margem nas bordas e espaço entre as colunas; as colunas dividem a largura útil (já sem a área
## segura) nestas proporções, que em 678x305 dão as larguras 196, 258 e 188 de sempre.
const MARGIN := 10.0
const GAP := 8.0
const SHARES: Array[float] = [196.0, 258.0, 188.0]
## Entrada: atraso de cada coluna, duração do deslize e deslocamento inicial.
const COLUMN_DELAY: Array[float] = [0.0, 0.12, 0.24]
const COLUMN_TIME := 0.36
const COLUMN_SHIFT: Array[Vector2] = [Vector2(-14, 0), Vector2(0, 10), Vector2(14, 0)]
## Contagem dos números: começo, intervalo entre blocos e duração de cada um (~0,9 s no total).
const COUNT_START := 0.2
const COUNT_STAGGER := 0.15
const COUNT_TIME := 0.45
const BAR_TIME := 0.5
const INTRO_END := 1.4
## Tempo em que os botões ignoram toques depois que a tela aparece.
const INPUT_GUARD := 0.4
const PORTRAIT := 76
## Largura mínima da coluna da esquerda (retrato e textos quebrados) ao dividir telas estreitas.
const LEFT_MIN := 112.0
const TILE_ICON := 24
const ROW_HEIGHT := 33
const PIP := Vector2(4, 4)
const MOTES := 44
const ICONS := {
	"time": "res://assets/art/items/object/Hourglass.png",
	"level": "res://assets/art/ui/icons/spell/Upgrade.png",
	"kills": "res://assets/art/ui/icons/spell/Cut.png",
	"ryo": "res://assets/art/ui/icons/items/Money.png",
}
const TIP_ICON := "res://assets/art/ui/icons/items/Scroll.png"
const GOLD := Color("d9a441")
const VERMILION := Color("b23a26")
const DIM := Color(0.8, 0.76, 0.72)
const INK := Color("c21a2c")
## Cores de cada clima: céu (de cima para baixo), painéis, bordas, título e barras.
const MOODS := {
	"defeat": {
		"sky": [Color("1b1838"), Color("0e0c1e"), Color("050408")],
		"panel": Color(0.035, 0.03, 0.07, 0.84), "edge": Color("5b2c3c"), "title": Color("ffb0a3"),
		"bar": Color(0.75, 0.16, 0.16, 0.35), "bar_top": Color("e0503f"),
	},
	"victory": {
		"sky": [Color("1c1a4d"), Color("5d3474"), Color("d0647a"), Color("ffc46b")],
		"panel": Color(0.09, 0.045, 0.07, 0.8), "edge": Color("8a6230"), "title": ThemeFactory.ACCENT,
		"bar": Color(0.85, 0.62, 0.2, 0.3), "bar_top": Color("ffd166"),
	},
}

var _result: Dictionary = {}
var _mood: Dictionary = MOODS["defeat"]
var _victory: bool = false
var _calm: bool = false
## Tempo desde que o resultado apareceu (linha do tempo da entrada e das animações).
var _t: float = 0.0
var _guard: float = 0.0
var _columns: Array[Control] = []
## Retângulos das colunas (esquerda, centro, direita) para o tamanho e a área segura atuais.
var _rects: Array[Rect2] = []
var _portrait: TextureRect
var _portrait_fx: Control
var _title: Label
var _subtitle: Label
var _record: PanelContainer
var _cause_row: HBoxContainer
var _cause_icon: TextureRect
var _cause: Label
var _taken: Label
## Blocos de números: {kind, value (Label), from, to, start, ticked}.
var _tiles: Array[Dictionary] = []
var _doubled_pill: PanelContainer
var _stats_grid: GridContainer
var _weapon_scroll: ScrollContainer
var _weapon_list: VBoxContainer
var _no_weapons: Label
## Linhas do painel de armas, na ordem mostrada: {id, damage, row, bar, ratio}.
var _rows: Array[Dictionary] = []
var _info_scroll: ScrollContainer
var _achievements: VBoxContainer
var _next_box: PanelContainer
var _next_name: Label
var _next_icon: TextureRect
var _next_bar: ProgressBar
var _next_detail: Label
var _next_percent: Label
var _tip_box: PanelContainer
var _tip: Label
var _again: Button
var _double: Button
var _menu: Button
var _again_style: StyleBoxFlat
## Partículas do céu: posição, velocidade e fase de cada uma.
var _motes: PackedVector2Array = []
var _mote_speed: PackedVector2Array = []
var _mote_phase: PackedFloat32Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	clip_contents = true
	_layout()
	_columns.append(_build_left())
	_columns.append(_build_center())
	_columns.append(_build_right())
	for i: int in range(_columns.size()):
		add_child(_columns[i])
	_rng.seed = 7
	resized.connect(_layout)
	# Furo da câmera que troca de lado com a tela aberta (giro de 180°).
	MenuKit.on_insets_change(self, _layout)
	_layout()


func on_show() -> void:
	var r := app.last_result
	if r.is_empty():
		return
	if is_same(r, _result):
		# Mesmo resultado (ex.: depois de dobrar o ryō): só atualiza, sem refazer a entrada.
		_refresh()
		_layout()
		return
	_result = r
	_victory = bool(r["victory"])
	_mood = MOODS["victory" if _victory else "defeat"]
	_calm = bool(Settings.get_value("reduce_flashes"))
	_fill_left(r)
	_fill_tiles(r)
	_fill_weapons(r.get("weapons", []))
	_fill_right(r)
	_style_panels()
	_layout()
	_seed_motes()
	_t = 0.0
	_guard = INPUT_GUARD
	_set_buttons_armed(false)
	_refresh()
	_apply_timeline()


func _process(delta: float) -> void:
	if _result.is_empty() or not is_visible_in_tree():
		return
	_t += delta
	if _guard > 0.0:
		_guard -= delta
		if _guard <= 0.0:
			_set_buttons_armed(true)
	_move_motes(delta)
	_apply_timeline()
	queue_redraw()
	_portrait_fx.queue_redraw()


## Pula a entrada (testes e capturas de tela): tudo no estado final e os botões liberados.
func skip_intro() -> void:
	_t = maxf(_t, INTRO_END + COUNT_TIME)
	for tile: Dictionary in _tiles:
		tile["from"] = tile["to"]
		tile["ticked"] = true
	_guard = 0.0
	_set_buttons_armed(true)
	_apply_timeline()


func on_back() -> void:
	app.go(&"title")


# --- Linha do tempo ---------------------------------------------------------------

func _apply_timeline() -> void:
	for i: int in range(_columns.size()):
		var k := _ease(clampf((_t - COLUMN_DELAY[i]) / COLUMN_TIME, 0.0, 1.0))
		var column := _columns[i]
		column.modulate.a = k
		column.size = _column_rect(i).size
		column.position = _column_rect(i).position + COLUMN_SHIFT[i] * (1.0 - k)
	for tile: Dictionary in _tiles:
		var start := float(tile["start"])
		var k := clampf((_t - start) / COUNT_TIME, 0.0, 1.0)
		if k > 0.0 and not bool(tile["ticked"]):
			tile["ticked"] = true
			if _t < INTRO_END + COUNT_TIME:
				AudioManager.play("paper_fold", 1.25, 0.05, -14.0, "UI")
		var value := lerpf(float(tile["from"]), float(tile["to"]), _ease(k))
		(tile["value"] as Label).text = _format_stat(String(tile["kind"]), value)
	var grow := _ease(clampf((_t - COUNT_START) / BAR_TIME, 0.0, 1.0))
	for row: Dictionary in _rows:
		_size_bar(row, grow)
	if _again_style != null:
		var pulse := 0.0 if _calm or _guard > 0.0 else 0.5 + 0.5 * sin(_t * 3.2)
		_again_style.shadow_color = Color(ThemeFactory.ACCENT, 0.2 + 0.25 * pulse)
		_again_style.border_color = ThemeFactory.ACCENT.lerp(Color.WHITE, 0.35 * pulse)


func _column_rect(i: int) -> Rect2:
	return _rects[i]


# --- Layout ---------------------------------------------------------------------------

## Divide a largura útil (tela menos a área segura e as margens) entre as três colunas e
## ajusta o que depende do espaço. Em telas estreitas ou baixas, compacta por etapas e só o
## necessário: a direita e o centro recebem a largura mínima dos botões e dos blocos (tirada do
## centro e, por último, da esquerda); sem espaço, "Jogar de novo" cai para a fonte menor e
## depois os blocos de números escondem o ícone; sem altura, o título cai para a fonte menor e,
## por fim, o retrato fica em escala 1.
func _layout() -> void:
	var view := _area()
	var insets := MenuKit.safe_insets(self)
	var height := view.y - MARGIN * 2.0
	var widths := _shares(view.x - insets.x - insets.y - MARGIN * 2.0 - GAP * (SHARES.size() - 1))
	if not _columns.is_empty():
		var base := widths.duplicate()
		for step: Array in [[24, true], [12, true], [12, false]]:
			widths = base.duplicate()
			_again.add_theme_font_size_override("font_size", step[0])
			_set_tile_icons(step[1])
			if _fit_widths(widths):
				break
		_fit_left(widths[0], height)
		_no_weapons.custom_minimum_size.x = widths[1] - 20.0
	_rects.clear()
	var x := insets.x + MARGIN
	for w: float in widths:
		_rects.append(Rect2(x, MARGIN, w, height))
		x += w + GAP
	if not _columns.is_empty():
		_apply_timeline()


## Larguras proporcionais (SHARES) da largura útil, em pixels inteiros.
static func _shares(width: float) -> Array[float]:
	var total := 0.0
	for share: float in SHARES:
		total += share
	var out: Array[float] = []
	for share: float in SHARES:
		out.append(floorf(width * share / total))
	return out


## Garante o mínimo do centro e da direita tirando a diferença das outras colunas (do centro
## antes da esquerda). Falso se não couber.
func _fit_widths(widths: Array[float]) -> bool:
	_no_weapons.custom_minimum_size.x = 0.0
	var mins: Array[float] = [LEFT_MIN, ceilf(_columns[1].get_combined_minimum_size().x),
			ceilf(_columns[2].get_combined_minimum_size().x)]
	for i: int in [2, 1]:
		for j: int in ([1, 0] if i == 2 else [0]):
			var need := mins[i] - widths[i]
			if need <= 0.0:
				break
			var take := minf(need, maxf(widths[j] - mins[j], 0.0))
			widths[j] -= take
			widths[i] += take
	for i: int in range(widths.size()):
		if widths[i] < mins[i]:
			return false
	return true


## Ícones dos blocos de números (escondidos quando o centro precisa da largura).
func _set_tile_icons(on: bool) -> void:
	for tile: Dictionary in _tiles:
		(tile["icon"] as Control).visible = on


## Quebra os textos da esquerda na largura da coluna e reduz título e retrato se não couber.
func _fit_left(width: float, height: float) -> void:
	for step: int in range(3):
		_title.add_theme_font_size_override("font_size", 24 if step == 0 else 12)
		_set_portrait(PORTRAIT if step < 2 else PORTRAIT / 2)
		var cause_w := minf(_text_width(_cause.text, 12), width - (23.0 if _cause_icon.visible else 0.0))
		_cause.custom_minimum_size.x = cause_w
		# A altura dos textos quebrados vale para a largura atual: mede já na largura da coluna
		# (e invalida o mínimo guardado, que o rótulo não refaz sozinho ao mudar de tamanho).
		for l: Label in [_title, _subtitle, _taken, _cause]:
			if l != _cause:
				l.custom_minimum_size.x = width
			l.size = Vector2(l.custom_minimum_size.x, l.size.y)
			l.update_minimum_size()
		if _columns[0].get_combined_minimum_size().y <= height:
			return


func _set_portrait(side: int) -> void:
	_portrait_fx.custom_minimum_size = Vector2(side + 8, side + 8)
	_portrait.size = Vector2(side, side)


static func _ease(k: float) -> float:
	return 1.0 - pow(1.0 - k, 3.0)


func _set_buttons_armed(armed: bool) -> void:
	for b: Button in [_again, _menu]:
		b.disabled = not armed
	_double.disabled = not armed or bool(_double.get_meta("busy", false))


# --- Esquerda: herói, título e golpe final ----------------------------------------

func _build_left() -> Control:
	var col := VBoxContainer.new()
	col.name = "Left"
	col.size = _rects[0].size
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	var holder := CenterContainer.new()
	col.add_child(holder)
	_portrait_fx = Control.new()
	_portrait_fx.name = "Portrait"
	_portrait_fx.custom_minimum_size = Vector2(PORTRAIT + 8, PORTRAIT + 8)
	_portrait_fx.draw.connect(_draw_portrait_fx)
	holder.add_child(_portrait_fx)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.position = Vector2(4, 4)
	_portrait.size = Vector2(PORTRAIT, PORTRAIT)
	_portrait_fx.add_child(_portrait)
	# A tinta do risco é desenhada por cima do retrato, num nó irmão posterior.
	var slash := Control.new()
	slash.name = "Slash"
	slash.set_anchors_preset(Control.PRESET_FULL_RECT)
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash.draw.connect(_draw_slash.bind(slash))
	_portrait_fx.add_child(slash)
	_portrait_fx.set_meta("slash", slash)
	_title = title_label("")
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(_rects[0].size.x, 0)
	col.add_child(_title)
	_subtitle = label("", 12, HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.custom_minimum_size = Vector2(_rects[0].size.x, 0)
	_subtitle.add_theme_color_override("font_color", DIM)
	col.add_child(_subtitle)
	var badge_row := CenterContainer.new()
	col.add_child(badge_row)
	_record = PanelContainer.new()
	_record.name = "Record"
	_record.add_theme_stylebox_override("panel", _pill(Color("5a3d10"), ThemeFactory.ACCENT, 6))
	badge_row.add_child(_record)
	var record_text := label(tr("results.record"), 12, HORIZONTAL_ALIGNMENT_CENTER)
	record_text.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	_record.add_child(record_text)
	var cause_center := CenterContainer.new()
	col.add_child(cause_center)
	_cause_row = HBoxContainer.new()
	_cause_row.add_theme_constant_override("separation", 4)
	cause_center.add_child(_cause_row)
	_cause_icon = icon_rect("", Vector2(19, 19))
	_cause_row.add_child(_cause_icon)
	_cause = label("", 12)
	_cause.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cause_row.add_child(_cause)
	_taken = label("", 12, HORIZONTAL_ALIGNMENT_CENTER)
	_taken.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_taken.custom_minimum_size = Vector2(_rects[0].size.x, 0)
	_taken.add_theme_color_override("font_color", DIM)
	col.add_child(_taken)
	return col


func _fill_left(r: Dictionary) -> void:
	var hero: Dictionary = DB.heroes.get(StringName(String(r.get("hero", ""))), {})
	var face := String(hero.get("face", ""))
	var tex: Texture2D = load(face) as Texture2D if ResourceLoader.exists(face) else null
	_portrait.texture = _desaturated(tex) if tex != null and not _victory else tex
	_portrait.modulate = Color.WHITE if _victory else Color(0.82, 0.8, 0.9)
	var gave_up := bool(r.get("gave_up", false))
	if _victory:
		_title.text = tr("results.victory")
	elif gave_up:
		_title.text = tr("results.gave_up")
	else:
		_title.text = tr("results.defeat")
	_title.add_theme_color_override("font_color", _mood["title"])
	_subtitle.text = subtitle_text(r)
	var prev := float(r.get("prev_best_time", 0.0))
	_record.visible = prev > 0.0 and float(r.get("time", 0.0)) > prev + 0.5
	var d: Dictionary = r.get("damage_taken", {})
	var source := ""
	if not d.is_empty():
		var top: Array = d.get("top", [])
		if _victory or gave_up:
			source = String(top[0]) if not top.is_empty() else ""
		else:
			source = String(d.get("cause", ""))
	_cause_row.visible = source != "" or (not d.is_empty() and not _victory and not gave_up)
	if _victory or gave_up:
		_cause.text = tr("results.hurt_most") % source_name(source)
	else:
		_cause.text = tr("results.final_blow") % source_name(source)
	_cause.add_theme_color_override("font_color", Color("ff8a80") if not _victory else ThemeFactory.TEXT)
	var icon := source_icon(source)
	_cause_icon.texture = load(icon) as Texture2D if icon != "" else null
	_cause_icon.visible = icon != ""
	# O texto do golpe quebra dentro da coluna, descontando o ícone (largura no _layout).
	_taken.visible = not d.is_empty()
	_taken.text = tr("results.taken") % Locale.format_number(roundi(float(d.get("total", 0.0))))


## "Fase · modo · Lua" (e Desafio Diário / Noite Sem Fim quando valem).
func subtitle_text(r: Dictionary) -> String:
	var parts: PackedStringArray = [tr("stage.%s.name" % String(r.get("stage", "")))]
	if bool(r.get("daily", false)):
		parts.append(tr("title.daily"))
	else:
		parts.append(tr("mode.%s" % String(r.get("mode", "normal"))))
	if bool(r.get("endless", false)):
		parts.append(tr("stages.endless"))
	if int(r.get("moon", 0)) > 0:
		parts.append(tr("moon.level") % roman(int(r["moon"])))
	return " · ".join(parts)


static func roman(n: int) -> String:
	return ["0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][clampi(n, 0, 10)]


## Nome de quem causou o dano: inimigo, chefe ou perigo da fase.
static func source_name(id: String) -> String:
	for key: String in ["enemy.%s.name" % id, "boss.%s.name" % id, "damage.source.%s" % id]:
		var text := TranslationServer.translate(key)
		if text != key:
			return text
	return TranslationServer.translate("damage.source.unknown")


## Retrato (Faceset) do inimigo ou chefe; "" para perigos da fase (lava, estátua).
static func source_icon(id: String) -> String:
	if id == "":
		return ""
	var sprite := ""
	if DB.enemies.has(StringName(id)):
		sprite = String(DB.enemy(StringName(id)).get("sprite", ""))
	elif DB.bosses.has(StringName(id)):
		sprite = String((DB.bosses[StringName(id)]["sprite"] as Dictionary).get("path", ""))
	var face := sprite.get_base_dir().path_join("Faceset.png") if sprite != "" else ""
	return face if face != "" and ResourceLoader.exists(face) else ""


## Retrato apagado da derrota: tons de cinza levemente azulados.
static func _desaturated(tex: Texture2D) -> Texture2D:
	var image := tex.get_image()
	if image == null:
		return tex
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var c := image.get_pixel(x, y)
			var l := c.get_luminance() * 0.85
			image.set_pixel(x, y, Color(l * 0.92, l * 0.92, l * 1.05, c.a))
	return ImageTexture.create_from_image(image)


func _draw_portrait_fx() -> void:
	var box := Rect2(Vector2.ZERO, _portrait_fx.size)
	var center := box.get_center()
	if _victory:
		# Brilho suave atrás do retrato (pulsa devagar, parado com "Reduzir flashes").
		var pulse := 1.0 if _calm else 0.85 + 0.15 * sin(_t * 2.0)
		for k: int in range(5):
			var radius := 34.0 + k * 7.0
			_portrait_fx.draw_circle(center, radius, Color(1.0, 0.82, 0.45, 0.07 * pulse))
	_portrait_fx.draw_rect(box, Color(0, 0, 0, 0.55))
	var edge: Color = GOLD if _victory else Color("6a5a70")
	_portrait_fx.draw_rect(box, edge, false, 2.0)
	_portrait_fx.draw_rect(box.grow(-3), Color(edge, 0.35), false, 1.0)
	(_portrait_fx.get_meta("slash") as Control).queue_redraw()


## Risco de tinta vermelha na diagonal, desenhado de cima para baixo durante a entrada.
func _draw_slash(on: Control) -> void:
	if _victory:
		return
	var k := _ease(clampf((_t - 0.15) / 0.3, 0.0, 1.0))
	if k <= 0.0:
		return
	var a := Vector2(on.size.x + 2, -4)
	var b := Vector2(-4, on.size.y + 2)
	var tip := a.lerp(b, k)
	var dir := (b - a).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var points := PackedVector2Array([a + normal * 1.0, a.lerp(tip, 0.45) + normal * 8.0,
			tip + normal * 2.0, tip - normal * 2.0, a.lerp(tip, 0.5) - normal * 6.0, a - normal * 1.0])
	on.draw_colored_polygon(points, Color(INK, 0.9))
	on.draw_line(a.lerp(tip, 0.1) + normal * 2.0, a.lerp(tip, 0.8) + normal * 2.0, Color(1, 0.55, 0.5, 0.5), 1.0)
	# Respingos de tinta ao longo do risco.
	for i: int in range(6):
		var at := a.lerp(tip, 0.15 + 0.14 * i) + normal * (7.0 if i % 2 == 0 else -6.0) * (0.6 + 0.1 * i)
		on.draw_rect(Rect2(at.floor(), Vector2(2, 2) if i % 3 else Vector2(1, 1)), Color(INK, 0.8))


# --- Centro: números e dano por arma ----------------------------------------------

func _build_center() -> Control:
	var col := VBoxContainer.new()
	col.name = "Center"
	col.size = _rects[1].size
	col.add_theme_constant_override("separation", 6)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	col.add_child(grid)
	var names := {"time": tr("results.stat_time"), "level": tr("results.stat_level"),
			"kills": tr("results.stat_kills"), "ryo": tr("results.stat_ryo")}
	for kind: String in ["time", "level", "kills", "ryo"]:
		grid.add_child(_make_tile(kind, String(names[kind])))
	_stats_grid = grid
	var box := PanelContainer.new()
	box.name = "Weapons"
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(box)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 3)
	box.add_child(inner)
	var header := HBoxContainer.new()
	inner.add_child(header)
	var weapon_head := label(tr("results.weapon"))
	weapon_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_head.add_theme_color_override("font_color", DIM)
	header.add_child(weapon_head)
	var damage_head := label(tr("results.damage"), 12, HORIZONTAL_ALIGNMENT_RIGHT)
	damage_head.add_theme_color_override("font_color", DIM)
	header.add_child(damage_head)
	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.35)
	rule.custom_minimum_size = Vector2(0, 1)
	inner.add_child(rule)
	_weapon_scroll = ScrollContainer.new()
	_weapon_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_weapon_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_weapon_scroll.scroll_deadzone = 8
	inner.add_child(_weapon_scroll)
	_weapon_list = VBoxContainer.new()
	_weapon_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_list.add_theme_constant_override("separation", 2)
	_weapon_scroll.add_child(_weapon_list)
	_no_weapons = label(tr("results.no_weapons"), 12, HORIZONTAL_ALIGNMENT_CENTER)
	_no_weapons.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_no_weapons.custom_minimum_size = Vector2(_rects[1].size.x - 20.0, 0)
	_no_weapons.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_no_weapons.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_no_weapons.add_theme_color_override("font_color", DIM)
	inner.add_child(_no_weapons)
	return col


func _make_tile(kind: String, title: String) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.name = "Tile_" + kind
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	tile.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load(String(ICONS[kind])) as Texture2D
	icon.custom_minimum_size = Vector2(TILE_ICON, TILE_ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	texts.add_child(head)
	var name_label := label(title)
	name_label.add_theme_color_override("font_color", DIM)
	head.add_child(name_label)
	if kind == "ryo":
		_doubled_pill = PanelContainer.new()
		_doubled_pill.add_theme_stylebox_override("panel", _pill(Color("5a3d10"), ThemeFactory.ACCENT, 3))
		var times := label("×2", 12, HORIZONTAL_ALIGNMENT_CENTER)
		times.add_theme_color_override("font_color", ThemeFactory.ACCENT)
		_doubled_pill.add_child(times)
		_doubled_pill.visible = false
		head.add_child(_doubled_pill)
	var value := label("0", 24)
	value.add_theme_color_override("font_color", ThemeFactory.ACCENT if kind == "ryo" else ThemeFactory.TEXT)
	texts.add_child(value)
	_tiles.append({"kind": kind, "value": value, "from": 0.0, "to": 0.0,
			"start": 0.0, "ticked": false, "tile": tile, "icon": icon})
	return tile


func _fill_tiles(r: Dictionary) -> void:
	var values := {"time": float(r.get("time", 0.0)), "level": float(r.get("level", 1)),
			"kills": float(r.get("kills", 0)), "ryo": float(r.get("ryo_earned", 0))}
	# Resumo numa linha (dica do mouse no desktop e leitores de tela).
	_stats_grid.tooltip_text = tr("results.summary") % [format_time(values["time"]), int(values["level"]),
			Locale.format_number(int(values["kills"])), Locale.format_number(int(values["ryo"]))]
	for i: int in range(_tiles.size()):
		var tile := _tiles[i]
		tile["from"] = 0.0
		tile["to"] = values[tile["kind"]]
		tile["start"] = COUNT_START + COUNT_STAGGER * i
		tile["ticked"] = false
		_size_value(tile)


## Fonte e largura do número pelo valor final: o bloco não muda de largura durante a contagem
## (e o _layout mede o centro já com ela). Números muito longos (ryō de Noite Sem Fim) caem
## para a fonte menor e cabem no bloco.
func _size_value(tile: Dictionary) -> void:
	var value := tile["value"] as Label
	var final := _format_stat(String(tile["kind"]), float(tile["to"]))
	var font := 24 if _text_width(final, 24) <= 88.0 else 12
	value.add_theme_font_size_override("font_size", font)
	value.custom_minimum_size.x = _text_width(final, font) - 6.0


func _format_stat(kind: String, value: float) -> String:
	if kind == "time":
		return format_time(value)
	return Locale.format_number(roundi(value))


func _fill_weapons(weapons: Array) -> void:
	for child: Node in _weapon_list.get_children():
		_weapon_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	var sorted: Array = weapons.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["damage"]) > float(b["damage"]))
	var top := float(sorted[0]["damage"]) if not sorted.is_empty() else 0.0
	for i: int in range(sorted.size()):
		var w: Dictionary = sorted[i]
		var ratio := float(w["damage"]) / top if top > 0.0 else 0.0
		_weapon_list.add_child(_make_row(w, ratio, i == 0 and top > 0.0))
	_weapon_scroll.visible = not sorted.is_empty()
	_no_weapons.visible = sorted.is_empty()
	_weapon_scroll.scroll_vertical = 0


func _make_row(w: Dictionary, ratio: float, mvp: bool) -> Control:
	var id := String(w["id"])
	var row := Control.new()
	row.name = "Row_" + id
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var track := ColorRect.new()
	track.name = "Track"
	track.color = Color(0, 0, 0, 0.3)
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(track)
	var bar := ColorRect.new()
	bar.name = "Bar"
	bar.color = _mood["bar"]
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var line := ColorRect.new()
	line.name = "BarLine"
	line.color = _mood["bar_top"] if mvp else Color(_mood["bar_top"], 0.6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(line)
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 3
	box.offset_right = -4
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	var data := DB.weapon(StringName(id))
	var well := CenterContainer.new()
	well.custom_minimum_size = Vector2(20, 20)
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(well)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_set_icon(icon, String(data.get("icon", "")), 16)
	well.add_child(icon)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 1)
	box.add_child(left)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	left.add_child(name_row)
	var title := label(tr("weapon.%s.name" % id))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	if mvp:
		title.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	name_row.add_child(title)
	if mvp:
		var badge := PanelContainer.new()
		badge.name = "Mvp"
		badge.add_theme_stylebox_override("panel", _pill(Color("5a3d10"), ThemeFactory.ACCENT, 3))
		var mvp_text := label(tr("results.mvp"), 12, HORIZONTAL_ALIGNMENT_CENTER)
		mvp_text.add_theme_color_override("font_color", ThemeFactory.ACCENT)
		badge.add_child(mvp_text)
		name_row.add_child(badge)
	var pips := HBoxContainer.new()
	pips.name = "Pips"
	pips.add_theme_constant_override("separation", 1)
	left.add_child(pips)
	var top := maxi(1, (data.get("levels", []) as Array).size())
	var level := int(w.get("level", 1))
	for i: int in range(maxi(top, level)):
		var pip := ColorRect.new()
		pip.custom_minimum_size = PIP
		pip.color = (ThemeFactory.ACCENT if level >= top else GOLD) if i < level else Color(0, 0, 0, 0.55)
		pips.add_child(pip)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 0)
	box.add_child(right)
	var damage := label(Locale.format_number(roundi(float(w["damage"]))), 12, HORIZONTAL_ALIGNMENT_RIGHT)
	damage.name = "Damage"
	right.add_child(damage)
	var dps := label("%s %s" % [_decimal(float(w.get("dps", 0.0))), tr("results.dps")], 12,
			HORIZONTAL_ALIGNMENT_RIGHT)
	dps.name = "Dps"
	dps.add_theme_color_override("font_color", DIM)
	right.add_child(dps)
	var entry := {"id": id, "damage": float(w["damage"]), "row": row, "bar": bar, "line": line, "ratio": ratio}
	row.resized.connect(func() -> void: _size_bar(entry, _ease(clampf((_t - COUNT_START) / BAR_TIME, 0.0, 1.0))))
	_rows.append(entry)
	return row


func _size_bar(entry: Dictionary, grow: float) -> void:
	var row := entry["row"] as Control
	var bar := entry["bar"] as ColorRect
	var width := floorf(row.size.x * float(entry["ratio"]) * grow)
	bar.position = Vector2.ZERO
	bar.size = Vector2(width, row.size.y)
	var line := entry["line"] as ColorRect
	line.position = Vector2(0, row.size.y - 2)
	line.size = Vector2(width, 2)


## Número com uma casa decimal no separador do idioma.
func _decimal(value: float) -> String:
	var tenths := roundi(value * 10.0)
	var mark := "," if Locale.current in ["pt_BR", "es", "de", "fr", "ru", "id"] else "."
	return "%s%s%d" % [Locale.format_number(floori(tenths / 10.0)), mark, tenths % 10]


# --- Direita: conquistas, próximo desbloqueio, dica e botões ----------------------

func _build_right() -> Control:
	var col := VBoxContainer.new()
	col.name = "Right"
	col.size = _rects[2].size
	col.add_theme_constant_override("separation", 6)
	_info_scroll = ScrollContainer.new()
	_info_scroll.name = "Info"
	_info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info_scroll.scroll_deadzone = 8
	col.add_child(_info_scroll)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 5)
	_info_scroll.add_child(info)
	_achievements = VBoxContainer.new()
	_achievements.add_theme_constant_override("separation", 3)
	info.add_child(_achievements)
	_next_box = PanelContainer.new()
	_next_box.name = "Next"
	info.add_child(_next_box)
	var next := VBoxContainer.new()
	next.add_theme_constant_override("separation", 2)
	_next_box.add_child(next)
	# "Próximo desbloqueio": ícone da conquista, nome e %, barra e o que falta (sem cabeçalho,
	# para a dica da derrota caber sem rolar em qualquer idioma).
	_next_box.tooltip_text = tr("results.next_unlock")
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	next.add_child(name_row)
	_next_icon = icon_rect("", Vector2(16, 16))
	_next_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	name_row.add_child(_next_icon)
	_next_name = label("")
	_next_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_name.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	name_row.add_child(_next_name)
	_next_bar = ProgressBar.new()
	_next_bar.show_percentage = false
	_next_bar.custom_minimum_size = Vector2(0, 7)
	_next_bar.max_value = 1.0
	_next_bar.step = 0.0
	_next_bar.add_theme_stylebox_override("background", _flat(Color(0, 0, 0, 0.6), Color(GOLD, 0.45), 1))
	_next_bar.add_theme_stylebox_override("fill", _flat(GOLD, ThemeFactory.ACCENT, 1))
	_next_percent = label("", 12, HORIZONTAL_ALIGNMENT_RIGHT)
	_next_percent.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_next_percent.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	name_row.add_child(_next_percent)
	next.add_child(_next_bar)
	_next_detail = label("")
	_next_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_detail.add_theme_color_override("font_color", DIM)
	next.add_child(_next_detail)
	_tip_box = PanelContainer.new()
	_tip_box.name = "Tip"
	info.add_child(_tip_box)
	var tip := HBoxContainer.new()
	tip.add_theme_constant_override("separation", 5)
	_tip_box.add_child(tip)
	var tip_icon := icon_rect(TIP_ICON, Vector2(16, 16))
	tip_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tip_icon.tooltip_text = tr("results.tip")
	tip.add_child(tip_icon)
	_tip = label("")
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tip.add_theme_color_override("font_color", Color("e8dccb"))
	tip.add_child(_tip)
	_again = button(tr("results.again"), _on_again, Vector2(0, 30))
	_again.name = "Again"
	col.add_child(_again)
	_double = button(double_text(), _on_double, Vector2(0, 22))
	_double.name = "Double"
	# Em colunas estreitas o texto do anúncio quebra em duas linhas em vez de alargar a coluna.
	_double.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_double.icon = _small_coin()
	_double.expand_icon = false
	col.add_child(_double)
	_menu = button(tr("results.menu"), _on_menu, Vector2(0, 20))
	_menu.name = "Menu"
	col.add_child(_menu)
	return col


func _fill_right(r: Dictionary) -> void:
	for child: Node in _achievements.get_children():
		_achievements.remove_child(child)
		child.queue_free()
	var news: Array = r.get("new_achievements", [])
	_achievements.visible = not news.is_empty()
	for id: Variant in news:
		_achievements.add_child(_achievement_card(String(id)))
	# Jingle de conquista uma vez por resultado (o on_show roda de novo ao dobrar o ryō).
	if not news.is_empty() and not bool(r.get("achievement_sound_played", false)):
		r["achievement_sound_played"] = true
		AudioManager.play("achievement")
	var next := next_unlock()
	_next_box.visible = not next.is_empty()
	if not next.is_empty():
		_next_name.text = tr("achievement.%s.name" % next["id"])
		var icon := String((DB.achievements[StringName(String(next["id"]))] as Dictionary).get("icon", ""))
		_next_icon.texture = load(icon) as Texture2D if ResourceLoader.exists(icon) else null
		_next_bar.value = float(next["progress"])
		_next_percent.text = "%d%%" % floori(float(next["progress"]) * 100.0)
		_next_detail.text = String(next["detail"])
		_next_detail.visible = _next_detail.text != ""
	_tip_box.visible = not _victory
	_tip.text = tip_text(r)
	_info_scroll.scroll_vertical = 0
	_again.text = tr("results.again")


func _achievement_card(id: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Achievement_" + id
	card.add_theme_stylebox_override("panel", _flat(Color(0.25, 0.17, 0.05, 0.75), GOLD, 1, 4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	card.add_child(row)
	var icon := icon_rect(String((DB.achievements.get(StringName(id), {}) as Dictionary).get("icon", "")),
			Vector2(16, 16))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var name_label := label(tr("achievement.%s.name" % id))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	row.add_child(name_label)
	return card


## Dica para a próxima noite: fixa por resultado (não muda ao dobrar o ryō).
func tip_text(r: Dictionary) -> String:
	var tips := [tr("results.tip.0"), tr("results.tip.1"), tr("results.tip.2"), tr("results.tip.3"),
			tr("results.tip.4"), tr("results.tip.5")]
	var pick := int(float(r.get("time", 0.0)) * 10.0) + int(r.get("kills", 0)) * 7 + int(r.get("level", 0))
	return tips[posmod(pick, tips.size())]


## Atualiza o que muda sem um resultado novo: ryō (dobrado), selo ×2 e o botão do anúncio.
func _refresh() -> void:
	var earned := float(_result.get("ryo_earned", 0))
	for tile: Dictionary in _tiles:
		if tile["kind"] == "ryo" and not is_equal_approx(float(tile["to"]), earned):
			# Conta do valor antigo até o novo (o dobro), a partir de agora.
			var shown := lerpf(float(tile["from"]), float(tile["to"]),
					_ease(clampf((_t - float(tile["start"])) / COUNT_TIME, 0.0, 1.0)))
			tile["from"] = shown
			tile["to"] = earned
			tile["start"] = _t
			_size_value(tile)
	_doubled_pill.visible = bool(_result.get("doubled", false))
	_double.text = double_text()
	_double.visible = int(_result.get("ryo_earned", 0)) > 0 and not bool(_result.get("doubled", false)) \
			and AdsManager.rewarded_available()
	_double.set_meta("busy", false)
	_double.disabled = _guard > 0.0


# --- Ações ------------------------------------------------------------------------

func _on_again() -> void:
	app.play_again()


func _on_menu() -> void:
	app.go(&"title")


## "Dobrar ryō (anúncio)" ou, sem anúncios (AdsManager.ads_enabled = false), "(presente)".
func double_text() -> String:
	return tr("results.double") if AdsManager.ads_enabled else tr("results.double_free")


## Dobra só o ryō desta partida, uma vez (plano 17.6).
func _on_double() -> void:
	if bool(_result.get("doubled", false)):
		return
	_double.disabled = true
	_double.set_meta("busy", true)
	AdsManager.show_rewarded("double_ryo", func(rewarded: bool) -> void:
		if not rewarded:
			_double.set_meta("busy", false)
			_double.disabled = false
			return
		var earned := int(app.last_result.get("ryo_earned", 0))
		SaveManager.add_ryo(earned)
		SaveManager.save_profile()
		app.last_result["ryo_earned"] = earned * 2
		app.last_result["doubled"] = true
		AudioManager.play("jingle_unlock")
		on_show())


## A conquista mais perto de ser completada: {id, progress, detail} ou {} (plano 15.5).
func next_unlock() -> Dictionary:
	var stats: Dictionary = SaveManager.data["stats"]
	var best := {}
	var best_progress := -1.0
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
			best = {"id": String(id), "progress": maxf(progress, 0.0), "detail": detail}
	return best


# --- Estilo -----------------------------------------------------------------------

func _style_panels() -> void:
	var panel_bg: Color = _mood["panel"]
	var edge: Color = _mood["edge"]
	for tile: Dictionary in _tiles:
		var box := _flat(panel_bg, edge, 1, 4)
		box.content_margin_top = 2
		box.content_margin_bottom = 2
		(tile["tile"] as PanelContainer).add_theme_stylebox_override("panel", box)
	var weapons := _columns[1].get_node("Weapons") as PanelContainer
	weapons.add_theme_stylebox_override("panel", _flat(panel_bg, edge, 1, 5))
	for box: PanelContainer in [_next_box, _tip_box]:
		box.add_theme_stylebox_override("panel", _flat(panel_bg, edge, 1, 5))
	for row: Dictionary in _rows:
		(row["bar"] as ColorRect).color = _mood["bar"]
	# Botão principal: vermelhão com borda dourada e brilho que pulsa (parado com "Reduzir flashes").
	_again_style = _flat(VERMILION, ThemeFactory.ACCENT, 2, 6)
	_again_style.shadow_size = 3
	_again_style.shadow_color = Color(ThemeFactory.ACCENT, 0.3)
	_again.add_theme_stylebox_override("normal", _again_style)
	_again.add_theme_stylebox_override("hover", _flat(VERMILION.lightened(0.12), Color.WHITE, 2, 6))
	_again.add_theme_stylebox_override("pressed", _flat(VERMILION.darkened(0.25), ThemeFactory.ACCENT, 2, 6))
	_again.add_theme_stylebox_override("disabled", _again_style)
	_again.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0), Color.WHITE, 1, 6))
	_again.add_theme_color_override("font_disabled_color", ThemeFactory.TEXT)
	var dark := _flat(Color(0, 0, 0, 0.45), GOLD.darkened(0.2), 1, 6)
	_double.add_theme_stylebox_override("normal", dark)
	_double.add_theme_stylebox_override("hover", _flat(Color(0, 0, 0, 0.6), ThemeFactory.ACCENT, 1, 6))
	_double.add_theme_stylebox_override("pressed", _flat(Color(0, 0, 0, 0.7), ThemeFactory.ACCENT, 2, 6))
	_double.add_theme_stylebox_override("disabled", _flat(Color(0, 0, 0, 0.35), Color(GOLD, 0.35), 1, 6))
	_double.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0), Color.WHITE, 1, 6))
	_double.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	var flat := _flat(Color(0, 0, 0, 0.2), Color(edge, 0.7), 1, 6)
	_menu.add_theme_stylebox_override("normal", flat)
	_menu.add_theme_stylebox_override("hover", _flat(Color(0, 0, 0, 0.4), GOLD.darkened(0.2), 1, 6))
	_menu.add_theme_stylebox_override("pressed", _flat(Color(0, 0, 0, 0.55), GOLD, 1, 6))
	_menu.add_theme_stylebox_override("disabled", flat)
	_menu.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0), Color.WHITE, 1, 6))
	_menu.add_theme_color_override("font_color", DIM)
	_menu.add_theme_color_override("font_disabled_color", DIM)


func _text_width(text: String, font_size: int) -> float:
	var font := get_theme_font("font", "Label")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 6.0


func _small_coin() -> Texture2D:
	var tex := load(ICONS["ryo"]) as Texture2D
	var image := tex.get_image()
	if image == null:
		return tex
	if image.is_compressed():
		image.decompress()
	image.resize(16, 16, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


## Ícone ampliado só em múltiplos inteiros (pixel art nítida), contido na caixa.
static func _set_icon(rect: TextureRect, path: String, box: int) -> void:
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	rect.texture = tex
	if tex == null:
		rect.custom_minimum_size = Vector2(box, box)
		return
	var side := maxi(tex.get_width(), tex.get_height())
	var scale := maxi(1, floori(float(box) / side))
	rect.custom_minimum_size = Vector2(tex.get_width(), tex.get_height()) * scale


static func _flat(bg: Color, border: Color, width: int, pad: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(3)
	box.anti_aliasing = false
	box.set_content_margin_all(pad)
	return box


static func _pill(bg: Color, border: Color, pad: int = 3) -> StyleBoxFlat:
	var box := _flat(bg, border, 1)
	box.content_margin_left = pad
	box.content_margin_right = pad
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box


# --- Céu --------------------------------------------------------------------------

func _seed_motes() -> void:
	_motes.resize(MOTES)
	_mote_speed.resize(MOTES)
	_mote_phase.resize(MOTES)
	var area := _area()
	for i: int in range(MOTES):
		_motes[i] = Vector2(_rng.randf() * area.x, _rng.randf() * area.y)
		_mote_phase[i] = _rng.randf() * TAU
		_mote_speed[i] = _mote_velocity(i)


## Na derrota: cinza caindo devagar e algumas brasas subindo; na vitória: luzes subindo e
## pétalas descendo na diagonal.
func _mote_velocity(i: int) -> Vector2:
	if _victory:
		return Vector2(_rng.randf_range(10, 18), _rng.randf_range(8, 14)) if i % 3 == 0 \
				else Vector2(_rng.randf_range(-3, 3), -_rng.randf_range(4, 10))
	if i % 6 == 0:
		return Vector2(0, -_rng.randf_range(8, 16))
	return Vector2(_rng.randf_range(-2, 2), _rng.randf_range(6, 13))


func _move_motes(delta: float) -> void:
	var area := _area()
	for i: int in range(_motes.size()):
		var p := _motes[i] + _mote_speed[i] * delta
		p.x += sin(_t * 0.9 + _mote_phase[i]) * 4.0 * delta
		if p.y > area.y + 2.0:
			p = Vector2(_rng.randf() * area.x, -2.0)
		elif p.y < -2.0:
			p = Vector2(_rng.randf() * area.x, area.y + 2.0)
		p.x = fposmod(p.x, area.x)
		_motes[i] = p


func _area() -> Vector2:
	return size if size.x > 1.0 and size.y > 1.0 else Vector2(678, 305)


func _draw() -> void:
	if _result.is_empty():
		return
	var area := _area()
	var sky: Array = _mood["sky"]
	var horizon := area.y * (0.78 if _victory else 1.0)
	for i: int in range(sky.size() - 1):
		var y0 := horizon * i / (sky.size() - 1)
		var y1 := horizon * (i + 1) / (sky.size() - 1)
		draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(area.x, y0), Vector2(area.x, y1), Vector2(0, y1)]),
				PackedColorArray([sky[i], sky[i], sky[i + 1], sky[i + 1]]))
	if _victory:
		_draw_dawn(area, horizon)
	else:
		_draw_embers(area)
	for i: int in range(_motes.size()):
		_draw_mote(i)


func _draw_dawn(area: Vector2, horizon: float) -> void:
	var sun := Vector2(_rects[0].get_center().x, horizon + 6.0)
	for k: int in range(4):
		draw_circle(sun, 70.0 - k * 14.0, Color(1.0, 0.85, 0.5, 0.08 + k * 0.05))
	draw_circle(sun, 22.0, Color("ffe7a8"))
	# Montanhas distantes e o chão escuro abaixo do horizonte.
	var hills := PackedVector2Array([Vector2(0, area.y)])
	for x: int in range(0, int(area.x) + 24, 24):
		hills.append(Vector2(x, horizon - 6.0 - 10.0 * absf(sin(x * 0.013)) - 6.0 * absf(sin(x * 0.041))))
	hills.append(Vector2(area.x, area.y))
	draw_colored_polygon(hills, Color("3b2240"))
	draw_rect(Rect2(0, horizon + 4.0, area.x, area.y - horizon), Color("24142a"))


func _draw_embers(area: Vector2) -> void:
	# Vinheta avermelhada nas bordas: anel de quatro trapézios que somem para dentro.
	var inset := 70.0
	var outer := [Vector2.ZERO, Vector2(area.x, 0), area, Vector2(0, area.y)]
	var inner := [Vector2(inset, inset), Vector2(area.x - inset, inset), area - Vector2(inset, inset),
			Vector2(inset, area.y - inset)]
	var red := Color(0.5, 0.06, 0.05, 0.38)
	var clear := Color(0.5, 0.06, 0.05, 0.0)
	for i: int in range(4):
		var j := (i + 1) % 4
		draw_polygon(PackedVector2Array([outer[i], outer[j], inner[j], inner[i]]),
				PackedColorArray([red, red, clear, clear]))
	# Brasa baixa no chão.
	draw_polygon(PackedVector2Array([Vector2(0, area.y - 50), Vector2(area.x, area.y - 50), area, Vector2(0, area.y)]),
			PackedColorArray([clear, clear, Color(0.6, 0.12, 0.05, 0.3), Color(0.6, 0.12, 0.05, 0.3)]))


func _draw_mote(i: int) -> void:
	var p := _motes[i].floor()
	var twinkle := 1.0 if _calm else 0.6 + 0.4 * sin(_t * 2.5 + _mote_phase[i])
	if _victory:
		if i % 3 == 0:
			draw_rect(Rect2(p, Vector2(2, 1)), Color(1.0, 0.72, 0.8, 0.75))
		else:
			draw_rect(Rect2(p, Vector2(1, 1)), Color(1.0, 0.9, 0.6, 0.8 * twinkle))
	elif i % 6 == 0:
		draw_rect(Rect2(p, Vector2(1, 1)), Color(1.0, 0.45, 0.2, 0.85 * twinkle))
	else:
		draw_rect(Rect2(p, Vector2(1, 1) if i % 2 else Vector2(2, 1)), Color(0.72, 0.7, 0.76, 0.45))
