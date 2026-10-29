extends RefCounted
## Testes do desempenho e da rolagem: medidor de quadros (FrameStats), chave da ordem de
## desenho dos inimigos (EnemyManager.order_key) e o
## ritmo de quadros por tela (FramePacing). run_unit roda sem cena (tests/run_tests.gd); run roda
## na árvore (tests/integration_tests.gd): rolagem pelo dedo começando em cima de botões
## (TouchScroll), sem apertar o botão ao arrastar.

const MS := 1000


func run_unit(check: Callable) -> void:
	_test_summary(check)
	_test_stalls(check)
	_test_motion(check)
	_test_order_key(check)
	_test_pacing(check)
	_test_silhouette(check)


func _us(list: Array) -> PackedInt64Array:
	var out := PackedInt64Array()
	for v: Variant in list:
		out.append(int(float(v) * MS))
	return out


func _test_summary(check: Callable) -> void:
	var frames: Array = []
	for k: int in range(19):
		frames.append(10.0)
	frames.append(60.0)
	var s := FrameStats.summarize(_us(frames))
	check.call(int(s["frames"]) == 20 and is_equal_approx(float(s["max_ms"]), 60.0),
			"FrameStats: 20 quadros, pior 60 ms")
	check.call(is_equal_approx(float(s["p95_ms"]), 10.0) and is_equal_approx(float(s["p99_ms"]), 60.0),
			"FrameStats: p95 = 10 ms e p99 = 60 ms (posto mais próximo)")
	check.call(int(s["over_20"]) == 1 and int(s["over_33"]) == 1 and int(s["over_50"]) == 1,
			"FrameStats: um quadro acima de 20/33/50 ms")
	check.call(is_equal_approx(float(s["avg_ms"]), 12.5) and is_equal_approx(float(s["fps"]), 80.0),
			"FrameStats: média 12,5 ms (80 fps)")
	check.call(int(FrameStats.summarize(PackedInt64Array())["frames"]) == 0
			and FrameStats.percentile(PackedInt64Array(), 0.95) == 0.0, "FrameStats: lista vazia não quebra")
	check.call(FrameStats.describe(s).contains("p95 10.00"), "FrameStats: descrição legível")


func _test_stalls(check: Callable) -> void:
	var frames := _us([16.6, 16.6, 16.6, 16.6, 16.6])
	var stall := PackedFloat32Array([0, 5, 10, 10, 15, 20])
	check.call(FrameStats.scroll_stalls(frames, stall) == 1, "FrameStats: quadro parado no meio do movimento é travada")
	var stop := PackedFloat32Array([0, 5, 10, 10, 10, 10])
	check.call(FrameStats.scroll_stalls(frames, stop) == 0, "FrameStats: parar no fim do movimento não é travada")
	var slow := PackedFloat32Array([0, 0.3, 0.6, 0.6, 0.9, 1.2])
	check.call(FrameStats.scroll_stalls(frames, slow) == 0, "FrameStats: rolagem muito lenta parada 1 quadro não conta")
	var stats := FrameStats.new()
	stats.frames_us = frames
	stats.scroll = stall
	var s := stats.summary()
	check.call(int(s["stalls"]) == 1 and is_equal_approx(float(s["distance"]), 20.0),
			"FrameStats: resumo traz travadas e distância percorrida")


func _test_motion(check: Callable) -> void:
	var stats := FrameStats.new()
	# 10 quadros parados de 100 ms (espera do adb), 6 em movimento de 16 ms, 10 parados.
	var positions: Array = []
	var frames: Array = []
	var y := 0.0
	positions.append(y)
	for k: int in range(10):
		frames.append(100.0)
		positions.append(y)
	for k: int in range(6):
		frames.append(16.0)
		y += 8.0
		positions.append(y)
	for k: int in range(10):
		frames.append(100.0)
		positions.append(y)
	stats.frames_us = _us(frames)
	stats.scroll = PackedFloat32Array(positions)
	var s := stats.motion_summary(1)
	check.call(int(s["frames"]) == 8, "FrameStats: só o movimento conta (6 quadros + 1 de cada lado; %d)" % s["frames"])
	check.call(is_equal_approx(float(s["distance"]), 48.0), "FrameStats: distância do movimento (48 px)")
	check.call(int(FrameStats.new().motion_summary()["frames"]) == 0, "FrameStats: sem medição, resumo vazio")


