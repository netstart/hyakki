extends Screen
## Loja de recompensas (plano 17.3): 6 vagas, cada uma libera uma recompensa ao assistir
## um anúncio até o fim e volta em 6 h. Também oferece a compra "Remover anúncio de
## abertura" e "Restaurar compras" (17.7).

var _row: HBoxContainer
var _status: Label
var _buy: Button
var _cards: Dictionary = {}
var _refresh_timer: float = 0.0


func _ready() -> void:
	add_child(back_button())
	var title := title_label(tr("shop.title"))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -150
	title.offset_right = 150
	title.offset_top = 6
	add_child(title)
	var margin := content_box(48.0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 6)
	col.add_child(_row)
	col.add_child(label(tr("shop.hint"), 12, HORIZONTAL_ALIGNMENT_CENTER))
	_status = label("", 12, HORIZONTAL_ALIGNMENT_CENTER)
	_status.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	col.add_child(_status)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 8)
	_buy = button("", _on_buy, Vector2(230, 30))
	bottom.add_child(_buy)
	bottom.add_child(button(tr("shop.restore"), func() -> void:
		PurchaseManager.restore()
		_status.text = tr("shop.restored")
		on_show(), Vector2(150, 30)))
	col.add_child(bottom)
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
		b.custom_minimum_size = Vector2(96, 120)
		b.icon = load(String(data["icon"])) as Texture2D
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = false
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_stylebox_override("normal", ThemeFactory.card_box())
		b.add_theme_stylebox_override("hover", ThemeFactory.card_box_hover())
		b.add_theme_stylebox_override("disabled", ThemeFactory.dark_box())
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_claim.bind(id))
		_row.add_child(b)
		_cards[id] = b
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
		var b: Button = _cards[id]
		var name := tr("shop.%s.name" % id)
		if id == &"slot_ryo":
			name = tr("shop.slot_ryo.name_value") % ShopManager.ryo_value()
		if ShopManager.is_ready(id):
			b.text = "\n\n%s\n\n> %s" % [name, tr("shop.watch")]
			b.disabled = not AdsManager.rewarded_available()
			if b.disabled:
				b.text = "\n\n%s\n\n%s" % [name, tr("shop.no_ads")]
		else:
			var left := ShopManager.seconds_left(id)
			b.text = "\n\n%s\n\n%02d:%02d:%02d" % [name, floori(left / 3600.0), floori(fmod(left, 3600) / 60.0), left % 60]
			b.disabled = true


func _claim(id: StringName) -> void:
	ShopManager.claim(id, func(ok: bool) -> void:
		_status.text = tr("shop.received") % tr("shop.%s.name" % id) if ok else tr("shop.watch_full")
		if ok:
			AudioManager.play("jingle_unlock")
		_update_cards())


func _on_buy() -> void:
	PurchaseManager.purchase()
