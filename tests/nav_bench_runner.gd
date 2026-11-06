extends Node
## Benchmark da navegação entre os menus (desempenho, ver "Rolagem suave e desempenho" no AGENTS.md).
## Abre o App de verdade (fundo animado, tema, telas), na qualidade gráfica Alta, em cada resolução
## de tests/device_profiles.gd, e para cada tela aberta pelo título faz título → tela → "voltar"
## várias vezes. O "voltar" é o mesmo do Android (NOTIFICATION_WM_GO_BACK_REQUEST no App).
## Mede, em cada troca:
##   - o custo dos quadros logo depois do go() (pior e p95 dos SWITCH_FRAMES primeiros quadros,
##     sem VSync: o custo real) e o tempo da própria chamada;
##   - as piscadas do título (tests/nav_probe.gd): quadro a quadro, a transparência acumulada e o
##     deslocamento de entrada do título, do saldo, das metas, de cada linha do menu e do bloco de
##     ação. Piscada = um nó que estava no lugar volta para o começo da entrada (ou some e volta).
##     Ao voltar de um submenu o título não pode nem piscar nem refazer a entrada (nenhum quadro com
##     nó fora do lugar); vindo dos Resultados (partida) a entrada toca, mas sem piscar.
##
## Rodar SEM --headless (o custo de desenho precisa contar):
##   godot --path . res://tests/nav_bench.tscn
##   godot --path . res://tests/nav_bench.tscn -- --res=585x270 --screens=shop,heroes --out=nav.json
## Opções depois de "--":
##   --res=<rótulos>      só estas resoluções (padrão: todas da tabela)
##   --shard=k/N          só a parte k de N das resoluções (blocos contíguos)
##   --screens=<nomes>    só estas telas (padrão: SCREENS)
##   --cycles=<n>         idas e voltas por tela (padrão 3; a 1ª abertura de cada tela fica à parte)
##   --out=<arquivo.json> grava todos os resultados
##   --strict             sai com erro se alguma troca passar de DESKTOP_LIMITS ou piscar
##   --strict-flicker     só as piscadas e o título refazendo a entrada reprovam (os ms são impressos,
##                        sem limite): o tools/run_checks usa este, em paralelo com as outras tarefas

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const ResultsLayoutTests := preload("res://tests/results_layout_tests.gd")
const NavProbe := preload("res://tests/nav_probe.gd")
## Telas abertas a partir do título ("results" volta ao título como depois de uma partida).
const SCREENS: Array[StringName] = [&"heroes", &"stages", &"sanctuary", &"shop", &"codex", &"options",
		&"credits", &"results"]
## Quadros medidos depois de cada troca (custo) e quanto tempo o título é observado (piscadas:
## cobre a entrada inteira, ~0,5 s).
const SWITCH_FRAMES := 10
const WATCH_TIME := 0.8
## Tempo parado na tela antes de voltar (as entradas das telas terminam).
const STAY_TIME := 0.6
## Limites do modo custo (sem VSync) no desktop: pior quadro e p95 da volta ao título (ms) e
## piscadas (em toda troca observada).
const DESKTOP_LIMITS := {"max_ms": 33.0, "p95_ms": 20.0, "flickers": 0}

