class_name SpatialHash
extends RefCounted
## Grade espacial para achar vizinhos rápido sem corpos físicos (plano 10.6).
## Reconstruída a cada passo; as listas das células são reaproveitadas.

const PRUNE_EVERY := 120

var cell_size: float

var _cells: Dictionary = {}
var _clears: int = 0


func _init(p_cell_size: float = 32.0) -> void:
	cell_size = p_cell_size


func clear() -> void:
	_clears += 1
	if _clears % PRUNE_EVERY == 0:
		_cells.clear()
		return
	for cell: Array in _cells.values():
		cell.clear()


func cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))


func insert(id: int, point: Vector2) -> void:
	var key := cell_of(point)
	var cell: Variant = _cells.get(key)
	if cell == null:
		cell = []
		_cells[key] = cell
	(cell as Array).append(id)


## Preenche `out` com os ids das células que tocam o círculo (sem filtrar distância).
## Com `max_results` > 0, para de coletar ao atingir esse número (aglomerados).
func query(center: Vector2, radius: float, out: Array[int], max_results: int = 0) -> void:
	out.clear()
	var min_cell := cell_of(center - Vector2(radius, radius))
	var max_cell := cell_of(center + Vector2(radius, radius))
	for cy: int in range(min_cell.y, max_cell.y + 1):
		for cx: int in range(min_cell.x, max_cell.x + 1):
			var cell: Variant = _cells.get(Vector2i(cx, cy))
			if cell == null:
				continue
			for id: int in cell as Array:
				out.append(id)
				if max_results > 0 and out.size() >= max_results:
					return
