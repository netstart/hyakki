extends RefCounted
## Tela do Santuário em cada resolução de tests/device_profiles.gd (sem e com o furo da
## câmera de cada lado): todos os cartões cabem sem rolagem, ícones contidos nos
## cartões, painel de detalhes do item selecionado e estados (comprável, sem ryō, máximo),
## em todos os idiomas; saldo e "voltar" fora do furo da câmera; em 678x305 sem recorte, o
## visual de referência (grade 6x3 de cartões 70x81 e painel de 196); e o layout refeito quando
## a tela muda de tamanho com a tela aberta. Chamado por tests/integration_tests.gd ou por
## tests/sanctuary_layout_runner.gd (tests/sanctuary_layout_tests.tscn), que passam o nó e o _check.

const DeviceProfiles := preload("res://tests/device_profiles.gd")

## Área segura do caso atual (tela lógica menos o furo da câmera).
var _safe := Rect2(Vector2.ZERO, DeviceProfiles.main_view())


func run(host: Node, check: Callable) -> void:
	var original := SaveManager.data
	for c: Dictionary in DeviceProfiles.layout_cases():
		_safe = DeviceProfiles.safe_rect(c["view"], c["insets"])
		DeviceProfiles.simulate_insets(c["insets"])
		for lang: String in c["langs"]:
			Locale.set_language(lang, false)
			var tag := "%s [%s]" % [lang, c["label"]]
			SaveManager.data = SaveManager.default_profile()
			SaveManager.data["ryo"] = 2500
			SaveManager.data["powerups"] = {"pu_might": 2, "pu_greed": 5, "pu_amount": 1}
			var app := App.new()
			host.add_child(app)
			await host.get_tree().process_frame
			# A raiz das telas com o tamanho da tela lógica do aparelho.
			var root := app.get("_root") as Control
			root.set_anchors_preset(Control.PRESET_TOP_LEFT)
			root.size = c["view"]
			app.go(&"sanctuary")
			await host.get_tree().process_frame
			await host.get_tree().process_frame
			var screen := (app.get("_screens") as Dictionary)[&"sanctuary"] as Control
			_check_grid(screen, check, tag)
			_check_chrome(screen, check, tag)
			if c["view"] == DeviceProfiles.main_view() and c["insets"] == Vector2.ZERO:
				_check_reference(screen, check, tag)
			for id: StringName in DB.ids("powerups"):
				screen.call("_select", id)
				await host.get_tree().process_frame
				_check_panel(screen, check, "%s, %s" % [tag, id])
			await _check_states(host, screen, check, tag)
			app.queue_free()
			await host.get_tree().process_frame
	await _check_resize(host, check)
	DeviceProfiles.clear_insets()
	SaveManager.data = original
	Locale.set_language("pt_BR", false)


## Tela aberta na de referência e depois trocada para cada resolução com o furo da câmera à
## esquerda (na de referência, só o furo muda, como ao girar o aparelho): a grade e o painel se
## refazem e continuam cabendo.
func _check_resize(host: Node, check: Callable) -> void:
	Locale.set_language("de", false)
	SaveManager.data = SaveManager.default_profile()
	SaveManager.data["ryo"] = 2500
	SaveManager.data["powerups"] = {"pu_might": 2, "pu_greed": 5, "pu_amount": 1}
	DeviceProfiles.clear_insets()
	var app := App.new()
	host.add_child(app)
	await host.get_tree().process_frame
	var root := app.get("_root") as Control
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.size = DeviceProfiles.main_view()
	app.go(&"sanctuary")
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var screen := (app.get("_screens") as Dictionary)[&"sanctuary"] as Control
	for c: Dictionary in DeviceProfiles.layout_cases():
		if c["insets"].x <= 0.0:
			continue
		DeviceProfiles.simulate_insets(c["insets"])
		_safe = DeviceProfiles.safe_rect(c["view"], c["insets"])
		root.size = c["view"]
		# A troca só do lado do furo (mesmo tamanho) chega por PixelScaler.safe_insets_changed.
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		var tag := "de [%s, redimensionada com a tela aberta]" % c["label"]
		_check_grid(screen, check, tag)
		_check_panel(screen, check, tag)
		_check_chrome(screen, check, tag)
	app.queue_free()
	await host.get_tree().process_frame


