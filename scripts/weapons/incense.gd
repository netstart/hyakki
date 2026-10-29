class_name Incense
extends Weapon
## Incenso Sagrado / Fumaça do Templo: aura de dano contínuo com leve empurrão
## (plano 4.5). A evolução rouba vida (no máximo 8 HP/s).
## O sopro do incenso soa baixo, só quando a aura acerta alguém e no máximo a cada PULSE_SOUND s.

const PULSE_SOUND := 1.8

var _hits: Array[int] = []
var _healed_this_second: float = 0.0
var _second: float = 0.0
var _last_sound: float = -100.0


func step(dt: float) -> void:
	game.player.aura_radius = radius()
	game.player.aura_color = Color(0.7, 1.0, 0.75) if is_evolved() else Color(1.0, 0.85, 0.5)
	_second += dt
	if _second >= 1.0:
		_second = 0.0
		_healed_this_second = 0.0
	super.step(dt)


## Golpe em volta do corpo: sai de sim_pos, não da mão.
func from_hand() -> bool:
	return false


func fire(origin: Vector2) -> void:
	var dmg := damage()
	var lifesteal := float(flags.get("lifesteal", 0.0))
	var cap := float(flags.get("lifesteal_cap", 0.0))
	game.enemies.query_circle(origin, radius(), _hits)
	var now := GameClock.game_time
	if not _hits.is_empty() and now - _last_sound >= PULSE_SOUND:
		_last_sound = now
		WeaponSfx.launch(self)
		if game.fx:
			game.fx.add_ring(origin, radius(), Color(fx_color(), 0.5), 0.5, 1.0)
	for i: int in _hits:
		var away := (game.enemies.pos[i] - origin).normalized()
		game.deal_damage(id, i, dmg, away, knockback(), false, true)
		if lifesteal > 0.0 and _healed_this_second < cap:
			var amount_healed := minf(dmg * lifesteal * 0.1, cap - _healed_this_second)
			_healed_this_second += amount_healed
			game.player.heal(amount_healed)


## Fumaça de incenso: fiapos e brasas subindo da borda da aura (Média/Alta; mais na Alta).
## A Fumaça do Templo é verde-espírito. Só desenho (randf fora da simulação).
func draw(canvas: CanvasItem) -> void:
	var fx := game.fx
	if fx == null or FxLayer.wfx == 0 or GameClock.paused:
		return
	var r := radius()
	var center := game.player.position
	var spin := GameClock.game_time * 0.8
	var marks := 6 + 4 * FxLayer.wfx
	for k: int in range(marks):
		var a := spin + TAU * k / float(marks)
		canvas.draw_rect(Rect2((center + Vector2.from_angle(a) * r).round(), Vector2.ONE), Color(fx_color(), 0.6))
	if randf() < 0.12 * FxLayer.wfx:
		fx.embers(center + Vector2.from_angle(randf() * TAU) * r * randf_range(0.6, 1.0), fx_color(), 1, 1.0)


func draw_glow(canvas: CanvasItem) -> void:
	var pulse := 0.85 + 0.15 * sin(GameClock.game_time * 3.0)
	FxLayer.draw_soft(canvas, game.player.position, radius() * 1.1 * pulse, Color(fx_color(), 0.12))


func radius() -> float:
	return raw("radius") * area()


func on_removed() -> void:
	game.player.aura_radius = 0.0
