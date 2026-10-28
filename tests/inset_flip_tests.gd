extends RefCounted
## Furo da câmera que troca de lado com a tela aberta, SEM redimensionar (girar o celular 180°):
## em cada resolução de tests/device_profiles.gd, cada tela (título, fases, guardiões,
## resultados, Santuário, loja, Diário, opções, créditos), a HUD, a pausa, a nova habilidade e
## o baú abrem com o furo à esquerda, o furo passa para a direita e volta; a cada troca o
## "voltar" e todo elemento de toque visível ficam fora do furo novo. A troca chega só pelo sinal
## único PixelScaler.safe_insets_changed (MenuKit.on_insets_change): sem tique de tela, sem
## resized. Também confere o próprio sinal (emite só quando muda; desliga com o nó).
## Chamado por tests/integration_tests.gd ou sozinho por tests/inset_flip_tests.tscn.

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const ResultsLayoutTests := preload("res://tests/results_layout_tests.gd")
const PauseMenuTests := preload("res://tests/pause_menu_tests.gd")
const LevelChestTests := preload("res://tests/level_chest_tests.gd")
const SCREENS: Array[StringName] = [&"title", &"stages", &"heroes", &"results", &"sanctuary", &"shop",
		&"codex", &"options", &"credits"]
## Telas sem "voltar" (o título é a raiz; os resultados saem pelos próprios botões).
const NO_BACK: Array[StringName] = [&"title", &"results"]
## Folga de arredondamento das posições (pontos lógicos).
const EPS := 0.5

var _host: Node
var _check: Callable


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var original := SaveManager.data
	Locale.set_language("pt_BR", false)
	await _check_signal()
	for r: Dictionary in DeviceProfiles.RESOLUTIONS:
		var view: Vector2 = r["view"]
		var cut := DeviceProfiles.cutout_logical(r)
		for name: StringName in SCREENS:
			await _flip_screen(name, view, cut, r["label"])
		await _flip_hud(view, cut, r["label"])
		await _flip_pause(view, cut, r["label"])
		await _flip_level_chest(view, cut, r["label"])
	DeviceProfiles.clear_insets()
	SaveManager.data = original
	Locale.set_language("pt_BR", false)


## Lados do furo, na ordem: à esquerda (abre), à direita, à esquerda de novo.
static func sides(cut: float) -> Array[Vector2]:
	return [Vector2(cut, 0.0), Vector2(0.0, cut), Vector2(cut, 0.0)]


# --- Sinal ----------------------------------------------------------------------------

## safe_insets_changed: emite uma vez por troca, nada quando o recorte não muda; o
## on_insets_change chama só com o nó na árvore e desliga quando ele sai.
func _check_signal() -> void:
	DeviceProfiles.clear_insets()
	var scaler := _host.get_tree().root.get_node(^"PixelScaler")
	var emitted: Array[int] = [0]
	var count := func() -> void: emitted[0] += 1
	scaler.connect("safe_insets_changed", count)
	DeviceProfiles.simulate_insets(Vector2(30, 0))
	_check.call(emitted[0] == 1, "Recorte: trocar o furo emite safe_insets_changed na hora (%d)" % emitted[0])
	DeviceProfiles.simulate_insets(Vector2(30, 0))
	_check.call(emitted[0] == 1, "Recorte: o mesmo furo não emite de novo (%d)" % emitted[0])
	DeviceProfiles.simulate_insets(Vector2(0, 30))
	_check.call(emitted[0] == 2, "Recorte: furo do outro lado emite (%d)" % emitted[0])
	DeviceProfiles.clear_insets()
	_check.call(emitted[0] == 3, "Recorte: tirar o furo emite (%d)" % emitted[0])
	scaler.disconnect("safe_insets_changed", count)
	var node := Control.new()
	_host.add_child(node)
	var calls: Array[int] = [0]
	MenuKit.on_insets_change(node, func() -> void: calls[0] += 1)
	DeviceProfiles.simulate_insets(Vector2(30, 0))
	_check.call(calls[0] == 1, "Recorte: on_insets_change chama o nó na árvore (%d)" % calls[0])
	_host.remove_child(node)
	DeviceProfiles.simulate_insets(Vector2(0, 30))
	_check.call(calls[0] == 1, "Recorte: fora da árvore o nó não é chamado (%d)" % calls[0])
	_host.add_child(node)
	DeviceProfiles.simulate_insets(Vector2(30, 0))
	_check.call(calls[0] == 2, "Recorte: de volta à árvore o nó volta a ser chamado (%d)" % calls[0])
	node.queue_free()
	await _host.get_tree().process_frame
	DeviceProfiles.simulate_insets(Vector2(0, 30))
	_check.call(calls[0] == 2, "Recorte: nó liberado não é chamado (%d)" % calls[0])
	DeviceProfiles.clear_insets()


