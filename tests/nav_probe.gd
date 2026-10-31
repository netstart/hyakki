extends RefCounted
## Sonda da troca de telas (benchmark de navegação e testes do "voltar"): lê, quadro a quadro, o
## estado dos nós principais do título (título, saldo, Próximas metas, cada linha do menu e o bloco
## de ação) e mede o quanto cada um ainda está longe do estado final: transparência acumulada
## (modulate.a do nó até a tela) e deslocamento da entrada, em fração (0 = parado no lugar,
## 1 = no começo da entrada).
##
## Uma entrada bem-feita só diminui essa distância quadro a quadro. "Piscada" é quando ela sobe:
## o nó aparece pronto e depois volta ao começo da entrada (o .from() de um Tween só é aplicado
## quando o tweener começa, e com set_delay isso fica para depois), ou some e volta.

## Subida mínima da distância (fração) para contar como piscada.
const FLICKER_STEP := 0.02
## Abaixo disto o nó já conta como "inteiro" (alpha ≥ 0,99, deslocamento < 1%).
const SETTLED := 0.01
## Deslocamentos da entrada do título (title_screen._play_intro): título 6 px, linhas e bloco 8 px.
const TITLE_SHIFT := 6.0
const ROW_SHIFT := 8.0


## Nós vigiados do título: [{name, node, axis ("x"/"y"/""), final, shift}].
static func title_nodes(screen: Control) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var title := screen.get("_title_box") as Control
	list.append({"name": "title", "node": title, "axis": "y", "final": _title_y(screen),
			"shift": TITLE_SHIFT})
	list.append({"name": "chip", "node": screen.get("_chip"), "axis": "", "final": 0.0, "shift": 1.0})
	list.append({"name": "goals", "node": screen.get("_goals"), "axis": "", "final": 0.0, "shift": 1.0})
	var rows: Array = screen.get("_rows")
	var base: Array = screen.get("_row_base")
	for i: int in rows.size():
		list.append({"name": "row%d" % i, "node": rows[i], "axis": "x", "final": (base[i] as Vector2).x,
				"shift": ROW_SHIFT})
	list.append({"name": "cta", "node": screen.get("_cta"), "axis": "x", "final": 0.0, "shift": ROW_SHIFT})
	return list


static func _title_y(screen: Control) -> float:
	return ((screen.get_script() as GDScript).get_script_constant_map()["TITLE_AT"] as Vector2).y


## Distância de cada nó ao estado final neste quadro (-1 = escondido, não conta).
static func sample(screen: Control, nodes: Array[Dictionary]) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for entry: Dictionary in nodes:
		var node := entry["node"] as Control
		if node == null or not node.is_visible_in_tree():
			out.append(-1.0)
			continue
		var alpha := 1.0
		var at: CanvasItem = node
		while at != null:
			alpha *= at.modulate.a
			if at == screen:
				break
			at = at.get_parent() as CanvasItem
		var off := 0.0
		match String(entry["axis"]):
			"x":
				off = absf(node.position.x - float(entry["final"])) / float(entry["shift"])
			"y":
				off = absf(node.position.y - float(entry["final"])) / float(entry["shift"])
		out.append(maxf(1.0 - alpha, clampf(off, 0.0, 1.0)))
	return out


## Resumo de uma sequência de amostras (uma por quadro): piscadas (a distância de um nó subiu),
## quadros com algum nó fora do lugar, a maior e a menor distância no 1º quadro (entrada que
## começa no lugar certo: todos perto de 1; título que volta de um submenu: todos 0) e os nós que
## piscaram.
static func summarize(nodes: Array[Dictionary], samples: Array[PackedFloat32Array]) -> Dictionary:
	var flickers := 0
	var unsettled := 0
	var names: PackedStringArray = []
	var first := 0.0
	var first_min := 1.0
	for k: int in samples.size():
		var row := samples[k]
		var off := false
		for i: int in row.size():
			if row[i] < 0.0:
				continue
			if k == 0:
				first = maxf(first, row[i])
				first_min = minf(first_min, row[i])
			if row[i] > SETTLED:
				off = true
			if k > 0 and samples[k - 1][i] >= 0.0 and row[i] > samples[k - 1][i] + FLICKER_STEP:
				flickers += 1
				var n := String(nodes[i]["name"])
				if not n in names:
					names.append(n)
		if off:
			unsettled += 1
	return {"flickers": flickers, "unsettled_frames": unsettled, "first_deficit": first, "first_min": first_min,
			"flicker_nodes": names}