func _test_order_key(check: Callable) -> void:
	var ys: Array[float] = [12.5, -300.0, 12.5, 4000.0, -0.04, 0.0, 12.53]
	var keys := PackedInt64Array()
	for i: int in range(ys.size()):
		keys.append(EnemyManager.order_key(ys[i], i))
	keys.sort()
	var order: Array[int] = []
	for key: int in keys:
		order.append(key & EnemyManager.ORDER_INDEX_MASK)
	check.call(order == [1, 4, 5, 0, 2, 6, 3], "Inimigos: ordem de desenho por Y, empate pelo índice (%s)" % [order])
	check.call(EnemyManager.CAPACITY <= EnemyManager.ORDER_INDEX_MASK + 1, "Inimigos: índice cabe na chave da ordem")
	check.call(EnemyManager.order_key(1e12, 639) > EnemyManager.order_key(-1e12, 0),
			"Inimigos: Y extremo não estoura a chave")


func _test_pacing(check: Callable) -> void:
	check.call(FramePacing.max_fps_for(60, 60.0, true) == 0,
			"Ritmo: 60 FPS numa tela de 60 Hz deixa o VSync ditar o ritmo")
	check.call(FramePacing.max_fps_for(120, 120.0, true) == 0, "Ritmo: 120 FPS numa tela de 120 Hz sem limitador")
	check.call(FramePacing.max_fps_for(120, 60.0, true) == 0, "Ritmo: pedir mais que a tela não limita (VSync)")
	check.call(FramePacing.max_fps_for(60, 120.0, true) == 60, "Ritmo: 60 FPS numa tela de 120 Hz limita a 60")
	check.call(FramePacing.max_fps_for(30, 60.0, true) == 30, "Ritmo: 30 FPS limita a 30")
	check.call(FramePacing.max_fps_for(60, 59.94, true) == 0, "Ritmo: tela de 59,94 Hz conta como 60")
	check.call(FramePacing.max_fps_for(60, -1.0, true) == 60, "Ritmo: taxa desconhecida mantém o limite")
	check.call(FramePacing.max_fps_for(60, 60.0, false) == 60, "Ritmo: no PC o limite da opção vale como antes")


## Silhueta dos bloqueados (MenuKit.silhouette_images): pixel a pixel igual ao jeito antigo
## (get_pixel/set_pixel), em folhas de inimigo, chefe e herói, e bem mais rápida.
func _test_silhouette(check: Callable) -> void:
	var fill := Color(0.3, 0.2, 0.13)
	var rim := Color(0.55, 0.38, 0.24, 0.9)
	for path: String in ["res://assets/art/actors/enemies/oni_red/SpriteSheet.png",
			"res://assets/art/actors/enemies/kitsune/SpriteSheet.png", "res://assets/art/actors/heroes/aki/SpriteSheet.png"]:
		var src := (load(path) as Texture2D).get_image()
		if src.is_compressed():
			src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		var t0 := Time.get_ticks_usec()
		var fast := MenuKit.silhouette_images(src, fill, rim)
		var t1 := Time.get_ticks_usec()
		var slow := _silhouette_reference(src, fill, rim)
		var t2 := Time.get_ticks_usec()
		check.call(fast[0].get_data() == slow[0].get_data() and fast[1].get_data() == slow[1].get_data(),
				"Silhueta: igual ao método antigo em %s (%.1f ms × %.1f ms)" % [path.get_base_dir().get_file(),
				(t1 - t0) / 1000.0, (t2 - t1) / 1000.0])


## Partículas (FxLayer): o passo e o desenho percorrem só a janela das vivas. Em sequências com
## vidas diferentes, quadros com e sem partícula e o anel dando a volta, toda partícula viva fica
## dentro dos trechos desenhados, sem índice repetido e em ordem crescente (a ordem de antes), e
## o passo envelhece exatamente as vivas.
func _test_particle_window(host: Node, check: Callable) -> void:
	var fx := FxLayer.new()
	host.add_child(fx)
	await host.get_tree().process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var cap: int = FxLayer.particles_max
	var covered := true
	var ordered := true
	var aged := true
	var empty_ok := true
	for frame: int in range(240):
		var burst := 0 if frame % 37 < 6 else rng.randi_range(0, 40)
		if frame == 120:
			burst = cap + 50
		for k: int in range(burst):
			fx.call("_emit", 0, Vector2.ZERO, Vector2(10, 0), rng.randf_range(0.05, 1.2), Color.WHITE, 1.0)
		var spans: Array[Vector2i] = fx.call("_particle_spans")
		var seen := {}
		var last := -1
		for span: Vector2i in spans:
			for i: int in range(span.x, span.y):
				ordered = ordered and i > last
				last = i
				seen[i] = true
		var lives: PackedFloat32Array = fx.get("_p_life")
		var before := lives.duplicate()
		for i: int in range(cap):
			if lives[i] > 0.0 and not seen.has(i):
				covered = false
		if fx.particles_alive() == 0:
			empty_ok = empty_ok and spans.is_empty()
		fx.step(1.0 / 60.0)
		lives = fx.get("_p_life")
		for i: int in range(cap):
			var expect := before[i] - 1.0 / 60.0 * fx.time_scale if before[i] > 0.0 else before[i]
			if not is_equal_approx(lives[i], expect):
				aged = false
	check.call(covered, "Partículas: toda partícula viva fica na janela desenhada (anel dando a volta incluído)")
	check.call(ordered, "Partículas: janela em ordem crescente de índice, sem repetir (mesma ordem de desenho)")
	check.call(aged, "Partículas: o passo envelhece exatamente as vivas")
	check.call(empty_ok, "Partículas: sem partícula viva, nada é percorrido")
	fx.queue_free()
	await host.get_tree().process_frame


