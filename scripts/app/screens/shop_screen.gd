extends Screen
## Loja de recompensas (plano 17.3): 6 vagas, cada uma libera uma recompensa ao assistir
## um anúncio até o fim e volta em 6 h. Uma segunda seção vende, com ryō, reforços de uso
## único para a próxima partida. No fim da rolagem ficam a compra "Remover anúncio de
## abertura" e "Restaurar compras" (17.7).
##
## Layout (referência 678x305; vale para qualquer tela lógica, ver tests/device_profiles.gd):
## fixos só o voltar, o título e a pílula do saldo de ryō no topo. Todo o resto rola num
## ScrollContainer vertical que vai até a borda inferior, em seções com cabeçalho (título,
## filete e subtítulo): Oferendas (vagas por anúncio), Reforços (itens por ryō) e Apoie o
## jogo (compra e restauração, por último). Tudo respeita a área segura (furo da câmera de
## MenuKit.safe_insets) e se refaz quando a tela muda de tamanho ou o recorte troca de lado.
##
## Cartões em grade: 6 colunas de até CARD_W (em 678x305, a linha única de sempre); se a
## largura útil não dá MIN_CARD_W por cartão, vira 3 colunas (2 linhas) de até WIDE_CARD_W.
## Cada texto fica numa caixa de altura fixa calculada no idioma atual com a quebra de linha
## da largura real (TextParagraph): a caixa cabe o texto mais longo da grade, então todos os
## cartões de uma grade têm a mesma altura, sem buracos e sem reticências. Os ícones ficam
## num poço de tamanho único, com escala inteira e corte (nunca saem do cartão). O status
## vira um aviso flutuante (toast) sobre a parte de baixo, que some sozinho.
##
## Os cartões usam MOUSE_FILTER_PASS para o arrasto chegar ao ScrollContainer, e um toque
## que virou arrasto não compra nem resgata nada.
##
## Sem anúncios (AdsManager.ads_enabled = false): as vagas viram presentes ("Receber grátis",
## com a mesma espera de 6 h) e a seção "Apoie o jogo" (compra e restauração) some.

## Largura máxima do cartão na grade de 6 colunas e a mínima para ela ainda valer; abaixo
## disso a grade vira 3 colunas, com cartões de até WIDE_CARD_W.
const CARD_W := 103.0
const MIN_CARD_W := 84.0
const WIDE_CARD_W := 128.0
const COLUMNS := 6
const NARROW_COLUMNS := 3
const GAP := 6.0
const PAD := 4.0
const SEP := 3.0
const WELL_HEIGHT := 36.0
const ICON_BOX := 32.0
## Moeda redonda do jogo: folha com 4 quadros de 10x10 (a do saldo gira).
const COIN_SHEET := "res://assets/art/items/treasure/Coin2.png"
const COIN_FRAME := 10.0
const COIN_FPS := 6.0
const PREMIUM_ICON := "res://assets/art/ui/icons/items/Money.png"
const CARD_TEXT_SIZE := 10
const CHIP_MARGIN_X := 3.0
const CHIP_MARGIN_Y := 1.0
const PILL_HEIGHT := 16.0
const PURCHASE_SEP := 8.0
const SIDE_MARGIN := 10.0
const SCROLL_TOP := 42.0
const SCROLL_RIGHT := 4.0
const BAR_WIDTH := 6.0
const TOAST_WIDTH := 440.0
const TOAST_BOTTOM := 12.0
## Tempo do aviso na tela (o último trecho é o esmaecer).
const TOAST_TIME := 2.5
const TOAST_FADE := 0.3
## Quanto o conteúdo pode rolar entre apertar e soltar um cartão para ainda valer o toque.
const TAP_SLOP := 6
## Quanto o ícone sobe no poço quando o cartão está em foco ou com o mouse em cima.
const ICON_LIFT := 2.0

const CARD_BG := Color("3b2329")
const CARD_HOVER_BG := Color("54313a")
const CARD_PRESSED_BG := Color("2a171c")
const CARD_BORDER := Color("a0603a")
const DIM_BG := Color("221519")
const DIM_BORDER := Color("4d3436")
const QUEUED_BG := Color("4a3420")
const WELL_BG := Color(0.05, 0.02, 0.03, 0.55)
const EFFECT_BG := Color("1f3a28")
const EFFECT_TEXT := Color("c2f5b8")
const MUTED := Color("cdb89c")
const SHORT := Color("ff8f80")
const CLOCK := Color("aab9cc")
const LACQUER := Color("8f2333")
const OWNED := Color("2c4a2e")

