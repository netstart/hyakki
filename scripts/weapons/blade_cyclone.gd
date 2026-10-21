class_name BladeCyclone
extends Weapon
## União Dança das Cem Lâminas: um ciclone de lâminas gira em volta da guardiã (plano 4.7).

const HIT_COOLDOWN := 0.3
const BLADE_RADIUS := 7.0

var _angle: float = 0.0
var _last_hit: Dictionary = {}
var _near: Array[int] = []
var _slash_timer: float = 0.0
var _tex: Texture2D


func _init(p_game: HyakkiGame, p_id: StringName) -> void:
	super(p_game, p_id)
	_tex = load("res://assets/art/items/weapons/ninjaku.png") as Texture2D


func step(dt: float) -> void:
	_angle += raw("speed") * dt
	var time := GameClock.game_time
	var r := raw("radius") * area()
	var count := amount()
	var dmg := damage()
	for k: int in range(count):
		var at := game.player.sim_pos + Vector2.from_angle(_angle + TAU * k / float(count)) * r
		game.enemies.query_circle(at, BLADE_RADIUS, _near)
		for j: int in _near:
			var key := j * 64 + k
			if time - float(_last_hit.get(key, -10.0)) < HIT_COOLDOWN:
				continue
			_last_hit[key] = time
			game.deal_damage(id, j, dmg, (game.enemies.pos[j] - game.player.sim_pos).normalized(), knockback())
	if _last_hit.size() > 3000:
		_last_hit.clear()
	_slash_timer -= dt
	if _slash_timer <= 0.0:
		_slash_timer = 0.8
		game.fx.play_anim("slash_circular", game.player.sim_pos, r / 14.0, _angle, Color(1, 0.95, 0.8, 0.8))
		AudioManager.play("slash3", 1.1, 0.1, -8.0)


func draw(canvas: CanvasItem) -> void:
	var r := raw("radius") * area()
	var count := amount()
	var center := game.player.position
	for k: int in range(count):
		var angle := _angle + TAU * k / float(count)
		canvas.draw_set_transform((center + Vector2.from_angle(angle) * r).round(), angle + PI * 0.5, Vector2.ONE)
		canvas.draw_texture(_tex, -_tex.get_size() * 0.5, Color(1.0, 0.95, 0.85))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
