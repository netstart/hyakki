extends RefCounted
## Créditos (scripts/app/screens/credits_screen.gd) em cada resolução de
## tests/device_profiles.gd (sem e com o furo da câmera de cada lado), em cada idioma; arrasto
## e roda na resolução de referência.
## Chamado por tests/integration_tests.gd e por tests/credits_screen_runner.gd.
##
## O que vale para a tela:
## - completude: TODA entrada de licenses/index.json (qualquer categoria) aparece com o nome e
##   o autor visíveis, na seção certa, e com glifos que a fonte desenha; CREDITS.md também
##   lista todas;
## - o crédito do criador, o agradecimento especial e a despedida aparecem;
## - nada estoura na horizontal (tudo dentro da largura visível da área rolável, com ≥ 12 px
##   de margem na tela), textos inteiros nas caixas e o voltar fora da área rolável;
## - arrastar no meio do conteúdo rola (toque emulado pelo mouse, como no aparelho), a roda
##   do mouse rola, e todo nó do conteúdo deixa o toque passar.

const CREDITS_SCREEN := "res://scripts/app/screens/credits_screen.gd"
const MIN_SIDE := 12.0
const DeviceProfiles := preload("res://tests/device_profiles.gd")

var _host: Node
var _check: Callable
## Tela lógica do caso atual e a área segura (fora do furo da câmera); fora do laço, a
## resolução de referência (arrasto e roda).
var _view := Rect2(Vector2.ZERO, DeviceProfiles.main_view())
var _safe := Rect2(Vector2.ZERO, DeviceProfiles.main_view())


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	for c: Dictionary in DeviceProfiles.layout_cases():
		use_case(c["view"], c["insets"])
		for lang: String in c["langs"]:
			Locale.set_language(lang, false)
			var tag := "%s [%s]" % [lang, c["label"]]
			var ctx: Array = await open_screen()
			var screen := ctx[1] as Control
			_check_complete(screen, tag)
			_check_texts(screen, tag)
			check_layout(screen, tag)
			await close(ctx)
	use_case(DeviceProfiles.main_view(), Vector2.ZERO)
	Locale.set_language("pt_BR", false)
	await _check_scrolling()
	_check_credits_md()


## Tela lógica e recorte da câmera (esquerda, direita) usados por open_screen e check_layout.
func use_case(view: Vector2, insets: Vector2) -> void:
	_view = Rect2(Vector2.ZERO, view)
	_safe = DeviceProfiles.safe_rect(view, insets)
	DeviceProfiles.simulate_insets(insets)


## Abre a tela pelo App (com o fundo dos menus), sem a abertura, no tamanho do jogo.
func open_screen() -> Array:
	var app := App.new()
	_host.add_child(app)
	await _host.get_tree().process_frame
	for child: Node in app.get_children():
		if child is CanvasLayer and (child as CanvasLayer).layer == 40:
			child.free()
	var root := app.get("_root") as Control
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.size = _view.size
	app.go(&"credits")
	var screen := (app.get("_screens") as Dictionary)[&"credits"] as Control
	await _host.get_tree().process_frame
	screen.call("_finish_intro")
	screen.call("stop_auto_scroll")
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	return [app, screen]


func close(ctx: Array) -> void:
	(ctx[0] as Node).queue_free()
	await _host.get_tree().process_frame


## Toda entrada do índice: cartão na seção certa, nome e autor visíveis, glifos desenháveis.
func _check_complete(screen: Control, lang: String) -> void:
	var entries := LicenseIndex.entries()
	_check.call(entries.size() >= 19, "Créditos %s: índice com todas as entradas (%d)" % [lang, entries.size()])
	var cards := screen.find_children("Entry_*", "PanelContainer", true, false)
	_check.call(cards.size() == entries.size(),
			"Créditos %s: um cartão por entrada do índice (%d de %d)" % [lang, cards.size(), entries.size()])
	var texts := _visible_texts(screen)
	var ja := load(String(screen.get("JA_FONT"))) as Font
	for entry: Dictionary in entries:
		var id := String(entry["id"])
		var entry_name := String(entry["name"])
		var author := String(entry["author"])
		_check.call(texts.has(entry_name), "Créditos %s: nome de %s visível (\"%s\")" % [lang, id, entry_name])
		_check.call(texts.has(author), "Créditos %s: autor de %s visível (\"%s\")" % [lang, id, author])
		var card := screen.find_child("Entry_%s" % id, true, false) as Control
		var section := String(screen.call("section_of", entry))
		var holder := screen.find_child("Section_%s" % section, true, false) as Control
		_check.call(card != null and holder != null and holder.is_ancestor_of(card),
				"Créditos %s: %s na seção %s" % [lang, id, section])
		if card != null:
			var badge := card.find_child("License", true, false) as Control
			_check.call(badge != null and texts.has(String(screen.call("badge_text", entry["license_id"]))),
					"Créditos %s: selo da licença de %s" % [lang, id])
		for text: String in [entry_name, author]:
			for i: int in text.length():
				var c := text.unicode_at(i)
				if c > 32 and not Locale.font.has_char(c) and not ja.has_char(c):
					_check.call(false, "Créditos %s: glifo U+%04X de \"%s\" sem fonte" % [lang, c, text])
	for category: String in ["engine", "android", "plugin"]:
		var found := false
		for entry: Dictionary in entries:
			found = found or String(entry["category"]) == category
		_check.call(found, "Créditos %s: há entradas de %s no índice (e na Tecnologia)" % [lang, category])


