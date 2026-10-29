class_name StaticBake
extends Control
## Camada fixa "assada" numa textura: o desenho caro (centenas de polígonos, linhas e sprites)
## é feito uma vez num SubViewport e, a cada quadro, a tela só desenha um retângulo com o
## resultado. Um _draw comum não sai de graça só por não ser refeito: o Godot manda todos os
## comandos guardados para a GPU em todo quadro (cada troca de textura ou de primitiva é mais
## uma chamada de desenho). No celular isso pesa bem mais que no PC.
##
## Uso: var bake := StaticBake.new(func(canvas: CanvasItem) -> void: canvas.draw_rect(...))
##      add_child(bake)        # ocupa o retângulo do pai (âncoras cheias)
##      bake.invalidate()      # quando o conteúdo mudar (o tamanho já refaz sozinho)
##
## O pintor recebe o CanvasItem onde desenhar (as coordenadas são as do próprio StaticBake) e
## roda dentro do SubViewport, na mesma resolução lógica da tela, com filtro nearest e o mesmo
## encaixe no pixel da janela: o resultado é o mesmo do desenho direto. Com `opaque` (o pintor
## cobre todo o retângulo), a textura é opaca; sem ele, o fundo é transparente e a textura é
## composta com alfa pré-multiplicado (assim as bordas semitransparentes não escurecem).

var painter: Callable
var opaque := false
## false: só gera a textura (para outros desenharem dela), sem desenhá-la na tela.
var display := true
## true: texturas repetem dentro do desenho (draw_texture_rect com tile), como num pai com
## texture_repeat ligado.
var repeat := false
## Quantas vezes a textura foi refeita (testes).
var bakes := 0

var _viewport: SubViewport
var _canvas: Control
var _baked_size := Vector2i.ZERO


func _init(p_painter: Callable = Callable(), p_opaque: bool = false) -> void:
	painter = p_painter
	opaque = p_opaque
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.disable_3d = true
	_viewport.transparent_bg = not opaque
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	if repeat:
		_viewport.canvas_item_default_texture_repeat = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_REPEAT_ENABLED
	var main := get_viewport()
	if main != null:
		_viewport.snap_2d_transforms_to_pixel = main.snap_2d_transforms_to_pixel
		_viewport.snap_2d_vertices_to_pixel = main.snap_2d_vertices_to_pixel
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_paint)
	_viewport.add_child(_canvas)
	add_child(_viewport)
	if not opaque:
		var premult := CanvasItemMaterial.new()
		premult.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		material = premult
	resized.connect(invalidate)
	invalidate()


## Refaz a textura no próximo quadro (conteúdo do pintor mudou).
func invalidate() -> void:
	if _viewport == null:
		return
	var want := Vector2i(ceili(maxf(size.x, 1.0)), ceili(maxf(size.y, 1.0)))
	if want != _baked_size:
		_baked_size = want
		_viewport.size = want
		_canvas.size = Vector2(want)
	_canvas.queue_redraw()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()


func _paint() -> void:
	bakes += 1
	if painter.is_valid():
		painter.call(_canvas)


func _draw() -> void:
	if display and _viewport != null:
		draw_texture(_viewport.get_texture(), Vector2.ZERO)


## Textura assada (testes e capturas).
func texture() -> Texture2D:
	return _viewport.get_texture() if _viewport != null else null
