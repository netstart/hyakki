extends RefCounted
## Tela de título em cada resolução de tests/device_profiles.gd (sem e com o furo da câmera
## de cada lado): coluna de menu, saldo, bloco de ação e selos (Loja pronta,
## Desafio Diário feito, partida suspensa) em todos os idiomas; foco no botão principal e
## entrada animada que não acumula deslocamento; balão de dicas da guardiã (TipBalloon) com a
## dica mais longa de cada idioma, sem cobrir nada e sem corte. Chamado por tests/integration_tests.gd.

const DeviceProfiles := preload("res://tests/device_profiles.gd")

## Tela lógica do caso atual e a área segura (fora do furo da câmera).
var _view := Rect2(Vector2.ZERO, DeviceProfiles.main_view())
var _safe := Rect2(Vector2.ZERO, DeviceProfiles.main_view())
## Dica mais larga de cada idioma (TipDeck.longest), calculada uma vez.
var _longest: Dictionary = {}


func run(host: Node, check: Callable) -> void:
	var original := SaveManager.data
	for c: Dictionary in DeviceProfiles.layout_cases():
		_view = Rect2(Vector2.ZERO, c["view"])
		_safe = DeviceProfiles.safe_rect(c["view"], c["insets"])
		DeviceProfiles.simulate_insets(c["insets"])
		for lang: String in c["langs"]:
			Locale.set_language(lang, false)
			for state: int in 4:
				# bit 0: Loja pronta; bit 1: Desafio Diário feito e partida suspensa.
				var shop_ready := state & 1 == 1
				var done := state & 2 == 2
				_setup(shop_ready, done)
				var app := App.new()
				host.add_child(app)
				await host.get_tree().process_frame
				_fit_game_view(app, _view.size)
				app.go(&"title")
				var screen := (app.get("_screens") as Dictionary)[&"title"] as Control
				await _settle(host, screen)
				var tag := "Título %s [%s] (loja %s, diário %s)" % [lang, c["label"], shop_ready, done]
				_check_layout(screen, check, tag)
				_check_states(app, screen, check, tag, shop_ready, done)
				_check_tip(screen, check, tag)
				if state == 0:
					await _check_repeat(host, app, screen, check, tag)
				app.queue_free()
				await host.get_tree().process_frame
	DeviceProfiles.clear_insets()
	SaveManager.data = original
	Locale.set_language("pt_BR", false)


## O teste roda numa janela menor que o jogo (64x64 no --headless, e o PixelScaler deixa o
## viewport lógico desse tamanho): a raiz das telas recebe o tamanho do viewport do jogo,
## como no aparelho. A tela ancora o saldo e o bloco de ação nos cantos dessa raiz.
static func _fit_game_view(app: App, view: Vector2) -> void:
	var root := app.get("_root") as Control
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.size = view


func _setup(shop_ready: bool, done: bool) -> void:
	SaveManager.data = SaveManager.default_profile()
	SaveManager.data["ryo"] = 1234567
	var now := int(Time.get_unix_time_from_system())
	var slots: Dictionary = SaveManager.data["shop"]["slots"]
	for id: StringName in ShopManager.ad_slots():
		slots[String(id)] = 0 if shop_ready else now + ShopManager.COOLDOWN
	SaveManager.data["daily"]["date"] = Time.get_date_string_from_system() if done else "2000-01-01"
	if done:
		SaveManager.data["suspended"] = {"version": 1, "saved_unix": now, "config": {"stage": "village"}}


func _settle(host: Node, screen: Control) -> void:
	await host.get_tree().process_frame
	screen.call("_finish_intro")
	await host.get_tree().process_frame
	await host.get_tree().process_frame


func _buttons(screen: Control) -> Array[Button]:
	var list: Array[Button] = []
	for node: Node in screen.find_children("*", "Button", true, false):
		if (node as Button).is_visible_in_tree():
			list.append(node as Button)
	return list


