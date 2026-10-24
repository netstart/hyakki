extends Screen
## Santuário (plano 4.10): power-ups permanentes com preço crescente (comprar qualquer um
## encarece os outros) e reembolso total gratuito.
##
## Tudo cabe em 678x305 sem rolagem: grade 6x3 de cartões compactos (só ícone, pips de nível
## e preço — sem texto traduzido, então serve em qualquer idioma) e, à direita, o painel do
## item selecionado com nome, efeito, nível atual → próximo e o botão de oferecer.

const COIN_ICON := "res://assets/art/ui/icons/items/Money.png"
const COLUMNS := 6
const CARD_SIZE := Vector2(70, 81)
const GAP := 5
## Caixa do ícone no cartão e no painel; o ícone é ampliado só em múltiplos inteiros.
const CARD_ICON_BOX := 32
const DETAIL_ICON_BOX := 48
const PIP_SIZE := Vector2(6, 6)
const PANEL_WIDTH := 196.0
## Laca escura do santuário, dourado e vermelhão do torii.
const LACQUER := Color("24150f")
const LACQUER_LIGHT := Color("3a2317")
const WOOD_EDGE := Color("6b4a32")
const GOLD := Color("d9a441")
const VERMILION := Color("b23a26")
const SHORT := Color("ff9a8a")
const DIM := Color(0.8, 0.74, 0.66)

var _grid: GridContainer
var _ryo: Label
var _info: Label
## id → {button, icon, pips, price_box, price, coin}
var _cards: Dictionary = {}
var _selected: StringName = &""
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_level: Label
var _detail_pips: HBoxContainer
var _detail_effect: Label
var _detail_next: Label
var _buy_button: Button
var _buy_coin: TextureRect
var _buy_label: Label
var _refund_button: Button