## Folhas de todos os inimigos, chefes e heróis (e da procissão do fundo dos menus): o atalho
## nativo de silhueta/contorno (SpriteSheet e MenuKit) dá exatamente os mesmos pixels do laço.
func _test_sheet_masks(check: Callable) -> void:
	var paths: Dictionary = {}
	for id: StringName in DB.ids("enemies"):
		paths[String(DB.enemies[id].get("sprite", ""))] = true
	for id: StringName in DB.ids("bosses"):
		paths[String((DB.bosses[id]["sprite"] as Dictionary)["path"])] = true
	for id: StringName in DB.ids("heroes"):
		paths[String(DB.heroes[id].get("sprite", ""))] = true
	for path: String in MenuBackdrop.WALKER_PATHS:
		paths[path] = true
	var same := 0
	var failed: PackedStringArray = []
	var fast_us := 0
	var slow_us := 0
	for path: String in paths:
		if path == "" or not ResourceLoader.exists(path):
			continue
		var src := (load(path) as Texture2D).get_image()
		if src.is_compressed():
			src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		var gold := Color("ffd166")
		var t0 := Time.get_ticks_usec()
		var flash := SpriteSheet._silhouette(src, Color.WHITE).get_data()
		var outline := SpriteSheet._outline(src, gold).get_data()
		var pair := MenuKit.silhouette_images(src, Color(0.3, 0.2, 0.13), Color(0.55, 0.38, 0.24, 0.9))
		var t1 := Time.get_ticks_usec()
		var ok := flash == SpriteSheet.silhouette_exact(src, Color.WHITE).get_data()
		ok = ok and outline == SpriteSheet.outline_exact(src, gold).get_data()
		var ref := _silhouette_reference(src, Color(0.3, 0.2, 0.13), Color(0.55, 0.38, 0.24, 0.9))
		slow_us += Time.get_ticks_usec() - t1
		fast_us += t1 - t0
		ok = ok and pair[0].get_data() == ref[0].get_data() and pair[1].get_data() == ref[1].get_data()
		if ok:
			same += 1
		else:
			failed.append(path.get_base_dir().get_file())
	check.call(failed.is_empty() and same >= 40,
			"Folhas: silhueta, contorno e silhueta do Diário iguais ao laço em %d folhas %s" % [same, failed])
	check.call(fast_us * 4 < slow_us, "Folhas: atalho nativo mais rápido que o laço (%.0f ms × %.0f ms)" % [
			fast_us / 1000.0, slow_us / 1000.0])


static func _silhouette_reference(src: Image, fill: Color, rim: Color) -> Array[Image]:
	var w := src.get_width()
	var h := src.get_height()
	var body := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var edge := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			if src.get_pixel(x, y).a > 0.3:
				body.set_pixel(x, y, fill)
				continue
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p := Vector2i(x, y) + o
				if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and src.get_pixelv(p).a > 0.3:
					edge.set_pixel(x, y, rim)
					break
	return [body, edge]


