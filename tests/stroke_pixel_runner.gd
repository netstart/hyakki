extends Node
## Confere pixel a pixel que os traços do Stroke (primitivas, sem buffer de polígono) saem iguais
## aos do Godot (draw_arc, draw_polyline, draw_polyline_colors, draw_colored_polygon), nos mesmos
## tamanhos e cores usados pelos efeitos da partida. Precisa desenhar de verdade: rodar SEM
## --headless:
##   godot --path . res://tests/stroke_pixel_tests.tscn
## Cada caso é desenhado das duas formas, lado a lado, sobre o mesmo fundo; a diferença máxima
## aceita é de 2 níveis de cor (arredondamento da interpolação) em nenhum ou poucos pixels.

const CELL := Vector2(72, 72)
const TOLERANCE := 2
## Pixels que podem diferir além da tolerância por caso (diagonal do quadrilátero em cantos).
const MAX_OFF_PIXELS := 2

var _count := 0
var _failures := 0
var _cases: Array[Callable] = []


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("stroke_pixel_tests: rode sem --headless")
		get_tree().quit(2)
		return
	_build_cases()
	# Tela própria grande o bastante para todos os casos (a janela do jogo é pequena).
	var view := SubViewport.new()
	view.size = Vector2i(int(CELL.x) * 8, int(CELL.y) * 2 * ceili(_cases.size() / 8.0))
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.snap_2d_transforms_to_pixel = get_viewport().snap_2d_transforms_to_pixel
	view.snap_2d_vertices_to_pixel = get_viewport().snap_2d_vertices_to_pixel
	add_child(view)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.2)
	bg.size = Vector2(view.size)
	view.add_child(bg)
	var native := Control.new()
	var ours := Control.new()
	for c: Control in [native, ours]:
		c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		view.add_child(c)
	for i: int in range(_cases.size()):
		var at := Vector2((i % 8) * CELL.x, floorf(i / 8.0) * CELL.y * 2.0)
		native.draw.connect(func() -> void:
			native.draw_set_transform(at)
			_cases[i].call(native, false))
		ours.draw.connect(func() -> void:
			ours.draw_set_transform(at + Vector2(0, CELL.y))
			_cases[i].call(ours, true))
	for k: int in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := view.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	for i: int in range(_cases.size()):
		var at := Vector2i(Vector2((i % 8) * CELL.x, floorf(i / 8.0) * CELL.y * 2.0))
		var a := img.get_region(Rect2i(at, Vector2i(CELL))).get_data()
		var b := img.get_region(Rect2i(at + Vector2i(0, int(CELL.y)), Vector2i(CELL))).get_data()
		var off := 0
		var worst := 0
		for j: int in range(0, a.size(), 4):
			var d := maxi(maxi(absi(a[j] - b[j]), absi(a[j + 1] - b[j + 1])), absi(a[j + 2] - b[j + 2]))
			worst = maxi(worst, d)
			if d > TOLERANCE:
				off += 1
		_check(off <= MAX_OFF_PIXELS, "Stroke caso %d igual ao Godot (%d pixels fora, maior diferença %d)" % [i, off, worst])
	print("%d verificações, %d falhas" % [_count, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## Casos com os parâmetros dos efeitos do jogo (anéis de área, aura, coleta, marcas de raio,
## rastros de projétil com degradê, setas e leques).
func _build_cases() -> void:
	var c := CELL * 0.5
	for spec: Array in [[30.0, 32, 1.0], [24.0, 48, 3.0], [20.0, 48, 5.0], [7.0, 12, 1.0], [12.0, 20, 1.0],
			[28.0, 40, 1.0], [10.0, 16, 1.5], [33.5, 24, 1.0]]:
		_cases.append(func(ci: CanvasItem, mine: bool) -> void:
			var col := Color(1.0, 0.8, 0.4, 0.8)
			if mine:
				Stroke.arc(ci, c, spec[0], 0.0, TAU, spec[1], col, spec[2])
			else:
				ci.draw_arc(c, spec[0], 0.0, TAU, spec[1], col, spec[2]))
	for spec: Array in [[0.3, 2.1, 14, 1.5], [PI, TAU - 0.2, 12, 1.0], [-PI * 0.5, PI, 32, 3.0], [0.0, 0.35, 6, 1.0]]:
		_cases.append(func(ci: CanvasItem, mine: bool) -> void:
			var col := Color(0.5, 0.75, 1.0, 0.9)
			if mine:
				Stroke.arc(ci, c, 25.0, spec[0], spec[1], spec[2], col, spec[3])
			else:
				ci.draw_arc(c, 25.0, spec[0], spec[1], spec[2], col, spec[3]))
	var zigzag := PackedVector2Array([Vector2(6, 60), Vector2(20, 12), Vector2(34, 58), Vector2(50, 14), Vector2(66, 40)])
	for width: float in [1.0, 3.0, 7.0]:
		_cases.append(func(ci: CanvasItem, mine: bool) -> void:
			var col := Color(1, 1, 1, 0.7)
			if mine:
				Stroke.polyline(ci, zigzag, PackedColorArray([col]), width)
			else:
				ci.draw_polyline(zigzag, col, width))
	var trail := PackedVector2Array([Vector2(60, 36), Vector2(50, 33), Vector2(40, 32), Vector2(30, 33),
			Vector2(20, 36), Vector2(12, 40)])
	var fade := PackedColorArray()
	for k: int in range(trail.size()):
		fade.append(Color(0.9, 0.95, 1.0, 0.8 * (1.0 - k / float(trail.size()))))
	for width: float in [1.0, 2.0, 3.0]:
		_cases.append(func(ci: CanvasItem, mine: bool) -> void:
			if mine:
				Stroke.polyline(ci, trail, fade, width)
			else:
				ci.draw_polyline_colors(trail, fade, width))
	var arrow := PackedVector2Array([Vector2(36, 10), Vector2(56, 50), Vector2(16, 50)])
	var quad := PackedVector2Array([Vector2(30, 66), Vector2(42, 66), Vector2(60, 6), Vector2(12, 6)])
	var fan := PackedVector2Array([Vector2(36, 36)])
	for k: int in range(9):
		fan.append(Vector2(36, 36) + Vector2.from_angle(-1.2 + k * 0.3) * 30.0)
	for poly: PackedVector2Array in [arrow, quad, fan]:
		_cases.append(func(ci: CanvasItem, mine: bool) -> void:
			var col := Color(1.0, 0.45, 0.2, 0.35)
			if mine:
				Stroke.convex(ci, poly, col)
			else:
				ci.draw_colored_polygon(poly, col))


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: " + label)
	elif "--verbose" in OS.get_cmdline_user_args():
		print("ok: " + label)
