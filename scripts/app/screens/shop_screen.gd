extends Screen
## Loja de recompensas (plano 17.3): 6 vagas, cada uma libera uma recompensa ao assistir
## um anúncio até o fim e volta em 6 h. Uma segunda linha vende, com ryō, reforços de uso
## único para a próxima partida. Também oferece a compra "Remover anúncio de abertura" e
## "Restaurar compras" (17.7).
##
## Layout com alturas fixas (viewport 678x305): cada texto fica numa caixa de altura fixa
## que cabe o número de linhas que o idioma mais longo precisa (quebra de linha, sem
## reticências). Ficam fixos: o voltar, o título e o saldo de ryō no topo; a linha de status
## e a linha de botões embaixo (a de botões a 10 px da borda). O meio (as duas linhas de
## cartões e a dica) fica num ScrollContainer vertical: o conteúdo que não cabe rola com o
## dedo. Os cartões usam MOUSE_FILTER_PASS para o arrasto chegar ao ScrollContainer, e um
## toque que virou arrasto não compra nem resgata nada.

const CARD_SIZE := Vector2(102, 124)
const COIN_CARD_SIZE := Vector2(102, 146)
const ICON_SIZE := Vector2(20, 20)
const COIN_ICON_SIZE := Vector2(14, 14)
const COIN_ICON := "res://assets/art/ui/icons/items/Money.png"
const CARD_TEXT_SIZE := 10
const CARD_NAME_HEIGHT := 57.0   # até 3 linhas de fonte 10
const CARD_STATE_HEIGHT := 38.0  # até 2 linhas de fonte 10
const COIN_NAME_HEIGHT := 38.0   # até 2 linhas de fonte 10
const COIN_EFFECT_HEIGHT := 57.0 # até 3 linhas de fonte 10
const PRICE_HEIGHT := 19.0       # 1 linha de fonte 10
const HINT_HEIGHT := 46.0       # até 2 linhas
const HEADER_HEIGHT := 24.0     # 1 linha
const STATUS_HEIGHT := 24.0     # 1 linha
const BOTTOM_MARGIN := 10.0
const BOTTOM_ROW_HEIGHT := 30.0  # 1 linha nos botões
const SCROLL_TOP := 44.0
const SIDE_MARGIN := 12.0
const GAP := 4.0
## Quanto o conteúdo pode rolar entre apertar e soltar um cartão para ainda valer o toque.
const TAP_SLOP := 6

var _scroll: ScrollContainer
var _row: HBoxContainer
var _coin_row: HBoxContainer
var _hint: Label
var _status: Label
var _ryo: Label
var _buy: Button
var _restore: Button
## id -> {"button": Button, "name": Label, "state": Label}
var _cards: Dictionary = {}
## id -> {"button": Button, "inner": Control, "price": Label, "coin": TextureRect}
var _coin_cards: Dictionary = {}
var _refresh_timer: float = 0.0
## Posição da rolagem quando o dedo apertou um cartão (-1: nenhum aperto registrado).
var _press_scroll: int = -1