var _scroll: ScrollContainer
var _title: Label
var _rule_line: ColorRect
var _balance: PanelContainer
var _row: GridContainer
var _coin_row: GridContainer
## Grade atual (colunas, largura do cartão), o recorte da câmera (esquerda, direita) e a
## largura da tela do último layout.
var _grid := Vector2(COLUMNS, CARD_W)
var _insets := Vector2(-1, -1)
var _laid_width := -1.0
var _status: Label
var _toast: PanelContainer
var _ryo: Label
var _balance_coin: TextureRect
var _coin_time: float = 0.0
var _purchase: BoxContainer
var _buy: Button
var _restore: Button
## Subtítulo das Oferendas (texto de anúncio ou de presente) e os nós da seção de compra.
var _offer_hint: Label
var _support: Array[Control] = []
## id -> {"button": Button, "name": Label, "state": Label, "pill": PanelContainer, "dim": Array}
var _cards: Dictionary = {}
## id -> {"button": Button, "price": Label, "coin": TextureRect, "pill": PanelContainer, "dim": Array}
var _coin_cards: Dictionary = {}
var _refresh_timer: float = 0.0
## Posição da rolagem quando o dedo apertou um cartão (-1: nenhum aperto registrado).
var _press_scroll: int = -1
## Texto que o aviso mostrou por último e quanto tempo ainda fica na tela.
var _toast_text: String = ""
var _toast_left: float = 0.0


