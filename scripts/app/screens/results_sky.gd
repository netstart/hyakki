class_name ResultsSky
extends Control
## Céu da tela de resultados, atrás das partículas: faixas do céu do humor, e o sol nascendo com
## os montes (vitória) ou a vinheta de brasa (derrota). Fica numa camada própria, refeita só
## quando o resultado, o tamanho ou o lugar do sol mudam (a tela de resultados redesenha as
## partículas a cada quadro; polígonos refeitos a cada quadro criam buffers novos na GPU).

## Cores das faixas do céu, de cima para baixo (vazio = nada desenhado).
var sky: Array = []
var victory := false
## Centro x da coluna do retrato (o sol nasce atrás dela).
var sun_x := 0.0


func _init() -> void:
	name = "Sky"
	show_behind_parent = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Atualiza o céu; só redesenha se algo mudou.
func set_sky(p_sky: Array, p_victory: bool, p_sun_x: float) -> void:
	if p_sky == sky and p_victory == victory and is_equal_approx(p_sun_x, sun_x):
		return
	sky = p_sky
	victory = p_victory
	sun_x = p_sun_x
	queue_redraw()


func _draw() -> void:
	if sky.size() < 2:
		return
	var c := self
	var area := size if size.x > 1.0 and size.y > 1.0 else Vector2(678, 305)
	var horizon := area.y * (0.78 if victory else 1.0)
	for i: int in range(sky.size() - 1):
		var y0 := horizon * i / (sky.size() - 1)
		var y1 := horizon * (i + 1) / (sky.size() - 1)
		c.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(area.x, y0), Vector2(area.x, y1), Vector2(0, y1)]),
				PackedColorArray([sky[i], sky[i], sky[i + 1], sky[i + 1]]))
	if victory:
		_draw_dawn(c, area, horizon)
	else:
		_draw_embers(c, area)


func _draw_dawn(c: Control, area: Vector2, horizon: float) -> void:
	var sun := Vector2(sun_x, horizon + 6.0)
	for k: int in range(4):
		c.draw_circle(sun, 70.0 - k * 14.0, Color(1.0, 0.85, 0.5, 0.08 + k * 0.05))
	c.draw_circle(sun, 22.0, Color("ffe7a8"))
	# Montanhas distantes e o chão escuro abaixo do horizonte.
	var hills := PackedVector2Array([Vector2(0, area.y)])
	for x: int in range(0, int(area.x) + 24, 24):
		hills.append(Vector2(x, horizon - 6.0 - 10.0 * absf(sin(x * 0.013)) - 6.0 * absf(sin(x * 0.041))))
	hills.append(Vector2(area.x, area.y))
	c.draw_colored_polygon(hills, Color("3b2240"))
	c.draw_rect(Rect2(0, horizon + 4.0, area.x, area.y - horizon), Color("24142a"))


func _draw_embers(c: Control, area: Vector2) -> void:
	# Vinheta avermelhada nas bordas: anel de quatro trapézios que somem para dentro.
	var inset := 70.0
	var outer := [Vector2.ZERO, Vector2(area.x, 0), area, Vector2(0, area.y)]
	var inner := [Vector2(inset, inset), Vector2(area.x - inset, inset), area - Vector2(inset, inset),
			Vector2(inset, area.y - inset)]
	var red := Color(0.5, 0.06, 0.05, 0.38)
	var clear := Color(0.5, 0.06, 0.05, 0.0)
	for i: int in range(4):
		var j := (i + 1) % 4
		c.draw_polygon(PackedVector2Array([outer[i], outer[j], inner[j], inner[i]]),
				PackedColorArray([red, red, clear, clear]))
	# Brasa baixa no chão.
	c.draw_polygon(PackedVector2Array([Vector2(0, area.y - 50), Vector2(area.x, area.y - 50), area, Vector2(0, area.y)]),
			PackedColorArray([clear, clear, Color(0.6, 0.12, 0.05, 0.3), Color(0.6, 0.12, 0.05, 0.3)]))