func _check_layout(screen: Control, check: Callable, tag: String) -> void:
	var buttons := _buttons(screen)
	var expected := 8 if (screen.get("_continue") as Button).visible else 7
	check.call(buttons.size() == expected, "%s: %d botões visíveis (%d)" % [tag, expected, buttons.size()])
	var rects: Array[Rect2] = []
	for b: Button in buttons:
		var rect := b.get_global_rect()
		check.call(_safe.encloses(rect), "%s: '%s' inteiro na tela (%s em %s)" % [tag, b.text, rect, _safe])
		check.call(rect.size.y >= 30, "%s: '%s' com alvo de toque ≥ 30 (%.0f)" % [tag, b.text, rect.size.y])
		check.call(is_equal_approx(b.modulate.a, 1.0), "%s: '%s' terminou de aparecer" % [tag, b.text])
		var font := b.get_theme_font("font")
		var font_size := b.get_theme_font_size("font_size")
		var box := b.get_theme_stylebox("normal")
		var need := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + box.get_margin(SIDE_LEFT) \
				+ box.get_margin(SIDE_RIGHT)
		check.call(need <= rect.size.x + 0.5 and b.get_minimum_size().x <= rect.size.x + 0.5,
				"%s: texto '%s' cabe no botão (%.0f > %.0f)" % [tag, b.text, need, rect.size.x])
		for other: Rect2 in rects:
			check.call(not other.intersects(rect), "%s: '%s' não encosta em outro botão" % [tag, b.text])
		rects.append(rect)
	var rows: Array = screen.get("_rows")
	for row: Button in rows:
		var icon := row.get_node("Icon") as TextureRect
		check.call(icon.texture != null and row.get_global_rect().encloses(icon.get_global_rect()),
				"%s: ícone de '%s' dentro da linha" % [tag, row.text])
		var box := row.get_theme_stylebox("normal")
		check.call(icon.get_global_rect().end.x <= row.get_global_rect().position.x + box.get_margin(SIDE_LEFT),
				"%s: ícone de '%s' antes do texto" % [tag, row.text])
	var title := (screen.get("_title_box") as Control).get_global_rect()
	check.call(_safe.encloses(title), "%s: título inteiro na tela (%s em %s)" % [tag, title, _safe])
	for row: Button in rows:
		check.call(not title.intersects(row.get_global_rect()), "%s: título não cobre '%s'" % [tag, row.text])
	var chip := (screen.get("_chip") as Control).get_global_rect()
	check.call(_safe.encloses(chip) and not title.intersects(chip),
			"%s: saldo inteiro e longe do título (%s em %s)" % [tag, chip, _safe])
	var ryo := screen.get("_ryo") as Label
	check.call(ryo.text == Locale.format_number(1234567) and chip.encloses(ryo.get_global_rect()),
			"%s: saldo mostra o ryō dentro do selo" % tag)
	for rect: Rect2 in rects:
		check.call(not rect.intersects(chip), "%s: saldo não encosta em botão" % tag)


func _check_states(app: App, screen: Control, check: Callable, tag: String, shop_ready: bool, done: bool) -> void:
	var shop := screen.get("_shop_button") as Button
	check.call(shop.text == TranslationServer.translate("title.shop"), "%s: Loja sem sufixo de texto" % tag)
	var badge := screen.get("_shop_badge") as Control
	check.call(badge.is_visible_in_tree() == ShopManager.any_ready() and badge.visible == shop_ready,
			"%s: selo da Loja só com vaga pronta" % tag)
	check.call(shop.get_global_rect().encloses(badge.get_global_rect()), "%s: selo dentro da linha da Loja" % tag)
	var daily := screen.get("_daily") as Button
	check.call(daily.text == TranslationServer.translate("title.daily"), "%s: Desafio sem sufixo de texto" % tag)
	check.call((screen.get("_daily_done") as Control).is_visible_in_tree() == done,
			"%s: visto do Desafio Diário só quando feito hoje" % tag)
	check.call((screen.get("_daily_new") as Control).is_visible_in_tree() != done,
			"%s: ponto de novo no Desafio Diário só quando falta" % tag)
	var cont := screen.get("_continue") as Button
	check.call(cont.is_visible_in_tree() == app.has_suspended_run() and cont.visible == done,
			"%s: Continuar só com partida suspensa" % tag)
	var primary := cont if done else screen.get("_play") as Button
	check.call(screen.get_viewport().gui_get_focus_owner() == primary, "%s: foco no botão principal" % tag)
	check.call(primary.get_global_rect().size.y >= 44, "%s: botão principal grande" % tag)
	for b: Button in _buttons(screen):
		check.call(b == primary or b.get_global_rect().size.y < primary.get_global_rect().size.y,
				"%s: '%s' menor que o principal" % [tag, b.text])


