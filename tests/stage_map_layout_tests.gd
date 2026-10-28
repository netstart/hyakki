extends RefCounted
## Jornada do Guardião (seleção de fase) em cada resolução de tests/device_profiles.gd, sem e
## com o furo da câmera de cada lado, em todos os idiomas: pontos do mapa
## dentro do mapa e da tela, tocáveis e sem se encostar; pergaminho com todos os textos
## (região, nome, chefes, narrativa, crônica, recordes) contidos; opções e Começar
## visíveis. Estados: perfil novo (só a vila liberada) e perfil com vila e bambuzal
## vencidos (selo, estrada vermelha, luas e chefes derrotados coloridos).
## Chamado por tests/integration_tests.gd e tests/stage_map_runner.gd (que passam o _check).

const DeviceProfiles := preload("res://tests/device_profiles.gd")
## Tamanho do pergaminho na resolução de referência (a primeira de tests/device_profiles.gd);
## nas outras ele só não pode mudar de um ponto para outro (não cresce com o texto).
const CARD_SIZE := Vector2(266, 293)

var _host: Node
var _check: Callable
## Tela lógica do caso atual e a área segura (fora do furo da câmera).
var _view := Rect2(Vector2.ZERO, DeviceProfiles.main_view())
var _safe := Rect2(Vector2.ZERO, DeviceProfiles.main_view())
var _case := ""
var _card_size := Vector2.ZERO


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var original := SaveManager.data
	for c: Dictionary in DeviceProfiles.layout_cases():
		use_case(c)
		for lang: String in c["langs"]:
			Locale.set_language(lang, false)
			var tag := "%s [%s]" % [lang, _case]
			SaveManager.data = SaveManager.default_profile()
			var ctx := await open_screen("village")
			await _check_layout(ctx[1], "%s, perfil novo" % tag)
			_check_new_profile(ctx[1], tag)
			await close(ctx)
			SaveManager.data = progress_profile(2)
			ctx = await open_screen("")
			_check_progress(ctx[1], tag)
			await _check_layout(ctx[1], "%s, com progresso" % tag)
			if lang == "pt_BR":
				await _check_walk(ctx[1])
			await close(ctx)
	DeviceProfiles.clear_insets()
	SaveManager.data = original
	Locale.set_language("pt_BR", false)


## Perfil com a vila (Lua `moon` vencida) e o bambuzal vencidos, o templo liberado, e os
## chefes da vila, do bambuzal e o primeiro do templo derrotados.
static func progress_profile(moon: int, extra_won: Array = []) -> Dictionary:
	var data := SaveManager.default_profile()
	var won: Array = ["village", "bamboo"] + extra_won
	var order := ["village", "bamboo", "temple", "dunes", "yomi", "secret"]
	data["unlocked"]["stages"] = order.slice(0, won.size() + 1)
	for id: String in won:
		data["stage_best"][id] = {"won": true, "won_brisa": false, "max_moon": moon if id == "village" else 0,
				"best_time": 600.0 + id.length() * 7.0, "endless_best": 0.0}
	for boss: String in ["tanuki", "kappa_elder", "bamboo_ancestral", "kitsune_nine", "tengu_crow_king"]:
		data["stats"]["bosses_defeated"][boss] = 1
	data["defeat_streak"] = {"temple": 5}
	return data


## Usa a tela lógica e o recorte de um caso de DeviceProfiles.layout_cases().
func use_case(c: Dictionary) -> void:
	_view = Rect2(Vector2.ZERO, c["view"])
	_safe = DeviceProfiles.safe_rect(c["view"], c["insets"])
	_case = String(c["label"])
	_card_size = Vector2.ZERO
	DeviceProfiles.simulate_insets(c["insets"])


