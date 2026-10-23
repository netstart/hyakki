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


func fire(origin: Vector2) -> void:
	var dmg := damage()
	var lifesteal := float(flags.get("lifesteal", 0.0))
	var cap := float(flags.get("lifesteal_cap", 0.0))
	game.enemies.query_circle(origin, radius(), _hits)
	var now := GameClock.game_time
	if not _hits.is_empty() and now - _last_sound >= PULSE_SOUND:
		_last_sound = now
		AudioManager.play("incense_pulse", 0.9 if is_evolved() else 1.0, 0.08, -14.0)
	for i: int in _hits:
		var away := (game.enemies.pos[i] - origin).normalized()
		game.deal_damage(id, i, dmg, away, knockback())
		if lifesteal > 0.0 and _healed_this_second < cap:
			var amount_healed := minf(dmg * lifesteal * 0.1, cap - _healed_this_second)
			_healed_this_second += amount_healed
			game.player.heal(amount_healed)


func radius() -> float:
	return raw("radius") * area()


func on_removed() -> void:
	game.player.aura_radius = 0.0