## Saldo de ryō e "voltar" inteiros na área segura, sem encostar um no outro nem no título.
func _check_chrome(screen: Control, check: Callable, tag: String) -> void:
	var pill := (screen.get("_ryo") as Control).get_parent().get_parent() as Control
	var pill_rect := pill.get_global_rect()
	check.call(_safe.encloses(pill_rect), "Santuário %s: saldo de ryō fora do furo (%s em %s)" % [tag, pill_rect, _safe])
	var back: Control = screen.find_children("*", "Button", false, false)[0]
	var back_rect := back.get_global_rect()
	check.call(_safe.encloses(back_rect), "Santuário %s: voltar fora do furo (%s em %s)" % [tag, back_rect, _safe])
	check.call(not back_rect.intersects(pill_rect), "Santuário %s: voltar e saldo não se encostam" % tag)
	var title: Label = screen.find_children("*", "Label", false, false)[0]
	var text_w := title.get_theme_font("font").get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			title.get_theme_font_size("font_size")).x
	var title_rect := title.get_global_rect()
	var text_rect := Rect2(title_rect.get_center().x - text_w / 2.0, title_rect.position.y, text_w, title_rect.size.y)
	check.call(not text_rect.intersects(back_rect) and not text_rect.intersects(pill_rect),
			"Santuário %s: título livre do voltar e do saldo" % tag)


## 678x305 sem recorte: o visual de sempre (grade 6x3 de cartões 70x81, painel de 196).
func _check_reference(screen: Control, check: Callable, tag: String) -> void:
	var grid := screen.get("_grid") as GridContainer
	check.call(grid.columns == 6, "Santuário %s: grade de referência com 6 colunas" % tag)
	var cards: Dictionary = screen.get("_cards")
	for id: StringName in cards:
		var b := cards[id]["button"] as Control
		check.call(b.size == Vector2(70, 81), "Santuário %s: cartão %s no tamanho de referência (%s)" % [tag, id, b.size])
	var panel := (screen.get("_buy_button") as Control).get_parent().get_parent() as Control
	check.call(is_equal_approx(panel.size.x, 196.0),
			"Santuário %s: painel de referência com 196 (%.0f)" % [tag, panel.size.x])


func _check_grid(screen: Control, check: Callable, lang: String) -> void:
	check.call(screen.find_children("*", "ScrollContainer", true, false).is_empty(),
			"Santuário %s: sem área de rolagem" % lang)
	var cards: Dictionary = screen.get("_cards")
	check.call(cards.size() == DB.ids("powerups").size(), "Santuário %s: um cartão por melhoria" % lang)
	var rects: Array[Rect2] = []
	for id: StringName in cards:
		var card: Dictionary = cards[id]
		var b := card["button"] as Button
		var rect := b.get_global_rect()
		check.call(b.is_visible_in_tree() and _safe.encloses(rect),
				"Santuário %s: cartão %s inteiro na tela (%s em %s)" % [lang, id, rect, _safe])
		check.call(rect.size.x >= 48 and rect.size.y >= 48, "Santuário %s: cartão %s com alvo de toque ≥ 48" % [lang, id])
		var icon := card["icon"] as TextureRect
		check.call(icon.texture != null and rect.encloses(icon.get_global_rect()),
				"Santuário %s: ícone de %s dentro do cartão" % [lang, id])
		check.call(icon.size.x >= 16 and icon.size.x <= 32 and icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
				"Santuário %s: ícone de %s legível e sem distorção (%.0f)" % [lang, id, icon.size.x])
		check.call(rect.encloses((card["price_box"] as Control).get_global_rect()),
				"Santuário %s: preço de %s dentro do cartão" % [lang, id])
		check.call(rect.encloses((card["pips"] as Control).get_global_rect()),
				"Santuário %s: nível de %s dentro do cartão" % [lang, id])
		for other: Rect2 in rects:
			check.call(not other.intersects(rect), "Santuário %s: cartão %s não encosta em outro" % [lang, id])
		rects.append(rect)
	var panel := (screen.get("_buy_button") as Control).get_parent().get_parent() as Control
	for rect: Rect2 in rects:
		check.call(not rect.intersects(panel.get_global_rect()), "Santuário %s: cartões fora do painel" % lang)


