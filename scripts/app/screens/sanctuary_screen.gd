extends Screen
## Santuário (plano 4.10): power-ups permanentes com preço crescente (comprar qualquer um
## encarece os outros) e reembolso total gratuito.
##
## Tudo cabe na tela sem rolagem: grade de cartões compactos (só ícone, pips de nível e preço —
## sem texto traduzido, então serve em qualquer idioma) e, à direita, o painel do item
## selecionado com nome, efeito, nível atual → próximo e o botão de oferecer.
##
## O layout segue a tela lógica e a área segura (furo da câmera, MenuKit.safe_insets): em 678x305
## é a grade 6x3 de cartões 70x81 com o painel de 196, como sempre foi; em telas menores o cartão
## troca para um miolo mais justo (CARD_STYLES), o painel estreita até PANEL_MIN e a grade escolhe
## as colunas que dão o maior cartão que ainda contém o miolo (e o alvo de toque ≥ 48). Refaz a
## cada mudança de tamanho, de área segura ou de preços.

const COIN_ICON := "res://assets/art/ui/icons/items/Money.png"
## Colunas da grade, da tela de referência (6x3) às telas estreitas.
const COLUMN_CHOICES: Array[int] = [6, 5, 4]
## Tamanho do cartão na tela de referência (também o máximo) e o mínimo (alvo de toque ≥ 48).
const CARD_SIZE := Vector2(70, 81)
const CARD_MIN := Vector2(48, 48)
const GAP := 5
const GAP_TIGHT := 4
## Margens do conteúdo: laterais (a partir da borda ou do fim do furo da câmera) e topo abaixo
## do "voltar"; ROW_SEP separa a grade do painel.
const MARGIN := 12.0
const INSET_MARGIN := 4.0
const TOP := 42.0
const ROW_SEP := 10
## Caixa do ícone no painel; o ícone é ampliado só em múltiplos inteiros.
const DETAIL_ICON_BOX := 48
const PIP_SIZE := Vector2(6, 6)
## Painel de detalhes: largura de referência (≈ 30% da área útil); estreita até PANEL_MIN
## (de PANEL_STEP em PANEL_STEP) quando a grade não cabe.
const PANEL_WIDTH := 196.0
const PANEL_MIN := 128.0
const PANEL_STEP := 4.0
const PANEL_SHARE := 0.3
## Miolo do cartão, do mais folgado (o de 678x305) ao mais justo; vence o primeiro que couber.
## medal: caixa do ícone (o ícone 24 px só amplia em múltiplos inteiros); pad: respiro do disco;
## pip: lado do pip de nível; coin: moeda do preço (0 = sem moeda no cartão; o botão do painel
## ainda a mostra); pill: respiro lateral da pílula de preço; sep: separação do miolo;
## side/edge: margens lateral e vertical do miolo.
const CARD_STYLES: Array[Dictionary] = [
	{"medal": 32, "pad": 2, "pip": 6, "coin": 12, "pill": 3, "sep": 3, "side": 3, "edge": 4},
	{"medal": 26, "pad": 1, "pip": 6, "coin": 12, "pill": 3, "sep": 2, "side": 2, "edge": 3},
	{"medal": 24, "pad": 1, "pip": 4, "coin": 0, "pill": 2, "sep": 1, "side": 2, "edge": 1},
]
## Espaçamento vertical do painel (separação e margem) e margem de baixo da tela, do folgado
## (678x305) ao justo; vale o primeiro em que painel e grade cabem.
const PANEL_STYLES: Array[Dictionary] = [
	{"sep": 4, "pad": 6, "bottom": 8},
	{"sep": 3, "pad": 4, "bottom": 4},
]
## Laca escura do santuário, dourado e vermelhão do torii.
const LACQUER := Color("24150f")
const LACQUER_LIGHT := Color("3a2317")
const WOOD_EDGE := Color("6b4a32")
const GOLD := Color("d9a441")
const VERMILION := Color("b23a26")
const SHORT := Color("ff9a8a")
const DIM := Color(0.8, 0.74, 0.66)

var _grid: GridContainer
var _margin: MarginContainer
var _side: PanelContainer
var _ryo_box: PanelContainer
## Miolo de cartão em uso (um de CARD_STYLES).
var _style: Dictionary = CARD_STYLES[0]
## Tamanho de tela, área segura e preços do último layout (evita refazer à toa).
var _laid_out: Array = []
var _ryo: Label
var _info: Label
## id → {button, box, disc, medal, icon, pips, price_box, price, coin}
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
	_ryo_box = _ryo_pill()
	add_child(_ryo_box)
	_margin = content_box(TOP)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEP)
	_margin.add_child(row)
	var left := CenterContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	_grid = GridContainer.new()
	_grid.columns = COLUMN_CHOICES[0]
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	left.add_child(_grid)
	for id: StringName in DB.ids("powerups"):
		_grid.add_child(_make_card(id))
	_side = _make_detail_panel()
	row.add_child(_side)
	resized.connect(_layout)
	# Furo da câmera que troca de lado com a tela aberta (giro de 180°).
	MenuKit.on_insets_change(self, _layout)