func _ready() -> void:
	add_child(back_button())
	var title := title_label(tr("shop.title"))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -150
	title.offset_right = 150
	title.offset_top = 6
	title.clip_text = true
	add_child(title)
	# Saldo de ryō (fixo, canto superior direito).
	var balance := HBoxContainer.new()
	balance.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	balance.offset_left = -170
	balance.offset_right = -SIDE_MARGIN
	balance.offset_top = 12
	balance.offset_bottom = 30
	balance.alignment = BoxContainer.ALIGNMENT_END
	balance.add_theme_constant_override("separation", 4)
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(balance)
	var coin := icon_rect(COIN_ICON, COIN_ICON_SIZE)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	balance.add_child(coin)
	_ryo = label("", 12, HORIZONTAL_ALIGNMENT_RIGHT)
	_ryo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balance.add_child(_ryo)

	# Meio rolável: do título até acima da linha de status.
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = SIDE_MARGIN
	_scroll.offset_right = -SIDE_MARGIN
	_scroll.offset_top = SCROLL_TOP
	_scroll.offset_bottom = -(BOTTOM_MARGIN + BOTTOM_ROW_HEIGHT + GAP + STATUS_HEIGHT + GAP)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.scroll_deadzone = 8
	_scroll.follow_focus = true
	add_child(_scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(col)
	_row = _card_row()
	col.add_child(_row)
	_hint = _text_label(tr("shop.hint"), HORIZONTAL_ALIGNMENT_CENTER, TextServer.AUTOWRAP_WORD_SMART)
	col.add_child(_fixed_box(_hint, HINT_HEIGHT))
	var header := _text_label(tr("shop.coin_row"), HORIZONTAL_ALIGNMENT_CENTER, TextServer.AUTOWRAP_WORD_SMART)
	header.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	col.add_child(_fixed_box(header, HEADER_HEIGHT))
	_coin_row = _card_row()
	col.add_child(_coin_row)

	# Status: fixo logo acima da linha de botões, sempre visível mesmo com o meio rolado.
	var status_box := Control.new()
	status_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status_box.offset_left = SIDE_MARGIN
	status_box.offset_right = -SIDE_MARGIN
	status_box.offset_top = -(BOTTOM_MARGIN + BOTTOM_ROW_HEIGHT + GAP + STATUS_HEIGHT)
	status_box.offset_bottom = -(BOTTOM_MARGIN + BOTTOM_ROW_HEIGHT + GAP)
	status_box.clip_contents = true
	status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_box)
	_status = _text_label("", HORIZONTAL_ALIGNMENT_CENTER, TextServer.AUTOWRAP_WORD_SMART)
	_status.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	_status.set_anchors_preset(Control.PRESET_FULL_RECT)
	status_box.add_child(_status)
	# Linha de botões: ancorada na borda inferior, sempre visível.
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -(BOTTOM_MARGIN + BOTTOM_ROW_HEIGHT)
	bottom.offset_bottom = -BOTTOM_MARGIN
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 8)
	add_child(bottom)
	_buy = button("", _on_buy, Vector2(476, BOTTOM_ROW_HEIGHT))
	_fit_button(_buy)
	bottom.add_child(_buy)
	_restore = button(tr("shop.restore"), func() -> void:
		PurchaseManager.restore()
		_status.text = tr("shop.restored")
		on_show(), Vector2(170, BOTTOM_ROW_HEIGHT))
	_fit_button(_restore)
	bottom.add_child(_restore)
	PurchaseManager.purchase_finished.connect(func(_p: String, ok: bool) -> void:
		var pending := bool(SaveManager.data["purchases"].get("pending", false))
		_status.text = tr("shop.thanks") if ok else (tr("shop.pending") if pending else tr("shop.failed"))
		on_show())


func on_show() -> void:
	for child: Node in _row.get_children():
		child.queue_free()
	for child: Node in _coin_row.get_children():
		child.queue_free()
	_cards.clear()
	_coin_cards.clear()
	for id: StringName in ShopManager.ad_slots():
		var data: Dictionary = DB.shop[id]
		var b := _card_button(CARD_SIZE, _claim.bind(id))
		_row.add_child(b)
		# Conteúdo do cartão: ícone, nome e estado, cada um em caixa de altura fixa.
		var inner := _card_inner(b)
		inner.add_child(_fixed_box(icon_rect(String(data["icon"]), ICON_SIZE), ICON_SIZE.y))
		var name_label := _text_label("", HORIZONTAL_ALIGNMENT_CENTER, TextServer.AUTOWRAP_WORD_SMART, CARD_TEXT_SIZE)
		inner.add_child(_fixed_box(name_label, CARD_NAME_HEIGHT))
		var state_label := _text_label("", HORIZONTAL_ALIGNMENT_CENTER, TextServer.AUTOWRAP_WORD_SMART, CARD_TEXT_SIZE)
		inner.add_child(_fixed_box(state_label, CARD_STATE_HEIGHT))
		_cards[id] = {"button": b, "name": name_label, "state": state_label}
	for id: StringName in ShopManager.coin_items():
		var data: Dictionary = DB.shop[id]
		var b := _card_button(COIN_CARD_SIZE, _buy_coin.bind(id))
		b.name = "Coin_%s" % id
		_coin_row.add_child(b)
		# Ícone, nome, efeito e preço (com moeda), cada um em caixa de altura fixa.
		var inner := _card_inner(b)
		inner.add_child(_fixed_box(icon_rect(String(data["icon"]), ICON_SIZE), ICON_SIZE.y))
		var name_label := _text_label(tr("shop.%s.name" % id), HORIZONTAL_ALIGNMENT_CENTER,
				TextServer.AUTOWRAP_WORD_SMART, CARD_TEXT_SIZE)
		inner.add_child(_fixed_box(name_label, COIN_NAME_HEIGHT))
		var effect := _text_label(ShopManager.coin_effect(id), HORIZONTAL_ALIGNMENT_CENTER,
				TextServer.AUTOWRAP_WORD_SMART, CARD_TEXT_SIZE)
		effect.add_theme_color_override("font_color", Color(0.75, 0.95, 0.75))
		inner.add_child(_fixed_box(effect, COIN_EFFECT_HEIGHT))
		var price_row := HBoxContainer.new()
		price_row.alignment = BoxContainer.ALIGNMENT_CENTER
		price_row.add_theme_constant_override("separation", 3)
		price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var coin := icon_rect(COIN_ICON, COIN_ICON_SIZE)
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_row.add_child(coin)
		var price := label("", CARD_TEXT_SIZE, HORIZONTAL_ALIGNMENT_CENTER)
		price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_row.add_child(price)
		inner.add_child(_fixed_box(price_row, PRICE_HEIGHT))
		_coin_cards[id] = {"button": b, "inner": inner, "price": price, "coin": coin}
	_update_cards()
	var owned := PurchaseManager.owns()
	_buy.text = tr("shop.owned") if owned else tr("shop.remove_ad") % PurchaseManager.price_text()
	_buy.disabled = owned


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 1.0
		_update_cards()