## Abre o App na tela de fases, com a raiz das telas do tamanho da tela lógica do caso;
## devolve [app, tela].
func open_screen(stage: String) -> Array:
	var app := App.new()
	_host.add_child(app)
	await _host.get_tree().process_frame
	var root := app.get("_root") as Control
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.size = _view.size
	# Sem a abertura (ela cobriria a tela e, ao terminar, levaria ao título).
	for child: Node in app.get_children():
		if child is CanvasLayer and (child as CanvasLayer).layer == 40:
			child.free()
	app.selection["stage"] = stage
	app.go(&"stages")
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	return [app, (app.get("_screens") as Dictionary)[&"stages"]]


func close(ctx: Array) -> void:
	(ctx[0] as Node).queue_free()
	await _host.get_tree().process_frame


func _check_layout(screen: Control, state: String) -> void:
	var map := screen.get("_map") as JourneyMap
	var card := screen.get("_card") as Control
	var map_rect := map.get_global_rect()
	var card_rect := card.get_global_rect()
	_check.call(_safe.encloses(map_rect) and _safe.encloses(card_rect),
			"Jornada %s: mapa e cartão na tela (%s, %s em %s)" % [state, map_rect, card_rect, _safe])
	_check.call(not map_rect.intersects(card_rect), "Jornada %s: mapa e cartão lado a lado" % state)
	# O mapa encolhe com a tela, mas segue o painel principal (os pontos precisam de espaço).
	_check.call(map_rect.size.x >= card_rect.size.x and map_rect.size.y >= card_rect.size.y,
			"Jornada %s: mapa ao menos do tamanho do cartão (%s, %s)" % [state, map_rect.size, card_rect.size])
	_check_card_size(card_rect, "Jornada %s: cartão não cresce com o texto" % state)
	var back := _back_button(screen)
	var title := map.get("_title") as Label
	_check.call(title.get_minimum_size().x <= title.size.x + 0.5 and map_rect.encloses(title.get_global_rect()),
			"Jornada %s: título cabe no topo do mapa" % state)
	_check.call(back != null and not back.get_global_rect().intersects(title.get_global_rect()),
			"Jornada %s: título não encosta no voltar" % state)
	_check.call(back != null and _safe.encloses(back.get_global_rect()),
			"Jornada %s: voltar fora do furo da câmera (%s)" % [state, back.get_global_rect() if back else Rect2()])
	var rects: Array[Rect2] = []
	for id: StringName in map.nodes:
		var node := map.nodes[id] as Control
		var rect := node.get_global_rect()
		_check.call(map_rect.encloses(rect) and _safe.encloses(rect), "Jornada %s: ponto %s dentro do mapa" % [state, id])
		_check.call(rect.size.x >= 28 and rect.size.y >= 28, "Jornada %s: ponto %s tocável (≥ 28)" % [state, id])
		_check.call(not rect.intersects(card_rect), "Jornada %s: ponto %s fora do cartão" % [state, id])
		_check.call(back == null or not rect.intersects(back.get_global_rect()),
				"Jornada %s: ponto %s longe do voltar" % [state, id])
		for other: Rect2 in rects:
			_check.call(not other.intersects(rect) and other.get_center().distance_to(rect.get_center()) >= 28.0,
					"Jornada %s: ponto %s não encosta em outro" % [state, id])
		rects.append(rect)
	# Passa o cartão por cada ponto e volta ao que estava escolhido ao abrir (o _viewing
	# acompanha o ponto olhado, então não serve para voltar).
	var start := map.selected
	for id: StringName in map.nodes:
		map.select(id, false)
		await _host.get_tree().process_frame
		_check_card(screen, "%s, %s" % [state, id])
	map.select(start, false)