## Na árvore: rolagem pelo dedo começando em cima de botões e painéis (TouchScroll).
func run(host: Node, check: Callable) -> void:
	_test_sheet_masks(check)
	await _test_particle_window(host, check)
	TouchScroll.install(host.get_tree())
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 20)
	scroll.size = Vector2(160, 120)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var presses := [0]
	var buttons: Array[Button] = []
	for k: int in range(10):
		var card := PanelContainer.new()
		var b := Button.new()
		b.text = "item %d" % k
		b.custom_minimum_size = Vector2(140, 36)
		b.pressed.connect(func() -> void: presses[0] += 1)
		card.add_child(b)
		list.add_child(card)
		buttons.append(b)
	var slider := HSlider.new()
	list.add_child(slider)
	var recipe := RichTextLabel.new()
	recipe.scroll_active = false
	recipe.fit_content = true
	recipe.text = "texto"
	list.add_child(recipe)
	host.add_child(scroll)
	await host.get_tree().process_frame
	TouchScroll.adopt_all(scroll)
	check.call(buttons.all(func(b: Button) -> bool: return b.mouse_filter == Control.MOUSE_FILTER_PASS)
			and (buttons[0].get_parent() as Control).mouse_filter == Control.MOUSE_FILTER_PASS,
			"Rolagem pelo dedo: botões e cartões da lista deixam o toque chegar à lista")
	check.call(slider.mouse_filter == Control.MOUSE_FILTER_STOP,
			"Rolagem pelo dedo: slider continua com o arrasto dele")
	check.call(recipe.mouse_filter == Control.MOUSE_FILTER_PASS,
			"Rolagem pelo dedo: texto sem rolagem própria não segura o arrasto")
	check.call(scroll.get_v_scroll_bar().mouse_filter == Control.MOUSE_FILTER_STOP,
			"Rolagem pelo dedo: a barra da lista continua arrastável")
	var outside := Button.new()
	host.add_child(outside)
	await host.get_tree().process_frame
	check.call(outside.mouse_filter == Control.MOUSE_FILTER_STOP, "Rolagem pelo dedo: botão fora de lista não muda")
	outside.queue_free()
	# Arrasto começando em cima do 2º botão: a lista rola e o botão não é apertado.
	var start := buttons[1].get_global_rect().get_center()
	await _drag(host, start, start + Vector2(0, -70), 8)
	check.call(scroll.scroll_vertical > 20,
			"Rolagem pelo dedo: arrastar sobre um botão rola a lista (%d px)" % scroll.scroll_vertical)
	check.call(presses[0] == 0, "Rolagem pelo dedo: arrastar não aperta o botão de baixo do dedo")
	# Toque parado num botão ainda aperta.
	var tap := buttons[4].get_global_rect().get_center()
	await _drag(host, tap, tap, 1)
	check.call(presses[0] == 1, "Rolagem pelo dedo: toque parado no botão aperta (%d)" % presses[0])
	# Reamostragem: um quadro sem posição nova no meio do arrasto anda meio passo, e a posição
	# seguinte é a exata (igual ao arrasto sem reamostragem).
	var with_gap := await _gap_drag(host, scroll, buttons[2].get_global_rect().get_center(), true)
	var raw := await _gap_drag(host, scroll, buttons[2].get_global_rect().get_center(), false)
	check.call(raw[1] == raw[0] and with_gap[1] > with_gap[0] and with_gap[1] - with_gap[0] <= with_gap[0] - with_gap[3],
			"Rolagem pelo dedo: quadro sem toque novo no meio do arrasto anda meio passo (%.1f → %.1f; cru %.1f → %.1f)" % [
				with_gap[0], with_gap[1], raw[0], raw[1]])
	check.call(is_equal_approx(with_gap[2], raw[2]),
			"Rolagem pelo dedo: o toque seguinte volta à posição exata do dedo (%.1f = %.1f)" % [with_gap[2], raw[2]])
	scroll.queue_free()
	await host.get_tree().process_frame


## Arrasto com um quadro sem evento no meio: [valor antes do buraco, valor no buraco, valor depois
## do toque seguinte, valor um passo antes do buraco].
func _gap_drag(host: Node, scroll: ScrollContainer, start: Vector2, resample: bool) -> Array[float]:
	TouchScroll.resample = resample
	scroll.scroll_vertical = 0
	await host.get_tree().process_frame
	var final := host.get_viewport().get_final_transform()
	var touch := InputEventScreenTouch.new()
	touch.position = final * start
	touch.pressed = true
	Input.parse_input_event(touch)
	await host.get_tree().process_frame
	var at := start
	var values: Array[float] = []
	for k: int in range(7):
		if k != 5:
			var drag := InputEventScreenDrag.new()
			drag.position = final * (at + Vector2(0, -8))
			drag.relative = final.basis_xform(Vector2(0, -8))
			drag.screen_relative = drag.relative
			at += Vector2(0, -8)
			Input.parse_input_event(drag)
		await host.get_tree().process_frame
		values.append(scroll.get_v_scroll_bar().value)
	var release := InputEventScreenTouch.new()
	release.position = final * at
	release.pressed = false
	Input.parse_input_event(release)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TouchScroll.resample = true
	return [values[4], values[5], values[6], values[3]]


## Dedo de `from` a `to` em `steps` quadros (toque, arrastos e soltura pelo Input, como no aparelho).
func _drag(host: Node, from: Vector2, to: Vector2, steps: int) -> void:
	var final := host.get_viewport().get_final_transform()
	var touch := InputEventScreenTouch.new()
	touch.position = final * from
	touch.pressed = true
	Input.parse_input_event(touch)
	await host.get_tree().process_frame
	var last := from
	for k: int in range(1, steps + 1):
		var at := from.lerp(to, float(k) / steps)
		if at != last:
			var drag := InputEventScreenDrag.new()
			drag.position = final * at
			drag.relative = final.basis_xform(at - last)
			drag.screen_relative = drag.relative
			Input.parse_input_event(drag)
		last = at
		await host.get_tree().process_frame
	var release := InputEventScreenTouch.new()
	release.position = final * to
	release.pressed = false
	Input.parse_input_event(release)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
