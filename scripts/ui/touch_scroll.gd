class_name TouchScroll
extends RefCounted
## Rolagem pelo dedo em todas as listas, sem depender de onde o dedo começa.
##
## O ScrollContainer do Godot só rola com o dedo se o toque chegar até ele. Botões, cartões e
## painéis têm mouse_filter STOP por padrão e engolem o toque: começar o arrasto em cima de um
## cartão (Diário, Resultados, Guardiões...) não rolava a lista. Aqui, todo Control com STOP
## dentro de um ScrollContainer passa a PASS: o toque chega ao controle (o botão ainda acende e
## responde ao toque parado) e sobe até a lista, que rola passando da zona morta. Quando a lista
## começa a rolar, o Godot avisa os filhos (NOTIFICATION_SCROLL_BEGIN) e o botão cancela o
## toque, então arrastar nunca aperta o botão por baixo do dedo.
##
## Ficam como estão os controles em que arrastar já significa outra coisa (barras, sliders,
## campos de texto, listas e outras rolagens aninhadas).
##
## RichTextLabel com rolagem própria e ItemList (Licenças) não rolam com o dedo no Godot: ganham
## o arrasto vertical aqui, direto na barra deles.
##
## Rolagem em andamento (busy): arrasto com o dedo ou piparote ainda andando (do scroll_started
## ao scroll_ended do ScrollContainer), mais BUSY_GRACE_MS; rolagens automáticas não contam.
## Animações só decorativas (palco do guardião, retrato do Diário, partículas dos Resultados,
## brilho do mapa, moedas da Loja) param de redesenhar enquanto a lista anda: o quadro fica só
## para a rolagem, que é o que o dedo sente.
##
## install(tree) liga isso para a árvore inteira (o App chama no início): cada nó que entra é
## conferido uma vez, então telas e cartões criados depois também ficam certos.
##
## Reamostragem do arrasto (resample): no Android o toque chega em lotes, um por quadro da tela
## (vsync), pela thread da interface, e o Godot desenha na thread dele. Quando um quadro sai
## adiantado (logo depois de um atrasado), ele começa antes do lote seguinte chegar e não tem
## posição nova do dedo: a lista fica parada naquele quadro (travada) e anda dobrado no próximo.
## Como o Android faz nas Views (reamostragem do toque), num quadro sem posição nova com o dedo
## ainda andando a lista avança meio passo na velocidade do dedo; o lote seguinte devolve a posição
## exata (o ScrollContainer posiciona pelo total arrastado desde o toque), sem acumular erro.

## Controles que tratam o arrasto sozinhos (não viram PASS).
const KEEP_TYPES: Array[String] = ["ScrollBar", "Slider", "LineEdit", "TextEdit", "ItemList", "Tree",
		"SpinBox", "ScrollContainer", "RichTextLabel", "GraphEdit", "TouchJoystick"]
## Meta que marca um controle que precisa mesmo de STOP (opt-out explícito).
const KEEP_META := &"touch_scroll_keep"
## Depois que a lista para, as animações decorativas ainda esperam isto (ms) para voltar.
const BUSY_GRACE_MS := 150

## Reamostragem: só logo depois de uma posição nova do dedo (ms) e no máximo meio passo por buraco.
const RESAMPLE_WINDOW_MS := 40
const RESAMPLE_FRACTION := 0.5

## false: busy() sempre falso (diagnóstico: mede sem pausar as animações decorativas).
static var throttle := true
## false: sem reamostragem do arrasto (diagnóstico: mede o arrasto cru).
static var resample := true
## Estado do arrasto de cada lista: id da lista -> {frame, samples [[µs, valor], [µs, valor]], filled}.
static var _drags: Dictionary = {}
static var _dragging: int = 0
static var _last_move_ms: int = -100000


## Liga a adaptação para todo nó que entrar na árvore a partir de agora (e os que já estão).
static func install(tree: SceneTree) -> void:
	if tree.node_added.is_connected(_on_node_added):
		return
	tree.node_added.connect(_on_node_added)
	if not tree.process_frame.is_connected(_resample_frame):
		tree.process_frame.connect(_resample_frame)
	adopt_all(tree.root)


## Confere todos os nós de uma subárvore (já na árvore).
static func adopt_all(root: Node) -> void:
	for node: Node in root.find_children("*", "Control", true, false):
		_on_node_added(node)


static func _on_node_added(node: Node) -> void:
	var control := node as Control
	if control == null:
		return
	if control is ScrollContainer:
		_watch(control as ScrollContainer)
	if control is ItemList or (control is RichTextLabel and (control as RichTextLabel).scroll_active):
		_add_drag(control)
		return
	if control.mouse_filter != Control.MOUSE_FILTER_STOP or keeps_drag(control):
		return
	if scroll_owner(control) != null:
		control.mouse_filter = Control.MOUSE_FILTER_PASS