func _check_card(screen: Control, state: String) -> void:
	var card_rect := (screen.get("_card") as Control).get_global_rect()
	_check_card_size(card_rect, "Jornada %s: cartão do tamanho fixo" % state)
	for key: String in ["_region", "_name", "_cleared", "_boss", "_stats", "_bonus", "_suggest"]:
		var l := screen.get(key) as Label
		if not l.visible:
			continue
		_check.call(card_rect.encloses(l.get_global_rect()), "Jornada %s: %s dentro do cartão" % [state, key])
		_check.call(l.get_visible_line_count() >= l.get_line_count(), "Jornada %s: %s aparece inteiro" % [state, key])
	var scroll := screen.get("_scroll") as ScrollContainer
	var scroll_rect := scroll.get_global_rect()
	_check.call(card_rect.encloses(scroll_rect) and scroll_rect.size.y >= 40.0,
			"Jornada %s: narrativa dentro do cartão com espaço (%.0f px)" % [state, scroll_rect.size.y])
	for key: String in ["_journey", "_chronicle"]:
		var l := screen.get(key) as Label
		if l.visible:
			_check.call(not l.text.is_empty() and l.size.x <= scroll_rect.size.x + 0.5,
					"Jornada %s: %s quebra dentro da largura do cartão" % [state, key])
	for key: String in ["_mode", "_moon", "_endless", "_go"]:
		var c := screen.get(key) as Control
		var rect := c.get_global_rect()
		_check.call(c.is_visible_in_tree() and card_rect.encloses(rect) and _safe.encloses(rect),
				"Jornada %s: %s visível dentro do cartão" % [state, key])
		_check.call(rect.size.y >= 28.0, "Jornada %s: %s com altura tocável" % [state, key])
	var go := (screen.get("_go") as Control).get_global_rect()
	_check.call(go.end.x >= card_rect.end.x - 14.0 and go.end.y >= card_rect.end.y - 14.0,
			"Jornada %s: Começar no canto inferior direito" % state)
	for key: String in ["_mode", "_moon", "_endless"]:
		_check.call(not (screen.get(key) as Control).get_global_rect().intersects(go),
				"Jornada %s: %s não encosta no Começar" % [state, key])
	for icon: TextureRect in screen.get("_boss_icons"):
		if icon.visible:
			_check.call(card_rect.encloses(icon.get_global_rect()) and icon.size.x >= 24.0 and icon.size.x <= 28.0,
					"Jornada %s: retrato do chefe no cartão" % state)


## Na resolução de referência o pergaminho tem o tamanho de CARD_SIZE; em toda tela, o mesmo em todo ponto.
func _check_card_size(card_rect: Rect2, label: String) -> void:
	if _card_size == Vector2.ZERO:
		_card_size = card_rect.size
	var expected := CARD_SIZE if _view.size == DeviceProfiles.main_view() else _card_size
	_check.call(card_rect.size.is_equal_approx(expected), "%s (%s, esperado %s)" % [label, card_rect.size, expected])


func _back_button(screen: Control) -> Button:
	var text := TranslationServer.translate("menu.back")
	for b: Node in screen.find_children("*", "Button", false, false):
		if (b as Button).text.trim_prefix("< ") == text:
			return b
	return null


func _check_new_profile(screen: Control, lang: String) -> void:
	var map := screen.get("_map") as JourneyMap
	_check.call(map.selected == &"village", "Jornada %s: perfil novo começa na vila" % lang)
	_check.call(map.node_state(&"village") == &"open", "Jornada %s: vila liberada e não vencida" % lang)
	var village := map.nodes[&"village"] as JourneyMap.MapNode
	_check.call(village.face != null and village.face_modulate().v < 0.15 and not village.has_seal(),
			"Jornada %s: vila mostra o chefe em silhueta, sem selo" % lang)
	for id: StringName in map.nodes:
		if id != &"village":
			_check.call(map.node_state(id) == &"locked", "Jornada %s: %s bloqueada no perfil novo" % [lang, id])
			_check.call(map.road_state(id) == &"locked", "Jornada %s: estrada até %s apagada" % [lang, id])
	_check.call(not (screen.get("_go") as Button).disabled, "Jornada %s: Começar liberado na vila" % lang)
	_check.call(not screen.call("boss_icon_known", 0) and not screen.call("boss_icon_known", 1),
			"Jornada %s: chefes da vila em silhueta no cartão" % lang)
	map.select(&"bamboo", false)
	_check.call((screen.get("_go") as Button).disabled, "Jornada %s: Começar desliga na fase bloqueada" % lang)
	_check.call((screen.get("_stats") as Label).text == TranslationServer.translate("stages.locked"),
			"Jornada %s: cartão avisa que está bloqueada" % lang)
	_check.call(String(SaveManager.data["selected"]["stage"]) == "village"
			and String(screen.get("app").selection["stage"]) == "village",
			"Jornada %s: fase bloqueada não vira a escolhida" % lang)
	map.select(&"secret", false)
	_check.call((screen.get("_name") as Label).text == "???"
			and (screen.get("_journey") as Label).text == TranslationServer.translate("stages.secret_hint"),
			"Jornada %s: fase secreta bloqueada não se revela" % lang)
	map.select(&"village", false)
	_check.call(not (screen.get("_go") as Button).disabled, "Jornada %s: volta à vila liga o Começar" % lang)


