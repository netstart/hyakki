class_name GashaKaina
extends Weapon
## Gasha-kaina がしゃ腕 (Kuon, evolução do Hone-kaze com o Incenso): o braço de esqueleto da Gashadokuro
## sai do chão atrás da guardiã e varre um arco de "angle" rad e raio "radius" em "duration" s, rumo ao
## yōkai mais próximo. A cada recarga são "amount" varridas, alternando o sentido, SWEEP_GAP s uma da
## outra. Quem a mão alcança leva o golpe uma vez por varrida, é arremessado e fica atordoado ("stun").
## As varridas em curso vão no hash pelo nível da arma (estado curto, refeito a cada recarga) e somem
## na troca de reino.

const SWEEP_GAP := 0.3
## Começo do braço (o ombro sai do chão a esta distância da guardiã) e a largura da mão (px).
const SHOULDER := 10.0
const HAND_WIDTH := 16.0
const BONE := Color(0.93, 0.88, 0.77)
const BONE_SHADE := Color(0.62, 0.56, 0.66)
const DARK := Color(0.16, 0.1, 0.22, 0.85)

## Varridas: {"delay", "t", "from", "span" (com sinal), "hits" (uid → true)}.
var _sweeps: Array[Dictionary] = []
var _near: Array[int] = []


func from_hand() -> bool:
	return false


func reach() -> float:
	return raw("radius") * area()


func fire(origin: Vector2) -> void:
	var aim := game.player.aim_direction(Player.Aim.NEAREST, reach() * 1.4)
	var span := raw("angle")
	for k: int in range(amount()):
		var side := 1.0 if k % 2 == 0 else -1.0
		_sweeps.append({"delay": k * SWEEP_GAP, "t": 0.0, "from": aim.angle() - side * span * 0.5,
				"span": side * span, "hits": {}, "started": false})
	if game.fx != null:
		game.fx.dust(origin, 10.0, Color(0.8, 0.75, 0.7, 0.7), 3 + 2 * FxLayer.wfx, 50.0)


func step(dt: float) -> void:
	super(dt)
	if _sweeps.is_empty():
		return
	var center := game.player.sim_pos
	var r := reach()
	var total := maxf(0.05, duration())
	var dmg := damage()
	var stun := float(flags.get("stun", 0.0))
	var enemies := game.enemies
	for s: int in range(_sweeps.size() - 1, -1, -1):
		var sweep := _sweeps[s]
		if float(sweep["delay"]) > 0.0:
			sweep["delay"] = float(sweep["delay"]) - dt
			continue
		if not bool(sweep["started"]):
			sweep["started"] = true
			WeaponSfx.launch(self)
			game.shake(0.8 * FxLayer.shake_mult)
		var t0 := float(sweep["t"]) / total
		sweep["t"] = float(sweep["t"]) + dt
		var t1 := minf(1.0, float(sweep["t"]) / total)
		var a0 := float(sweep["from"]) + float(sweep["span"]) * _ease(t0)
		var a1 := float(sweep["from"]) + float(sweep["span"]) * _ease(t1)
		var hits: Dictionary = sweep["hits"]
		var mid := (a0 + a1) * 0.5
		var half := absf(a1 - a0) * 0.5 + HAND_WIDTH / maxf(r, 1.0)
		enemies.query_cone(center, Vector2.from_angle(mid), half, r + HAND_WIDTH * 0.5, _near)
		for j: int in _near.duplicate():
			var key := enemies.uid[j]
			if hits.has(key) or enemies.alive[j] == 0:
				continue
			hits[key] = true
			var away := (enemies.pos[j] - center).normalized()
			var swing := Vector2.from_angle(a1 + signf(float(sweep["span"])) * PI * 0.5)
			game.deal_damage(id, j, dmg, (away + swing).normalized(), knockback())
			if stun > 0.0 and enemies.alive[j] == 1:
				enemies.stun_one(j, stun * (EnemyManager.BOSS_STUN if enemies.is_boss(j) else 1.0))
		if t1 >= 1.0:
			if game.fx != null:
				var hand := center + Vector2.from_angle(a1) * r
				game.fx.dust(hand, 8.0, Color(0.85, 0.8, 0.75, 0.7), 2 + 2 * FxLayer.wfx, 40.0)
			WeaponSfx.play("bone_crack", 0.8)
			_sweeps.remove_at(s)