func _ready() -> void:
	add_child(back_button())
	_title = title_label(tr("shop.title"))
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.offset_top = 6
	_title.clip_text = true
	add_child(_title)
	_balance = _balance_pill()
	add_child(_balance)
	# Filete fino separando o topo fixo do conteúdo que rola.
	_rule_line = ColorRect.new()
	_rule_line.color = Color(ThemeFactory.ACCENT, 0.22)
	_rule_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_rule_line.offset_top = SCROLL_TOP - 3
	_rule_line.offset_bottom = SCROLL_TOP - 2
	_rule_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rule_line)

	# Todo o resto rola, do topo até a borda inferior.
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top = SCROLL_TOP
	_scroll.offset_bottom = 0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.scroll_deadzone = 8
	_scroll.follow_focus = true
	_style_scroll_bar(_scroll.get_v_scroll_bar())
	add_child(_scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(col)
	var offerings := _section(tr("shop.section.offerings"), tr("shop.hint"))
	_offer_hint = offerings.get_child(1) as Label
	col.add_child(offerings)
	_row = _card_row()
	col.add_child(_row)
	col.add_child(_spacer(6))
	col.add_child(_section(tr("shop.section.boosts"), tr("shop.coin_row")))
	_coin_row = _card_row()
	col.add_child(_coin_row)
	col.add_child(_spacer(6))
	_support.append(_section(tr("shop.section.support"), tr("shop.support_hint")))
	_support.append(_purchase_row())
	for node: Control in _support:
		col.add_child(node)
	col.add_child(_spacer(10))

	_build_toast()
	_apply_frame(MenuKit.safe_insets(self))
	resized.connect(_relayout)
	# Furo da câmera que troca de lado com a tela aberta (giro de 180°).
	MenuKit.on_insets_change(self, _relayout)
	PurchaseManager.purchase_finished.connect(func(_p: String, ok: bool) -> void:
		var pending := bool(SaveManager.data["purchases"].get("pending", false))
		_show_status(tr("shop.thanks") if ok else (tr("shop.pending") if pending else tr("shop.failed")))
		on_show())


func on_show() -> void:
	for child: Node in _row.get_children():
		child.queue_free()
	for child: Node in _coin_row.get_children():
		child.queue_free()
	_cards.clear()
	_coin_cards.clear()
	_offer_hint.text = tr("shop.hint") if AdsManager.ads_enabled else tr("shop.hint_free")
	for node: Control in _support:
		node.visible = PurchaseManager.available()
	_insets = MenuKit.safe_insets(self)
	_laid_width = _screen_width()
	_apply_frame(_insets)
	_grid = _grid_for(_insets)
	var card_w := _grid.y
	_row.columns = int(_grid.x)
	_coin_row.columns = int(_grid.x)
	var text_w := card_w - 2 * PAD
	var chip_w := text_w - 2 * CHIP_MARGIN_X
	# Vagas por anúncio: a caixa do nome cabe o nome mais longo da linha; a do estado, o
	# mais longo entre "ver anúncio", "sem anúncios" e o cronômetro.
	var slot_names: Dictionary = {}
	var name_lines := 1
	for id: StringName in ShopManager.ad_slots():
		slot_names[id] = _slot_name(id)
		name_lines = maxi(name_lines, _lines(slot_names[id], text_w))
	var state_lines := 1
	for text: String in ["> %s" % claim_text(), tr("shop.no_ads"), "00:00:00"]:
		state_lines = maxi(state_lines, _lines(text, chip_w))
	var slot_h := _card_height([_text_height(name_lines), _text_height(state_lines) + 2 * CHIP_MARGIN_Y])
	for id: StringName in ShopManager.ad_slots():
		var data: Dictionary = DB.shop[id]
		var b := _card_button(Vector2(card_w, slot_h), _claim.bind(id))
		b.name = "Slot_%s" % id
		_row.add_child(b)
		var inner := _card_inner(b)
		var well := _icon_well(String(data["icon"]), b)
		inner.add_child(well)
		var name_label := _card_label(String(slot_names[id]))
		inner.add_child(_fixed_box(name_label, _text_height(name_lines)))
		var state_label := _card_label("")
		var pill := _chip(state_label, _text_height(state_lines))
		inner.add_child(pill)
		_cards[id] = {"button": b, "name": name_label, "state": state_label, "pill": pill, "dim": [well, name_label]}
	# Reforços por ryō: nome, efeito (numa faixa) e preço (numa pílula).
	var coin_name_lines := 1
	var effect_lines := 1
	for id: StringName in ShopManager.coin_items():
		coin_name_lines = maxi(coin_name_lines, _lines(tr("shop.%s.name" % id), text_w))
		effect_lines = maxi(effect_lines, _lines(ShopManager.coin_effect(id), chip_w))
	var coin_h := _card_height([_text_height(coin_name_lines),
			_text_height(effect_lines) + 2 * CHIP_MARGIN_Y, PILL_HEIGHT])
	for id: StringName in ShopManager.coin_items():
		var data: Dictionary = DB.shop[id]
		var b := _card_button(Vector2(card_w, coin_h), _buy_coin.bind(id))
		b.name = "Coin_%s" % id
		_coin_row.add_child(b)
		var inner := _card_inner(b)
		var well := _icon_well(String(data["icon"]), b)
		inner.add_child(well)
		var name_label := _card_label(tr("shop.%s.name" % id))
		inner.add_child(_fixed_box(name_label, _text_height(coin_name_lines)))
		var effect := _card_label(ShopManager.coin_effect(id))
		effect.add_theme_color_override("font_color", EFFECT_TEXT)
		var chip := _chip(effect, _text_height(effect_lines), _flat(EFFECT_BG, Color(EFFECT_TEXT, 0.25), 1, 2))
		inner.add_child(chip)
		var price_pill := PanelContainer.new()
		price_pill.custom_minimum_size = Vector2(0, PILL_HEIGHT)
		price_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var price_row := HBoxContainer.new()
		price_row.alignment = BoxContainer.ALIGNMENT_CENTER
		price_row.add_theme_constant_override("separation", 3)
		price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_pill.add_child(price_row)
		var coin := _coin_rect()
		price_row.add_child(coin)
		var price := label("", CARD_TEXT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
		price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_row.add_child(price)
		inner.add_child(price_pill)
		_coin_cards[id] = {"button": b, "price": price, "coin": coin, "pill": price_pill,
				"dim": [well, name_label, chip]}
	_update_cards()
	var owned := PurchaseManager.owns()
	_buy.text = tr("shop.owned") if owned else tr("shop.remove_ad") % PurchaseManager.price_text()
	_buy.disabled = owned
	# Tela estreita: "Restaurar compras" desce para baixo da compra em vez de alargar a linha.
	var row_w := _buy.get_combined_minimum_size().x + PURCHASE_SEP + _restore.get_combined_minimum_size().x
	_purchase.vertical = row_w > _content_width(_insets)


func _process(delta: float) -> void:
	if not visible:
		return
	_update_toast(delta)
	_coin_time += delta
	var frame := floori(_coin_time * COIN_FPS) % 4
	(_balance_coin.texture as AtlasTexture).region = Rect2(frame * COIN_FRAME, 0, COIN_FRAME, COIN_FRAME)
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 1.0
		_update_cards()


func _update_cards() -> void:
	for id: StringName in _cards:
		var card: Dictionary = _cards[id]
		var b: Button = card["button"]
		(card["name"] as Label).text = _slot_name(id)
		var state: Label = card["state"]
		var pill: PanelContainer = card["pill"]
		var is_ready := ShopManager.is_ready(id)
		if is_ready:
			b.disabled = not AdsManager.rewarded_available()
		else:
			b.disabled = true
		if is_ready and not b.disabled:
			# Chamada para ação: pílula dourada com texto escuro.
			state.text = "> %s" % claim_text()
			state.add_theme_color_override("font_color", ThemeFactory.TEXT_DARK)
			state.add_theme_constant_override("outline_size", 0)
			pill.add_theme_stylebox_override("panel", _flat(ThemeFactory.ACCENT, Color("fff1c4"), 1, 3))
		else:
			var left := ShopManager.seconds_left(id)
			state.text = tr("shop.no_ads") if is_ready else "%02d:%02d:%02d" % [
					floori(left / 3600.0), floori(fmod(left, 3600) / 60.0), left % 60]
			state.add_theme_color_override("font_color", MUTED if is_ready else CLOCK)
			state.remove_theme_constant_override("outline_size")
			pill.add_theme_stylebox_override("panel", _flat(Color(0, 0, 0, 0.35), Color(CLOCK, 0.3), 1, 3))
		for node: CanvasItem in card["dim"]:
			node.modulate = Color(1, 1, 1, 0.5) if b.disabled else Color.WHITE
	_update_coin_cards()


## Saldo e estado dos reforços: apagado com preço em vermelho sem ryō suficiente; selo
## dourado "guardado" quando já está na fila da próxima partida.
func _update_coin_cards() -> void:
	_ryo.text = Locale.format_number(SaveManager.ryo())
	for id: StringName in _coin_cards:
		var card: Dictionary = _coin_cards[id]
		var b: Button = card["button"]
		var queued := ShopManager.is_queued(id)
		b.disabled = not ShopManager.can_buy_coin(id)
		var short := b.disabled and not queued
		b.add_theme_stylebox_override("disabled", _queued_style() if queued else _dim_style())
		for node: CanvasItem in card["dim"]:
			node.modulate = Color(1, 1, 1, 0.45) if short else Color.WHITE
		var price: Label = card["price"]
		var pill: PanelContainer = card["pill"]
		(card["coin"] as Control).visible = not queued
		if queued:
			price.text = tr("shop.coin.queued")
			price.add_theme_color_override("font_color", ThemeFactory.TEXT_DARK)
			price.add_theme_constant_override("outline_size", 0)
			pill.add_theme_stylebox_override("panel", _flat(ThemeFactory.ACCENT, Color("fff1c4"), 1, 6))
		else:
			price.text = Locale.format_number(ShopManager.coin_price(id))
			price.add_theme_color_override("font_color", SHORT if short else ThemeFactory.ACCENT)
			price.remove_theme_constant_override("outline_size")
			pill.add_theme_stylebox_override("panel",
					_flat(Color(0.05, 0.02, 0.03, 0.7), Color(SHORT if short else ThemeFactory.ACCENT, 0.5), 1, 6))


# --- Layout pela tela e pela área segura ----------------------------------------------

## Largura lógica da tela (antes do primeiro layout, a do pai).
func _screen_width() -> float:
	return size.x if size.x > 0.0 else get_parent_area_size().x


## Largura útil do conteúdo rolável (sem o recorte, as margens e a barra de rolagem).
func _content_width(insets: Vector2) -> float:
	return _screen_width() - insets.x - insets.y - SIDE_MARGIN - SCROLL_RIGHT - BAR_WIDTH


## Grade dos cartões para a largura útil da área rolável: (colunas, largura do cartão).
func _grid_for(insets: Vector2) -> Vector2:
	var avail := _content_width(insets)
	var wide := floorf((avail - (COLUMNS - 1) * GAP) / COLUMNS)
	if wide >= MIN_CARD_W:
		return Vector2(COLUMNS, minf(CARD_W, wide))
	var narrow := floorf((avail - (NARROW_COLUMNS - 1) * GAP) / NARROW_COLUMNS)
	return Vector2(NARROW_COLUMNS, minf(WIDE_CARD_W, narrow))


## Fixos, filete, área rolável e aviso afastados do recorte da câmera (esquerda, direita).
func _apply_frame(insets: Vector2) -> void:
	var shift := (insets.x - insets.y) / 2
	_title.offset_left = -150 + shift
	_title.offset_right = 150 + shift
	_balance.offset_left = -SIDE_MARGIN - insets.y
	_balance.offset_right = -SIDE_MARGIN - insets.y
	_rule_line.offset_left = SIDE_MARGIN + insets.x
	_rule_line.offset_right = -SIDE_MARGIN - insets.y
	_scroll.offset_left = SIDE_MARGIN + insets.x
	_scroll.offset_right = -SCROLL_RIGHT - insets.y
	var toast_w := minf(TOAST_WIDTH, _screen_width() - insets.x - insets.y - 2 * SIDE_MARGIN)
	_toast.offset_left = shift - toast_w / 2
	_toast.offset_right = shift + toast_w / 2
	_status.custom_minimum_size = Vector2(toast_w - 20, 0)


## A tela mudou de tamanho ou o recorte trocou de lado (giro de 180°): refaz o layout
## (fixos, grade e linha de compra) só quando algo mudou de fato.
func _relayout() -> void:
	if _cards.is_empty():
		return
	var insets := MenuKit.safe_insets(self)
	if insets != _insets or not is_equal_approx(_screen_width(), _laid_width):
		on_show()


## Chamada da vaga pronta: "Ver anúncio" ou, sem anúncios, "Receber grátis".
func claim_text() -> String:
	return tr("shop.watch") if AdsManager.ads_enabled else tr("shop.claim_free")


func _claim(id: StringName) -> void:
	if _was_drag():
		return
	ShopManager.claim(id, func(ok: bool) -> void:
		_show_status(tr("shop.received") % tr("shop.%s.name" % id) if ok else tr("shop.watch_full"))
		if ok:
			AudioManager.play("jingle_unlock")
		_update_cards())


## Compra um reforço com ryō (devolve se comprou; o teste e o E2E chamam direto).
func _buy_coin(id: StringName) -> bool:
	if _was_drag():
		return false
	var ok := ShopManager.buy_coin(id)
	if ok:
		AudioManager.play("coin2")
		_show_status(tr("shop.received") % tr("shop.%s.name" % id))
	else:
		AudioManager.play_ui("ui_cancel")
		_show_status(tr("sanctuary.not_enough"))
	_update_coin_cards()
	return ok


func _on_buy() -> void:
	PurchaseManager.purchase()


func _on_restore() -> void:
	PurchaseManager.restore()
	_show_status(tr("shop.restored"))
	on_show()


## O conteúdo rolou desde que o dedo apertou o cartão: foi arrasto, não toque.
func _was_drag() -> bool:
	var moved := _press_scroll >= 0 and absi(_scroll.scroll_vertical - _press_scroll) > TAP_SLOP
	_press_scroll = -1
	return moved


# --- Aviso (toast) ------------------------------------------------------------------

## Mostra o aviso (de novo, mesmo que o texto seja igual ao anterior).
func _show_status(text: String) -> void:
	_status.text = text
	_toast_text = text
	_toast_left = TOAST_TIME if text != "" else 0.0
	_toast.modulate.a = 1.0 if text != "" else 0.0


## O aviso acompanha `_status.text` (quem muda o texto direto também faz o aviso aparecer)
## e esmaece no fim do tempo.
func _update_toast(delta: float) -> void:
	if _status.text != _toast_text:
		_show_status(_status.text)
		return
	if _toast_left <= 0.0:
		return
	_toast_left = maxf(0.0, _toast_left - delta)
	_toast.modulate.a = clampf(_toast_left / TOAST_FADE, 0.0, 1.0)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.name = "Toast"
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_left = -TOAST_WIDTH / 2
	_toast.offset_right = TOAST_WIDTH / 2
	_toast.offset_top = -TOAST_BOTTOM
	_toast.offset_bottom = -TOAST_BOTTOM
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	var box := _flat(Color(0.07, 0.03, 0.05, 0.94), ThemeFactory.ACCENT, 1, 4)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 4
	_toast.add_theme_stylebox_override("panel", box)
	add_child(_toast)
	_status = label("", 12, HORIZONTAL_ALIGNMENT_CENTER)
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(TOAST_WIDTH - 20, 0)
	_status.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_child(_status)


# --- Peças do layout ----------------------------------------------------------------

## Saldo de ryō numa pílula escura no canto superior direito (cresce para a esquerda).
func _balance_pill() -> PanelContainer:
	var pill := PanelContainer.new()
	pill.name = "Balance"
	pill.anchor_left = 1.0
	pill.anchor_right = 1.0
	pill.offset_left = -SIDE_MARGIN
	pill.offset_right = -SIDE_MARGIN
	pill.offset_top = 10
	pill.offset_bottom = 32
	pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := _flat(Color(0.06, 0.02, 0.04, 0.85), Color(ThemeFactory.ACCENT, 0.55), 1, 10)
	box.content_margin_left = 6
	box.content_margin_right = 9
	pill.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	_balance_coin = _coin_rect()
	row.add_child(_balance_coin)
	_ryo = label("", 12, HORIZONTAL_ALIGNMENT_RIGHT)
	_ryo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ryo.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	_ryo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_ryo)
	return pill


## Cabeçalho de seção: marca, título em destaque, filete até a borda e subtítulo.
func _section(title: String, subtitle: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(head)
	head.add_child(_rule(Vector2(8, 2), ThemeFactory.ACCENT))
	var title_label_node := label(title, 12)
	title_label_node.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	title_label_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title_label_node)
	var line := _rule(Vector2(0, 1), Color(ThemeFactory.ACCENT, 0.35))
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(line)
	var sub := label(subtitle, CARD_TEXT_SIZE)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_color_override("font_color", MUTED)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sub)
	return box


