class_name Watashimori
extends Weapon
## Watashimori 渡し守 (Kuon, evolução do Sanzu-nagare com o Sino da Itako): a balsa do barqueiro do Sanzu
## atravessa a tela por "duration" s a "speed" px/s, passando pela guardiã rumo ao yōkai mais próximo
## (com "amount" 2, a segunda vem do lado oposto). A água em volta da balsa ("width" px × Área) fere a
## cada "tick" s (dano contínuo), deixa lento ("slow" por "slow_time" s) e, com "heal_minions", devolve
## aos servos da Kuon que estão perto o tempo de vida cheio. A balsa é dos mortos: atravessa casas e
## árvores. Some na troca de reino.

const HULL := Color(0.16, 0.12, 0.16)
const HULL_LIGHT := Color(0.36, 0.28, 0.3)
const FERRYMAN := Color(0.62, 0.5, 0.9, 0.85)
const LANTERN := Color(0.75, 0.6, 1.0)
const WAKE := Color(0.7, 0.95, 0.92, 0.6)

## Balsas: {"from", "dir", "t", "tick"}.
var _boats: Array[Dictionary] = []
var _near: Array[int] = []


func from_hand() -> bool:
	return false


func radius() -> float:
	return raw("width") * area() * 0.5


func fire(origin: Vector2) -> void:
	var dir := game.player.aim_direction(Player.Aim.NEAREST, 260.0)
	var travel := proj_speed() * duration()
	for k: int in range(amount()):
		var d := dir if k % 2 == 0 else -dir
		var side := d.orthogonal() * (k / 2) * radius() * 1.4
		_boats.append({"from": origin - d * travel * 0.5 + side, "dir": d, "t": 0.0, "tick": 0.0})
	WeaponSfx.launch(self)


func boat_pos(boat: Dictionary) -> Vector2:
	return Vector2(boat["from"]) + Vector2(boat["dir"]) * proj_speed() * float(boat["t"])


func step(dt: float) -> void:
	super(dt)
	if _boats.is_empty():
		return
	var enemies := game.enemies
	var r := radius()
	var tick := maxf(0.05, raw("tick"))
	var life := duration()
	var slow := clampf(1.0 - raw("slow"), 0.05, 1.0)
	var slow_time := raw("slow_time") * stats().get_stat("duration")
	var heal := bool(flags.get("heal_minions", false))
	for k: int in range(_boats.size() - 1, -1, -1):
		var boat := _boats[k]
		boat["t"] = float(boat["t"]) + dt
		boat["tick"] = float(boat["tick"]) - dt
		var at := boat_pos(boat)
		if float(boat["tick"]) <= 0.0:
			boat["tick"] = tick
			var dmg := damage() * tick
			enemies.query_circle(at, r, _near)
			for j: int in _near.duplicate():
				if enemies.alive[j] == 0 or enemies.is_prop(j):
					continue
				game.deal_damage(id, j, dmg, Vector2(boat["dir"]), knockback(), false, true)
				if enemies.alive[j] == 1:
					enemies.apply_slow(j, slow, slow_time)
			if heal and game.minions != null:
				game.minions.refresh(at, r * 1.5)
			if game.fx != null and FxLayer.wfx > 0 and enemies.view_rect.has_point(at):
				game.fx.motes(at, WAKE, FxLayer.wfx, r * 0.5, 14.0)
		if float(boat["t"]) >= life:
			_boats.remove_at(k)


func on_realm_change() -> void:
	_boats.clear()


func on_removed() -> void:
	_boats.clear()
	super()


func boats() -> int:
	return _boats.size()


## Água escura em volta, a esteira em V, o casco de madeira com a proa erguida, o barqueiro
## encapuzado com a vara e a lanterna de alma na popa (retângulos e Stroke).
func draw(canvas: CanvasItem) -> void:
	var r := radius()
	var time := GameClock.game_time
	var life := maxf(0.1, duration())
	for boat: Dictionary in _boats:
		var t := float(boat["t"])
		var fade := clampf(t / 0.4, 0.0, 1.0) * clampf((life - t) / 0.4, 0.0, 1.0)
		var dir: Vector2 = boat["dir"]
		var at := (Vector2(boat["from"]) + dir * proj_speed() * (t + GameClock.alpha * GameClock.STEP)).round()
		var side := dir.orthogonal()
		Stroke.arc(canvas, at, r, 0.0, TAU, 28, Color(0.1, 0.25, 0.32, 0.35 * fade), 2.0)
		for s: float in [-1.0, 1.0]:
			Stroke.line(canvas, PackedVector2Array([at - dir * 8.0, at - dir * (r + 6.0) + side * s * r * 0.6]),
					Color(WAKE, WAKE.a * fade), 1.0)
		var flip := -1.0 if dir.x < 0.0 else 1.0
		var bob := roundf(sin(time * 3.0 + t) * 1.0)
		var hull := at + Vector2(0, 3 + bob)
		canvas.draw_rect(Rect2(hull + Vector2(-11, -2), Vector2(22, 4)), Color(HULL, fade))
		canvas.draw_rect(Rect2(hull + Vector2(-11, -3), Vector2(22, 1)), Color(HULL_LIGHT, fade))
		canvas.draw_rect(Rect2(hull + Vector2(9.0 * flip - (1.0 if flip > 0.0 else 2.0), -6), Vector2(3, 4)),
				Color(HULL, fade))
		var man := hull + Vector2(-4.0 * flip, -3)
		canvas.draw_rect(Rect2(man + Vector2(-2, -9), Vector2(5, 9)), Color(FERRYMAN, FERRYMAN.a * fade))
		canvas.draw_rect(Rect2(man + Vector2(-3, -11), Vector2(7, 3)), Color(FERRYMAN.darkened(0.3), fade))
		Stroke.line(canvas, PackedVector2Array([man + Vector2(3.0 * flip, -10), man + Vector2(9.0 * flip, 4)]),
				Color(HULL_LIGHT, fade), 1.0)
		var lamp := hull + Vector2(-10.0 * flip, -9)
		Stroke.line(canvas, PackedVector2Array([lamp + Vector2(0, 6), lamp]), Color(HULL_LIGHT, fade), 1.0)
		canvas.draw_rect(Rect2(lamp + Vector2(-1, -2), Vector2(3, 3)), Color(LANTERN, fade))


func draw_glow(canvas: CanvasItem) -> void:
	for boat: Dictionary in _boats:
		var dir: Vector2 = boat["dir"]
		var flip := -1.0 if dir.x < 0.0 else 1.0
		var at := boat_pos(boat) + Vector2(-10.0 * flip, -7)
		FxLayer.draw_soft(canvas, at, 12.0, Color(LANTERN, 0.5))