func _ready() -> void:
	add_child(back_button())
	var title := title_label(tr("sanctuary.title"))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -150
	title.offset_right = 150
	title.offset_top = 6
	add_child(title)
	add_child(_ryo_pill())
	var margin := content_box(42.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var left := CenterContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	left.add_child(_grid)
	for id: StringName in DB.ids("powerups"):
		_grid.add_child(_make_card(id))
	row.add_child(_make_detail_panel())


func on_show() -> void:
	_ryo.text = Locale.format_number(SaveManager.ryo())
	if _selected == &"" or not _cards.has(_selected):
		_selected = DB.ids("powerups")[0]
	for id: StringName in _cards:
		_update_card(id)
	_update_detail()


## Toque/foco num cartão: mostra o item no painel (a compra é pelo botão do painel).
func _select(id: StringName) -> void:
	if id == _selected:
		return
	var previous := _selected
	_selected = id
	_info.text = tr("sanctuary.hint")
	_info.add_theme_color_override("font_color", DIM)
	if _cards.has(previous):
		_update_card(previous)
	_update_card(id)
	_update_detail()


## Mantido por compatibilidade: descreve o item no painel.
func _describe(id: StringName) -> void:
	_select(id)


func _buy(id: StringName) -> void:
	_select(id)
	if MetaProgress.buy(id):
		AudioManager.play("coin2")
		on_show()
	else:
		AudioManager.play_ui("ui_cancel")
		_info.text = tr("sanctuary.not_enough")
		_info.add_theme_color_override("font_color", SHORT)


func _refund() -> void:
	var refunded := MetaProgress.refund_all()
	_info.text = tr("sanctuary.refunded") % Locale.format_number(refunded)
	_info.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	on_show()


# --- Estado -----------------------------------------------------------------------

func _level(id: StringName) -> int:
	return SaveManager.powerup_level(id)


func _max(id: StringName) -> int:
	return int(DB.powerups[id]["max"])


func _is_maxed(id: StringName) -> bool:
	return _level(id) >= _max(id)


## "max", "buy" (dá para comprar) ou "short" (falta ryō).
func card_state(id: StringName) -> String:
	if _is_maxed(id):
		return "max"
	return "buy" if MetaProgress.can_buy(id) else "short"


func _update_card(id: StringName) -> void:
	var card: Dictionary = _cards[id]
	var b := card["button"] as Button
	var state := card_state(id)
	var selected := id == _selected
	var border := WOOD_EDGE
	var bg := LACQUER
	match state:
		"buy":
			border = GOLD.darkened(0.25)
			bg = LACQUER_LIGHT
		"max":
			border = GOLD
			bg = Color("3b2a12")
	if selected:
		border = ThemeFactory.ACCENT
		bg = bg.lightened(0.1)
	var width := 2 if selected else 1
	var normal := _flat(bg, border, width)
	if selected:
		normal.shadow_color = Color(ThemeFactory.ACCENT, 0.35)
		normal.shadow_size = 2
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", _flat(bg.lightened(0.08), border.lightened(0.15), width))
	b.add_theme_stylebox_override("pressed", _flat(bg.darkened(0.2), ThemeFactory.ACCENT, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	(card["icon"] as TextureRect).modulate = Color(1, 1, 1, 0.55) if state == "short" else Color.WHITE
	_fill_pips(card["pips"] as HBoxContainer, _level(id), _max(id))
	var price := card["price"] as Label
	var pill := card["price_box"] as PanelContainer
	var coin := card["coin"] as TextureRect
	if state == "max":
		price.text = tr("sanctuary.max")
		price.add_theme_color_override("font_color", ThemeFactory.ACCENT)
		coin.visible = false
		pill.add_theme_stylebox_override("panel", _pill(Color("5a3d10"), GOLD))
	else:
		price.text = Locale.format_number(MetaProgress.powerup_price(id))
		price.add_theme_color_override("font_color", SHORT if state == "short" else ThemeFactory.TEXT)
		coin.visible = true
		coin.modulate = Color(1, 1, 1, 0.6) if state == "short" else Color.WHITE
		pill.add_theme_stylebox_override("panel", _pill(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0)))


func _update_detail() -> void:
	var id := _selected
	var data: Dictionary = DB.powerups[id]
	var stat := String(data["stat"])
	var per_level: float = float(data["per_level"])
	var level := _level(id)
	var top := _max(id)
	var state := card_state(id)
	_set_icon(_detail_icon, String(data["icon"]), DETAIL_ICON_BOX)
	_detail_name.text = tr("powerup.%s.name" % id)
	_detail_level.text = "%d/%d" % [level, top]
	_detail_level.add_theme_color_override("font_color",
			ThemeFactory.ACCENT if state == "max" else ThemeFactory.TEXT)
	_fill_pips(_detail_pips, level, top)
	_detail_effect.text = LevelUpSystem.describe_stats({stat: per_level}) + " " + tr("sanctuary.per_level")
	if state == "max":
		_detail_next.text = LevelUpSystem.describe_stats({stat: per_level * level})
	elif level == 0:
		_detail_next.text = "→ " + LevelUpSystem.describe_stats({stat: per_level})
	else:
		_detail_next.text = "%s → %s" % [LevelUpSystem.describe_stats({stat: per_level * level}),
				LevelUpSystem.describe_stats({stat: per_level * (level + 1)})]
	var short := state == "short"
	_buy_button.disabled = state == "max"
	_buy_coin.visible = state != "max"
	_buy_coin.modulate = Color(1, 1, 1, 0.6) if short else Color.WHITE
	if state == "max":
		_buy_label.text = tr("sanctuary.max")
		_buy_label.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	else:
		_buy_label.text = Locale.format_number(MetaProgress.powerup_price(id))
		_buy_label.add_theme_color_override("font_color", SHORT if short else ThemeFactory.TEXT)
	var fill := Color("4a2a20") if short else VERMILION
	var edge := WOOD_EDGE if short else ThemeFactory.ACCENT
	_buy_button.add_theme_stylebox_override("normal", _flat(fill, edge, 1, 6))
	_buy_button.add_theme_stylebox_override("hover", _flat(fill.lightened(0.1), edge.lightened(0.2), 1, 6))
	_buy_button.add_theme_stylebox_override("pressed", _flat(fill.darkened(0.2), edge, 2, 6))
	_buy_button.add_theme_stylebox_override("disabled", _flat(Color("3b2a12"), GOLD, 1, 6))
	_buy_button.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0), Color.WHITE, 1, 6))


# --- Construção -------------------------------------------------------------------

func _ryo_pill() -> PanelContainer:
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _pill(Color(LACQUER, 0.9), GOLD, 8))
	pill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pill.offset_right = -12
	pill.offset_top = 9
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	pill.add_child(box)
	box.add_child(_coin(16))
	_ryo = label("", 12, HORIZONTAL_ALIGNMENT_RIGHT)
	_ryo.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	box.add_child(_ryo)
	return pill


func _make_card(id: StringName) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = true
	b.pressed.connect(_on_card_pressed.bind(id))
	b.focus_entered.connect(_select.bind(id))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 3
	box.offset_right = -3
	box.offset_top = 4
	box.offset_bottom = -4
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var disc := PanelContainer.new()
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_theme_stylebox_override("panel", _flat(Color(0, 0, 0, 0.35), Color(GOLD, 0.25), 1, 2))
	box.add_child(disc)
	var medal := CenterContainer.new()
	medal.custom_minimum_size = Vector2(CARD_ICON_BOX, CARD_ICON_BOX)
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(medal)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_icon(icon, String(DB.powerups[id]["icon"]), CARD_ICON_BOX)
	medal.add_child(icon)
	var pips := HBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.add_theme_constant_override("separation", 2)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pips)
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	var coin := _coin(12)
	row.add_child(coin)
	var price := label("", 12, HORIZONTAL_ALIGNMENT_CENTER)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(price)
	_cards[id] = {"button": b, "icon": icon, "pips": pips, "price_box": pill, "price": price, "coin": coin}
	return b


