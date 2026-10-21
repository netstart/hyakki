class_name Ofuda
extends Weapon
## Ofuda Orbitante / Barreira de Amaterasu: papéis-selo giram em volta da guardiã
## (plano 4.5). Ficam ativos por "duration" e pausam por "cooldown"; a evolução é permanente.

const HIT_COOLDOWN := 0.45
const PAPER_RADIUS := 6.0

var _active_left: float = 0.0
var _pause_left: float = 0.0
var _angle: float = 0.0
var _last_hit: Dictionary = {}
var _near: Array[int] = []
var _tex: Texture2D


func _init(p_game: HyakkiGame, p_id: StringName) -> void:
	super(p_game, p_id)
	_tex = load("res://assets/art/items/scroll/Scroll.png") as Texture2D
	_active_left = duration()


func step(dt: float) -> void:
	var permanent := bool(flags.get("permanent", false))
	if not permanent:
		if _active_left > 0.0:
			_active_left -= dt
			if _active_left <= 0.0:
				_pause_left = cooldown()
		else:
			_pause_left -= dt
			if _pause_left <= 0.0:
				_active_left = duration()
			return
	_angle += raw("speed") * stats().get_stat("proj_speed") * dt
	var time := GameClock.game_time
	var r := orbit_radius()
	var dmg := damage()
	for k: int in range(amount()):
		var at := position_of(k, r)
		game.enemies.query_circle(at, PAPER_RADIUS, _near)
		for j: int in _near:
			var key := j * 64 + k
			if time - float(_last_hit.get(key, -10.0)) < HIT_COOLDOWN:
				continue
			_last_hit[key] = time
			game.deal_damage(id, j, dmg, (game.enemies.pos[j] - game.player.sim_pos).normalized(), knockback())
	if _last_hit.size() > 2000:
		_last_hit.clear()


func is_active() -> bool:
	return bool(flags.get("permanent", false)) or _active_left > 0.0


func orbit_radius() -> float:
	return raw("radius") * area()


func position_of(k: int, r: float) -> Vector2:
	var angle := _angle + TAU * k / float(maxi(1, amount()))
	return game.player.sim_pos + Vector2.from_angle(angle) * r


func draw(canvas: CanvasItem) -> void:
	if not is_active():
		return
	var r := orbit_radius()
	var center := game.player.position
	var tint := Color(1.0, 0.95, 0.7) if is_evolved() else Color.WHITE
	for k: int in range(amount()):
		var angle := _angle + TAU * k / float(maxi(1, amount()))
		var at := (center + Vector2.from_angle(angle) * r).round()
		canvas.draw_set_transform(at, angle + PI * 0.5, Vector2(0.8, 0.8))
		canvas.draw_texture(_tex, -_tex.get_size() * 0.5, tint)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
