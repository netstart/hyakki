extends RefCounted
## Loja (scripts/app/screens/shop_screen.gd): layout em cada idioma e rolagem.
## Chamado por tests/integration_tests.gd, que passa o nó da cena e o _check.
##
## Layout em cada resolução de tests/device_profiles.gd, sem e com o furo da câmera de cada
## lado; a Loja já aberta refeita ao mudar de tamanho e de recorte; a rolagem na resolução de
## referência. Cartões em grade uniforme de 6 ou 3 colunas (linha única de 6 em 678x305).
##
## O que vale para a tela: fixos só o voltar, o título e o saldo (dentro da área segura com 8 px
## de folga embaixo e fora da área rolável); a área rolável vai até a borda inferior; os
## cartões, os cabeçalhos e, por último, "Apoiar o jogo" e "Restaurar compras" ficam
## dentro do conteúdo rolável; textos inteiros nas caixas; ícones do mesmo tamanho de poço e
## sempre dentro do cartão; hover escuro e legível (nada do painel quase branco); o status
## é um aviso flutuante que aparece e some.
##
## Ampulheta de Fūjin (velocidade 2x/3x): seção própria entre Reforços e Apoie o jogo, em cada
## resolução e idioma nos estados sem saldo, com saldo (não comprada) e liberada: ícone, textos e
## botões inteiros no cartão, sem sobreposição; preço em ryō em vermelho e apagado sem saldo;
## liberada, só o selo dourado.
##
## "Apoie o jogo" comprado (com anúncios ligados): as vagas dizem "Receber grátis", o subtítulo
## fala de presente, a compra vira o agradecimento e o layout continua íntegro.

const SHOP_SCREEN := "res://scripts/app/screens/shop_screen.gd"
const DeviceProfiles := preload("res://tests/device_profiles.gd")
## Contraste mínimo (WCAG AA) entre o texto e o fundo do cartão.
const MIN_CONTRAST := 4.5

var _host: Node
var _check: Callable
## Tela lógica do caso atual (tamanho do anfitrião) e a área segura (fora do furo da câmera).
var _view := Rect2(Vector2.ZERO, DeviceProfiles.main_view())
var _safe := Rect2(Vector2.ZERO, DeviceProfiles.main_view())


