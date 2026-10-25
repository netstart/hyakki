class_name LacquerChest
extends Control
## O Baú Laqueado desenhado em pixel art (32x26 pixels, em escala inteira `px`): laca
## vermelha e preta, cantoneiras e fechadura de ouro e uma borla de seda. Desenhado em código
## (sem arquivo de arte): a tampa abre de verdade (sobe e inclina para trás, mostrando o forro
## e a luz de dentro), a luz vaza pela fresta antes de abrir e o baú amassa ao cair.
## Quem anima (ChestPanel) mexe em `lid`, `crack`, `squash`, `shake` e `glow`.

const W := 32
const LID_H := 10
const BODY_H := 16
const OUT := Color("1a0b08")
const RED := Color("9c2218")
const RED_HI := Color("d0452e")
const RED_SH := Color("5e1010")
const BLACK := Color("221319")
const BLACK_HI := Color("3e2a36")
const GOLD := Color("d9a441")
const GOLD_HI := Color("ffe08a")
const GOLD_SH := Color("8a5a12")
const LINING := Color("4a0e12")

## Escala do pixel (2 ou 3).
var px: int = 3:
	set(value):
		px = maxi(1, value)
		custom_minimum_size = Vector2(W, LID_H + BODY_H) * px
		size = custom_minimum_size
		pivot_offset = Vector2(size.x * 0.5, size.y)
		queue_redraw()
## Tampa: 0 = fechada, 1 = aberta.
var lid: float = 0.0:
	set(value):
		lid = value
		queue_redraw()
## Luz vazando pela fresta (0..1) antes de abrir.
var crack: float = 0.0:
	set(value):
		crack = value
		queue_redraw()
## Cor da luz de dentro (a da raridade).
var glow: Color = Color(1.0, 0.85, 0.5)
## Deslocamento do tremor, em pixels lógicos.
var shake: Vector2 = Vector2.ZERO:
	set(value):
		shake = value
		queue_redraw()
## Amassado da queda (x, y), aplicado a partir da base.
var squash: Vector2 = Vector2.ONE:
	set(value):
		squash = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	px = 3


## Centro da boca do baú (de onde saem a luz e os itens), em coordenadas locais.
func mouth() -> Vector2:
	return Vector2(size.x * 0.5, LID_H * px)


func _p(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(Vector2(x, y) * px, Vector2(w, h) * px), color)


func _draw() -> void:
	_draw_body()
	_draw_lid()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Base do baú (amassado a partir do chão, com o tremor).
func _frame() -> Transform2D:
	return Transform2D(0.0, squash, 0.0, _origin())


func _draw_body() -> void:
	draw_set_transform_matrix(_frame() * Transform2D(0.0, Vector2(0, LID_H * px)))
	var b := 0.0
	_p(0, b, 32, 14, OUT)
	_p(1, b, 30, 13, BLACK)
	_p(5, b + 2, 1, 9, BLACK_HI)
	_p(7, b + 3, 1, 5, BLACK_HI)
	_p(23, b + 3, 1, 7, BLACK_HI)
	_p(1, b, 30, 2, RED)
	_p(1, b, 30, 1, RED_HI)
	_p(1, b + 11, 30, 2, RED_SH)
	for x0: float in [0.0, 28.0]:
		_p(x0, b, 4, 14, GOLD)
		_p(x0 + 1, b + 1, 1, 12, GOLD_HI)
		_p(x0 + (3 if x0 < 1.0 else 0), b, 1, 14, GOLD_SH)
		_p(x0 + 2, b + 3, 1, 1, GOLD_SH)
		_p(x0 + 2, b + 10, 1, 1, GOLD_SH)
	_p(12, b + 2, 8, 8, GOLD_SH)
	_p(13, b + 2, 6, 7, GOLD)
	_p(13, b + 2, 6, 1, GOLD_HI)
	_p(15, b + 4, 2, 2, OUT)
	_p(16, b + 6, 1, 2, OUT)
	_p(14, b + 9, 4, 1, GOLD_SH)
	_p(15, b + 10, 2, 3, RED_HI)
	_p(15, b + 12, 2, 1, RED)
	_p(1, b + 14, 4, 2, OUT)
	_p(27, b + 14, 4, 2, OUT)
	_p(2, b + 14, 2, 1, GOLD_SH)
	_p(28, b + 14, 2, 1, GOLD_SH)
	# Boca aberta: a luz de dentro, na cor da raridade, acima da borda do corpo.
	if lid > 0.4:
		var open := clampf((lid - 0.4) / 0.6, 0.0, 1.0)
		_p(1, b - 2, 30, 2, OUT)
		_p(2, b - 2, 28, 2, Color(glow.darkened(0.2), open))
		_p(4, b - 2, 24, 1, Color(glow.lerp(Color.WHITE, 0.7), open))
	# Luz vazando pela fresta.
	if crack > 0.0 and lid <= 0.05:
		var a := clampf(crack, 0.0, 1.0)
		draw_rect(Rect2(Vector2(3, b) * px - Vector2(0, 1), Vector2(26 * px, 2)), Color(glow.lerp(Color.WHITE, 0.5), a))
		for i: int in range(5):
			var x := (5.0 + i * 5.5) * px
			var len := (2.0 + 3.0 * a) * px * (0.6 + 0.4 * sin(i * 2.1 + crack * 9.0))
			draw_rect(Rect2(x, b - len, 1, len), Color(glow, 0.5 * a))


