class_name Taikyoku
extends Weapon
## Taikyoku do Onmyō 陰陽太極, união de Kagutsuchi e Sopro da Yuki-onna (.ai/06-fogo-gelo-clones.md):
## dois orbes grandes, um de fogo e um de gelo, em lados opostos girando em volta da guardiã num
## raio que pulsa ("radius" ± ORBIT_SWING), com rastro curto. O de fogo queima ("burn" dps por
## "burn_time" s), o de gelo soma "chill" pilhas; cada um dispara o Choque Térmico no estado
## oposto. A cada recarga, um pulso yin-yang em PULSE_RADIUS causa o Choque Térmico em área em quem
## tem Queimadura, frio ou está congelado (consome os estados).

## Orbe que está batendo agora (element_hit / apply_status leem).
enum Hit { FIRE, ICE, PULSE }

const ORB_RADIUS := 10.0
const HIT_COOLDOWN := 0.4
const ORBIT_SWING := 15.0
const ORBIT_RATE := 1.3
const PULSE_RADIUS := 110.0
## Vapores do pulso desenhados por vez (o resto do bando lê pelo anel).
const PULSE_STEAMS := 8
const FIRE_CORE := Color(1.0, 0.42, 0.18)
const ICE_CORE := Color(0.5, 0.86, 1.0)
const TRAIL_ARC := 0.7

var _angle: float = 0.0
var _hit: Hit = Hit.FIRE
var _last_hit: Dictionary = {}
var _near: Array[int] = []


func from_hand() -> bool:
	return false


func orbit_radius() -> float:
	return (raw("radius") + ORBIT_SWING * sin(GameClock.game_time * ORBIT_RATE)) * area()


## Centro do orbe `k` (0 = fogo, 1 = gelo), em lados opostos.
func orb_position(k: int, center: Vector2) -> Vector2:
	return center + Vector2.from_angle(_angle + PI * k) * orbit_radius()


func step(dt: float) -> void:
	super(dt)
	_angle += raw("speed") * dt
	var time := GameClock.game_time
	var center := game.player.sim_pos
	var dmg := damage()
	for k: int in range(2):
		_hit = Hit.FIRE if k == 0 else Hit.ICE
		var at := orb_position(k, center)
		game.enemies.query_circle(at, ORB_RADIUS, _near)
		for j: int in _near.duplicate():
			var key := j * 2 + k
			if time - float(_last_hit.get(key, -10.0)) < HIT_COOLDOWN:
				continue
			_last_hit[key] = time
			game.deal_damage(id, j, dmg, (game.enemies.pos[j] - center).normalized(), knockback())
	if _last_hit.size() > 2000:
		_last_hit.clear()


## Pulso yin-yang: Choque Térmico em área em quem tem fogo ou gelo (consome os estados).
func fire(_origin: Vector2) -> void:
	var center := game.player.sim_pos
	var enemies := game.enemies
	var r := PULSE_RADIUS * area()
	enemies.query_circle(center, r, _near)
	var dmg := damage() * EnemyManager.THERMAL_SHOCK_MULT
	var steams := 0
	_hit = Hit.PULSE
	for j: int in _near.duplicate():
		if enemies.alive[j] == 0 or enemies.is_prop(j) or not enemies.consume_elements(j):
			continue
		if steams < PULSE_STEAMS:
			steams += 1
			game.elements.steam(enemies.pos[j])
		game.deal_damage(id, j, dmg, (enemies.pos[j] - center).normalized(), knockback())
	var fx := game.fx
	fx.add_ring(center, r, Color(FIRE_CORE, 0.85), 0.35, 2.0)
	fx.add_ring(center, r * 0.92, Color(ICE_CORE, 0.85), 0.35, 2.0)
	fx.distort(center, r, 0.8, 0.4)
	WeaponSfx.launch(self)


## Orbe de fogo em congelado, de gelo em quem queima: Choque Térmico (o pulso já consumiu).
func element_hit(j: int, amount: float) -> float:
	var e := game.enemies
	if _hit == Hit.FIRE and e.frozen[j] > 0.0:
		return e.thermal_shock(j, amount, true)
	if _hit == Hit.ICE and e.burn_time[j] > 0.0:
		return e.thermal_shock(j, amount, false)
	return 0.0


func apply_status(j: int) -> void:
	if _hit == Hit.FIRE:
		game.enemies.burn_one(j, burn_dps(), raw("burn_time"), id)
	elif _hit == Hit.ICE:
		game.enemies.chill_one(j, int(raw("chill")))


## Orbes com rastro curto (arco do Stroke), núcleo e o "olho" da cor oposta (yin-yang). Primeiro os
## rastros dos dois e depois os discos (Stroke.disc, uma textura só): sem trocar de tipo de
## desenho a cada orbe (os dois ficam em lados opostos, nunca se cobrem).
func draw(canvas: CanvasItem) -> void:
	var center := game.player.position
	var r := orbit_radius()
	var dir := signf(raw("speed")) if raw("speed") != 0.0 else 1.0
	if FxLayer.trail_points > 0:
		for k: int in range(2):
			var color := FIRE_CORE if k == 0 else ICE_CORE
			var angle := _angle + PI * k
			Stroke.arc(canvas, center, r, angle - dir * TRAIL_ARC, angle, 10, Color(color, 0.35), 4.0)
			Stroke.arc(canvas, center, r, angle - dir * TRAIL_ARC * 0.5, angle, 6, Color(color.lerp(Color.WHITE, 0.4), 0.5), 1.0)
	for k: int in range(2):
		var color := FIRE_CORE if k == 0 else ICE_CORE
		var other := ICE_CORE if k == 0 else FIRE_CORE
		var angle := _angle + PI * k
		var at := (center + Vector2.from_angle(angle) * r).round()
		Stroke.disc(canvas, at, 6.0, Color(0.05, 0.03, 0.08, 0.6))
		Stroke.disc(canvas, at, 5.0, color)
		Stroke.disc(canvas, at, 3.0, color.lerp(Color.WHITE, 0.55))
		Stroke.disc(canvas, at + Vector2.from_angle(angle + PI * 0.5) * 2.0, 1.2, other)


func draw_glow(canvas: CanvasItem) -> void:
	var center := game.player.position
	for k: int in range(2):
		FxLayer.draw_soft(canvas, center + Vector2.from_angle(_angle + PI * k) * orbit_radius(), 14.0,
				Color(FIRE_CORE if k == 0 else ICE_CORE, 0.5))
