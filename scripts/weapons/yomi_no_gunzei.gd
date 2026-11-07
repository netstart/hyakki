class_name YomiNoGunzei
extends Weapon
## Yomi no Gunzei 黄泉の軍勢 (Kuon, união do Hyakki-shō com o Gasha-kaina): o Exército de Yomi.
## - A cada "cooldown" s um samurai espectral se levanta em volta da guardiã (MinionSystem, até
##   "minion_cap" + o atributo "minions"), com "minion_damage" de golpe e "duration" s de vida;
## - a cada "march_every" s (× recarga) o exército marcha: "amount" soldados saem da guardiã num anel que
##   abre até "radius" × 3 px (× Área) a "speed" × 2 px/s; cada yōkai que o anel cruza leva "damage" uma
##   vez e é empurrado para fora. Os servos que já estavam de pé viram samurais quando a união chega.
## O anel em marcha some na troca de reino.

## Folga do anel que fere (px) e de onde ele sai.
const BAND := 9.0
const START := 14.0
const SHEET := "res://assets/art/actors/enemies/skeleton/SpriteSheet.png"
const SOLDIER := Color(0.74, 0.62, 1.0, 0.9)
const BANNER := Color(0.55, 0.32, 0.95)

var _march_left: float = 1.0
## Anel em marcha: raio atual (< 0 = parado), raio final e quem já levou (uid → true).
var _ring: float = -1.0
var _ring_max: float = 0.0
var _ring_hits: Dictionary = {}
var _sheet: SpriteSheet
var _near: Array[int] = []


func _init(p_game: HyakkiGame, p_id: StringName) -> void:
	super(p_game, p_id)
	if game != null and game.minions != null:
		game.minions.promote_all(MinionSystem.Kind.SAMURAI, id)


func from_hand() -> bool:
	return false


func march_every() -> float:
	return maxf(0.5, raw("march_every") * stats().get_stat("cooldown"))


## Um samurai a mais em volta da guardiã (se houver vaga).
func fire(origin: Vector2) -> void:
	var minions := game.minions
	if minions == null or minions.count() >= minions.cap():
		return
	var a := minions.raised_total * 2.39996
	minions.raise(origin + Vector2.from_angle(a) * 18.0, id, raw("minion_damage"), raw("duration"),
			MinionSystem.Kind.SAMURAI, raw("minion_speed"))


func step(dt: float) -> void:
	super(dt)
	_march_left -= dt
	if _march_left <= 0.0:
		_march_left += march_every()
		_ring = START
		_ring_max = raw("radius") * 3.0 * area()
		_ring_hits.clear()
		WeaponSfx.launch(self)
		if game.fx != null:
			game.fx.shockwave(game.player.sim_pos, _ring_max, Color(fx_color(), 0.7), 0.6, 0.6)
	if _ring < 0.0:
		return
	var r0 := _ring
	_ring = minf(_ring_max, _ring + raw("speed") * 2.0 * dt)
	var center := game.player.sim_pos
	var enemies := game.enemies
	var dmg := damage()
	enemies.query_circle(center, _ring + BAND, _near)
	for j: int in _near.duplicate():
		var key := enemies.uid[j]
		if _ring_hits.has(key) or enemies.alive[j] == 0:
			continue
		var dist := enemies.pos[j].distance_to(center)
		if dist < r0 - BAND - enemies.radius[j]:
			continue
		_ring_hits[key] = true
		game.deal_damage(id, j, dmg, (enemies.pos[j] - center).normalized(), knockback())
	if _ring >= _ring_max:
		_ring = -1.0
		_ring_hits.clear()


func marching() -> bool:
	return _ring >= 0.0


func on_realm_change() -> void:
	_ring = -1.0
	_ring_hits.clear()


## O anel de soldados: samurais espectrais marchando para fora, um estandarte a cada três e a linha
## da frente (Stroke); esmaece no fim.
func draw(canvas: CanvasItem) -> void:
	if _ring < 0.0:
		return
	if _sheet == null:
		_sheet = SpriteSheet.load_sheet(SHEET)
	var center := game.player.position
	var n := maxi(1, amount())
	var fade := clampf((_ring_max - _ring) / 30.0, 0.0, 1.0)
	var time := GameClock.game_time
	Stroke.arc(canvas, center, _ring, 0.0, TAU, clampi(int(_ring * 0.5), 24, 64), Color(fx_color(), 0.35 * fade), 2.0)
	var half := _sheet.frame_size * 0.5
	for k: int in range(n):
		var a := TAU * k / float(n) + time * 0.4
		var dir := Vector2.from_angle(a)
		var at := (center + dir * _ring).round()
		var facing := SpriteSheet.dir_from_vector(dir)
		canvas.draw_texture_rect_region(_sheet.texture, Rect2(at - half, _sheet.frame_size),
				_sheet.region(int(time * 10.0) + k, facing), Color(SOLDIER, SOLDIER.a * fade))
		if k % 3 == 0:
			Stroke.line(canvas, PackedVector2Array([at + Vector2(4, 2), at + Vector2(4, -14)]), Color(0.3, 0.22, 0.3, fade), 1.0)
			canvas.draw_rect(Rect2(at + Vector2(5, -14), Vector2(4, 6)), Color(BANNER, 0.9 * fade))


func draw_glow(canvas: CanvasItem) -> void:
	if _ring < 0.0:
		return
	var center := game.player.position
	var n := maxi(1, amount())
	var time := GameClock.game_time
	for k: int in range(n):
		var a := TAU * k / float(n) + time * 0.4
		FxLayer.draw_soft(canvas, center + Vector2.from_angle(a) * _ring, 10.0, Color(0.7, 0.5, 1.0, 0.35))
