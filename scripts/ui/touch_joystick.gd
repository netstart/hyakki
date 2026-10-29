class_name TouchJoystick
extends Control
## Joystick virtual (plano 4.1): flutuante (nasce onde o polegar toca, na metade da tela
## do lado escolhido) ou fixo. Zona morta de 12%. Opção de lado para canhotos.
## (O Godot 4.7 tem uma classe nativa chamada VirtualJoystick, daí o nome TouchJoystick.)

const RADIUS := 36.0
const DEAD_ZONE := 0.12
const KNOB_RADIUS := 10.0
const FIXED_OFFSET := Vector2(64.0, 64.0)

var vector := Vector2.ZERO
var fixed: bool = false
var left_side: bool = true
## Recorte da câmera (esquerda, direita), em pontos: o joystick fixo fica do lado de dentro.
var insets := Vector2.ZERO

var _touch_index: int = -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1 and _in_zone(touch.position):
			_touch_index = touch.index
			_origin = _fixed_center() if fixed else touch.position
			_knob = touch.position
			_update_vector()
		elif not touch.pressed and touch.index == _touch_index:
			release()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_knob = drag.position
			_update_vector()


func _in_zone(p: Vector2) -> bool:
	if p.y < 44.0:
		return false
	return p.x < size.x * 0.5 if left_side else p.x > size.x * 0.5


func _fixed_center() -> Vector2:
	if left_side:
		return Vector2(FIXED_OFFSET.x + insets.x, size.y - FIXED_OFFSET.y)
	return Vector2(size.x - FIXED_OFFSET.x - insets.y, size.y - FIXED_OFFSET.y)


## Centro do joystick fixo (testes de layout).
func fixed_center() -> Vector2:
	return _fixed_center()


func release() -> void:
	_touch_index = -1
	vector = Vector2.ZERO
	queue_redraw()


func _update_vector() -> void:
	var offset := (_knob - _origin).limit_length(RADIUS)
	var value := offset / RADIUS
	vector = Vector2.ZERO if value.length() < DEAD_ZONE else value
	queue_redraw()


func _draw() -> void:
	var center := _origin
	if _touch_index < 0:
		if not fixed:
			return
		center = _fixed_center()
	draw_circle(center, RADIUS, Color(1.0, 1.0, 1.0, 0.1))
	Stroke.arc(self, center, RADIUS, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.35), 1.0)
	draw_circle(center + vector * RADIUS, KNOB_RADIUS, Color(1.0, 1.0, 1.0, 0.45))