func _check_panel(screen: Control, check: Callable, state: String) -> void:
	var id: StringName = screen.get("_selected")
	var name := screen.get("_detail_name") as Label
	check.call(name.text == TranslationServer.translate("powerup.%s.name" % id),
			"Santuário %s: painel mostra o nome do selecionado" % state)
	var level := SaveManager.powerup_level(id)
	check.call((screen.get("_detail_level") as Label).text == "%d/%d" % [level, int(DB.powerups[id]["max"])],
			"Santuário %s: painel mostra o nível" % state)
	var buy := screen.get("_buy_button") as Button
	var panel := buy.get_parent().get_parent() as Control
	var panel_rect := panel.get_global_rect()
	check.call(_safe.encloses(panel_rect), "Santuário %s: painel inteiro na tela (%s em %s)" % [state, panel_rect, _safe])
	var parts: Array[Control] = [name, screen.get("_detail_effect"), screen.get("_detail_next"),
			screen.get("_info"), buy, screen.get("_refund_button"), screen.get("_detail_icon")]
	for part: Control in parts:
		check.call(panel_rect.encloses(part.get_global_rect()),
				"Santuário %s: %s dentro do painel" % [state, part.get_path().get_name(part.get_path().get_name_count() - 1)])
	var info := screen.get("_info") as Control
	check.call(info.get_global_rect().end.y <= buy.get_global_rect().position.y,
			"Santuário %s: texto não invade o botão de oferecer" % state)


func _check_states(host: Node, screen: Control, check: Callable, lang: String) -> void:
	var cards: Dictionary = screen.get("_cards")
	var max_text := TranslationServer.translate("sanctuary.max")
	# Máximo: selo MAX no cartão e botão desligado.
	check.call(screen.call("card_state", &"pu_greed") == "max", "Santuário %s: Avidez no máximo" % lang)
	check.call((cards[&"pu_greed"]["price"] as Label).text == max_text, "Santuário %s: cartão no máximo mostra MAX" % lang)
	screen.call("_select", &"pu_greed")
	var buy := screen.get("_buy_button") as Button
	check.call(buy.disabled and (screen.get("_buy_label") as Label).text == max_text,
			"Santuário %s: no máximo o botão de oferecer desliga" % lang)
	# Sem ryō: preço em vermelho, compra falha, avisa e não gasta.
	check.call(screen.call("card_state", &"pu_revive") == "short", "Santuário %s: Renascer caro demais" % lang)
	var short_price := cards[&"pu_revive"]["price"] as Label
	check.call(short_price.get_theme_color("font_color") == screen.get("SHORT"),
			"Santuário %s: preço sem ryō em vermelho" % lang)
	screen.call("_buy", &"pu_revive")
	await host.get_tree().process_frame
	check.call(SaveManager.ryo() == 2500 and SaveManager.powerup_level(&"pu_revive") == 0,
			"Santuário %s: sem ryō não compra" % lang)
	check.call((screen.get("_info") as Label).text == TranslationServer.translate("sanctuary.not_enough"),
			"Santuário %s: sem ryō avisa" % lang)
	var info := screen.get("_info") as Label
	check.call(info.get_visible_line_count() >= info.get_line_count(), "Santuário %s: aviso aparece inteiro" % lang)
	_check_panel(screen, check, "%s, aviso de ryō" % lang)
	# Comprável: o botão do painel compra o selecionado e tudo se atualiza.
	check.call(screen.call("card_state", &"pu_might") == "buy", "Santuário %s: Poder comprável" % lang)
	screen.call("_select", &"pu_might")
	var price := MetaProgress.powerup_price(&"pu_might")
	buy.pressed.emit()
	await host.get_tree().process_frame
	check.call(SaveManager.powerup_level(&"pu_might") == 3 and SaveManager.ryo() == 2500 - price,
			"Santuário %s: o botão do painel compra" % lang)
	check.call((screen.get("_ryo") as Label).text == Locale.format_number(2500 - price),
			"Santuário %s: saldo atualizado" % lang)
	check.call((screen.get("_detail_level") as Label).text == "3/5", "Santuário %s: nível atualizado no painel" % lang)
	screen.call("_refund")
	await host.get_tree().process_frame
	check.call(SaveManager.ryo() == 2500 and MetaProgress.powerup_modifiers().is_empty(),
			"Santuário %s: reembolso devolve tudo" % lang)
	_check_panel(screen, check, "%s, após reembolso" % lang)