## Balão de dicas com a dica mais longa do idioma: dentro da área segura, sem cobrir título,
## saldo, menu, bloco de ação, versão nem a guardiã; rabicho até a cabeça; texto inteiro.
func _check_tip(screen: Control, check: Callable, tag: String) -> void:
	var balloon := screen.call("tip_balloon") as TipBalloon
	var font: Font = Locale.font if Locale.font != null else ThemeDB.fallback_font
	if not _longest.has(Locale.current):
		_longest[Locale.current] = TipDeck.longest(font)
	var tip: Dictionary = _longest[Locale.current]
	balloon.show_tip(tip, false)
	balloon.reveal()
	var rects := balloon.layout_rects()
	var name := String(tip.get("id", ""))
	check.call(bool(rects.get("ok", false)) and balloon.visible, "%s: balão cabe com a dica mais longa (%s)" % [tag, name])
	if not bool(rects.get("ok", false)):
		return
	var xf := screen.get_global_transform()
	var box: Rect2 = xf * (rects["box"] as Rect2)
	check.call(_safe.encloses(box), "%s: balão inteiro na área segura (%s em %s)" % [tag, box, _safe])
	var blockers: Array[Control] = [screen.get("_title_box") as Control, screen.get("_chip") as Control,
			screen.get("_version") as Control]
	for b: Button in _buttons(screen):
		blockers.append(b)
	for c: Control in blockers:
		check.call(not box.intersects(c.get_global_rect()), "%s: balão não cobre '%s'" % [tag, c.name])
	var app := screen.get("app") as App
	var backdrop := app.backdrop()
	var hero := backdrop.get_global_transform() * backdrop.hero_rect()
	check.call(not box.intersects(hero), "%s: balão não cobre a guardiã" % tag)
	var tail: PackedVector2Array = rects["tail"]
	var tip_at := xf * tail[2]
	check.call(tip_at.distance_to(Vector2(hero.get_center().x, hero.position.y)) <= 16.0 + hero.size.y * 0.5,
			"%s: rabicho aponta para a guardiã (%s, %s)" % [tag, tip_at, hero])
	# "×": desenho dentro do papel (sem a moldura de 6 px), da área assada e da área de toque, sem
	# encostar nos ícones da receita nem no texto.
	var glyph: Rect2 = xf * (rects["close_glyph"] as Rect2)
	var bake := balloon.get_node("StaticBake") as Control if balloon.has_node("StaticBake") else null
	var baked := bake.get_global_rect() if bake != null else balloon.get_global_rect()
	check.call(box.grow(-6.0).encloses(glyph) and baked.encloses(glyph) and baked.size == balloon.size
			and (xf * (rects["close"] as Rect2)).encloses(glyph),
			"%s: × do balão inteiro no papel e na área assada (%s em %s, %s)" % [tag, glyph, box, baked])
	var chain: Rect2 = xf * (rects["chain"] as Rect2)
	check.call(chain.size.x <= 0.0 or not chain.intersects(glyph), "%s: × não encosta nos ícones" % tag)
	var label := balloon.text_label()
	var text := label.get_global_rect()
	check.call(not text.intersects(glyph), "%s: × não encosta no texto" % tag)
	check.call(box.encloses(text) and int(rects["lines"]) <= TipBalloon.MAX_LINES
			and label.get_line_count() <= int(rects["lines"]) and TipBalloon.words_fit(label.text, text.size.x, font),
			"%s: dica '%s' inteira no balão (%d linhas)" % [tag, name, label.get_line_count()])
	balloon.show_tip({})


func _check_repeat(host: Node, app: App, screen: Control, check: Callable, tag: String) -> void:
	var before := _positions(screen)
	app.go(&"options")
	await host.get_tree().process_frame
	app.go(&"title")
	screen.call("on_show")
	await _settle(host, screen)
	check.call(_positions(screen) == before, "%s: mostrar de novo não desloca nada" % tag)
	await host.get_tree().create_timer(0.6).timeout
	check.call(_positions(screen) == before, "%s: entrada termina nas mesmas posições" % tag)


func _positions(screen: Control) -> Array[Vector2]:
	var list: Array[Vector2] = []
	for b: Button in _buttons(screen):
		list.append(b.get_global_rect().position)
	list.append((screen.get("_title_box") as Control).get_global_rect().position)
	return list
