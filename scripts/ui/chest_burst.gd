class_name ChestBurst
extends Control
## Explosão de luz atrás do baú quando ele abre: os quadros da folha "explosion" (CC0, a
## mesma do FxLayer) bem maiores que o baú, em modo aditivo, e um anel de luz que se expande.
## Fica como filho da imagem do baú com show_behind_parent: desenha atrás dela, centrada,
## sem tamanho próprio (não mexe no layout do VBox) e sem pegar toques. Toca uma vez e some.

const SHEET := "res://assets/art/fx/explosion/SpriteSheet.png"
## Largura de cada quadro da folha (a altura é a da imagem).
const FRAME := 40.0
## Lado do quadro desenhado, em pixels lógicos: 3x o baú de 48 px.
const DRAWN := 144.0
const DURATION := 0.6
## Fração da duração em que a explosão começa a sumir.
const FADE_FROM := 0.55
const TINT := Color(1.5, 1.3, 1.0)
## Anel: raio inicial e final, espessura (pixel art: sem antialias) e cor.
const RING_FROM := 14.0
const RING_TO := 88.0
const RING_WIDTH := 3.0
const RING_COLOR := Color(1.0, 0.86, 0.52)
const RING_SEGMENTS := 40

## Cor da raridade do baú (anel e clarão) e tamanho relativo (1 = 144 px).
var color: Color = RING_COLOR
var zoom: float = 1.0

var _texture: Texture2D
var _frames: int = 1
var _region_height: float = FRAME
## Tempo desde o início; negativo = parada.
var _t: float = -1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	visible = false
	set_process(false)
	if ResourceLoader.exists(SHEET):
		_texture = load(SHEET) as Texture2D
		_frames = maxi(1, floori(_texture.get_width() / FRAME))
		_region_height = float(_texture.get_height())


## Começa do primeiro quadro, centrada no pai, ou em `at` (coordenadas do pai) se dado.
func play(at: Vector2 = Vector2(-1, -1)) -> void:
	var holder := get_parent() as Control
	if at.x >= 0.0:
		position = at
	elif holder != null:
		position = holder.size * 0.5
	_t = 0.0
	visible = true
	set_process(true)
	queue_redraw()


## Para e esconde (fim natural, pular, fechar ou novo baú).
func stop() -> void:
	_t = -1.0
	visible = false
	set_process(false)


func active() -> bool:
	return _t >= 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		stop()
		return
	queue_redraw()


func _draw() -> void:
	if _t < 0.0:
		return
	var k := clampf(_t / DURATION, 0.0, 1.0)
	# Anel e clarão saem rápido e desaceleram; perdem a força até o fim.
	var grow := 1.0 - pow(1.0 - k, 3.0)
	var radius := lerpf(RING_FROM, RING_TO, grow) * zoom
	var power := 1.0 - k
	draw_circle(Vector2.ZERO, radius * 0.7, Color(color, 0.22 * power))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, RING_SEGMENTS, Color(color, 0.85 * power), RING_WIDTH)
	if _texture == null:
		return
	var frame := mini(_frames - 1, floori(k * _frames))
	var drawn := DRAWN * zoom
	var half := drawn * 0.5
	var fade := 1.0 - smoothstep(FADE_FROM, 1.0, k)
	var tint := Color(TINT.r * lerpf(1.0, color.r * 1.3, 0.5), TINT.g * lerpf(1.0, color.g * 1.3, 0.5),
			TINT.b * lerpf(1.0, color.b * 1.3, 0.5), fade * 0.7)
	draw_texture_rect_region(_texture, Rect2(-half, -half, drawn, drawn),
			Rect2(frame * FRAME, 0.0, FRAME, _region_height), tint)
