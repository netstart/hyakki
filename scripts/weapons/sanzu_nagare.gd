class_name SanzuNagare
extends Weapon
## Sanzu-nagare 三途流 (Kuon): uma onda escura do rio dos mortos nasce aos pés da guardiã e corre "range"
## px (× Área) a "speed" px/s, rumo ao yōkai à vista mais próximo (nearest_in_sight); com mais de uma,
## as outras saem em leque à volta. A frente tem "width" px (× Área): cada yōkai que ela cruza leva o
## dano uma vez, é empurrado e fica lento ("slow" por "slow_time" s). Como os projéteis, a onda quebra
## na primeira casa, árvore ou rocha do caminho (WorldMap.solid_hit), espirrando espuma.
## Ondas em voo somem na troca de reino.

## Espessura da frente que fere a cada passo (px, além do quanto ela anda).
const FRONT := 6.0
const WATER := Color(0.18, 0.32, 0.42, 0.85)
const DEEP := Color(0.07, 0.09, 0.2, 0.75)
const FOAM := Color(0.9, 1.0, 0.98, 0.9)

## Ondas: {"o" (origem), "dir", "d" (andado), "max", "w" (meia largura), "hits" (uid → true)}.
var _waves: Array[Dictionary] = []
var _near: Array[int] = []


func from_hand() -> bool:
	return false


func fire(origin: Vector2) -> void:
	var enemies := game.enemies
	var reach := raw("range") * area()
	var target := enemies.nearest_in_sight(origin, reach)
	var aim := game.player.facing if game.player.facing != Vector2.ZERO else Vector2.RIGHT
	if target >= 0 and enemies.pos[target].distance_squared_to(origin) > 0.01:
		aim = (enemies.pos[target] - origin).normalized()
	var n := amount()
	for k: int in range(n):
		_waves.append({"o": origin, "dir": aim.rotated(TAU * k / float(n)), "d": 0.0, "max": reach,
				"w": raw("width") * area() * 0.5, "hits": {}})
	WeaponSfx.launch(self)
	if game.fx != null and FxLayer.wfx > 0:
		game.fx.dust(origin, 8.0, Color(0.6, 0.85, 0.9, 0.6), 2 * FxLayer.wfx, 40.0)


func step(dt: float) -> void:
	super(dt)
	if _waves.is_empty():
		return
	var enemies := game.enemies
	var spd := proj_speed()
	var dmg := damage()
	var slow := clampf(1.0 - raw("slow"), 0.05, 1.0)
	var slow_time := raw("slow_time") * stats().get_stat("duration")
	for k: int in range(_waves.size() - 1, -1, -1):
		var wave := _waves[k]
		var dir: Vector2 = wave["dir"]
		var o: Vector2 = wave["o"]
		var d0 := float(wave["d"])
		var d1 := minf(float(wave["max"]), d0 + spd * dt)
		var from := o + dir * d0
		var to := o + dir * d1
		var wall := game.world.solid_hit(from, to, 0.0) if game.world != null else -1.0
		if wall >= 0.0:
			d1 = lerpf(d0, d1, wall)
			to = o + dir * d1
		wave["d"] = d1
		var side := dir.orthogonal() * float(wave["w"])
		var hits: Dictionary = wave["hits"]
		enemies.query_segment(to - side, to + side, FRONT + (d1 - d0), _near)
		for j: int in _near.duplicate():
			var key := enemies.uid[j]
			if hits.has(key) or enemies.alive[j] == 0:
				continue
			hits[key] = true
			game.deal_damage(id, j, dmg, dir, knockback())
			if enemies.alive[j] == 1:
				enemies.apply_slow(j, slow, slow_time)
		if wall >= 0.0 or d1 >= float(wave["max"]):
			_splash(to, dir, float(wave["w"]))
			_waves.remove_at(k)


func _splash(at: Vector2, dir: Vector2, w: float) -> void:
	var fx := game.fx
	if fx == null or not game.enemies.view_rect.has_point(at):
		return
	fx.sparks(at, -dir, FOAM, [2, 4, 7][FxLayer.wfx], 80.0, 1.2, 0.25)
	if FxLayer.wfx > 0:
		fx.dust(at, w * 0.6, Color(0.55, 0.8, 0.85, 0.6), 2 * FxLayer.wfx, 30.0)


func on_realm_change() -> void:
	_waves.clear()


func on_removed() -> void:
	_waves.clear()
	super()


func waves() -> int:
	return _waves.size()


## A frente da onda em arco (curva para a frente no meio), água escura por trás e espuma clara na
## crista, com gotas que saltam; esmaece no fim do percurso (Stroke e retângulos).
func draw(canvas: CanvasItem) -> void:
	var time := GameClock.game_time
	for wave: Dictionary in _waves:
		var dir: Vector2 = wave["dir"]
		var d := float(wave["d"])
		var w := float(wave["w"])
		var fade := clampf((float(wave["max"]) - d) / 40.0, 0.0, 1.0) * clampf(d / 12.0, 0.0, 1.0)
		var front := Vector2(wave["o"]) + dir * d
		var side := dir.orthogonal()
		var crest := PackedVector2Array()
		var back := PackedVector2Array()
		var steps := 9
		for s: int in range(steps):
			var u := s / float(steps - 1) * 2.0 - 1.0
			var bulge := (1.0 - u * u) * w * 0.35
			var wob := sin(time * 9.0 + u * 4.0 + d * 0.05) * 1.2
			crest.append(front + side * u * w + dir * (bulge + wob))
			back.append(front + side * u * w * 0.9 + dir * (bulge * 0.5 - 7.0))
		Stroke.line(canvas, back, Color(DEEP, DEEP.a * fade), 6.0)
		Stroke.line(canvas, crest, Color(WATER, WATER.a * fade), 4.0)
		Stroke.line(canvas, crest, Color(FOAM, FOAM.a * fade), 1.0)
		for s: int in range(0, steps, 2):
			var hop := fmod(time * 2.5 + s * 0.37, 1.0)
			var drop: Vector2 = crest[s] + dir * (2.0 + hop * 5.0) + Vector2(0, -hop * 3.0)
			canvas.draw_rect(Rect2(drop.round(), Vector2(1, 1)), Color(FOAM, 0.8 * fade * (1.0 - hop)))


func draw_glow(canvas: CanvasItem) -> void:
	for wave: Dictionary in _waves:
		var front := Vector2(wave["o"]) + Vector2(wave["dir"]) * float(wave["d"])
		FxLayer.draw_soft(canvas, front, float(wave["w"]) * 0.8, Color(0.5, 0.95, 0.9, 0.22))
