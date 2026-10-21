class_name Typhoon
extends Weapon
## União Fūjin-Raijin: tufões elétricos que vagam pela tela, sugando inimigos e soltando
## raios (plano 4.7). Mantém sempre "amount" tufões ativos.

const LIFETIME := 10.0

var _respawn: float = 0.0


func step(dt: float) -> void:
	_respawn -= dt
	if _respawn > 0.0:
		return
	_respawn = LIFETIME
	for _k: int in range(amount()):
		var at := game.player.sim_pos + Vector2.from_angle(game.rng.randf() * TAU) * 60.0
		game.areas.hurricane(id, at, raw("radius") * area(), damage(), raw("cooldown"), LIFETIME,
				raw("speed"), 110.0, true)
	AudioManager.play("magic4", 0.8, 0.0, -4.0)