## Compra que remove o anúncio de abertura (destaque) e "Restaurar compras" (discreto), lado a
## lado; em tela estreita (on_show) a linha vira coluna, com a restauração embaixo à direita.
func _purchase_row() -> BoxContainer:
	var row := BoxContainer.new()
	row.add_theme_constant_override("separation", int(PURCHASE_SEP))
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	_purchase = row
	_buy = button("", _on_buy, Vector2(0, 38))
	_buy.name = "RemoveAd"
	_buy.clip_text = false
	_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy.mouse_filter = Control.MOUSE_FILTER_PASS
	_buy.icon = load(PREMIUM_ICON) as Texture2D
	_buy.add_theme_constant_override("h_separation", 8)
	_buy.add_theme_stylebox_override("normal", _premium_style(LACQUER, ThemeFactory.ACCENT))
	_buy.add_theme_stylebox_override("hover", _premium_style(LACQUER.lightened(0.15), Color("fff1c4")))
	_buy.add_theme_stylebox_override("pressed", _premium_style(LACQUER.darkened(0.25), ThemeFactory.ACCENT))
	_buy.add_theme_stylebox_override("disabled", _premium_style(OWNED, Color("8fd18a")))
	_buy.add_theme_stylebox_override("focus", _focus_style())
	_buy.add_theme_color_override("font_disabled_color", Color("d6f5d0"))
	row.add_child(_buy)
	_restore = button(tr("shop.restore"), _on_restore, Vector2(0, 26))
	_restore.name = "Restore"
	_restore.clip_text = false
	_restore.size_flags_horizontal = Control.SIZE_SHRINK_END
	_restore.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_restore.mouse_filter = Control.MOUSE_FILTER_PASS
	_restore.add_theme_font_size_override("font_size", CARD_TEXT_SIZE)
	_restore.add_theme_color_override("font_color", MUTED)
	var quiet := _flat(Color(0, 0, 0, 0.25), Color(MUTED, 0.45), 1, 3)
	quiet.content_margin_left = 10
	quiet.content_margin_right = 10
	_restore.add_theme_stylebox_override("normal", quiet)
	var quiet_hover := quiet.duplicate() as StyleBoxFlat
	quiet_hover.bg_color = Color(1, 1, 1, 0.08)
	quiet_hover.border_color = ThemeFactory.ACCENT
	_restore.add_theme_stylebox_override("hover", quiet_hover)
	_restore.add_theme_stylebox_override("pressed", quiet_hover)
	_restore.add_theme_stylebox_override("focus", _focus_style())
	row.add_child(_restore)
	return row