func on_show() -> void:
	_ryo.text = Locale.format_number(SaveManager.ryo())
	if _selected == &"" or not _cards.has(_selected):
		_selected = DB.ids("powerups")[0]
	for id: StringName in _cards:
		_update_card(id)
	_update_detail()
	# Os preços mudam a largura dos cartões (e a área segura pode ter mudado): refaz o layout.
	_layout()


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


# --- Layout -----------------------------------------------------------------------

## Distribui grade e painel pela tela atual, fora do furo da câmera: o miolo de cartão mais
## folgado que couber, com o painel o mais largo possível (até a parte de referência).
func _layout() -> void:
	if _grid == null or size.x <= 0.0 or size.y <= 0.0 or _selected == &"":
		return
	var insets := MenuKit.safe_insets(self)
	var prices: Array[String] = []
	for id: StringName in _cards:
		prices.append((_cards[id]["price"] as Label).text)
	var key := [size, insets, prices]
	if key == _laid_out:
		return
	_laid_out = key
	var left := ceilf(maxf(MARGIN, insets.x + INSET_MARGIN))
	var right := ceilf(maxf(MARGIN, insets.y + INSET_MARGIN))
	_margin.add_theme_constant_override("margin_left", int(left))
	_margin.add_theme_constant_override("margin_right", int(right))
	_ryo_box.offset_right = -right
	var width := size.x - left - right
	var plan := {}
	for panel_style: Dictionary in PANEL_STYLES:
		_apply_panel_style(panel_style)
		var area_h := size.y - TOP - float(panel_style["bottom"])
		for style: Dictionary in CARD_STYLES:
			_apply_card_style(style)
			plan = _fit(width, area_h)
			if plan["fits"]:
				break
		if plan["fits"]:
			break
	_size_panel(_side.custom_minimum_size.x)
	_update_detail()
	_grid.columns = plan["columns"]
	_grid.add_theme_constant_override("h_separation", plan["gap"])
	_grid.add_theme_constant_override("v_separation", plan["gap"])
	for id: StringName in _cards:
		(_cards[id]["button"] as Button).custom_minimum_size = plan["card"]


## Painel e grade na largura e altura úteis com o miolo de cartão em uso. O painel parte da
## largura de referência (proporcional à tela) e só alarga se o texto mais longo não couber na
## altura; a grade fica com o resto e, se não couber, o painel estreita até PANEL_MIN.
## Devolve o grid_plan, com "fits" só se o painel também couber.
func _fit(width: float, area_h: float) -> Dictionary:
	var need := _card_need()
	var panel_w := clampf(roundf(width * PANEL_SHARE), PANEL_MIN, PANEL_WIDTH)
	while panel_w < PANEL_WIDTH and _panel_need_h(panel_w) > area_h:
		panel_w = minf(PANEL_WIDTH, panel_w + PANEL_STEP)
	var plan := {}
	while true:
		var real_w := _size_panel(panel_w)
		plan = grid_plan(Vector2(width - ROW_SEP - real_w, area_h), _cards.size(), need)
		if plan["fits"] or panel_w <= PANEL_MIN:
			break
		panel_w = maxf(PANEL_MIN, panel_w - PANEL_STEP)
	plan["fits"] = plan["fits"] and _panel_need_h(panel_w) <= area_h
	return plan


## Melhor grade para `count` cartões numa área: as colunas que dão o maior cartão (na
## proporção do de referência), sem passar de CARD_SIZE nem ficar menor que `need` (o miolo)
## ou CARD_MIN (alvo de toque). Devolve {columns, gap, card, fits}; sem encaixe, o maior.
static func grid_plan(area: Vector2, count: int, need: Vector2 = CARD_MIN) -> Dictionary:
	var least := need.max(CARD_MIN)
	var best := {}
	var best_score := -INF
	for gap: int in [GAP, GAP_TIGHT]:
		for cols: int in COLUMN_CHOICES:
			var rows := ceili(float(count) / cols)
			var w := minf(CARD_SIZE.x, floorf((area.x - (cols - 1) * gap) / cols))
			var h := minf(CARD_SIZE.y, floorf((area.y - (rows - 1) * gap) / rows))
			var fits := w >= least.x and h >= least.y
			var score := minf(w / CARD_SIZE.x, h / CARD_SIZE.y) + (1.0 if fits else 0.0)
			if score > best_score:
				best_score = score
				best = {"columns": cols, "gap": gap, "card": Vector2(w, h), "fits": fits}
		if best["fits"]:
			break
	return best


