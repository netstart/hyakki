class_name Kaminari
extends Weapon
## Kaminari / Takemikazuchi: um raio grosso cai do céu sobre o maior grupo de inimigos.
## Diferente do Raijin (raios pequenos e aleatórios): poucos golpes, pesados e de área
## grande, com um aviso no chão ("delay" segundos) antes do impacto. No impacto: risco
## vertical do topo da tela até o alvo, explosão em área, tremor e clarão leve (os dois
## respeitam "reduzir clarões"). A evolução deixa o chão eletrificado por alguns segundos.

const RANGE := 240.0
## Quantos inimigos sorteados são testados como centro do grupo (barato e determinístico).
const SAMPLES := 12
const BOLT_LIFE := 0.22
const FLASH_LIFE := 0.12
const MARK_COLOR := Color(0.55, 0.85, 1.0)

## Golpes avisados: {"pos", "left", "delay", "radius", "damage"}.
var strikes: Array[Dictionary] = []
## Raios já caídos, só desenho: {"points", "life"}.
var bolts: Array[Dictionary] = []
var _flash: float = 0.0
var _near: Array[int] = []
## Zigue-zague do desenho: fora da simulação, não mexe no determinismo.
var _look := RandomNumberGenerator.new()


func fire(origin: Vector2) -> void:
	var r := raw("radius") * area()
	var taken: Array[Vector2] = []
	for _k: int in range(amount()):
		var at := densest_point(origin, r, taken)
		if at == Vector2.INF:
			return
		taken.append(at)
		strikes.append({"pos": at, "left": raw("delay"), "delay": maxf(raw("delay"), 0.01),
				"radius": r, "damage": damage()})
	AudioManager.play("magic1", 0.7, 0.05, -12.0)


## Centro do maior grupo perto da guardiã: testa alguns inimigos sorteados e fica com o
## que tem mais vizinhos no raio. Evita repetir o mesmo ponto no mesmo disparo.
func densest_point(origin: Vector2, r: float, taken: Array[Vector2] = []) -> Vector2:
	var best := Vector2.INF
	var best_count := -1
	for _s: int in range(SAMPLES):
		var j := game.enemies.random_alive(origin, RANGE)
		if j < 0:
			break
		var at := game.enemies.pos[j]
		var repeated := false
		for other: Vector2 in taken:
			if other.distance_to(at) < r:
				repeated = true
		game.enemies.query_circle(at, r, _near)
		var count := _near.size() - (1000 if repeated else 0)
		if count > best_count:
			best_count = count
			best = at
	return best


func step(dt: float) -> void:
	super.step(dt)
	for i: int in range(strikes.size() - 1, -1, -1):
		var s := strikes[i]
		s["left"] = float(s["left"]) - dt
		if float(s["left"]) <= 0.0:
			strikes.remove_at(i)
			_impact(s)
	for i: int in range(bolts.size() - 1, -1, -1):
		bolts[i]["life"] = float(bolts[i]["life"]) - dt
		if float(bolts[i]["life"]) <= 0.0:
			bolts.remove_at(i)
	_flash = maxf(0.0, _flash - dt)


func _impact(s: Dictionary) -> void:
	var at: Vector2 = s["pos"]
	var r := float(s["radius"])
	game.areas.blast(id, at, r, float(s["damage"]), 60.0, float(flags.get("stun", 0.0)))
	var field := float(flags.get("field", 0.0))
	if field > 0.0:
		game.areas.pool(id, at, r * 0.8, float(s["damage"]) * 0.2, 0.4, field, 1.0, 0.0,
				Color(0.6, 0.85, 1.0, 0.7))
	game.fx.play_anim("thunder", at - Vector2(0, 14), 2.0 + r / 30.0, 0.0, Color(0.85, 0.95, 1.0), 20.0)
	game.fx.play_anim("circle_spark", at, r / 14.0)
	game.fx.add_ring(at, r * 1.15, Color(0.7, 0.9, 1.0))
	bolts.append({"points": _bolt_points(at), "life": BOLT_LIFE})
	_flash = FLASH_LIFE
	game.shake(2.5)
	AudioManager.play("thunder", 1.0, 0.08, -4.0)


## Linha quebrada do topo da tela até o alvo.
func _bolt_points(at: Vector2) -> PackedVector2Array:
	var top := at.y - 40.0
	if game.player:
		top = minf(top, game.player.position.y - game.view_size().y * 0.5 - 8.0)
	var points := PackedVector2Array()
	var segments := 9
	for k: int in range(segments + 1):
		var t := k / float(segments)
		var p := Vector2(at.x, lerpf(top, at.y, t))
		if k > 0 and k < segments:
			p.x += _look.randf_range(-12.0, 12.0)
		points.append(p)
	return points


func draw(canvas: CanvasItem) -> void:
	var calm := bool(Settings.get_value("reduce_flashes"))
	for s: Dictionary in strikes:
		var at: Vector2 = (s["pos"] as Vector2).round()
		var r := float(s["radius"])
		var t := 1.0 - clampf(float(s["left"]) / float(s["delay"]), 0.0, 1.0)
		canvas.draw_circle(at, r, Color(MARK_COLOR.r, MARK_COLOR.g, MARK_COLOR.b, 0.08 + 0.17 * t))
		canvas.draw_arc(at, r, 0.0, TAU, 40, Color(MARK_COLOR.r, MARK_COLOR.g, MARK_COLOR.b, 0.85), 1.0)
		canvas.draw_arc(at, r * (1.0 - t), 0.0, TAU, 32, Color(1.0, 1.0, 0.85, 0.6), 1.0)
		canvas.draw_line(at - Vector2(5, 0), at + Vector2(5, 0), Color(1, 1, 1, 0.7), 1.0)
		canvas.draw_line(at - Vector2(0, 5), at + Vector2(0, 5), Color(1, 1, 1, 0.7), 1.0)
	for b: Dictionary in bolts:
		var a := clampf(float(b["life"]) / BOLT_LIFE, 0.0, 1.0)
		var points: PackedVector2Array = b["points"]
		canvas.draw_polyline(points, Color(0.5, 0.75, 1.0, 0.55 * a), 7.0)
		canvas.draw_polyline(points, Color(0.85, 0.95, 1.0, 0.9 * a), 3.0)
		canvas.draw_polyline(points, Color(1.0, 1.0, 1.0, a), 1.0)
	if _flash > 0.0 and game.player:
		var view := game.view_size()
		var alpha := (0.05 if calm else 0.2) * _flash / FLASH_LIFE
		canvas.draw_rect(Rect2(game.player.position - view * 0.5 - Vector2(16, 16), view + Vector2(32, 32)),
				Color(0.85, 0.92, 1.0, alpha))
