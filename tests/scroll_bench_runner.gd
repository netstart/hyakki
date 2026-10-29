extends Node
## Benchmark de rolagem das telas (desempenho, ver "Rolagem suave" no AGENTS.md). Abre o App de
## verdade (fundo animado, tema, telas), na qualidade gráfica Alta, em cada resolução de
## tests/device_profiles.gd, e em cada tela com lista rolável passa o dedo pela lista inteira:
## piparotes (flick) até o fim e de volta ao começo, e um arrasto lento e constante. O dedo é
## simulado como no aparelho (InputEventScreenTouch/ScreenDrag pelo Input, que emula o mouse),
## um passo por quadro. Mede cada quadro (FrameStats): média, p95, p99, pior, quadros longos e
## "travadas" (quadros em que a lista parou no meio do movimento).
##
## Rodar SEM --headless (o custo de desenho precisa contar):
##   godot --path . res://tests/scroll_bench.tscn
##   godot --path . res://tests/scroll_bench.tscn -- --res=585x270 --screens=shop,codex --out=bench.json
## Opções depois de "--":
##   --res=<rótulos>      só estas resoluções (padrão: todas da tabela)
##   --screens=<nomes>    só estas telas (padrão: SCREENS)
##   --fps=<n>            limita o FPS como a opção do jogo (padrão 0 = sem limite e sem VSync:
##                        mede o custo real do quadro; 60/120 medem o ritmo com o limitador)
##   --out=<arquivo.json> grava todos os resultados
##   --no-backdrop        esconde o fundo animado dos menus (para medir quanto ele custa)
##   --strict             sai com erro se algum caso passar dos limites de DESKTOP_LIMITS
##
## Limites no desktop (custo, sem VSync): um quadro de menu rolando tem de caber com folga no
## orçamento de 8,3 ms (120 Hz) mesmo num PC. É o critério de rolagem suave do projeto (AGENTS.md).

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const ResultsLayoutTests := preload("res://tests/results_layout_tests.gd")
const SCREENS: Array[StringName] = [&"heroes", &"stages", &"shop", &"codex", &"options", &"credits",
		&"results", &"sanctuary", &"title"]
## Limites do modo custo (sem VSync) no desktop: p95 e pior quadro (ms), travadas.
const DESKTOP_LIMITS := {"p95_ms": 6.0, "max_ms": 33.0, "stalls": 0}
## Piparote: distância (fração da altura da lista) e duração do gesto.
const FLICK_FRACTION := 0.6
const FLICK_TIME := 0.16
const SLOW_SPEED := 90.0
const SLOW_TIME := 1.2
const SETTLE_FRAMES := 8
const MAX_FLICKS := 14

var _stats := FrameStats.new()
var _measuring := false
var _scroll_probe: ScrollContainer
var _results: Array[Dictionary] = []
var _failures := 0
var _real_files: Dictionary = {}
var _cpu_render := 0.0
var _cpu_frames := 0
var _uncapped := false
var _draw_calls := 0
var _primitives := 0