# --- Telas ----------------------------------------------------------------------------

func _flip_screen(name: StringName, view: Vector2, cut: float, label: String) -> void:
	SaveManager.data = SaveManager.default_profile()
	SaveManager.data["ryo"] = 2500
	var flips := sides(cut)
	DeviceProfiles.simulate_insets(flips[0])
	var app := App.new()
	_host.add_child(app)
	await _host.get_tree().process_frame
	# Sem a abertura (ela cobriria a tela e, ao terminar, levaria ao título).
	for child: Node in app.get_children():
		if child is CanvasLayer and (child as CanvasLayer).layer == 40:
			child.free()
	var root := app.get("_root") as Control
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.size = view
	if name == &"results":
		app.last_result = ResultsLayoutTests.make_result("victory", 6)
	app.go(name)
	var screen := (app.get("_screens") as Dictionary)[name] as Control
	await _host.get_tree().process_frame
	_skip_intro(screen)
	await _settle()
	for i: int in flips.size():
		if i > 0:
			DeviceProfiles.simulate_insets(flips[i])
			await _settle()
		_check_inside(screen, view, flips[i], "Furo trocado %s [%s] %s" % [name, label, _side(flips[i])], name not in NO_BACK)
	app.queue_free()
	await _host.get_tree().process_frame


func _skip_intro(screen: Control) -> void:
	for method: String in ["_finish_intro", "skip_intro", "stop_auto_scroll"]:
		if screen.has_method(method):
			screen.call(method)


# --- HUD e painéis da partida -----------------------------------------------------------

func _flip_hud(view: Vector2, cut: float, label: String) -> void:
	var joystick_mode: Variant = Settings.get_value("joystick_mode")
	var joystick_side: Variant = Settings.get_value("joystick_side")
	Settings.set_value("joystick_mode", "fixed")
	var flips := sides(cut)
	for side: String in ["left", "right"]:
		Settings.set_value("joystick_side", side)
		DeviceProfiles.simulate_insets(flips[0])
		var hud := Hud.new()
		_host.add_child(hud)
		await _host.get_tree().process_frame
		var root := hud.get("_root") as Control
		root.set_anchors_preset(Control.PRESET_TOP_LEFT)
		root.size = view
		# Sem o tique da HUD: a troca tem de chegar pelo sinal.
		hud.set_process(false)
		await _settle()
		for i: int in flips.size():
			if i > 0:
				DeviceProfiles.simulate_insets(flips[i])
				await _settle()
			var state := "Furo trocado HUD [%s] joystick à %s, %s" % [label, side, _side(flips[i])]
			var safe := DeviceProfiles.safe_rect(view, flips[i])
			for b: Control in [hud.get("_pause_button"), hud.get("_speed_button"), hud.get("_ult_button")]:
				var r := b.get_global_rect()
				_check.call(not b.is_visible_in_tree() or _encloses(safe, r),
						"%s: botão %s fora do furo (%s em %s)" % [state, b.name, r, safe])
			var joy := hud.joystick
			var center: Vector2 = joy.get_global_transform() * joy.fixed_center()
			_check.call(center.x - TouchJoystick.RADIUS >= safe.position.x - EPS
					and center.x + TouchJoystick.RADIUS <= safe.end.x + EPS,
					"%s: joystick fixo fora do furo (%s em %s)" % [state, center, safe])
			_check_inside(root, view, flips[i], state, false)
		hud.queue_free()
		await _host.get_tree().process_frame
	Settings.set_value("joystick_mode", joystick_mode)
	Settings.set_value("joystick_side", joystick_side)