## Criador, agradecimento especial e despedida.
func _check_texts(screen: Control, lang: String) -> void:
	var texts := _visible_texts(screen)
	var credit: PackedStringArray = screen.call("split_credit", tr("credits.design"))
	_check.call(credit[1] == "Clayton K. N. Passos", "Créditos %s: o criador sai do crédito (%s)" % [lang, credit[1]])
	_check.call(texts.has(credit[1]) and (credit[0] == "" or texts.has(credit[0])),
			"Créditos %s: crédito do criador visível" % lang)
	_check.call(texts.has(tr("credits.special_thanks")), "Créditos %s: agradecimento especial visível" % lang)
	_check.call(texts.has(tr("credits.thanks")), "Créditos %s: despedida visível" % lang)
	_check.call(texts.has(tr("credits.title")) and texts.has(tr("title.subtitle")),
			"Créditos %s: título e subtítulo" % lang)
	for key: String in ["credits.section.art", "credits.section.music", "credits.section.sfx",
			"credits.section.fonts", "credits.section.tech", "credits.section.thanks"]:
		_check.call(texts.has(tr(key)), "Créditos %s: cabeçalho %s" % [lang, key])
	# A despedida é o último texto do conteúdo (o "fim" da noite).
	var thanks := screen.find_child("Thanks", true, false) as Control
	var special := screen.find_child("SpecialThanks", true, false) as Control
	_check.call(thanks != null and special != null
			and thanks.get_global_rect().position.y > special.get_global_rect().end.y,
			"Créditos %s: a despedida vem depois do agradecimento especial" % lang)


## Nada estoura na horizontal; textos inteiros; fixos fora da área rolável.
func check_layout(screen: Control, state: String) -> void:
	var scroll := screen.get("_scroll") as ScrollContainer
	var content := scroll.get_child(0) as Control
	var scroll_rect := scroll.get_global_rect()
	var bar := scroll.get_v_scroll_bar()
	var visible_right := bar.get_global_rect().position.x if bar.visible else scroll_rect.end.x
	_check.call(_safe.encloses(scroll_rect) and scroll_rect.position.x >= MIN_SIDE
			and _safe.end.x - scroll_rect.end.x >= 0.0,
			"Créditos %s: área rolável na tela (%s em %s)" % [state, scroll_rect, _safe])
	_check.call(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
			"Créditos %s: sem rolagem horizontal" % state)
	_check.call(bar.visible and bar.max_value > scroll.size.y, "Créditos %s: barra de rolagem visível" % state)
	_check.call(content.get_combined_minimum_size().x <= content.size.x + 0.5
			and content.get_global_rect().end.x <= visible_right + 0.5,
			"Créditos %s: o conteúdo cabe na largura (%s, mínimo %s)" % [state, content.get_global_rect(),
			content.get_combined_minimum_size()])
	var left := scroll_rect.position.x
	for node: Node in content.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		var rect := control.get_global_rect()
		_check.call(rect.position.x >= left - 0.5 and rect.end.x <= visible_right + 0.5,
				"Créditos %s: %s dentro da largura (%s)" % [state, control.name, rect])
		if control is Label and (control as Label).text != "":
			var l := control as Label
			var font := l.get_theme_font("font")
			var size := l.get_theme_font_size("font_size")
			var lines := l.get_line_count()
			var needed := lines * font.get_height(size) + (lines - 1) * l.get_theme_constant("line_spacing")
			_check.call(needed <= l.size.y + 0.5 and l.get_visible_line_count() == l.get_line_count(),
					"Créditos %s: \"%s\" inteiro (%.0f de %.0f px)" % [state, l.text, needed, l.size.y])
			if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var width := font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				_check.call(width <= l.size.x + 0.5, "Créditos %s: \"%s\" cabe na largura" % [state, l.text])
	for child: Node in screen.get_children():
		if child is Button or child is Label:
			var fixed := (child as Control).get_global_rect()
			_check.call(_safe.encloses(fixed) and not fixed.intersects(scroll_rect),
					"Créditos %s: %s fixo fora da área rolável (%s)" % [state, child.name, fixed])