var _results: Array[Dictionary] = []
var _failures := 0
var _real_files: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for path: String in [SaveManager.PATH, SaveManager.BACKUP_PATH, Settings.PATH]:
		_real_files[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	SaveManager.use_test_files()
	Settings.use_test_file()
	if DisplayServer.get_name() == "headless":
		printerr("nav_bench: rode sem --headless (o desenho precisa contar)")
		get_tree().quit(2)
		return
	GfxQuality.set_override(GfxQuality.HIGH)
	Settings.set_value("graphics_quality", "high")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _run()
	_finish()


func _arg(key: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % key):
			return arg.substr(key.length() + 3)
	return fallback


func _process(_delta: float) -> void:
	# Qualquer opção salva reaplica o limite de FPS (Settings): no modo custo fica sem limite.
	Engine.max_fps = 0


func _run() -> void:
	_fill_profile()
	var app := (load("res://scenes/app/App.tscn") as PackedScene).instantiate() as App
	add_child(app)
	await get_tree().process_frame
	Engine.max_fps = 0
	for node: Node in app.find_children("*", "SplashScreen", true, false):
		node.get_parent().queue_free()
	var wanted := _arg("screens", "").split(",", false)
	var cycles := maxi(1, int(_arg("cycles", "3")))
	var native := get_window().size
	var first := true
	# --shard=k/N: só a parte k das resoluções (tools/run_checks reparte o benchmark em N processos).
	for res: Dictionary in DeviceProfiles.shard_items(DeviceProfiles.shot_resolutions()):
		await DeviceProfiles.set_window_view(self, res["view"])
		var label := String(res["label"])
		if first:
			# 1ª aparição do título na sessão (abertura a frio): a entrada toca, sem piscar.
			var cold := await _switch(app, func() -> void: app.go(&"title"), true)
			_report(label, &"title", "1ª vez", [cold], true)
			first = false
		else:
			app.go(&"title")
		await _wait(STAY_TIME)
		for screen_name: StringName in SCREENS:
			if not wanted.is_empty() and not String(screen_name) in wanted:
				continue
			await _bench_screen(app, screen_name, label, cycles)
	app.queue_free()
	DisplayServer.window_set_size(native)


## Perfil cheio (todos os heróis, ryō, bestiário visto), como nas telas de verdade.
func _fill_profile() -> void:
	SaveManager.data = SaveManager.default_profile()
	SaveManager.unlock_all_heroes()
	SaveManager.data["ryo"] = 12840
	SaveManager.data["consent"]["asked"] = true
	SaveManager.data["story"]["intro_seen"] = true


func _bench_screen(app: App, screen_name: StringName, res: String, cycles: int) -> void:
	if screen_name == &"results":
		app.last_result = ResultsLayoutTests.make_result("victory", 8)
	var opens: Array[Dictionary] = []
	var backs: Array[Dictionary] = []
	var first_open := {}
	var built := (app.get("_screens") as Dictionary).has(screen_name)
	for cycle: int in cycles + (0 if built else 1):
		var fwd := await _switch(app, func() -> void: app.go(screen_name), false)
		if cycle == 0 and not built:
			first_open = fwd
		else:
			opens.append(fwd)
		await _wait(STAY_TIME)
		var back := await _switch(app, func() -> void: app.notification(NOTIFICATION_WM_GO_BACK_REQUEST), true)
		backs.append(back)
		await _wait(STAY_TIME)
	if not first_open.is_empty():
		_report(res, screen_name, "abrir (1ª vez)", [first_open], false)
	_report(res, screen_name, "abrir", opens, false)
	# Dos Resultados (fim de partida) a entrada do título toca de propósito: só não pode piscar.
	_report(res, screen_name, "voltar", backs, true, screen_name != &"results")


## Uma troca: chama `action` no começo de um quadro e mede os quadros seguintes; com `watch`,
## observa o título por WATCH_TIME.
func _switch(app: App, action: Callable, watch: bool) -> Dictionary:
	await get_tree().process_frame
	var start := Time.get_ticks_usec()
	action.call()
	var call_us := Time.get_ticks_usec() - start
	var title := (app.get("_screens") as Dictionary).get(&"title") as Control
	var nodes: Array[Dictionary] = []
	if watch and title != null:
		nodes = NavProbe.title_nodes(title)
	var frames := PackedInt64Array()
	var samples: Array[PackedFloat32Array] = []
	var last := start
	while frames.size() < SWITCH_FRAMES or (watch and (Time.get_ticks_usec() - start) / 1e6 < WATCH_TIME):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frames.append(now - last)
		last = now
		if not nodes.is_empty():
			samples.append(NavProbe.sample(title, nodes))
	var out := {"call_ms": call_us / 1000.0, "switch_us": frames.slice(0, SWITCH_FRAMES)}
	if not nodes.is_empty():
		out.merge(NavProbe.summarize(nodes, samples))
	return out


## Junta as trocas do mesmo caso e confere os limites. `still`: o título tem de ficar parado.
func _report(res: String, screen_name: StringName, kind: String, runs: Array, watch: bool,
		still: bool = false) -> void:
	if runs.is_empty():
		return
	var all := PackedInt64Array()
	var call_ms := 0.0
	var flickers := 0
	var unsettled := 0
	var names: PackedStringArray = []
	for run: Dictionary in runs:
		all.append_array(run["switch_us"])
		call_ms = maxf(call_ms, float(run["call_ms"]))
		flickers += int(run.get("flickers", 0))
		unsettled += int(run.get("unsettled_frames", 0))
		for n: String in run.get("flicker_nodes", PackedStringArray()):
			if not n in names:
				names.append(n)
	var s := FrameStats.summarize(all)
	var entry := {"res": res, "screen": String(screen_name), "case": kind, "runs": runs.size(),
			"max_ms": s["max_ms"], "p95_ms": s["p95_ms"], "call_ms": call_ms}
	if watch:
		entry["flickers"] = flickers
		entry["unsettled_frames"] = unsettled
		entry["flicker_nodes"] = names
	var over := ""
	var strict := "--strict" in OS.get_cmdline_user_args()
	if strict or "--strict-flicker" in OS.get_cmdline_user_args():
		for key: String in DESKTOP_LIMITS:
			# Custo: só a volta ao título (aberturas medidas e impressas, sem limite por enquanto); com
			# --strict-flicker, nenhum limite de ms (a disputa de CPU do run_checks muda os tempos).
			if key != "flickers" and (kind != "voltar" or not strict):
				continue
			if entry.has(key) and float(entry[key]) > float(DESKTOP_LIMITS[key]):
				over += " %s>%s" % [key, DESKTOP_LIMITS[key]]
		if still and unsettled > 0:
			over += " título refez a entrada (%d quadros)" % unsettled
	if over != "":
		_failures += 1
	_results.append(entry)
	var watch_text := ""
	if watch:
		watch_text = " | piscadas %d%s, quadros fora do lugar %d" % [flickers,
				(" (" + ",".join(names) + ")") if not names.is_empty() else "", unsettled]
	print("NAV %s %s %s | troca: pior %.2f ms, p95 %.2f ms, chamada %.2f ms%s%s" % [res, screen_name, kind,
			entry["max_ms"], entry["p95_ms"], call_ms, watch_text, (" | FALHOU:" + over) if over != "" else ""])


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_usec() + int(seconds * 1e6)
	while Time.get_ticks_usec() < until:
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