## Miolo de todos os cartões no estilo dado (o tamanho do cartão vem do _layout).
func _apply_card_style(style: Dictionary) -> void:
	_style = style
	var medal := int(style["medal"])
	for id: StringName in _cards:
		var card: Dictionary = _cards[id]
		var box := card["box"] as VBoxContainer
		box.offset_left = int(style["side"])
		box.offset_right = -int(style["side"])
		box.offset_top = int(style["edge"])
		box.offset_bottom = -int(style["edge"])
		box.add_theme_constant_override("separation", int(style["sep"]))
		(card["medal"] as Control).custom_minimum_size = Vector2(medal, medal)
		(card["disc"] as PanelContainer).add_theme_stylebox_override("panel",
				_flat(Color(0, 0, 0, 0.35), Color(GOLD, 0.25), 1, int(style["pad"])))
		(card["coin"] as Control).custom_minimum_size = Vector2.ONE * int(style["coin"])
		# Pips, moeda e pílula de preço seguem o estilo (_update_card os refaz com ele).
		_update_card(id)


## Espaçamento vertical do painel e margem de baixo da tela.
func _apply_panel_style(style: Dictionary) -> void:
	_side.get_child(0).add_theme_constant_override("separation", int(style["sep"]))
	var box := _side.get_theme_stylebox("panel") as StyleBoxFlat
	box.content_margin_top = int(style["pad"])
	box.content_margin_bottom = int(style["pad"])
	_margin.add_theme_constant_override("margin_bottom", int(style["bottom"]))


## Altura do painel na largura dada com o item de textos mais longos e um aviso inteiro
## (falta de ryō ou reembolso) no lugar da dica; depois volta os textos do selecionado.
func _panel_need_h(width: float) -> float:
	_size_panel(width)
	var info_text := _info.text
	var overrun := _info.text_overrun_behavior
	_info.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var notices: Array[String] = [tr("sanctuary.not_enough"),
			tr("sanctuary.refunded") % Locale.format_number(SaveManager.ryo() + 99999)]
	var need := 0.0
	for id: StringName in _cards:
		var texts := _detail_texts(id)
		_detail_name.text = texts[0]
		_detail_effect.text = texts[1]
		_detail_next.text = texts[2]
		for notice: String in notices:
			_info.text = notice
			need = maxf(need, _side.get_combined_minimum_size().y)
	_info.text_overrun_behavior = overrun
	_info.text = info_text
	var texts := _detail_texts(_selected)
	_detail_name.text = texts[0]
	_detail_effect.text = texts[1]
	_detail_next.text = texts[2]
	return need


## Menor cartão que contém o miolo de todos os cartões no estilo em uso.
func _card_need() -> Vector2:
	var need := Vector2.ZERO
	for id: StringName in _cards:
		need = need.max((_cards[id]["box"] as Control).get_combined_minimum_size())
	return need + Vector2(int(_style["side"]), int(_style["edge"])) * 2


## Largura do painel e dos textos que quebram linha dentro dele; devolve a largura real
## (um botão de texto longo pode alargar o painel além do pedido). Já põe nos textos a largura
## que o painel vai lhes dar: o Label quebra linhas pela largura atual, então a altura mínima
## medida logo depois (_panel_need_h) é a de verdade, sem esperar o contêiner reorganizar.
func _size_panel(width: float) -> float:
	_side.custom_minimum_size.x = width
	_detail_name.custom_minimum_size.x = width - DETAIL_ICON_BOX - 26
	for wrap: Label in [_detail_effect, _detail_next, _info]:
		wrap.custom_minimum_size.x = width - 16
	var real := maxf(width, _side.get_combined_minimum_size().x)
	var inner := real - _side.get_theme_stylebox("panel").get_minimum_size().x
	var head := _detail_name.get_parent().get_parent() as HBoxContainer
	var medal := head.get_child(0) as Control
	_detail_name.size.x = inner - medal.get_combined_minimum_size().x - head.get_theme_constant("separation")
	for wrap: Label in [_detail_effect, _detail_next, _info]:
		wrap.size.x = inner
	return real


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


