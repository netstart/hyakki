class_name HoneKaze
extends Weapon
## Hone-kaze 骨風 (Kuon): ossos levados por um vento frio giram em volta da guardiã, por "duration" s, e
## descansam por "cooldown" s. Cada osso fere quem toca (um golpe por inimigo e osso a cada
## HIT_COOLDOWN s) e a órbita respira para dentro e para fora, como uma lufada. Som: ossos girando ao
## aparecer e um estalo seco ao recolher.

const HIT_COOLDOWN := 0.45
const BONE_RADIUS := 5.0
## Quanto a órbita respira (fração do raio) e o ritmo.
const BREATH := 0.12
const BREATH_RATE := 2.0
const BONE := Color(0.92, 0.87, 0.76)
const BONE_DARK := Color(0.32, 0.26, 0.36, 0.9)

var _active_left: float = 0.0
var _pause_left: float = 0.0
var _angle: float = 0.0
var _last_hit: Dictionary = {}
var _near: Array[int] = []
var _announced: bool = false


func _init(p_game: HyakkiGame, p_id: StringName) -> void:
	super(p_game, p_id)
	_active_left = duration()


func from_hand() -> bool:
	return false


func is_active() -> bool:
	return _active_left > 0.0


func orbit_radius() -> float:
	return raw("radius") * area()


func step(dt: float) -> void:
	if not _announced:
		_announced = true
		_appear()
	if _active_left > 0.0:
		_active_left -= dt
		if _active_left <= 0.0:
			_pause_left = cooldown()
			WeaponSfx.play("bone_crack", 0.9)
			return
	else:
		_pause_left -= dt
		if _pause_left <= 0.0:
			_active_left = duration()
			_appear()
		return
	_angle += raw("speed") * stats().get_stat("proj_speed") * dt
	var time := GameClock.game_time
	var center := game.player.sim_pos
	var dmg := damage()
	var n := amount()
	for k: int in range(n):
		var at := position_of(center, k, n)
		game.enemies.query_circle(at, BONE_RADIUS, _near)
		for j: int in _near:
			var key := j * 64 + k
			if time - float(_last_hit.get(key, -10.0)) < HIT_COOLDOWN:
				continue
			_last_hit[key] = time
			game.deal_damage(id, j, dmg, (game.enemies.pos[j] - center).normalized(), knockback())
	if _last_hit.size() > 2000:
		_last_hit.clear()


func position_of(center: Vector2, k: int, n: int) -> Vector2:
	var angle := _angle + TAU * k / float(maxi(1, n))
	var r := orbit_radius() * (1.0 + BREATH * sin(_angle * BREATH_RATE + k * 1.9))
	return center + Vector2.from_angle(angle) * r


func _appear() -> void:
	WeaponSfx.launch(self)
	if game.fx != null:
		game.fx.add_ring(game.player.sim_pos, orbit_radius(), Color(fx_color(), 0.7), 0.35)
		game.fx.dust(game.player.sim_pos, orbit_radius() * 0.6, Color(0.85, 0.8, 0.9, 0.6), 2 + 2 * FxLayer.wfx, 40.0)


## Osso de `length` px em `at`, girado em `angle`: a haste e os dois nós de cada ponta, com o
## contorno escuro por baixo (retângulos, sem polígono por quadro).
static func draw_bone(canvas: CanvasItem, at: Vector2, angle: float, length: float, color: Color,
		outline: Color = BONE_DARK) -> void:
	var half := length * 0.5
	canvas.draw_set_transform(at.round(), angle, Vector2.ONE)
	canvas.draw_rect(Rect2(-half - 1.0, -2.0, length + 2.0, 4.0), outline)
	canvas.draw_rect(Rect2(-half, -0.5, length, 1.5), color)
	for side: float in [-1.0, 1.0]:
		var end := side * half
		canvas.draw_rect(Rect2(end - 1.5, -2.0, 2.5, 1.5), color)
		canvas.draw_rect(Rect2(end - 1.5, 0.5, 2.5, 1.5), color)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Ossos girando com o rastro do vento (fantasmas atrás, Média/Alta).
func draw(canvas: CanvasItem) -> void:
	if not is_active():
		return
	var center := game.player.position
	var n := amount()
	var ghosts := mini(3, FxLayer.trail_points / 4)
	var fade := clampf(_active_left / 0.25, 0.0, 1.0)
	for k: int in range(n):
		var at := position_of(center, k, n)
		var spin := _angle * 3.0 + k
		for g: int in range(ghosts, 0, -1):
			var back := Vector2.from_angle(_angle + TAU * k / float(maxi(1, n)) - g * 0.16)
			var ghost := center + back * at.distance_to(center)
			draw_bone(canvas, ghost, spin - g * 0.4, 7.0, Color(fx_color(), 0.25 * fade * (1.0 - g / float(ghosts + 1))),
					Color(0, 0, 0, 0))
		draw_bone(canvas, at, spin, 8.0, Color(BONE, fade), Color(BONE_DARK, BONE_DARK.a * fade))


func draw_glow(canvas: CanvasItem) -> void:
	if not is_active():
		return
	var center := game.player.position
	var n := amount()
	for k: int in range(n):
		FxLayer.draw_soft(canvas, position_of(center, k, n), 8.0, Color(0.7, 0.55, 1.0, 0.35))


func on_realm_change() -> void:
	_last_hit.clear()
