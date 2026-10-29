class_name SpatialHash
extends RefCounted
## Grade espacial para achar vizinhos rápido sem corpos físicos (plano 10.6).
## Reconstruída a cada passo como grade plana: os pontos são ordenados por célula
## (linha a linha, Y depois X) mantendo a ordem de inserção dentro de cada célula,
## e cada célula guarda onde começa e quantos ids tem num array compacto.
## A ordem devolvida por query() é a mesma da grade antiga com dicionário: células
## de cima para baixo e da esquerda para a direita, ids na ordem em que entraram.

## Acima disto (células da caixa que envolve os pontos) cai no modo dicionário.
const MAX_DENSE_CELLS := 1 << 18
## Bits da posição de inserção dentro da chave de ordenação (célula << bits | ordem).
const ORDER_BITS := 20
const ORDER_MASK := (1 << ORDER_BITS) - 1

var cell_size: float

# Pontos inseridos desde o último clear(), na ordem de inserção.
var _ids := PackedInt32Array()
var _cx := PackedInt32Array()
var _cy := PackedInt32Array()
var _n: int = 0
var _dirty: bool = false

# Grade montada: caixa de células [_min_x.._max_x] × [_min_y.._max_y], largura _w.
var _min_x: int = 0
var _min_y: int = 0
var _max_x: int = -1
var _max_y: int = -1
var _w: int = 0
## Por célula: início em _sorted (-1 = vazia) e quantidade. Fora das células usadas fica -1.
var _cell_start := PackedInt32Array()
var _cell_count := PackedInt32Array()
## Células escritas na última montagem (para limpar só elas).
var _touched := PackedInt32Array()
var _touched_n: int = 0
## Ids ordenados por célula.
var _sorted := PackedInt32Array()
## Modo dicionário (pontos muito espalhados): Vector2i -> Vector2i(início, quantidade).
var _sparse: bool = false
var _sparse_cells: Dictionary = {}


func _init(p_cell_size: float = 32.0) -> void:
	cell_size = p_cell_size


func clear() -> void:
	_n = 0
	_dirty = true


func cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))


func insert(id: int, point: Vector2) -> void:
	if _n >= _ids.size():
		_grow(maxi(16, _n * 2))
	_ids[_n] = id
	_cx[_n] = floori(point.x / cell_size)
	_cy[_n] = floori(point.y / cell_size)
	_n += 1
	_dirty = true


## Reconstrói a grade de uma vez com os índices vivos de `points` (ordem crescente),
## igual a clear() seguido de insert(i, points[i]) para cada i com alive[i] == 1.
func rebuild(points: PackedVector2Array, alive: PackedByteArray, capacity: int) -> void:
	if _ids.size() < capacity:
		_grow(capacity)
	var cs := cell_size
	var n := 0
	for i: int in range(capacity):
		if alive[i] == 1:
			var p: Vector2 = points[i]
			_ids[n] = i
			_cx[n] = floori(p.x / cs)
			_cy[n] = floori(p.y / cs)
			n += 1
	_n = n
	_build()


## Preenche `out` com os ids das células que tocam o círculo (sem filtrar distância).
## Com `max_results` > 0, para de coletar ao atingir esse número (aglomerados).
func query(center: Vector2, radius: float, out: Array[int], max_results: int = 0) -> void:
	out.clear()
	if _dirty:
		_build()
	if _n == 0:
		return
	# Mesmas contas de cell_of(center ± Vector2(radius, radius)) (em Vector2, não em double).
	var cs := cell_size
	var lo := center - Vector2(radius, radius)
	var hi := center + Vector2(radius, radius)
	var lo_x := floori(lo.x / cs)
	var lo_y := floori(lo.y / cs)
	var hi_x := floori(hi.x / cs)
	var hi_y := floori(hi.y / cs)
	# Células fora da caixa estão vazias: recortar não muda o resultado.
	lo_x = maxi(lo_x, _min_x)
	lo_y = maxi(lo_y, _min_y)
	hi_x = mini(hi_x, _max_x)
	hi_y = mini(hi_y, _max_y)
	if lo_x > hi_x or lo_y > hi_y:
		return
	var limit := max_results if max_results > 0 else 0x7fffffff
	var found := 0
	if _sparse:
		for cy: int in range(lo_y, hi_y + 1):
			for cx: int in range(lo_x, hi_x + 1):
				var run: Variant = _sparse_cells.get(Vector2i(cx, cy))
				if run == null:
					continue
				var r := run as Vector2i
				for k: int in range(r.x, r.x + r.y):
					out.append(_sorted[k])
					found += 1
					if found >= limit:
						return
		return
	var w := _w
	var starts := _cell_start
	var counts := _cell_count
	var sorted := _sorted
	for cy: int in range(lo_y, hi_y + 1):
		var row := (cy - _min_y) * w - _min_x
		for cx: int in range(lo_x, hi_x + 1):
			var s: int = starts[row + cx]
			if s < 0:
				continue
			for k: int in range(s, s + counts[row + cx]):
				out.append(sorted[k])
				found += 1
				if found >= limit:
					return


