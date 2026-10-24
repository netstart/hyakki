extends RefCounted
## Loja (scripts/app/screens/shop_screen.gd): layout em cada idioma e rolagem.
## Chamado por tests/integration_tests.gd, que passa o nó da cena e o _check.
##
## O que vale para a tela: fixos só o voltar, o título e o saldo (dentro de 678x305 com 8 px
## de folga embaixo e fora da área rolável); a área rolável vai até a borda inferior; os
## cartões, os cabeçalhos e, por último, "Remover anúncio" e "Restaurar compras" ficam
## dentro do conteúdo rolável; textos inteiros nas caixas; ícones do mesmo tamanho de poço e
## sempre dentro do cartão; hover escuro e legível (nada do painel quase branco); o status
## é um aviso flutuante que aparece e some.

const SHOP_SCREEN := "res://scripts/app/screens/shop_screen.gd"
const SCREEN := Rect2(Vector2.ZERO, Vector2(678, 305))
## Contraste mínimo (WCAG AA) entre o texto e o fundo do cartão.
const MIN_CONTRAST := 4.5

var _host: Node
var _check: Callable


## Loja em cada idioma: ao abrir, depois de um resgate, com cada status e sem anúncio.
func run_layout(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var view := Rect2(Vector2.ZERO, Vector2(678, 305 - 8))
	AdsManager.auto_answer = true
	for lang: String in Locale.SUPPORTED:
		Locale.set_language(lang, false)
		SaveManager.data = SaveManager.default_profile()
		AdsManager.mock_fill = true
		var screen := await _open()
		var status := screen.get("_status") as Label
		var toast := screen.get("_toast") as Control
		check.call(toast.modulate.a == 0.0, "%s: o aviso começa escondido" % lang)
		check_layout(screen, view, "%s, ao abrir" % lang)
		_check_cards(screen, lang)

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
		screen.get_parent().queue_free()
		await host.get_tree().process_frame
	AdsManager.auto_answer = false
	Locale.set_language("pt_BR", false)


## Rolagem: o conteúdo rola só na vertical, o arrasto chega ao ScrollContainer, os botões de
## compra ficam no fim (fora da vista até rolar), a compra pela tela atualiza o saldo, o
## cartão e o status; um toque que virou arrasto não compra.
func run_scroll(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	Locale.set_language("pt_BR", false)
	SaveManager.data = SaveManager.default_profile()
	AdsManager.mock_fill = true
	var view := Rect2(Vector2.ZERO, Vector2(678, 305 - 8))
	var screen := await _open()
	var scroll := screen.get("_scroll") as ScrollContainer
	var content := scroll.get_child(0) as Control
	check.call(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
			and scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "Loja: rola só na vertical")
	check.call(is_equal_approx(scroll.get_global_rect().end.y, SCREEN.end.y),
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
	for c: Control in [last, buy, restore]:
		check.call(scroll.get_global_rect().grow(0.5).encloses(c.get_global_rect()),
				"Loja: rolando até o fim, %s aparece inteiro" % c.name)
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
	screen.get_parent().queue_free()
	await host.get_tree().process_frame
	SaveManager.data = SaveManager.default_profile()


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
	_check.call(SCREEN.encloses(scroll_rect), "%s: a área rolável fica dentro da tela (%s)" % [state, scroll_rect])
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
		var card_size := Vector2.ZERO
		var top := -1.0
		for id: StringName in cards:
			var b := cards[id]["button"] as Button
			var rect := b.get_global_rect()
			if card_size == Vector2.ZERO:
				card_size = rect.size
				top = rect.position.y
			_check.call(rect.size.is_equal_approx(card_size) and is_equal_approx(rect.position.y, top),
					"%s: cartão %s do mesmo tamanho e na mesma linha (%s)" % [lang, id, rect])
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


func _open() -> Control:
	# Host com o tamanho do viewport do jogo: a tela sozinha na árvore de testes não tem esse tamanho.
	var host := Control.new()
	host.size = SCREEN.size
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
