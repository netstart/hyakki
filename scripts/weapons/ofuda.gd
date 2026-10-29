class_name Ofuda
extends Weapon
## Ofuda Orbitante / Barreira de Amaterasu: papéis-selo giram em volta da guardiã
## (plano 4.5). Ficam ativos por "duration" e pausam por "cooldown"; a evolução é permanente.
## Som: leque de papel ao aparecer, farfalhar acompanhando a órbita e papel recolhendo ao sumir.

const HIT_COOLDOWN := 0.45
const PAPER_RADIUS := 6.0
## Intervalo mínimo entre dois farfalhares (tempo de jogo).
const FLUTTER_GAP := 0.25

var _active_left: float = 0.0
var _pause_left: float = 0.0
var _angle: float = 0.0
var _last_hit: Dictionary = {}
var _near: Array[int] = []
var _tex: Texture2D
var _announced: bool = false
## Meia volta do conjunto em que o último selo cruzou o ângulo de referência.
var _flutter_mark: int = 0
var _flutter_wait: float = 0.0


func _init(p_game: HyakkiGame, p_id: StringName) -> void:
	super(p_game, p_id)
	_tex = load("res://assets/art/items/scroll/Scroll.png") as Texture2D
	_active_left = duration()


func step(dt: float) -> void:
	var permanent := bool(flags.get("permanent", false))
	if not _announced:
		_announced = true
		_cast_sound()
	if not permanent:
		if _active_left > 0.0:
			_active_left -= dt
			if _active_left <= 0.0:
				_pause_left = cooldown()
				AudioManager.play("paper_fold", 1.0, 0.06, -8.0)
		else:
			_pause_left -= dt
			if _pause_left <= 0.0:
				_active_left = duration()
				_cast_sound()
			return
	var spin := raw("speed") * stats().get_stat("proj_speed")
	_angle += spin * dt
	_flutter(spin, dt)
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


## Os selos aparecem (ou voltam depois da pausa): papel abrindo em leque, o selo mágico e os
## guizos do santuário (WeaponSfx "ofuda"/"amaterasu_barrier"), com um anel de luz.
func _cast_sound() -> void:
	WeaponSfx.launch(self)
	if game.fx:
		game.fx.add_ring(game.player.sim_pos, orbit_radius(), Color(fx_color(), 0.8), 0.35)
		game.fx.motes(game.player.sim_pos, fx_color(), 3 * FxLayer.wfx, orbit_radius(), 20.0)


## Farfalhar enquanto os selos giram: toca quando um selo cruza o ângulo de referência
## (a cada meia volta do conjunto, derivado de _angle), com intervalo mínimo. O tom sobe
## com a velocidade de giro e cada selo extra soma um pouco de volume (até +4 dB).
func _flutter(spin: float, dt: float) -> void:
	var count := maxi(1, amount())
	var mark := floori(_angle / (PI / count))
	_flutter_wait -= dt
	if mark == _flutter_mark:
		return
	_flutter_mark = mark
	if _flutter_wait > 0.0:
		return
	_flutter_wait = FLUTTER_GAP
	var pitch := clampf(0.8 + 0.08 * absf(spin), 0.85, 1.35)
	AudioManager.play("paper_flutter", pitch, 0.05, -8.0 + 0.8 * mini(count - 1, 5))


func is_active() -> bool:
	return bool(flags.get("permanent", false)) or _active_left > 0.0


func orbit_radius() -> float:
	return raw("radius") * area()


func position_of(k: int, r: float) -> Vector2:
	var angle := _angle + TAU * k / float(maxi(1, amount()))
	return game.player.sim_pos + Vector2.from_angle(angle) * r


## Selos girando com fantasmas atrás (rastro, Média/Alta); a Barreira de Amaterasu tem um
## círculo de luz fino na órbita e selos dourados.
func draw(canvas: CanvasItem) -> void:
	if not is_active():
		return
	var r := orbit_radius()
	var center := game.player.position
	var evolved := is_evolved()
	var tint := Color(1.0, 0.92, 0.65) if evolved else Color.WHITE
	var ghosts := mini(4, FxLayer.trail_points / 3)
	var dir := signf(raw("speed")) if raw("speed") != 0.0 else 1.0
	if evolved and FxLayer.wfx > 0:
		Stroke.arc(canvas, center, r, 0.0, TAU, 40, Color(fx_color(), 0.22), 1.0)
	for k: int in range(amount()):
		var angle := _angle + TAU * k / float(maxi(1, amount()))
		for g: int in range(ghosts, 0, -1):
			var ga := angle - dir * g * 0.14
			canvas.draw_set_transform((center + Vector2.from_angle(ga) * r).round(), ga + PI * 0.5,
					Vector2(0.8, 0.8))
			canvas.draw_texture(_tex, -_tex.get_size() * 0.5, Color(fx_color(), 0.32 * (1.0 - g / float(ghosts + 1))))
		var at := (center + Vector2.from_angle(angle) * r).round()
		canvas.draw_set_transform(at, angle + PI * 0.5, Vector2(0.8, 0.8))
		canvas.draw_texture(_tex, -_tex.get_size() * 0.5, tint)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_glow(canvas: CanvasItem) -> void:
	if not is_active():
		return
	var r := orbit_radius()
	var center := game.player.position
	var pulse := 0.8 + 0.2 * sin(GameClock.game_time * 6.0)
	for k: int in range(amount()):
		var angle := _angle + TAU * k / float(maxi(1, amount()))
		FxLayer.draw_soft(canvas, center + Vector2.from_angle(angle) * r, (12.0 if is_evolved() else 8.0) * pulse,
				Color(fx_color(), 0.5))
