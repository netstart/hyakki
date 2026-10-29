extends Node
## Benchmark da partida renderizada (desempenho): abre a cena da partida com os argumentos da
## linha de comando (os mesmos do teste de estresse) na qualidade Alta e mede cada quadro
## (FrameStats) depois de um aquecimento, sem VSync e sem limite de FPS (custo real do quadro,
## simulação + desenho). Rodar SEM --headless:
##   godot --path . res://tests/game_bench.tscn -- --bot --seed=7 --stress=500 --bench-seconds=20
## Imprime "BENCH partida | <resumo> | render CPU, chamadas de desenho, primitivas" e sai.
## Opções: --native-strokes desenha arcos e polilinhas pelo caminho antigo do motor (Stroke.native),
## para comparar o custo; --compare-shots=<pasta> no fim pausa a partida e desenha o mesmo quadro
## pelos dois caminhos, grava as capturas e conta os pixels diferentes.

const WARMUP := 4.0

var _stats := FrameStats.new()
var _measuring := false
var _render_ms := 0.0
var _draw_calls := 0
var _primitives := 0
var _frames := 0
var _strokes := 0


func _ready() -> void:
	process_priority = -1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.use_test_files()
	Settings.use_test_file()
	GfxQuality.set_override(GfxQuality.HIGH)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var seconds := 20.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--bench-seconds="):
			seconds = arg.get_slice("=", 1).to_float()
	Stroke.native = "--native-strokes" in OS.get_cmdline_user_args()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var game := (load("res://scenes/game/Game.tscn") as PackedScene).instantiate()
	add_child(game)
	Engine.max_fps = 0
	await get_tree().create_timer(WARMUP, true, false, true).timeout
	Engine.max_fps = 0
	_measuring = true
	await get_tree().create_timer(seconds, true, false, true).timeout
	_measuring = false
	var s := _stats.summary()
	var enemies: Variant = game.get("enemies")
	var alive := int((enemies as Node).get("count_alive")) if enemies is Node else -1
	var n := maxi(_frames, 1)
	print("BENCH partida%s | %s | render CPU %.2f ms, %d chamadas de desenho, %d primitivas, %.1f traços/quadro"
			% [" (traços do motor)" if Stroke.native else "", FrameStats.describe(s), _render_ms / n, _draw_calls / n,
			_primitives / n, float(_strokes) / n] + " | sim %.2f ms | inimigos %d" % [GameClock.last_sim_ms, alive])
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--compare-shots="):
			await _compare(game, arg.get_slice("=", 1))
	GfxQuality.clear_override()
	for path: String in SaveManager.TEST_PATHS + [Settings.TEST_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	get_tree().quit()


func _process(_delta: float) -> void:
	if _measuring:
		_stats.tick()
		_render_ms += RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
		_draw_calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		_primitives += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		_strokes += Stroke.drawn
		_frames += 1
	Stroke.drawn = 0


## Mesmo quadro (partida pausada) desenhado com os traços antigos e com o Stroke: capturas e
## contagem de pixels diferentes (as duas formas têm de dar a mesma imagem).
func _compare(game: Node, dir: String) -> void:
	# Congela tudo (delta 0): a partida, as animações e as partículas param no mesmo quadro.
	Engine.time_scale = 0.0
	for k: int in range(3):
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(dir)
	var shots: Array[Image] = []
	# Motor duas vezes (o que muda sozinho entre dois desenhos do mesmo quadro) e depois o Stroke.
	for native: bool in [true, true, false]:
		Stroke.native = native
		for node: Node in game.find_children("*", "CanvasItem", true, false):
			(node as CanvasItem).queue_redraw()
		for k: int in range(3):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.save_png(dir.path_join("partida_%d_%s.png" % [shots.size(), "motor" if native else "stroke"]))
		shots.append(img)
	print("COMPARA partida: motor × motor %s; motor × Stroke %s" % [_diff(shots[0], shots[1]), _diff(shots[1], shots[2])])
	Engine.time_scale = 1.0
	Stroke.native = false


static func _diff(x: Image, y: Image) -> String:
	var a := x.get_data()
	var b := y.get_data()
	var off := 0
	var worst := 0
	for j: int in range(0, a.size(), 4):
		var d := maxi(maxi(absi(a[j] - b[j]), absi(a[j + 1] - b[j + 1])), absi(a[j + 2] - b[j + 2]))
		worst = maxi(worst, d)
		if d > 2:
			off += 1
	return "%d pixels com diferença > 2 (maior %d)" % [off, worst]