func _update_cards() -> void:
	for id: StringName in _cards:
		var card: Dictionary = _cards[id]
		var b: Button = card["button"]
		var card_name := tr("shop.%s.name" % id)
		if id == &"slot_ryo":
			card_name = tr("shop.slot_ryo.name_value") % ShopManager.ryo_value()
		(card["name"] as Label).text = card_name
		if ShopManager.is_ready(id):
			b.disabled = not AdsManager.rewarded_available()
			(card["state"] as Label).text = tr("shop.no_ads") if b.disabled else "> %s" % tr("shop.watch")
		else:
			var left := ShopManager.seconds_left(id)
			b.disabled = true
			(card["state"] as Label).text = "%02d:%02d:%02d" % [
					floori(left / 3600.0), floori(fmod(left, 3600) / 60.0), left % 60]
	_update_coin_cards()


## Saldo e estado dos reforços: apagado sem ryō suficiente ou quando já está guardado.
func _update_coin_cards() -> void:
	_ryo.text = "%s %s" % [tr("hud.ryo"), Locale.format_number(SaveManager.ryo())]
	for id: StringName in _coin_cards:
		var card: Dictionary = _coin_cards[id]
		var b: Button = card["button"]
		var queued := ShopManager.is_queued(id)
		b.disabled = not ShopManager.can_buy_coin(id)
		(card["inner"] as Control).modulate = Color(1, 1, 1, 0.45) if b.disabled and not queued else Color.WHITE
		var price: Label = card["price"]
		(card["coin"] as Control).visible = not queued
		if queued:
			price.text = tr("shop.coin.queued")
			price.add_theme_color_override("font_color", ThemeFactory.ACCENT)
		else:
			price.text = Locale.format_number(ShopManager.coin_price(id))
			price.remove_theme_color_override("font_color")


func _claim(id: StringName) -> void:
	if _was_drag():
		return
	ShopManager.claim(id, func(ok: bool) -> void:
		_status.text = tr("shop.received") % tr("shop.%s.name" % id) if ok else tr("shop.watch_full")
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
		_status.text = tr("shop.received") % tr("shop.%s.name" % id)
	else:
		AudioManager.play_ui("ui_cancel")
		_status.text = tr("sanctuary.not_enough")
	_update_coin_cards()
	return ok


func _on_buy() -> void:
	PurchaseManager.purchase()


## O conteúdo rolou desde que o dedo apertou o cartão: foi arrasto, não toque.
func _was_drag() -> bool:
	var moved := _press_scroll >= 0 and absi(_scroll.scroll_vertical - _press_scroll) > TAP_SLOP
	_press_scroll = -1
	return moved


func _card_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	return row


## Cartão-botão: PASS deixa o arrasto chegar ao ScrollContainer (rolar com o dedo).
func _card_button(size: Vector2, on_press: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.add_theme_stylebox_override("normal", ThemeFactory.card_box())
	b.add_theme_stylebox_override("hover", ThemeFactory.card_box_hover())
	b.add_theme_stylebox_override("disabled", ThemeFactory.dark_box())
	b.button_down.connect(func() -> void: _press_scroll = _scroll.scroll_vertical)
	b.pressed.connect(on_press)
	return b


func _card_inner(b: Button) -> VBoxContainer:
	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 2
	inner.offset_right = -2
	inner.offset_top = 2
	inner.offset_bottom = -2
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 2)
	b.add_child(inner)
	return inner


## Texto que quebra em linhas dentro da caixa; nunca alarga o layout.
func _text_label(text: String, align: HorizontalAlignment,
		wrap: TextServer.AutowrapMode = TextServer.AUTOWRAP_OFF, size: int = 12) -> Label:
	var l := label(text, size, align)
	l.clip_text = true
	l.autowrap_mode = wrap
	if wrap == TextServer.AUTOWRAP_OFF:
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Botão sem corte: a largura mínima segue o texto, então o preço nunca fica cortado
## (o teste confere que o botão cabe no texto inteiro).
func _fit_button(b: Button) -> void:
	b.clip_text = false


## Caixa de altura fixa: o conteúdo que não couber é cortado e não empurra os vizinhos.
func _fixed_box(node: Control, height: float) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(0, height)
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(node)
	return box