func _ready() -> void:
	process_priority = -1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	for path: String in [SaveManager.PATH, SaveManager.BACKUP_PATH, Settings.PATH]:
		_real_files[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	SaveManager.use_test_files()
	Settings.use_test_file()
	if DisplayServer.get_name() == "headless":
		printerr("scroll_bench: rode sem --headless (o desenho precisa contar)")
		get_tree().quit(2)
		return
	var fps := int(_arg("fps", "0"))
	_uncapped = fps <= 0
	GfxQuality.set_override(GfxQuality.HIGH)
	Settings.set_value("graphics_quality", "high")
	if fps <= 0:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	else:
		Settings.set_value("fps", fps)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	await _run(fps)
	_finish()


func _arg(key: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % key):
			return arg.substr(key.length() + 3)
	return fallback


func _run(fps: int) -> void:
	_fill_profile()
	var app := (load("res://scenes/app/App.tscn") as PackedScene).instantiate() as App
	add_child(app)
	await get_tree().process_frame
	if fps <= 0:
		# O App aplica o ritmo da opção "fps" (FramePacing) ao abrir: no modo custo, sem limite.
		Engine.max_fps = 0
	for node: Node in app.find_children("*", "SplashScreen", true, false):
		node.get_parent().queue_free()
	if "--no-backdrop" in OS.get_cmdline_user_args():
		var backdrop := app.get("_backdrop") as Control
		backdrop.process_mode = Node.PROCESS_MODE_DISABLED
		backdrop.visibility_changed.connect(func() -> void: backdrop.hide())
		backdrop.hide()
	# Como no jogo: o título abre primeiro (e pré-carrega os scripts das outras telas).
	app.go(&"title")
	await _frames(120)
	var wanted := _arg("screens", "").split(",", false)
	var native := get_window().size
	for res: Dictionary in DeviceProfiles.shot_resolutions():
		await DeviceProfiles.set_window_view(self, res["view"])
		for screen_name: StringName in SCREENS:
			if not wanted.is_empty() and not String(screen_name) in wanted:
				continue
			await _bench_screen(app, screen_name, String(res["label"]), fps)
	app.queue_free()
	DisplayServer.window_set_size(native)


## Perfil cheio (todos os heróis, ryō, bestiário visto) para as listas terem o tamanho de verdade.
func _fill_profile() -> void:
	SaveManager.data = SaveManager.default_profile()
	SaveManager.unlock_all_heroes()
	SaveManager.data["ryo"] = 12840
	SaveManager.data["consent"]["asked"] = true
	SaveManager.data["story"]["intro_seen"] = true


func _bench_screen(app: App, screen_name: StringName, res: String, fps: int) -> void:
	if screen_name == &"results":
		app.last_result = ResultsLayoutTests.make_result("victory", 8)
	var first := not (app.get("_screens") as Dictionary).has(screen_name)
	var opened := Time.get_ticks_usec()
	app.go(screen_name)
	await get_tree().process_frame
	var open_ms := (Time.get_ticks_usec() - opened) / 1000.0
	print("BENCH %s %s abrir%s: %.1f ms" % [res, screen_name, " (1ª vez)" if first else "", open_ms])
	var screen := (app.get("_screens") as Dictionary)[screen_name] as Control
	if screen.has_method("skip_intro"):
		screen.call("skip_intro")
	await _frames(30)
	# Parado: custo do quadro da tela sem tocar em nada (fundo animado e efeitos).
	_begin(null)
	await _frames(90)
	_record(res, screen_name, "parada", fps)
	var scrollers := _scrollers(screen)
	if scrollers.is_empty():
		return
	for scroll: ScrollContainer in scrollers:
		await _bench_scroller(scroll, res, screen_name, fps)


## Listas roláveis visíveis da tela com conteúdo maior que a área (só as que rolam de fato).
func _scrollers(screen: Control) -> Array[ScrollContainer]:
	var list: Array[ScrollContainer] = []
	for node: Node in screen.find_children("*", "ScrollContainer", true, false):
		var scroll := node as ScrollContainer
		var bar := scroll.get_v_scroll_bar()
		if scroll.is_visible_in_tree() and bar.max_value - bar.page > 4.0:
			list.append(scroll)
	return list


func _bench_scroller(scroll: ScrollContainer, res: String, screen_name: StringName, fps: int) -> void:
	scroll.scroll_vertical = 0
	await _frames(10)
	var bar := scroll.get_v_scroll_bar()
	var label := "%s/%s" % [screen_name, scroll.name]
	var area := scroll.get_global_rect()
	var reach := bar.max_value - bar.page
	# Piparotes até o fim e de volta (o dedo sobe para descer a lista e vice-versa).
	_begin(scroll)
	var flicks := 0
	while scroll.scroll_vertical < reach - 1.0 and flicks < MAX_FLICKS:
		await _flick(area, -1.0)
		flicks += 1
	flicks = 0
	while scroll.scroll_vertical > 1 and flicks < MAX_FLICKS:
		await _flick(area, 1.0)
		flicks += 1
	_record(res, screen_name, label + " piparotes", fps)
	# Arrasto lento e contínuo (onde a falta de suavidade aparece mais).
	scroll.scroll_vertical = 0
	await _frames(5)
	_begin(scroll)
	await _drag(area, -SLOW_SPEED, SLOW_TIME)
	_record(res, screen_name, label + " arrasto lento", fps)
	scroll.scroll_vertical = 0


## Um piparote: o dedo anda FLICK_FRACTION da altura em FLICK_TIME e solta; espera assentar.
func _flick(area: Rect2, direction: float) -> void:
	var speed := area.size.y * FLICK_FRACTION / FLICK_TIME
	await _drag(area, direction * speed, FLICK_TIME)
	await _settle()


## Dedo na lista andando `speed` px/s (y; negativo = para cima) por `seconds`, um passo por
## quadro com o tempo real do quadro, e solta.
func _drag(area: Rect2, speed: float, seconds: float) -> void:
	var start := area.get_center() + Vector2(0.0, -signf(speed) * area.size.y * 0.3)
	var finger := start
	_touch(finger, true)
	await get_tree().process_frame
	var elapsed := 0.0
	var last := Time.get_ticks_usec()
	while elapsed < seconds:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1e6
		last = now
		elapsed += dt
		var next := finger + Vector2(0.0, speed * dt)
		next.y = clampf(next.y, area.position.y + 2.0, area.end.y - 2.0)
		_move(finger, next)
		finger = next
	_touch(finger, false)


## Espera a lista parar de verdade antes do próximo gesto. Compara a posição fracionária da
## barra, não `scroll_vertical` (inteiro): sem VSync (~1000 fps) o fim da inércia anda ~0,1 px por
## quadro, o inteiro fica igual por SETTLE_FRAMES quadros e o piparote seguinte começava com a
## lista ainda andando; o toque do dedo a segurava (comportamento certo da lista) e esse quadro
## parado entre dois em movimento era contado como travada. O limite é por tempo (2 s), não por
## quadros, para valer em qualquer FPS.
func _settle() -> void:
	var bar := _scroll_probe.get_v_scroll_bar()
	var still := 0
	var last := bar.value
	var deadline := Time.get_ticks_msec() + 2000
	while still < SETTLE_FRAMES and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if bar.value == last:
			still += 1
		else:
			still = 0
			last = bar.value


func _touch(at: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = _to_window(at)
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _move(from: Vector2, to: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = _to_window(to)
	ev.relative = _to_window(to) - _to_window(from)
	ev.screen_relative = ev.relative
	Input.parse_input_event(ev)


## Ponto lógico (viewport) → janela física (o Input converte de volta pelo stretch).
func _to_window(p: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * p


func _begin(scroll: ScrollContainer) -> void:
	_scroll_probe = scroll
	_stats.reset()
	_cpu_render = 0.0
	_draw_calls = 0
	_primitives = 0
	_cpu_frames = 0
	_measuring = true


func _process(_delta: float) -> void:
	if _uncapped:
		# Qualquer opção salva reaplica o limite de FPS (Settings): no modo custo fica sem limite.
		Engine.max_fps = 0
	if not _measuring:
		return
	if _scroll_probe != null and is_instance_valid(_scroll_probe):
		_stats.tick_scroll(_scroll_probe.get_v_scroll_bar().value)
	else:
		_stats.tick()
	_cpu_render += RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
	_draw_calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	_primitives += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	_cpu_frames += 1


func _record(res: String, screen_name: StringName, label: String, fps: int) -> void:
	_measuring = false
	var s := _stats.summary()
	s["res"] = res
	s["screen"] = String(screen_name)
	s["case"] = label
	s["fps_cap"] = fps
	s["cpu_render_ms"] = _cpu_render / maxi(_cpu_frames, 1)
	s["draw_calls"] = _draw_calls / maxi(_cpu_frames, 1)
	s["primitives"] = _primitives / maxi(_cpu_frames, 1)
	var over := ""
	if fps <= 0 and "--strict" in OS.get_cmdline_user_args():
		for key: String in DESKTOP_LIMITS:
			if s.has(key) and float(s[key]) > float(DESKTOP_LIMITS[key]):
				over += " %s>%s" % [key, DESKTOP_LIMITS[key]]
	if over != "":
		_failures += 1
	_results.append(s)
	var verdict := (" | FALHOU:" + over) if over != "" else ""
	print("BENCH %s %s | %s | render CPU %.2f ms, %d draw calls, %d primitivas%s" % [res, label,
			FrameStats.describe(s), s["cpu_render_ms"], s["draw_calls"], s["primitives"], verdict])


func _frames(n: int) -> void:
	for k: int in range(n):
		await get_tree().process_frame


func _finish() -> void:
	var out := _arg("out", "")
	if out != "":
		var file := FileAccess.open(out, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(_results, "\t"))
	for path: String in SaveManager.TEST_PATHS + [Settings.TEST_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	for path: String in _real_files:
		var now := FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
		if now != _real_files[path]:
			printerr("FALHOU: o benchmark mexeu em %s do jogador" % path)
			_failures += 1
	GfxQuality.clear_override()
	print("%d casos medidos, %d acima dos limites" % [_results.size(), _failures])
	get_tree().quit(1 if _failures > 0 else 0)