func _flip_pause(view: Vector2, cut: float, label: String) -> void:
	var t := PauseMenuTests.new()
	t.set("_host", _host)
	t.set("_check", _check)
	var flips := sides(cut)
	t.use_insets(flips[0])
	var menu: PauseMenu = await t.open_standalone(view, PauseMenuTests.make_snapshot(true))
	for i: int in flips.size():
		if i > 0:
			t.use_insets(flips[i])
			await _settle()
		var state := "Furo trocado pausa [%s] %s" % [label, _side(flips[i])]
		t.check_layout(menu, view, state)
		_check_inside(menu, view, flips[i], state, false)
	menu.get_parent().queue_free()
	await _host.get_tree().process_frame


func _flip_level_chest(view: Vector2, cut: float, label: String) -> void:
	var t := LevelChestTests.new()
	t.set("_host", _host)
	t.set("_check", _check)
	var flips := sides(cut)
	t.set("_insets", flips[0])
	DeviceProfiles.simulate_insets(flips[0])
	var area := Control.new()
	area.theme = ThemeFactory.build()
	area.size = view
	_host.add_child(area)
	var panel := LevelUpPanel.new()
	area.add_child(panel)
	panel.show_cards(LevelChestTests.sample_cards(), 2, 1, 3, 27)
	await _host.get_tree().create_timer(0.75).timeout
	for i: int in flips.size():
		if i > 0:
			t.set("_insets", flips[i])
			DeviceProfiles.simulate_insets(flips[i])
			await _settle()
		t.check_level_layout(panel, view, "Furo trocado nova habilidade [%s] %s" % [label, _side(flips[i])])
	var chest := ChestPanel.new()
	area.add_child(chest)
	panel.close_now()
	chest.show_chest(LevelChestTests.sample_rewards(5))
	chest.skip()
	await _host.get_tree().process_frame
	for i: int in flips.size():
		t.set("_insets", flips[i])
		DeviceProfiles.simulate_insets(flips[i])
		await _settle()
		t.check_chest_layout(chest, view, "Furo trocado baú [%s] %s" % [label, _side(flips[i])])
	area.queue_free()
	await _host.get_tree().process_frame


# --- Conferência ------------------------------------------------------------------------

## "Voltar" (se a tela tiver) na posição de sempre a partir da área segura e todo elemento de
## toque visível fora do furo (a parte que aparece: dentro de rolagens, só o trecho à vista).
func _check_inside(screen: Control, view: Vector2, insets: Vector2, state: String, has_back: bool) -> void:
	var safe := DeviceProfiles.safe_rect(view, insets)
	var back: Button = null
	for node: Node in screen.find_children("*", "Button", true, false):
		if node is MenuKit.BackButton:
			back = node as Button
	_check.call(back != null or not has_back, "%s: tem o voltar" % state)
	if back != null:
		var r := back.get_global_rect()
		_check.call(_encloses(safe, r) and is_equal_approx(r.position.x, 4.0 + insets.x),
				"%s: voltar fora do furo (%s em %s)" % [state, r, safe])
	var touched := 0
	for node: Node in screen.find_children("*", "Control", true, false):
		var c := node as Control
		if not _interactive(c) or not c.is_visible_in_tree():
			continue
		var r := _visible_part(c, Rect2(Vector2.ZERO, view))
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		touched += 1
		_check.call(r.position.x >= safe.position.x - EPS and r.end.x <= safe.end.x + EPS,
				"%s: %s \"%s\" fora do furo (%s em %s)" % [state, c.get_class(), c.name, r, safe])
	_check.call(touched > 0, "%s: a tela tem elementos de toque à vista (%d)" % [state, touched])


static func _interactive(c: Control) -> bool:
	return c is BaseButton or (c is Range and not c is ScrollBar) or c is LineEdit


## Trecho do controle que aparece: recortado pelos ancestrais com clip_contents (rolagens).
static func _visible_part(c: Control, view: Rect2) -> Rect2:
	var r := c.get_global_rect().intersection(view)
	var node := c.get_parent()
	while node != null and r.size.x > 0.0 and r.size.y > 0.0:
		if node is Control and ((node as Control).clip_contents or node is ScrollContainer):
			r = r.intersection((node as Control).get_global_rect())
		node = node.get_parent()
	return r


static func _encloses(safe: Rect2, r: Rect2) -> bool:
	return r.position.x >= safe.position.x - EPS and r.end.x <= safe.end.x + EPS \
			and r.position.y >= safe.position.y - EPS and r.end.y <= safe.end.y + EPS


static func _side(insets: Vector2) -> String:
	return "furo à esquerda" if insets.x > 0.0 else "furo à direita"


func _settle() -> void:
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
