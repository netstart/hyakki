extends Screen
## Loja de recompensas (plano 17.3): 6 vagas, cada uma libera uma recompensa ao assistir
## um anúncio até o fim e volta em 6 h. Também oferece a compra "Remover anúncio de
## abertura" e "Restaurar compras" (17.7).
##
## Layout com alturas fixas (viewport 678x305): cada texto fica numa caixa de altura fixa
## que cabe o número de linhas que o idioma mais longo precisa (quebra de linha, sem
## reticências). A linha de botões fica ancorada na borda inferior, com folga de 10 px.

const CARD_SIZE := Vector2(102, 124)
const ICON_SIZE := Vector2(20, 20)
const CARD_TEXT_SIZE := 10
const CARD_NAME_HEIGHT := 57.0   # até 3 linhas de fonte 10
const CARD_STATE_HEIGHT := 38.0  # até 2 linhas de fonte 10
const HINT_HEIGHT := 46.0       # até 2 linhas
const STATUS_HEIGHT := 24.0     # 1 linha
const BOTTOM_MARGIN := 10.0
const BOTTOM_ROW_HEIGHT := 30.0  # 1 linha nos botões

var _row: HBoxContainer
var _hint: Label
var _status: Label
var _buy: Button
var _restore: Button
## id -> {"button": Button, "name": Label, "state": Label}
var _cards: Dictionary = {}
var _refresh_timer: float = 0.0


func _ready() -> void:
	add_child(back_button())
	var title := title_label(tr("shop.title"))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -150
	title.offset_right = 150
	title.offset_top = 6
	title.clip_text = true
	add_child(title)
	# Área do meio (do título até acima da linha de botões).
	var margin := content_box(44.0)
	margin.add_theme_constant_override("margin_bottom", int(BOTTOM_MARGIN + BOTTOM_ROW_HEIGHT + 8))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 6)
	col.add_child(_row)
	_hint = _text_label(tr("shop.hint"), HORIZONTAL_ALIGNMENT_CENTER, TextServer.AUTOWRAP_WORD_SMART)
	col.add_child(_fixed_box(_hint, HINT_HEIGHT))
	_status = _text_label("", HORIZONTAL_ALIGNMENT_CENTER, TextServer.AUTOWRAP_WORD_SMART)
	_status.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	col.add_child(_fixed_box(_status, STATUS_HEIGHT))
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
	_cards.clear()
	for id: StringName in DB.ids("shop"):
		var data: Dictionary = DB.shop[id]
		var b := Button.new()
		b.custom_minimum_size = CARD_SIZE
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_stylebox_override("normal", ThemeFactory.card_box())
		b.add_theme_stylebox_override("hover", ThemeFactory.card_box_hover())
		b.add_theme_stylebox_override("disabled", ThemeFactory.dark_box())
		b.pressed.connect(_claim.bind(id))
		_row.add_child(b)
		# Conteúdo do cartão: ícone, nome e estado, cada um em caixa de altura fixa.
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
		inner.add_child(_fixed_box(icon_rect(String(data["icon"]), ICON_SIZE), ICON_SIZE.y))
		var name_label := _text_label("", HORIZONTAL_ALIGNMENT_CENTER, TextServer.AUTOWRAP_WORD_SMART, CARD_TEXT_SIZE)
		inner.add_child(_fixed_box(name_label, CARD_NAME_HEIGHT))
		var state_label := _text_label("", HORIZONTAL_ALIGNMENT_CENTER, TextServer.AUTOWRAP_WORD_SMART, CARD_TEXT_SIZE)
		inner.add_child(_fixed_box(state_label, CARD_STATE_HEIGHT))
		_cards[id] = {"button": b, "name": name_label, "state": state_label}
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


func _claim(id: StringName) -> void:
	ShopManager.claim(id, func(ok: bool) -> void:
		_status.text = tr("shop.received") % tr("shop.%s.name" % id) if ok else tr("shop.watch_full")
		if ok:
			AudioManager.play("jingle_unlock")
		_update_cards())


func _on_buy() -> void:
	PurchaseManager.purchase()


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