## Grade dos cartões, centrada na área rolável (as colunas vêm de _grid_for).
func _card_row() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", int(GAP))
	grid.add_theme_constant_override("v_separation", int(GAP))
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	return grid


## Cartão-botão: PASS deixa o arrasto chegar ao ScrollContainer (rolar com o dedo).
func _card_button(card_size: Vector2, on_press: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = card_size
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.add_theme_stylebox_override("normal", _card_style(CARD_BG, CARD_BORDER))
	b.add_theme_stylebox_override("hover", _card_style(CARD_HOVER_BG, ThemeFactory.ACCENT, true))
	b.add_theme_stylebox_override("pressed", _card_style(CARD_PRESSED_BG, ThemeFactory.ACCENT))
	b.add_theme_stylebox_override("disabled", _dim_style())
	b.add_theme_stylebox_override("focus", _focus_style())
	b.button_down.connect(func() -> void: _press_scroll = _scroll.scroll_vertical)
	b.pressed.connect(on_press)
	return b


func _card_inner(b: Button) -> VBoxContainer:
	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = PAD
	inner.offset_right = -PAD
	inner.offset_top = PAD
	inner.offset_bottom = -PAD
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", int(SEP))
	b.add_child(inner)
	return inner


## Altura do cartão: padding, poço do ícone e as caixas de texto, sem sobra.
func _card_height(parts: Array) -> float:
	var total := 2 * PAD + WELL_HEIGHT
	for part: float in parts:
		total += SEP + part
	return total


## Poço escuro do ícone: mesma caixa para todos, ícone em escala inteira e cortado na borda.
## Folhas com quadros lado a lado (ex.: baús abrindo) mostram só o primeiro quadro.
func _icon_well(path: String, card: Button) -> Panel:
	var well := Panel.new()
	well.name = "Well"
	well.custom_minimum_size = Vector2(0, WELL_HEIGHT)
	well.clip_contents = true
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_theme_stylebox_override("panel", _flat(WELL_BG, Color(0, 0, 0, 0.35), 1, 3))
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var side := ICON_BOX
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		var frame := Vector2(tex.get_width(), tex.get_height())
		var frames := floori(frame.x / frame.y)
		if frames >= 2:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(0, 0, floorf(frame.x / frames), frame.y)
			tex = atlas
			frame = atlas.region.size
		var scale_i := maxf(1.0, floorf(ICON_BOX / maxf(frame.x, frame.y)))
		side = maxf(frame.x, frame.y) * scale_i
		icon.texture = tex
	icon.anchor_left = 0.5
	icon.anchor_right = 0.5
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = -side / 2
	icon.offset_right = side / 2
	icon.offset_top = -side / 2
	icon.offset_bottom = side / 2
	well.add_child(icon)
	# Mouse em cima ou foco: o ícone sobe um pouco no poço.
	var lift := func(up: bool) -> void:
		if card.disabled and up:
			return
		var tween := icon.create_tween()
		tween.tween_property(icon, "offset_top", -side / 2 - (ICON_LIFT if up else 0.0), 0.08)
		tween.parallel().tween_property(icon, "offset_bottom", side / 2 - (ICON_LIFT if up else 0.0), 0.08)
	card.mouse_entered.connect(lift.bind(true))
	card.mouse_exited.connect(lift.bind(false))
	card.focus_entered.connect(lift.bind(true))
	card.focus_exited.connect(lift.bind(false))
	return well


## Faixa (efeito, estado da vaga) com o texto numa caixa de altura fixa.
func _chip(text: Label, text_height: float, style: StyleBoxFlat = null) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := style if style != null else _flat(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 3)
	box.content_margin_left = CHIP_MARGIN_X
	box.content_margin_right = CHIP_MARGIN_X
	box.content_margin_top = CHIP_MARGIN_Y
	box.content_margin_bottom = CHIP_MARGIN_Y
	chip.add_theme_stylebox_override("panel", box)
	text.custom_minimum_size = Vector2(0, text_height)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(text)
	return chip


## Texto do cartão: quebra em linhas dentro da caixa; nunca alarga o layout.
func _card_label(text: String) -> Label:
	var l := label(text, CARD_TEXT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
	l.clip_text = true
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Caixa de altura fixa: o conteúdo que não couber é cortado e não empurra os vizinhos.
func _fixed_box(node: Control, height: float) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(0, height)
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(node)
	return box


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _rule(size_px: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = size_px
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Primeiro quadro da moeda redonda em escala 1 (nítida ao lado do texto de fonte 10-12).
func _coin_rect() -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(COIN_SHEET) as Texture2D
	atlas.region = Rect2(0, 0, COIN_FRAME, COIN_FRAME)
	var rect := TextureRect.new()
	rect.texture = atlas
	rect.custom_minimum_size = Vector2(COIN_FRAME, COIN_FRAME)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _slot_name(id: StringName) -> String:
	if id == &"slot_ryo":
		return tr("shop.slot_ryo.name_value") % ShopManager.ryo_value()
	return tr("shop.%s.name" % id)


## Linhas que o texto ocupa na largura dada, com a mesma quebra do Label (WORD_SMART).
func _lines(text: String, width: float) -> int:
	var paragraph := TextParagraph.new()
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND \
			| TextServer.BREAK_ADAPTIVE | TextServer.BREAK_TRIM_START_EDGE_SPACES \
			| TextServer.BREAK_TRIM_END_EDGE_SPACES
	paragraph.width = width
	paragraph.add_string(text, get_theme_font("font", "Label"), CARD_TEXT_SIZE)
	return maxi(1, paragraph.get_line_count())


## Altura de `lines` linhas do texto do cartão (fonte 10 com o espaçamento do Label).
func _text_height(lines: int) -> float:
	var font := get_theme_font("font", "Label")
	var spacing := get_theme_constant("line_spacing", "Label")
	return lines * font.get_height(CARD_TEXT_SIZE) + (lines - 1) * spacing


# --- Estilos ------------------------------------------------------------------------

func _flat(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.corner_detail = 3
	box.anti_aliasing = false
	return box


## Cartão laqueado: fundo escuro, borda de madeira (ou dourada) e brilho opcional.
func _card_style(bg: Color, border: Color, glow: bool = false) -> StyleBoxFlat:
	var box := _flat(bg, border, 1, 4)
	box.border_width_bottom = 2
	if glow:
		box.shadow_color = Color(ThemeFactory.ACCENT, 0.35)
		box.shadow_size = 3
	return box


func _dim_style() -> StyleBoxFlat:
	return _card_style(DIM_BG, DIM_BORDER)


func _queued_style() -> StyleBoxFlat:
	var box := _card_style(QUEUED_BG, ThemeFactory.ACCENT)
	box.set_border_width_all(2)
	return box


func _focus_style() -> StyleBoxFlat:
	var box := _flat(Color(0, 0, 0, 0), ThemeFactory.ACCENT, 1, 4)
	box.draw_center = false
	return box


func _premium_style(bg: Color, border: Color) -> StyleBoxFlat:
	var box := _flat(bg, border, 2, 5)
	box.border_width_bottom = 3
	box.shadow_color = Color(ThemeFactory.ACCENT, 0.18)
	box.shadow_size = 3
	box.content_margin_left = 12
	box.content_margin_right = 12
	return box


func _style_scroll_bar(bar: VScrollBar) -> void:
	var track := _flat(Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 0, 3)
	track.content_margin_left = BAR_WIDTH / 2
	track.content_margin_right = BAR_WIDTH / 2
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", _flat(Color(ThemeFactory.ACCENT, 0.55), Color(0, 0, 0, 0), 0, 3))
	bar.add_theme_stylebox_override("grabber_highlight", _flat(ThemeFactory.ACCENT, Color(0, 0, 0, 0), 0, 3))
	bar.add_theme_stylebox_override("grabber_pressed", _flat(ThemeFactory.ACCENT, Color(0, 0, 0, 0), 0, 3))