func _check_progress(screen: Control, lang: String) -> void:
	var map := screen.get("_map") as JourneyMap
	_check.call(map.selected == &"temple", "Jornada %s: sem escolha, abre na primeira fase não vencida" % lang)
	for id: StringName in [&"village", &"bamboo"]:
		var node := map.nodes[id] as JourneyMap.MapNode
		_check.call(map.node_state(id) == &"cleared" and node.has_seal() and node.face_modulate() == Color.WHITE,
				"Jornada %s: %s vencida, colorida e com selo" % [lang, id])
	_check.call(map.road_state(&"bamboo") == &"cleared", "Jornada %s: estrada vermelha até o bambuzal" % lang)
	_check.call(map.node_state(&"temple") == &"open" and map.road_state(&"temple") == &"open",
			"Jornada %s: templo liberado com estrada aberta" % lang)
	_check.call(map.node_state(&"dunes") == &"locked", "Jornada %s: dunas ainda bloqueadas" % lang)
	_check.call((map.nodes[&"village"] as JourneyMap.MapNode).moons == 2, "Jornada %s: vila mostra Lua II" % lang)
	_check.call(screen.call("boss_icon_known", 0) and not screen.call("boss_icon_known", 1),
			"Jornada %s: templo com o Tengu derrotado colorido e o chefe final em silhueta" % lang)
	_check.call((screen.get("_suggest") as Label).visible, "Jornada %s: sugere Brisa após 5 derrotas" % lang)
	map.select(&"village", false)
	var chronicle := screen.get("_chronicle") as Label
	_check.call(chronicle.visible and chronicle.text.contains(TranslationServer.translate("stage.village.dawn")),
			"Jornada %s: vila vencida mostra a crônica" % lang)
	var moon := screen.get("_moon") as OptionButton
	_check.call(moon.item_count == 4 and not (screen.get("_endless") as Button).disabled,
			"Jornada %s: vila vencida libera Lua até III e Noite Sem Fim" % lang)
	for id: StringName in map.nodes:
		var node := map.nodes[id] as Control
		_check.call(not node.get_focus_neighbor(SIDE_LEFT).is_empty() or not node.get_focus_neighbor(SIDE_RIGHT).is_empty(),
				"Jornada %s: ponto %s navegável pelas setas" % [lang, id])
	map.select(&"temple", false)


## Trocar de ponto faz a guardiã andar até o novo ponto.
func _check_walk(screen: Control) -> void:
	var map := screen.get("_map") as JourneyMap
	map.select(&"temple", false)
	_check.call(map.hero_position().distance_to(map.node_center(&"temple")) < 34.0, "Jornada: guardiã ao lado do templo")
	map.select(&"village")
	await _host.get_tree().create_timer(0.5).timeout
	_check.call(map.hero_position().distance_to(map.node_center(&"village")) < 34.0,
			"Jornada: guardiã caminha até a vila (%.0f px)" % map.hero_position().distance_to(map.node_center(&"village")))
	(map.nodes[&"bamboo"] as BaseButton).pressed.emit()
	await _host.get_tree().process_frame
	_check.call(map.selected == &"bamboo" and String(screen.get("app").selection["stage"]) == "bamboo",
			"Jornada: tocar no ponto escolhe a fase")