## Textos do painel para um item: [nome, efeito por nível, nível atual → próximo].
func _detail_texts(id: StringName) -> Array[String]:
	var data: Dictionary = DB.powerups[id]
	var stat := String(data["stat"])
	var per_level: float = float(data["per_level"])
	var level := _level(id)
	var effect := LevelUpSystem.describe_stats({stat: per_level}) + " " + tr("sanctuary.per_level")
	var next := ""
	if _is_maxed(id):
		next = LevelUpSystem.describe_stats({stat: per_level * level})
	elif level == 0:
		next = "→ " + LevelUpSystem.describe_stats({stat: per_level})
	else:
		next = "%s → %s" % [LevelUpSystem.describe_stats({stat: per_level * level}),
				LevelUpSystem.describe_stats({stat: per_level * (level + 1)})]
	return [tr("powerup.%s.name" % id), effect, next]


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
	var pip := Vector2.ONE * int(_style["pip"])
	_fill_pips(card["pips"] as HBoxContainer, _level(id), _max(id), pip)
	var price := card["price"] as Label
	var pill := card["price_box"] as PanelContainer
	var coin := card["coin"] as TextureRect
	var pad := int(_style["pill"])
	if state == "max":
		price.text = tr("sanctuary.max")
		price.add_theme_color_override("font_color", ThemeFactory.ACCENT)
		coin.visible = false
		pill.add_theme_stylebox_override("panel", _pill(Color("5a3d10"), GOLD, pad))
	else:
		price.text = Locale.format_number(MetaProgress.powerup_price(id))
		price.add_theme_color_override("font_color", SHORT if state == "short" else ThemeFactory.TEXT)
		# No miolo mais justo o cartão fica sem a moeda (o botão do painel ainda a mostra).
		coin.visible = int(_style["coin"]) > 0
		coin.modulate = Color(1, 1, 1, 0.6) if state == "short" else Color.WHITE
		pill.add_theme_stylebox_override("panel", _pill(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), pad))


func _update_detail() -> void:
	var id := _selected
	var data: Dictionary = DB.powerups[id]
	var level := _level(id)
	var top := _max(id)
	var state := card_state(id)
	_set_icon(_detail_icon, String(data["icon"]), DETAIL_ICON_BOX)
	_detail_level.text = "%d/%d" % [level, top]
	_detail_level.add_theme_color_override("font_color",
			ThemeFactory.ACCENT if state == "max" else ThemeFactory.TEXT)
	_fill_pips(_detail_pips, level, top, PIP_SIZE)
	var texts := _detail_texts(id)
	_detail_name.text = texts[0]
	_detail_effect.text = texts[1]
	_detail_next.text = texts[2]
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
	pill.offset_right = -MARGIN
	pill.offset_top = 9
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	pill.add_child(box)
	box.add_child(_coin(16))
	_ryo = label("", 12, HORIZONTAL_ALIGNMENT_RIGHT)
	_ryo.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	box.add_child(_ryo)
	return pill


## Cartão no tamanho e miolo de referência; o _layout ajusta os dois à tela.
func _make_card(id: StringName) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = true
	b.pressed.connect(_on_card_pressed.bind(id))
	b.focus_entered.connect(_select.bind(id))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = int(_style["side"])
	box.offset_right = -int(_style["side"])
	box.offset_top = int(_style["edge"])
	box.offset_bottom = -int(_style["edge"])
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(_style["sep"]))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var disc := PanelContainer.new()
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_theme_stylebox_override("panel", _flat(Color(0, 0, 0, 0.35), Color(GOLD, 0.25), 1, int(_style["pad"])))
	box.add_child(disc)
	var medal := CenterContainer.new()
	medal.custom_minimum_size = Vector2.ONE * int(_style["medal"])
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(medal)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_icon(icon, String(DB.powerups[id]["icon"]), int(CARD_STYLES[0]["medal"]))
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
	var coin := _coin(int(_style["coin"]))
	row.add_child(coin)
	var price := label("", 12, HORIZONTAL_ALIGNMENT_CENTER)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(price)
	_cards[id] = {"button": b, "box": box, "disc": disc, "medal": medal, "icon": icon, "pips": pips,
			"price_box": pill, "price": price, "coin": coin}
	return b


func _on_card_pressed(id: StringName) -> void:
	if id != _selected:
		AudioManager.play_ui("ui_accept")
	_select(id)


func _make_detail_panel() -> PanelContainer:
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	var style := _flat(Color(Color("1c110c"), 0.92), GOLD.darkened(0.3), 1, 7)
	style.content_margin_top = int(PANEL_STYLES[0]["pad"])
	style.content_margin_bottom = int(PANEL_STYLES[0]["pad"])
	side.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(PANEL_STYLES[0]["sep"]))
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


func _fill_pips(row: HBoxContainer, level: int, top: int, pip_size: Vector2) -> void:
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for i: int in range(top):
		var pip := Panel.new()
		pip.custom_minimum_size = pip_size
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