func _origin() -> Vector2:
	var base := Vector2(size.x * 0.5, size.y)
	return base + shake.round() - Vector2(size.x * 0.5 * squash.x, size.y * squash.y)


## Tampa: na 1ª metade de `lid` a tampa fechada achata em direção à dobradiça (gira para
## trás); na 2ª, a tampa aberta cresce para cima mostrando o forro de seda por dentro.
func _draw_lid() -> void:
	var open := clampf(lid, 0.0, 1.0)
	var hinge := Vector2(0, LID_H * px)
	if open < 0.5:
		var flat := 1.0 - open * 2.0 * 0.85
		draw_set_transform_matrix(_frame() * Transform2D(0.0, hinge) * Transform2D(0.0, Vector2(1.0, flat), 0.0,
				Vector2.ZERO) * Transform2D(0.0, -hinge))
		_draw_closed_lid()
		return
	# Tampa aberta vista por dentro: forro vermelho escuro, aro de ouro em cima e as
	# cantoneiras, um pouco mais larga em cima (perspectiva).
	var grow := clampf((open - 0.5) * 2.0, 0.0, 1.0)
	var h := 8.0
	var top := Transform2D(0.0, hinge + Vector2(0, -2.0 * px)) * Transform2D(0.0, Vector2(1.0, grow), 0.0, Vector2.ZERO)
	draw_set_transform_matrix(_frame() * top)
	_p(-1, -h, 34, h, OUT)
	_p(0, -h + 1, 32, h - 1, LINING)
	_p(2, -h + 2, 28, h - 3, Color(LINING.lightened(0.12)))
	for i: int in range(4):
		_p(4 + i * 7, -h + 2, 1, h - 3, Color(LINING.darkened(0.25)))
	_p(2, -2, 28, 1, Color(glow, 0.5))
	_p(-1, -h, 34, 2, GOLD)
	_p(-1, -h, 34, 1, GOLD_HI)
	_p(-1, -h, 3, h, GOLD)
	_p(30, -h, 3, h, GOLD)
	_p(0, -h + 1, 1, h - 2, GOLD_HI)
	_p(14, -h, 4, 2, GOLD_SH)


func _draw_closed_lid() -> void:
	_p(1, 0, 30, 1, OUT)
	_p(0, 1, 32, 9, OUT)
	_p(1, 1, 30, 8, RED)
	_p(2, 1, 28, 1, RED_HI)
	_p(1, 7, 30, 1, RED_SH)
	_p(4, 3, 24, 3, BLACK)
	_p(4, 3, 24, 1, BLACK_HI)
	_p(0, 8, 32, 2, GOLD)
	_p(0, 8, 32, 1, GOLD_HI)
	for x0: float in [0.0, 29.0]:
		_p(x0, 1, 3, 9, GOLD)
		_p(x0 + 1, 1, 1, 7, GOLD_HI)
	# Brasão (mon) dourado no meio da tampa.
	_p(14, 2, 4, 5, GOLD_SH)
	_p(13, 3, 6, 3, GOLD_SH)
	_p(14, 3, 4, 3, GOLD)
	_p(15, 2, 2, 5, GOLD)
	_p(15, 4, 2, 1, RED)
	_p(15, 3, 1, 1, GOLD_HI)