## Começa rápido e freia no fim (o peso do braço).
static func _ease(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


func angle_now(sweep: Dictionary) -> float:
	var t := clampf(float(sweep["t"]) / maxf(0.05, duration()), 0.0, 1.0)
	return float(sweep["from"]) + float(sweep["span"]) * _ease(t)


func on_realm_change() -> void:
	_sweeps.clear()


func on_removed() -> void:
	_sweeps.clear()
	super()


func sweeping() -> int:
	var n := 0
	for sweep: Dictionary in _sweeps:
		n += int(bool(sweep["started"]))
	return n


## O braço: úmero e os dois ossos do antebraço em linhas grossas com contorno escuro, os nós das
## juntas, a mão de quatro dedos em garra e o rastro de vento do arco (Stroke, sem polígono do motor).
func draw(canvas: CanvasItem) -> void:
	if _sweeps.is_empty():
		return
	var center := game.player.position
	var r := reach()
	for sweep: Dictionary in _sweeps:
		if not bool(sweep["started"]):
			continue
		var a := angle_now(sweep)
		var t := clampf(float(sweep["t"]) / maxf(0.05, duration()), 0.0, 1.0)
		var fade := clampf((1.0 - t) / 0.2, 0.0, 1.0) * clampf(t / 0.08, 0.0, 1.0)
		var dir := Vector2.from_angle(a)
		var side := dir.orthogonal() * signf(float(sweep["span"]))
		var shoulder := center + dir * SHOULDER
		var elbow := center + dir * r * 0.5 - side * 6.0
		var wrist := center + dir * (r - HAND_WIDTH * 0.6)
		var start := float(sweep["from"])
		if FxLayer.wfx > 0:
			Stroke.arc(canvas, center, r, minf(start, a), maxf(start, a), 18, Color(fx_color(), 0.22 * fade), 3.0)
		Stroke.line(canvas, PackedVector2Array([shoulder, elbow, wrist]), Color(DARK, DARK.a * fade), 8.0)
		Stroke.line(canvas, PackedVector2Array([shoulder, elbow]), Color(BONE, fade), 4.0)
		Stroke.line(canvas, PackedVector2Array([elbow - side * 1.5, wrist - side * 1.5]), Color(BONE, fade), 2.0)
		Stroke.line(canvas, PackedVector2Array([elbow + side * 1.5, wrist + side * 1.5]), Color(BONE_SHADE, fade), 2.0)
		for joint: Vector2 in [shoulder, elbow, wrist]:
			canvas.draw_rect(Rect2(joint.round() - Vector2(3, 3), Vector2(6, 6)), Color(DARK, DARK.a * fade))
			canvas.draw_rect(Rect2(joint.round() - Vector2(2, 2), Vector2(4, 4)), Color(BONE, fade))
		for f: int in range(4):
			var spread := (f - 1.5) * 0.34
			var tip_dir := dir.rotated(spread + signf(float(sweep["span"])) * 0.45)
			var knuckle := wrist + dir.rotated(spread) * 7.0
			var finger := PackedVector2Array([wrist, knuckle, knuckle + tip_dir * 9.0])
			Stroke.line(canvas, finger, Color(DARK, DARK.a * fade), 4.0)
			Stroke.line(canvas, finger, Color(BONE, fade), 2.0)


func draw_glow(canvas: CanvasItem) -> void:
	var center := game.player.position
	for sweep: Dictionary in _sweeps:
		if bool(sweep["started"]):
			FxLayer.draw_soft(canvas, center + Vector2.from_angle(angle_now(sweep)) * reach(), 14.0,
					Color(0.7, 0.5, 1.0, 0.4))