## Loja em cada idioma: ao abrir, depois de um resgate, com cada status e sem anúncio.
func run_layout(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	AdsManager.auto_answer = true
	for c: Dictionary in DeviceProfiles.layout_cases():
		use_case(c["view"], c["insets"])
		for lang: String in c["langs"]:
			await _layout_lang(host, check, lang, "%s [%s]" % [lang, c["label"]])
	await _relayout_cases()
	use_case(DeviceProfiles.main_view(), Vector2.ZERO)
	AdsManager.auto_answer = false
	Locale.set_language("pt_BR", false)


## Tela lógica e recorte da câmera (esquerda, direita) usados por _open e check_layout.
func use_case(view: Vector2, insets: Vector2) -> void:
	_view = Rect2(Vector2.ZERO, view)
	_safe = DeviceProfiles.safe_rect(view, insets)
	DeviceProfiles.simulate_insets(insets)


## Área dos fixos: a área segura com 8 px de folga embaixo.
func fixed_area() -> Rect2:
	return Rect2(_safe.position, _safe.size - Vector2(0, 8))


func _layout_lang(host: Node, check: Callable, lang_code: String, lang: String) -> void:
	var view := fixed_area()
	Locale.set_language(lang_code, false)
	SaveManager.data = SaveManager.default_profile()
	AdsManager.mock_fill = true
	var screen := await _open()
	var status := screen.get("_status") as Label
	var toast := screen.get("_toast") as Control
	check.call(toast.modulate.a == 0.0, "%s: o aviso começa escondido" % lang)
	check_layout(screen, view, "%s, ao abrir" % lang)
	_check_cards(screen, lang)
	await check_speed_states(screen, view, lang)

	# Resgate bem-sucedido (anúncio simulado até o fim): a vaga volta a ficar em cronômetro.
	screen.call("_claim", &"slot_ryo")
	var waited := 0.0
	while ShopManager.is_ready(&"slot_ryo") and waited < 10.0:
		await host.get_tree().create_timer(0.1).timeout
		waited += 0.1
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	check.call(not ShopManager.is_ready(&"slot_ryo"), "%s: o resgate põe a vaga em cronômetro" % lang)
	check.call(status.text == tr("shop.received") % tr("shop.slot_ryo.name"),
			"%s: o status mostra o recebido" % lang)
	check.call(toast.modulate.a > 0.9, "%s: o aviso aparece com o recebido" % lang)
	check_layout(screen, view, "%s, depois do resgate" % lang)

	# Status (o texto mais longo de cada caso), escrito direto no Label: o aviso acompanha.
	var long_reward := tr("shop.received") % tr("shop.slot_lantern.name")
	for text: String in [tr("shop.failed"), tr("shop.pending"), tr("shop.watch_full"), long_reward]:
		status.text = text
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		check.call(toast.modulate.a > 0.9, "%s: o aviso mostra \"%s\"" % [lang, text])
		check_layout(screen, view, "%s, status \"%s\"" % [lang, text])
	# O aviso some sozinho depois do tempo dele.
	screen.call("_update_toast", 3.0)
	check.call(toast.modulate.a == 0.0, "%s: o aviso some depois de ~2,5 s" % lang)

	# Sem anúncio disponível: as vagas prontas ficam desativadas com o aviso.
	SaveManager.data = SaveManager.default_profile()
	AdsManager.mock_fill = false
	screen.call("on_show")
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	check_layout(screen, view, "%s, sem anúncio" % lang)
	AdsManager.mock_fill = true

	# "Apoie o jogo" comprado: recompensas de presente, compra vira o agradecimento.
	SaveManager.data["purchases"]["remove_open_ad"] = true
	screen.call("on_show")
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	check_layout(screen, view, "%s, Apoie o jogo comprado" % lang)
	var gifts := true
	var cards: Dictionary = screen.get("_cards")
	for id: StringName in cards:
		var state_text := (cards[id]["state"] as Label).text
		gifts = gifts and not (cards[id]["button"] as Button).disabled and state_text == "> %s" % tr("shop.claim_free")
	check.call(gifts, "%s: com Apoie o jogo as vagas dizem \"%s\"" % [lang, tr("shop.claim_free")])
	check.call((screen.get("_offer_hint") as Label).text == tr("shop.hint_free"),
			"%s: com Apoie o jogo o subtítulo das Oferendas fala de presente" % lang)
	var buy := screen.get("_buy") as Button
	check.call(buy.is_visible_in_tree() and buy.disabled and buy.text == tr("shop.owned"),
			"%s: com Apoie o jogo a compra mostra \"%s\"" % [lang, tr("shop.owned")])
	SaveManager.data = SaveManager.default_profile()
	screen.call("on_show")
	await host.get_tree().process_frame
	check.call((screen.get("_buy") as Button).text == tr("shop.support") % PurchaseManager.price_text(),
			"%s: sem a compra o botão é \"Apoiar o jogo\" com o preço" % lang)
	screen.get_parent().queue_free()
	await host.get_tree().process_frame


## Loja já aberta: a tela muda de tamanho (resized) e o recorte troca de lado (giro de 180°,
## avisado por PixelScaler.safe_insets_changed) e o layout se refaz sozinho, íntegro em cada caso.
func _relayout_cases() -> void:
	Locale.set_language("pt_BR", false)
	SaveManager.data = SaveManager.default_profile()
	AdsManager.mock_fill = true
	use_case(DeviceProfiles.main_view(), Vector2.ZERO)
	var screen := await _open()
	var host := screen.get_parent() as Control
	for c: Dictionary in DeviceProfiles.layout_cases():
		if c["view"] == DeviceProfiles.main_view() and c["insets"] == Vector2.ZERO:
			continue
		use_case(c["view"], c["insets"])
		host.size = c["view"]
		await _host.get_tree().process_frame
		await _host.get_tree().process_frame
		var tag := "pt_BR, refeita para %s" % c["label"]
		check_layout(screen, fixed_area(), tag)
		_check_cards(screen, tag)
		check_speed_card(screen, tag)
	screen.get_parent().queue_free()
	await _host.get_tree().process_frame


## Rolagem: o conteúdo rola só na vertical, o arrasto chega ao ScrollContainer, os botões de
## compra ficam no fim (fora da vista até rolar), a compra pela tela atualiza o saldo, o
## cartão e o status; um toque que virou arrasto não compra.
func run_scroll(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	Locale.set_language("pt_BR", false)
	SaveManager.data = SaveManager.default_profile()
	AdsManager.mock_fill = true
	use_case(DeviceProfiles.main_view(), Vector2.ZERO)
	var view := fixed_area()
	var screen := await _open()
	var scroll := screen.get("_scroll") as ScrollContainer
	var content := scroll.get_child(0) as Control
	check.call(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
			and scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "Loja: rola só na vertical")
	check.call(is_equal_approx(scroll.get_global_rect().end.y, _view.end.y),
			"Loja: a área rolável vai até a borda inferior (%s)" % scroll.get_global_rect())
	check.call(content.size.y > scroll.size.y, "Loja: conteúdo (%.0f) mais alto que a área (%.0f) rola" % [
			content.size.y, scroll.size.y])
	check.call(scroll.get_v_scroll_bar().visible and scroll.get_v_scroll_bar().max_value > scroll.size.y,
			"Loja: a barra de rolagem aparece")
	check.call(scroll.scroll_deadzone > 0, "Loja: zona morta evita rolar com um toque")
	var cards: Dictionary = screen.get("_coin_cards")
	check.call(cards.size() == 6, "Loja: 6 cartões de reforço")
	for id: StringName in cards:
		var b := cards[id]["button"] as Button
		check.call(b.mouse_filter == Control.MOUSE_FILTER_PASS, "Loja: cartão %s deixa o arrasto passar" % id)
		check.call(b.disabled, "Loja: sem ryō o cartão %s fica apagado" % id)
		check.call((cards[id]["price"] as Label).get_theme_color("font_color") != ThemeFactory.ACCENT,
				"Loja: sem ryō o preço de %s muda de cor" % id)
	var ad_cards: Dictionary = screen.get("_cards")
	for id: StringName in ad_cards:
		check.call((ad_cards[id]["button"] as Button).mouse_filter == Control.MOUSE_FILTER_PASS,
				"Loja: vaga %s deixa o arrasto passar" % id)
	# Compra e restauração: dentro do conteúdo rolável, depois de todos os cartões.
	var buy := screen.get("_buy") as Button
	var restore := screen.get("_restore") as Button
	var last_card_end := 0.0
	for row: Dictionary in [cards, ad_cards]:
		for id: StringName in row:
			last_card_end = maxf(last_card_end, (row[id]["button"] as Control).get_global_rect().end.y)
	for b: Button in [buy, restore]:
		check.call(content.is_ancestor_of(b), "Loja: \"%s\" fica no conteúdo rolável" % b.text)
		check.call(b.get_global_rect().position.y >= last_card_end,
				"Loja: \"%s\" vem depois de todos os cartões" % b.text)
		check.call(not scroll.get_global_rect().intersects(b.get_global_rect()),
				"Loja: \"%s\" só aparece rolando até o fim" % b.text)
		check.call(b.mouse_filter == Control.MOUSE_FILTER_PASS, "Loja: \"%s\" deixa o arrasto passar" % b.text)
	scroll.scroll_vertical = int(content.size.y)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	check.call(scroll.scroll_vertical > 0, "Loja: rola até o fim")
	var last := cards[&"coin_chest"]["button"] as Button
	# A Ampulheta de Fūjin fica entre os Reforços e a compra: no fim aparecem a compra e a restauração.
	for c: Control in [buy, restore]:
		check.call(scroll.get_global_rect().grow(0.5).encloses(c.get_global_rect()),
				"Loja: rolando até o fim, %s aparece inteiro" % c.name)
	# Ampulheta de Fūjin: entre os Reforços e "Apoie o jogo".
	var speed_card := screen.get("_speed_card") as Control
	check.call(content.is_ancestor_of(speed_card)
			and speed_card.get_global_rect().position.y >= last.get_global_rect().end.y
			and speed_card.get_global_rect().end.y <= buy.get_global_rect().position.y,
			"Loja: a Ampulheta fica entre os Reforços e \"Apoie o jogo\"")
	check_layout(screen, view, "pt_BR, rolada até o fim")
	var status := screen.get("_status") as Label
	check.call(not bool(screen.call("_buy_coin", &"coin_bag")) and status.text == tr("sanctuary.not_enough"),
			"Loja: sem ryō a compra pela tela falha e avisa")
	SaveManager.data["ryo"] = 1000
	screen.call("_update_coin_cards")
	var bag := cards[&"coin_bag"]["button"] as Button
	check.call(not bag.disabled, "Loja: com ryō o cartão acende")
	check.call(bool(screen.call("_buy_coin", &"coin_bag")), "Loja: compra pela tela")
	var left := 1000 - ShopManager.coin_price(&"coin_bag")
	check.call(SaveManager.ryo() == left and (screen.get("_ryo") as Label).text.contains(Locale.format_number(left)),
			"Loja: o saldo mostrado cai para %d" % left)
	check.call(bag.disabled and (cards[&"coin_bag"]["price"] as Label).text == tr("shop.coin.queued"),
			"Loja: o cartão comprado fica com o selo de guardado")
	var queued_box := bag.get_theme_stylebox("disabled") as StyleBoxFlat
	check.call(queued_box != null and queued_box.border_color == ThemeFactory.ACCENT,
			"Loja: o cartão guardado ganha borda dourada")
	check.call(status.text == tr("shop.received") % tr("shop.coin_bag.name"), "Loja: o status mostra a compra")
	check.call((screen.get("_toast") as Control).modulate.a > 0.9, "Loja: o aviso aparece com a compra")
	# Toque que virou arrasto: apertou com a rolagem no topo e soltou com o conteúdo rolado.
	screen.set("_press_scroll", 0)
	check.call(not bool(screen.call("_buy_coin", &"coin_scroll")) and SaveManager.ryo() == left,
			"Loja: arrastar sobre o cartão não compra")
	await host.get_tree().process_frame
	check_layout(screen, view, "pt_BR, depois da compra")
	await _speed_purchase(screen, status)
	screen.get_parent().queue_free()
	await host.get_tree().process_frame
	SaveManager.data = SaveManager.default_profile()


## Compra da Ampulheta pela tela: sem saldo avisa e não debita; com 3.000 ryō debita, vira o
## selo "Liberado" e agradece; não compra duas vezes.
func _speed_purchase(screen: Control, status: Label) -> void:
	var price := PurchaseManager.SPEED_RYO_PRICE
	SaveManager.data["ryo"] = price - 1
	screen.call("_update_coin_cards")
	_check.call(not bool(screen.call("_buy_speed_ryo")) and SaveManager.ryo() == price - 1
			and status.text == tr("sanctuary.not_enough") and not PurchaseManager.owns_speed(),
			"Loja: sem ryō a Ampulheta não é comprada e avisa")
	SaveManager.data["ryo"] = price + 50
	screen.call("_update_coin_cards")
	_check.call(bool(screen.call("_buy_speed_ryo")) and SaveManager.ryo() == 50 and PurchaseManager.owns_speed(),
			"Loja: com %d ryō a Ampulheta é comprada e debitada" % price)
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	_check.call((screen.get("_speed_seal") as Control).is_visible_in_tree()
			and not (screen.get("_speed_ryo") as Control).is_visible_in_tree()
			and not (screen.get("_speed_money") as Control).is_visible_in_tree(),
			"Loja: comprada, os dois botões viram o selo \"Liberado\"")
	_check.call(status.text == tr("shop.speed.thanks"), "Loja: o aviso agradece a Ampulheta")
	_check.call(not bool(screen.call("_buy_speed_ryo")) and SaveManager.ryo() == 50,
			"Loja: a Ampulheta não é comprada duas vezes")
	check_layout(screen, fixed_area(), "pt_BR, Ampulheta comprada pela tela")
	SaveManager.data = SaveManager.default_profile()


## Os três estados da Ampulheta (sem saldo, com saldo e liberada) com o layout inteiro.
func check_speed_states(screen: Control, view: Rect2, lang: String) -> void:
	SaveManager.data["ryo"] = 0
	screen.call("on_show")
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	check_speed_card(screen, "%s, Ampulheta sem saldo" % lang)
	var ryo_button := screen.get("_speed_ryo") as Button
	_check.call(ryo_button.get_theme_color("font_color") != ThemeFactory.ACCENT and ryo_button.modulate.a < 1.0,
			"%s: sem saldo o preço da Ampulheta fica em vermelho e apagado" % lang)
	SaveManager.data["ryo"] = PurchaseManager.SPEED_RYO_PRICE
	screen.call("on_show")
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	check_layout(screen, view, "%s, Ampulheta com saldo" % lang)
	check_speed_card(screen, "%s, Ampulheta com saldo" % lang)
	_check.call(ryo_button.get_theme_color("font_color") == ThemeFactory.ACCENT and ryo_button.modulate.a == 1.0,
			"%s: com saldo o preço da Ampulheta fica dourado" % lang)
	SaveManager.data["purchases"]["unlock_speed"] = true
	SaveManager.data["purchases"]["unlock_speed_source"] = "ryo"
	screen.call("on_show")
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	check_layout(screen, view, "%s, Ampulheta liberada" % lang)
	check_speed_card(screen, "%s, Ampulheta liberada" % lang)
	SaveManager.data = SaveManager.default_profile()
	screen.call("on_show")
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame


## Cartão da Ampulheta: ícone, textos e compras (ou o selo) inteiros dentro do cartão, sem se
## sobrepor; o preço em dinheiro aparece (simulado no PC) só sem a posse.
func check_speed_card(screen: Control, state: String) -> void:
	var card := screen.get("_speed_card") as Control
	var owned := PurchaseManager.owns_speed()
	var ryo_button := screen.get("_speed_ryo") as Button
	var money := screen.get("_speed_money") as Button
	var seal := screen.get("_speed_seal") as Control
	_check.call(card.is_visible_in_tree(), "%s: o cartão da Ampulheta aparece" % state)
	_check.call(ryo_button.is_visible_in_tree() != owned and seal.is_visible_in_tree() == owned
			and money.is_visible_in_tree() == (not owned and PurchaseManager.billing_available()),
			"%s: botões da Ampulheta conforme a posse (liberada: %s)" % [state, owned])
	if not owned:
		_check.call(money.text == PurchaseManager.speed_price_text(), "%s: preço da loja \"%s\"" % [state, money.text])
		_check.call(ryo_button.text == Locale.format_number(PurchaseManager.SPEED_RYO_PRICE) and ryo_button.icon != null,
				"%s: preço em ryō com a moeda" % state)
	var rect := card.get_global_rect()
	var parts: Array[Control] = [card.find_child("SpeedWell", true, false) as Control,
			screen.get("_speed_texts") as Control]
	for c: Control in [ryo_button, money, seal]:
		if c.is_visible_in_tree():
			parts.append(c)
	for i: int in parts.size():
		var r := parts[i].get_global_rect()
		_check.call(rect.grow(0.5).encloses(r), "%s: %s dentro do cartão da Ampulheta (%s em %s)" % [state,
				parts[i].name, r, rect])
		for j: int in range(i + 1, parts.size()):
			_check.call(not r.grow(-0.5).intersects(parts[j].get_global_rect().grow(-0.5)),
					"%s: %s e %s não se sobrepõem" % [state, parts[i].name, parts[j].name])


## Confere que cada botão e texto da Loja está visível: os fixos do topo dentro de `view` e
## fora da área rolável; o aviso dentro de `view` (ele flutua sobre a área rolável); os do
## conteúdo alcançáveis rolando (dentro da largura visível e da altura do conteúdo, sem
## estouro horizontal nem cobrir a barra).
func check_layout(screen: Control, view: Rect2, state: String) -> void:
	var controls: Array[Control] = []
	_controls_in(screen, controls)
	_check.call(controls.size() >= 24, "%s: a Loja mostra os controles (%d)" % [state, controls.size()])
	var scroll := screen.get("_scroll") as ScrollContainer
	var toast := screen.get("_toast") as Control
	if scroll == null or toast == null:
		_check.call(false, "%s: a Loja tem a área rolável e o aviso" % state)
		return
	var scroll_rect := scroll.get_global_rect()
	var content := scroll.get_child(0) as Control
	var content_rect := content.get_global_rect()
	_check.call(_safe.encloses(scroll_rect), "%s: a área rolável fica dentro da tela (%s em %s)" % [state, scroll_rect,
			_safe])
	_check.call(content.get_combined_minimum_size().x <= content.size.x + 0.5
			and content_rect.end.x <= scroll_rect.end.x + 0.5,
			"%s: o conteúdo rolável não estoura na horizontal (%s em %s)" % [state,
			content.get_combined_minimum_size(), scroll.size])
	var bar := scroll.get_v_scroll_bar()
	if bar.visible:
		_check.call(content_rect.end.x <= bar.get_global_rect().position.x + 0.5,
				"%s: a barra de rolagem não cobre os cartões" % state)
	for control: Control in controls:
		var rect := control.get_global_rect()
		var path := "%s (%s, %s)" % [control.get_class(), rect, control.get_path()]
		if scroll.is_ancestor_of(control):
			var local := Rect2(rect.position - content_rect.position, rect.size)
			_check.call(control.is_visible_in_tree() and local.position.x >= -0.5 and local.position.y >= -0.5
					and local.end.x <= content.size.x + 0.5 and local.end.y <= content.size.y + 0.5
					and rect.size.y <= scroll_rect.size.y + 0.5,
					"%s: %s alcançável rolando" % [state, path])
		elif toast.is_ancestor_of(control):
			_check.call(control.is_visible_in_tree() and view.encloses(rect),
					"%s: %s (aviso) dentro da tela com folga" % [state, path])
		else:
			_check.call(control.is_visible_in_tree() and view.encloses(rect),
					"%s: %s dentro da tela com folga" % [state, path])
			_check.call(not rect.intersects(scroll_rect), "%s: %s fixo fora da área rolável" % [state, path])
		# Nada sai da caixa que o corta (ex.: o preço dentro do cartão).
		var clip := _clip_parent(control, scroll)
		if clip != null and control.is_visible_in_tree():
			_check.call(clip.get_global_rect().grow(0.5).encloses(rect),
					"%s: %s cabe na caixa %s" % [state, path, clip.get_global_rect()])
		# Texto inteiro (sem corte): o motor calcula a altura necessária com a quebra de linha
		# da largura real; ela tem de caber na caixa (Label) ou no botão.
		if control is Label and (control as Label).text != "":
			var label_node := control as Label
			var font := label_node.get_theme_font("font")
			var font_size := label_node.get_theme_font_size("font_size")
			var needed := label_node.get_line_count() * font.get_height(font_size)
			_check.call(needed <= label_node.size.y + 0.5,
					"%s: o texto \"%s\" cabe na caixa (%.0f de %.0f px)" % [state, label_node.text,
					needed, label_node.size.y])
			if label_node.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var width := font.get_string_size(label_node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				_check.call(width <= label_node.size.x + 0.5,
						"%s: o texto \"%s\" cabe na largura (%.0f de %.0f px)" % [state, label_node.text,
						width, label_node.size.x])
		if control is Button and (control as Button).text != "":
			var button_node := control as Button
			var minimum := button_node.get_combined_minimum_size()
			_check.call(minimum.x <= button_node.size.x + 0.5 and minimum.y <= button_node.size.y + 0.5,
					"%s: o botão \"%s\" mostra o texto inteiro (%s de %s)" % [state, button_node.text,
					minimum, button_node.size])


## Cartões: grade uniforme por linha, ícone no poço (mesmo tamanho para todos, dentro do
## cartão e do poço) e hover/foco escuros com texto legível.
func _check_cards(screen: Control, lang: String) -> void:
	var well_size := Vector2.ZERO
	for key: String in ["_cards", "_coin_cards"]:
		var cards: Dictionary = screen.get(key)
		_check.call(cards.size() == 6, "%s: 6 cartões em %s" % [lang, key])
		_check_grid(cards, "%s, %s" % [lang, key])
		for id: StringName in cards:
			var b := cards[id]["button"] as Button
			var rect := b.get_global_rect()
			var icons: Array[Control] = []
			_icons_in(b, icons)
			_check.call(icons.size() == 1, "%s: cartão %s mostra um ícone" % [lang, id])
			for icon: Control in icons:
				var well := icon.get_parent() as Control
				_check.call(well.clip_contents, "%s: o poço do ícone de %s corta o que sobra" % [lang, id])
				_check.call(rect.encloses(well.get_global_rect()) and well.get_global_rect().encloses(icon.get_global_rect()),
						"%s: ícone de %s dentro do poço e do cartão (%s em %s)" % [lang, id,
						icon.get_global_rect(), rect])
				if well_size == Vector2.ZERO:
					well_size = well.size
				_check.call(well.size.is_equal_approx(well_size), "%s: poço de %s do mesmo tamanho" % [lang, id])
			for style_name: String in ["hover", "pressed", "focus"]:
				var style := b.get_theme_stylebox(style_name)
				_check.call(style is StyleBoxFlat, "%s: %s do cartão %s é o cartão escuro, sem o painel claro" % [
						lang, style_name, id])
			var hover := b.get_theme_stylebox("hover") as StyleBoxFlat
			if hover != null:
				_check.call(_contrast(hover.bg_color, ThemeFactory.TEXT) >= MIN_CONTRAST,
						"%s: texto legível no hover de %s (%.1f:1)" % [lang, id,
						_contrast(hover.bg_color, ThemeFactory.TEXT)])
				_check.call(hover.border_color == ThemeFactory.ACCENT, "%s: hover de %s com borda dourada" % [lang, id])


## Grade uniforme (generaliza a antiga "linha única de 6 cartões", que só cabia em 678x305):
## todos do mesmo tamanho, em ordem de leitura, linhas completas de 6 ou 3 colunas, cada
## coluna na mesma x em todas as linhas, mesmo passo entre colunas e entre linhas, sem
## sobreposição. Na tela de referência sem recorte continua exigida a linha única de 6.
func _check_grid(cards: Dictionary, tag: String) -> void:
	var rects: Array[Rect2] = []
	for id: StringName in cards:
		rects.append((cards[id]["button"] as Control).get_global_rect())
	if rects.is_empty():
		return
	var first := rects[0]
	var cols := 0
	for rect: Rect2 in rects:
		if is_equal_approx(rect.position.y, first.position.y):
			cols += 1
	_check.call(cols in [6, 3] and rects.size() % cols == 0,
			"%s: cartões em linhas completas de 6 ou 3 colunas (%d por linha)" % [tag, cols])
	if _view.size == DeviceProfiles.main_view() and _safe.size == _view.size:
		_check.call(cols == 6, "%s: na tela de referência os 6 cartões ficam numa linha só" % tag)
	if cols <= 0:
		return
	var step_x := rects[1].position.x - first.position.x if cols > 1 else 0.0
	var step_y := rects[cols].position.y - first.position.y if rects.size() > cols else 0.0
	_check.call(cols == 1 or step_x >= first.size.x, "%s: colunas sem sobreposição (passo %.1f)" % [tag, step_x])
	_check.call(rects.size() == cols or step_y >= first.size.y,
			"%s: linhas sem sobreposição (passo %.1f)" % [tag, step_y])
	for i: int in rects.size():
		var expected := first.position + Vector2((i % cols) * step_x, floori(i / float(cols)) * step_y)
		_check.call(rects[i].size.is_equal_approx(first.size) and rects[i].position.is_equal_approx(expected),
				"%s: cartão %d do mesmo tamanho e no lugar da grade (%s, esperado em %s)" % [tag, i,
				rects[i], expected])


func _open() -> Control:
	# Host com o tamanho do viewport do jogo: a tela sozinha na árvore de testes não tem esse tamanho.
	var host := Control.new()
	host.size = _view.size
	_host.add_child(host)
	var screen := (load(SHOP_SCREEN) as GDScript).new() as Control
	host.add_child(screen)
	screen.on_show()
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	return screen


## Ancestral mais próximo que corta o conteúdo (até a área rolável, que é conferida à parte).
func _clip_parent(control: Control, stop: Control) -> Control:
	var node := control.get_parent()
	while node != null and node != stop:
		if node is Control and (node as Control).clip_contents:
			return node as Control
		node = node.get_parent()
	return null


## Coleta botões e textos de uma árvore de controles.
func _controls_in(node: Node, out: Array[Control]) -> void:
	for child: Node in node.get_children():
		# Seção escondida (ex.: "Apoie o jogo" sem anúncios) não conta como controle da tela.
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		if (child is BaseButton or child is Label) and not out.has(child):
			out.append(child as Control)
		_controls_in(child, out)


## Ícones dos cartões: TextureRect com textura que não seja a moeda do preço.
func _icons_in(node: Node, out: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is TextureRect and child.name == "Icon" and (child as TextureRect).texture != null:
			out.append(child as Control)
		_icons_in(child, out)


## Razão de contraste (WCAG) entre duas cores.
func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luminance(c: Color) -> float:
	var channels: Array[float] = []
	for v: float in [c.r, c.g, c.b]:
		channels.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