## Arrasto (toque emulado pelo mouse) e roda num SubViewport do tamanho do jogo.
func _check_scrolling() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(_view.size)
	viewport.gui_disable_input = false
	_host.add_child(viewport)
	var root := Control.new()
	root.theme = ThemeFactory.build()
	root.size = _view.size
	viewport.add_child(root)
	var screen := (load(CREDITS_SCREEN) as GDScript).new() as Control
	root.add_child(screen)
	screen.call("on_show")
	await _host.get_tree().process_frame
	screen.call("_finish_intro")
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	var scroll := screen.get("_scroll") as ScrollContainer
	var content := scroll.get_child(0) as Control
	for node: Node in content.find_children("*", "Control", true, false) + [content]:
		var control := node as Control
		var passive := control is Label or control is TextureRect or control is ColorRect
		var wanted := Control.MOUSE_FILTER_IGNORE if passive else Control.MOUSE_FILTER_PASS
		_check.call(control.mouse_filter == wanted,
				"Créditos: %s (%s) deixa o arrasto passar" % [control.name, control.get_class()])
	_check.call(scroll.scroll_deadzone > 0, "Créditos: zona morta evita rolar com um toque")
	_check.call(scroll.scroll_vertical == 0, "Créditos: abre no topo")
	# Um toque qualquer para a rolagem automática.
	# Começa o arrasto em cima de um cartão (nome, autor e selo): é ali que o dedo pousa.
	var middle := scroll.get_global_rect().get_center()
	var first := screen.find_child("Entry_%s" % LicenseIndex.entries()[0]["id"], true, false) as Control
	for node: Node in screen.find_children("Entry_*", "PanelContainer", true, false):
		var rect := (node as Control).get_global_rect()
		if scroll.get_global_rect().encloses(rect) and rect.get_center().y > middle.y - 40:
			first = node as Control
			break
	if first != null and scroll.get_global_rect().has_point(first.get_global_rect().get_center()):
		middle = first.get_global_rect().get_center()
	_press(viewport, middle, true)
	_press(viewport, middle, false)
	_check.call(not bool(screen.get("_auto")), "Créditos: o primeiro toque para a rolagem automática")
	scroll.scroll_vertical = 0
	await _host.get_tree().process_frame
	_press(viewport, middle, true)
	var at := middle
	for i: int in 12:
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.relative = Vector2(0, -10)
		at += motion.relative
		motion.position = at
		motion.global_position = at
		viewport.push_input(motion)
		await _host.get_tree().process_frame
	_press(viewport, at, false)
	await _host.get_tree().process_frame
	var dragged := scroll.scroll_vertical
	_check.call(dragged >= 60, "Créditos: arrastar 120 px para cima no meio do conteúdo rola (%d)" % dragged)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.factor = 1.0
	wheel.position = middle
	wheel.global_position = middle
	viewport.push_input(wheel)
	await _host.get_tree().process_frame
	_check.call(scroll.scroll_vertical > dragged, "Créditos: a roda do mouse rola (%d → %d)" % [
			dragged, scroll.scroll_vertical])
	# Rolando até o fim, o sol nasce e a despedida aparece inteira.
	scroll.scroll_vertical = int(content.size.y)
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	var dawn := screen.get("_dawn") as Control
	_check.call(float(dawn.get("rise")) > 0.9, "Créditos: no fim o sol nasce (%.2f)" % float(dawn.get("rise")))
	var thanks := screen.find_child("Thanks", true, false) as Control
	_check.call(scroll.get_global_rect().grow(0.5).encloses(thanks.get_global_rect()),
			"Créditos: no fim a despedida aparece inteira")
	viewport.queue_free()
	await _host.get_tree().process_frame


func _press(viewport: SubViewport, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.position = at
	event.global_position = at
	viewport.push_input(event)


## CREDITS.md (gerado por tools/build_license_index.py) lista toda entrada do índice.
func _check_credits_md() -> void:
	var md := FileAccess.get_file_as_string("res://CREDITS.md")
	_check.call(md != "", "CREDITS.md existe")
	for entry: Dictionary in LicenseIndex.entries():
		_check.call(md.contains(String(entry["name"])) and md.contains(String(entry["author"])),
				"CREDITS.md lista %s (nome e autor)" % entry["id"])
	_check.call(md.contains("Clayton K. N. Passos"), "CREDITS.md tem o crédito do criador")


## Textos visíveis da tela (labels e botões), depois da entrada.
func _visible_texts(screen: Control) -> Dictionary:
	var texts := {}
	for node: Node in screen.find_children("*", "", true, false):
		if node is Label and (node as Label).is_visible_in_tree() and (node as Control).modulate.a > 0.99:
			texts[(node as Label).text] = true
		elif node is Button and (node as Button).is_visible_in_tree():
			texts[(node as Button).text] = true
	return texts