func _on_card_pressed(id: StringName) -> void:
	if id != _selected:
		AudioManager.play_ui("ui_accept")
	_select(id)


func _make_detail_panel() -> PanelContainer:
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	var style := _flat(Color(Color("1c110c"), 0.92), GOLD.darkened(0.3), 1, 7)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	side.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	side.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	var medal := PanelContainer.new()
	var medal_style := _flat(Color(0, 0, 0, 0.45), GOLD.darkened(0.2), 1, 2)
	medal.add_theme_stylebox_override("panel", medal_style)
	head.add_child(medal)
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(DETAIL_ICON_BOX, DETAIL_ICON_BOX)
	medal.add_child(center)
	_detail_icon = TextureRect.new()
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	center.add_child(_detail_icon)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", 3)
	head.add_child(titles)
	_detail_name = Label.new()
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_name.custom_minimum_size = Vector2(PANEL_WIDTH - DETAIL_ICON_BOX - 26, 0)
	_detail_name.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	titles.add_child(_detail_name)
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 5)
	titles.add_child(level_row)
	_detail_pips = HBoxContainer.new()
	_detail_pips.add_theme_constant_override("separation", 2)
	_detail_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	_detail_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_row.add_child(_detail_pips)
	_detail_level = label("")
	level_row.add_child(_detail_level)
	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.45)
	rule.custom_minimum_size = Vector2(0, 1)
	col.add_child(rule)
	_detail_effect = wrap_label("", PANEL_WIDTH - 16)
	col.add_child(_detail_effect)
	_detail_next = wrap_label("", PANEL_WIDTH - 16)
	_detail_next.add_theme_color_override("font_color", Color("a8e07a"))
	col.add_child(_detail_next)
	_info = wrap_label(tr("sanctuary.hint"), PANEL_WIDTH - 16)
	_info.add_theme_color_override("font_color", DIM)
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Ocupa só a sobra do painel: em idiomas longos a dica corta com "…" e nada sai da tela.
	_info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_info)
	_buy_button = Button.new()
	_buy_button.custom_minimum_size = Vector2(0, 28)
	_buy_button.focus_mode = Control.FOCUS_ALL
	_buy_button.pressed.connect(func() -> void: _buy(_selected))
	col.add_child(_buy_button)
	var buy_center := CenterContainer.new()
	buy_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	buy_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buy_button.add_child(buy_center)
	var buy_row := HBoxContainer.new()
	buy_row.add_theme_constant_override("separation", 4)
	buy_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy_center.add_child(buy_row)
	_buy_coin = _coin(16)
	buy_row.add_child(_buy_coin)
	_buy_label = label("")
	_buy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy_row.add_child(_buy_label)
	_refund_button = button(tr("sanctuary.refund"), _refund, Vector2(0, 22))
	_refund_button.add_theme_color_override("font_color", DIM)
	_refund_button.add_theme_color_override("font_hover_color", ThemeFactory.TEXT)
	_refund_button.add_theme_stylebox_override("normal", _flat(Color(0, 0, 0, 0.25), WOOD_EDGE, 1, 6))
	_refund_button.add_theme_stylebox_override("hover", _flat(Color(0, 0, 0, 0.4), GOLD.darkened(0.2), 1, 6))
	_refund_button.add_theme_stylebox_override("pressed", _flat(Color(0, 0, 0, 0.55), GOLD, 1, 6))
	_refund_button.add_theme_stylebox_override("focus", _flat(Color(0, 0, 0, 0), Color.WHITE, 1, 6))
	col.add_child(_refund_button)
	return side


func _fill_pips(row: HBoxContainer, level: int, top: int) -> void:
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for i: int in range(top):
		var pip := Panel.new()
		pip.custom_minimum_size = PIP_SIZE
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var on := i < level
		var full := level >= top
		var fill := (ThemeFactory.ACCENT if full else GOLD) if on else Color(0, 0, 0, 0.5)
		pip.add_theme_stylebox_override("panel", _flat(fill, GOLD.darkened(0.35) if not on else fill.lightened(0.3), 1, 0))
		row.add_child(pip)


## Ícone ampliado só em múltiplos inteiros (pixel art nítida), contido na caixa.
func _set_icon(rect: TextureRect, path: String, box: int) -> void:
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	rect.texture = tex
	if tex == null:
		rect.custom_minimum_size = Vector2(box, box)
		return
	var side := maxi(tex.get_width(), tex.get_height())
	var scale := maxi(1, floori(float(box) / side))
	rect.custom_minimum_size = Vector2(tex.get_width(), tex.get_height()) * scale
	rect.size = rect.custom_minimum_size


func _coin(px: int) -> TextureRect:
	var coin := TextureRect.new()
	coin.texture = load(COIN_ICON) as Texture2D
	coin.custom_minimum_size = Vector2(px, px)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return coin


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
	var box := _flat(bg, border, 1 if border.a > 0 else 0)
	box.content_margin_left = pad
	box.content_margin_right = pad
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	return box
