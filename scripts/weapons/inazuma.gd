class_name Inazuma
extends Weapon
## Inazuma / Raikiri: a guardiã solta raios do próprio corpo contra os inimigos mais
## próximos. Cada raio é uma linha quebrada da guardiã até o alvo e salta para mais
## "chain" inimigos, perdendo um pouco de força a cada salto ("falloff").

const BOLT_LIFE := 0.16

## Raios em tela, só desenho: {"points", "life"}.
var bolts: Array[Dictionary] = []
## Zigue-zague do desenho: fora da simulação, não mexe no determinismo.
var _look := RandomNumberGenerator.new()


func fire(origin: Vector2) -> void:
	var chain := int(raw("chain"))
	var chain_range := raw("chain_range") * area()
	var falloff := float(flags.get("falloff", 0.85))
	var targeted: Array[int] = []
	var launched := false
	for _k: int in range(amount()):
		var first := game.enemies.nearest(origin, raw("range") * area(), targeted)
		if first < 0:
			break
		targeted.append(first)
		launched = true
		var hit: Array[int] = []
		var from := origin
		var current := first
		var dmg := damage()
		for link: int in range(chain + 1):
			if current < 0 or game.enemies.alive[current] == 0:
				break
			hit.append(current)
			var at := game.enemies.pos[current]
			bolts.append({"points": _jagged(from, at), "life": BOLT_LIFE})
			game.fx.play_anim("spark", at, 0.6, 0.0, Color(0.75, 0.9, 1.0))
			game.deal_damage(id, current, dmg, (at - from).normalized(), knockback())
			if link > 0:
				AudioManager.play("chain_zap", 1.0 + 0.06 * link, 0.05, -10.0)
			from = at
			dmg *= falloff
			current = game.enemies.nearest(at, chain_range, hit)
	if launched:
		AudioManager.play("zap", 1.0, 0.08, -6.0)


func step(dt: float) -> void:
	super.step(dt)
	for i: int in range(bolts.size() - 1, -1, -1):
		bolts[i]["life"] = float(bolts[i]["life"]) - dt
		if float(bolts[i]["life"]) <= 0.0:
			bolts.remove_at(i)


## Linha quebrada entre dois pontos: desvios perpendiculares menores nas pontas.
func _jagged(from: Vector2, to: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var length := from.distance_to(to)
	var segments := clampi(int(length / 10.0), 2, 12)
	var normal := (to - from).orthogonal().normalized()
	for k: int in range(segments + 1):
		var t := k / float(segments)
		var p := from.lerp(to, t)
		if k > 0 and k < segments:
			p += normal * _look.randf_range(-6.0, 6.0) * sin(t * PI)
		points.append(p)
	return points


func draw(canvas: CanvasItem) -> void:
	var tint := Color(1.0, 0.9, 0.55) if is_evolved() else Color(0.6, 0.85, 1.0)
	for b: Dictionary in bolts:
		var a := clampf(float(b["life"]) / BOLT_LIFE, 0.0, 1.0)
		var points: PackedVector2Array = b["points"]
		canvas.draw_polyline(points, Color(tint.r, tint.g, tint.b, 0.5 * a), 4.0)
		canvas.draw_polyline(points, Color(1.0, 1.0, 1.0, a), 1.0)
