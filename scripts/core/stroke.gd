class_name Stroke
extends RefCounted
## Traços (arcos, polilinhas e polígonos convexos) desenhados como primitivas de 3 ou 4 pontos,
## com a mesma geometria do draw_arc / draw_polyline / draw_colored_polygon do Godot.
##
## Por quê: no Godot 4 cada draw_polyline, draw_arc ou draw_colored_polygon vira um polígono com
## buffers de vértices próprios na GPU, criados e destruídos a cada redesenho. Nos efeitos da
## partida (rastros de projéteis, anéis de área, auras, marcas de raio) isso acontece dezenas de
## vezes por quadro. Já draw_primitive não cria buffer: vai para o lote de instâncias do quadro,
## e primitivas seguidas com a mesma textura saem numa chamada de desenho só.
##
## A geometria é a mesma do motor (servers/rendering/renderer_canvas_cull.cpp, 4.7): cada ponto
## da polilinha vira um par esquerda/direita deslocado pela bissetriz (meia-esquadria limitada a
## 3x) e cada trecho é um quadrilátero com a mesma diagonal da faixa de triângulos do motor, então
## os pixels cobertos e as cores interpolam igual. Só para traços sem antialiasing (como todos os
## do jogo); largura negativa (linha fina) cai no desenho do motor.

static var _no_uv := PackedVector2Array()
## Testes e benchmark: true desenha pelo caminho antigo do motor (draw_arc, draw_polyline,
## draw_colored_polygon), para comparar pixels e custo no mesmo quadro.
static var native := false
## Traços desenhados (cada um seria um polígono com buffer próprio no caminho do motor); o
## benchmark da partida lê e zera por quadro.
static var drawn: int = 0


## Igual a CanvasItem.draw_arc (sem antialiasing).
static func arc(ci: CanvasItem, center: Vector2, radius: float, start: float, end: float, point_count: int,
		color: Color, width: float = -1.0) -> void:
	if point_count < 2:
		return
	if native:
		drawn += 1
		ci.draw_arc(center, radius, start, end, point_count, color, width)
		return
	var points := PackedVector2Array()
	points.resize(point_count)
	var delta := clampf(end - start, -TAU, TAU)
	for i: int in range(point_count):
		var theta := (i / (point_count - 1.0)) * delta + start
		points[i] = center + Vector2(cos(theta), sin(theta)) * radius
	polyline(ci, points, PackedColorArray([color]), width)


## Igual a CanvasItem.draw_polyline (uma cor, sem antialiasing).
static func line(ci: CanvasItem, points: PackedVector2Array, color: Color, width: float = -1.0) -> void:
	polyline(ci, points, PackedColorArray([color]), width)


## Igual a CanvasItem.draw_polyline / draw_polyline_colors (sem antialiasing): `colors` com uma
## cor ou uma por ponto (pontos sem cor repetem a anterior, como no motor).
static func polyline(ci: CanvasItem, points: PackedVector2Array, colors: PackedColorArray, width: float = -1.0) -> void:
	var n := points.size()
	if n < 2:
		return
	drawn += 1
	if width < 0.0 or native:
		ci.draw_polyline_colors(points, colors, width)
		return
	var loop := points[0].is_equal_approx(points[n - 1])
	var first_dir := Vector2.ZERO
	for i: int in range(1, n):
		first_dir = (points[i] - points[i - 1]).normalized()
		if not first_dir.is_zero_approx():
			break
	var last_dir := Vector2.ZERO
	for i: int in range(n - 1, 0, -1):
		last_dir = (points[i] - points[i - 1]).normalized()
		if not last_dir.is_zero_approx():
			break
	var half := width * 0.5
	var prev_dir := Vector2.ZERO
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var vertex_colors := PackedColorArray()
	left.resize(n)
	right.resize(n)
	vertex_colors.resize(n)
	var color := Color.WHITE
	for i: int in range(n):
		var is_first := i == 0
		var is_last := i == n - 1
		var segment_dir := prev_dir
		if not is_last:
			segment_dir = (points[i + 1] - points[i]).normalized()
			if segment_dir.is_zero_approx():
				segment_dir = prev_dir
		if is_first and loop:
			prev_dir = last_dir
		elif is_last and loop:
			prev_dir = first_dir
		var base: Vector2
		if is_first and not loop:
			base = first_dir.orthogonal()
		elif is_last and not loop:
			base = last_dir.orthogonal()
		else:
			base = edge_offset(segment_dir, prev_dir)
		var offset := base * half
		left[i] = points[i] + offset
		right[i] = points[i] - offset
		if i < colors.size():
			color = colors[i]
		vertex_colors[i] = color
		prev_dir = segment_dir
	var quad := PackedVector2Array()
	quad.resize(4)
	var quad_colors := PackedColorArray()
	quad_colors.resize(4)
	for i: int in range(n - 1):
		# Diagonal direita(i) → esquerda(i+1), a mesma da faixa de triângulos do motor.
		quad[0] = right[i]
		quad[1] = left[i]
		quad[2] = left[i + 1]
		quad[3] = right[i + 1]
		quad_colors[0] = vertex_colors[i]
		quad_colors[1] = vertex_colors[i]
		quad_colors[2] = vertex_colors[i + 1]
		quad_colors[3] = vertex_colors[i + 1]
		ci.draw_primitive(quad, quad_colors, _no_uv)


## Igual a CanvasItem.draw_colored_polygon para polígonos CONVEXOS (triângulos, quadriláteros,
## leques), em leque a partir do 1º ponto.
static func convex(ci: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	var n := points.size()
	if n < 3:
		return
	drawn += 1
	if native:
		ci.draw_colored_polygon(points, color)
		return
	var colors := PackedColorArray([color])
	if n <= 4:
		ci.draw_primitive(points, colors, _no_uv)
		return
	var tri := PackedVector2Array([points[0], Vector2.ZERO, Vector2.ZERO])
	for i: int in range(1, n - 1):
		tri[1] = points[i]
		tri[2] = points[i + 1]
		ci.draw_primitive(tri, colors, _no_uv)


## Deslocamento da borda num ponto da polilinha (bissetriz com a meia-esquadria limitada a 3x),
## como compute_polyline_edge_offset_clamped do motor.
static func edge_offset(segment_dir: Vector2, prev_dir: Vector2) -> Vector2:
	var length := 1.0
	var bisector := (prev_dir * segment_dir.length() - segment_dir * prev_dir.length()).normalized()
	var angle := atan2(bisector.cross(prev_dir), bisector.dot(prev_dir))
	var sin_angle := sin(angle)
	if not is_zero_approx(sin_angle) and not segment_dir.is_equal_approx(prev_dir):
		length = clampf(1.0 / sin_angle, -3.0, 3.0)
	else:
		bisector = segment_dir.orthogonal()
	if bisector.is_zero_approx():
		bisector = segment_dir.orthogonal()
	return bisector * length