## Este controle trata o arrasto sozinho (ou pediu para ficar com STOP)?
static func keeps_drag(control: Control) -> bool:
	if control.has_meta(KEEP_META):
		return true
	if control is RichTextLabel:
		# Texto corrido sem rolagem própria (receitas do Diário) não segura o arrasto da lista.
		var rich := control as RichTextLabel
		return rich.scroll_active or rich.selection_enabled
	for type: String in KEEP_TYPES:
		if control.is_class(type):
			return true
	var script := control.get_script() as Script
	return script != null and script.get_global_name() in KEEP_TYPES


## ScrollContainer que rola este controle (o mais próximo acima dele), ou null. Um controle
## dentro de outro que guarda o arrasto (lista aninhada, campo de texto) não conta.
static func scroll_owner(control: Control) -> ScrollContainer:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return parent as ScrollContainer
		if parent is Control and keeps_drag(parent as Control):
			return null
		parent = parent.get_parent()
	return null


## Arrasto vertical pelo dedo em RichTextLabel (com rolagem) e ItemList, pela barra deles.
static func _add_drag(control: Control) -> void:
	if control.has_meta(&"touch_scroll_drag"):
		return
	control.set_meta(&"touch_scroll_drag", true)
	control.gui_input.connect(func(event: InputEvent) -> void:
		var drag := event as InputEventScreenDrag
		if drag == null:
			return
		var bar: VScrollBar = control.call("get_v_scroll_bar")
		if bar == null or not bar.visible:
			return
		bar.value = clampf(bar.value - drag.relative.y, bar.min_value, bar.max_value - bar.page))


## Alguma lista está rolando agora (ou acabou de parar)? Ver o comentário do topo.
static func busy() -> bool:
	if not throttle:
		return false
	return _dragging > 0 or Time.get_ticks_msec() - _last_move_ms < BUSY_GRACE_MS


## Avisa que o dedo mexeu numa lista agora.
static func mark_moving() -> void:
	_last_move_ms = Time.get_ticks_msec()


static func _watch(scroll: ScrollContainer) -> void:
	if scroll.has_meta(&"touch_scroll_watch"):
		return
	scroll.set_meta(&"touch_scroll_watch", true)
	scroll.scroll_started.connect(func() -> void:
		_dragging += 1
		# A lista pula a zona morta de uma vez ao começar: a velocidade do dedo conta só daqui.
		_drags.erase(scroll.get_instance_id())
		mark_moving())
	scroll.scroll_ended.connect(func() -> void:
		_dragging = maxi(0, _dragging - 1)
		_drags.erase(scroll.get_instance_id())
		mark_moving())
	# Posição nova do dedo neste quadro (o arrasto sobe dos cartões até a lista).
	scroll.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenDrag:
			var id := scroll.get_instance_id()
			var state: Dictionary = _drags.get(id, {"samples": [], "filled": false})
			state["frame"] = Engine.get_process_frames()
			state["scroll"] = scroll
			_drags[id] = state
		elif event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
			_drags.erase(scroll.get_instance_id()))
	# Saiu da árvore no meio de um arrasto: não deixa a contagem presa.
	scroll.tree_exiting.connect(func() -> void:
		_dragging = 0
		_drags.erase(scroll.get_instance_id()))


## Uma vez por quadro, depois da entrada (SceneTree.process_frame): guarda cada posição nova das
## listas sob o dedo e, num quadro em que a lista não andou com o dedo ainda andando (posição nova
## do dedo há pouco), avança meio passo na velocidade do dedo (ver o topo). Um buraco só recebe um
## meio passo; a próxima posição do dedo devolve a posição exata.
static func _resample_frame() -> void:
	if _drags.is_empty():
		return
	var frame := Engine.get_process_frames()
	var now := Time.get_ticks_usec()
	for id: int in _drags.keys():
		var state: Dictionary = _drags[id]
		var scroll := state.get("scroll") as ScrollContainer
		if scroll == null or not is_instance_valid(scroll) or not scroll.is_inside_tree():
			_drags.erase(id)
			continue
		var bar := scroll.get_v_scroll_bar()
		var samples: Array = state["samples"]
		if not state.has("seen") or not is_equal_approx(bar.value, float(state["seen"])):
			samples.append([now, bar.value])
			if samples.size() > 2:
				samples.pop_front()
			state["seen"] = bar.value
			state["filled"] = false
			continue
		if not resample or bool(state["filled"]) or samples.size() < 2 or frame - int(state["frame"]) > 2:
			continue
		var first: Array = samples[0]
		var last: Array = samples[1]
		var age := now - int(last[0])
		var span := int(last[0]) - int(first[0])
		var step := float(last[1]) - float(first[1])
		if age > RESAMPLE_WINDOW_MS * 1000 or span <= 0 or absf(step) < 0.5:
			continue
		var fill := clampf(step * float(age) / span * RESAMPLE_FRACTION, -absf(step), absf(step))
		bar.value = clampf(bar.value + fill, bar.min_value, bar.max_value - bar.page)
		state["seen"] = bar.value
		state["filled"] = true