func _grow(size: int) -> void:
	_ids.resize(size)
	_cx.resize(size)
	_cy.resize(size)


## Ordena os pontos por (linha, coluna, ordem de inserção) e monta os intervalos por célula.
func _build() -> void:
	_dirty = false
	# Desfaz as células da montagem anterior (o resto da grade já está em -1).
	for t: int in range(_touched_n):
		_cell_start[_touched[t]] = -1
	_touched_n = 0
	_sparse_cells.clear()
	var n := _n
	if n == 0:
		_max_x = _min_x - 1
		_max_y = _min_y - 1
		return
	var cx := _cx
	var cy := _cy
	var min_x: int = cx[0]
	var max_x: int = min_x
	var min_y: int = cy[0]
	var max_y: int = min_y
	for k: int in range(1, n):
		var x: int = cx[k]
		var y: int = cy[k]
		if x < min_x:
			min_x = x
		elif x > max_x:
			max_x = x
		if y < min_y:
			min_y = y
		elif y > max_y:
			max_y = y
	_min_x = min_x
	_min_y = min_y
	_max_x = max_x
	_max_y = max_y
	var w := max_x - min_x + 1
	var h := max_y - min_y + 1
	_w = w
	_sparse = n > ORDER_MASK or w > MAX_DENSE_CELLS or h > MAX_DENSE_CELLS or w * h > MAX_DENSE_CELLS
	if _sorted.size() < n:
		_sorted.resize(n)
	if _sparse:
		_build_sparse()
		return
	if _cell_start.size() < w * h:
		var old := _cell_start.size()
		_cell_start.resize(w * h)
		_cell_count.resize(w * h)
		for c: int in range(old, w * h):
			_cell_start[c] = -1
	# Chave = célula linear << ORDER_BITS | ordem: o sort nativo deixa cada célula
	# contígua, em linhas de cima para baixo, e mantém a ordem de inserção dentro dela.
	var keys := PackedInt64Array()
	keys.resize(n)
	for k: int in range(n):
		keys[k] = (((cy[k] - min_y) * w + (cx[k] - min_x)) << ORDER_BITS) | k
	keys.sort()
	if _touched.size() < n:
		_touched.resize(n)
	var ids := _ids
	var last := -1
	var start := 0
	for k: int in range(n):
		var key: int = keys[k]
		var cell := key >> ORDER_BITS
		_sorted[k] = ids[key & ORDER_MASK]
		if cell != last:
			if last >= 0:
				_cell_count[last] = k - start
			_cell_start[cell] = k
			_touched[_touched_n] = cell
			_touched_n += 1
			last = cell
			start = k
	_cell_count[last] = n - start


## Pontos muito espalhados: listas por célula num dicionário (ordem de inserção mantida).
func _build_sparse() -> void:
	var lists: Dictionary = {}
	var order: Array[Vector2i] = []
	for k: int in range(_n):
		var key := Vector2i(_cx[k], _cy[k])
		var list: Variant = lists.get(key)
		if list == null:
			list = PackedInt32Array()
			order.append(key)
		var packed := list as PackedInt32Array
		packed.append(_ids[k])
		lists[key] = packed
	var at := 0
	for key: Vector2i in order:
		var packed := lists[key] as PackedInt32Array
		for id: int in packed:
			_sorted[at] = id
			at += 1
		_sparse_cells[key] = Vector2i(at - packed.size(), packed.size())
