class_name Yumi
extends Weapon
## Arco Yumi / Flecha de Hachiman: flecha longa que perfura em linha (plano 4.5).
## A evolução tem crítico garantido e explode no fim.


func fire(origin: Vector2) -> void:
	var target := game.enemies.nearest(origin, 320.0)
	var aim := game.player.facing
	if target >= 0:
		aim = (game.enemies.pos[target] - origin).normalized()
	var count := amount()
	var golden := bool(flags.get("always_crit", false))
	for k: int in range(count):
		var lateral := aim.orthogonal() * (k - (count - 1) * 0.5) * 6.0
		game.projectiles.spawn(id, "golden_arrow" if golden else "arrow", origin + lateral,
				aim * proj_speed(), damage(), 3.0, int(raw("pierce")), duration(), knockback(),
				ProjectileManager.Move.STRAIGHT, 0.0, float(flags.get("explode_radius", 0.0)) * area(),
				golden)
	# Flecha: swish agudo (o launch.wav, rms -38 dB, mal se ouvia) e o estalo curto da corda.
	AudioManager.play("arrow", 1.45, 0.06, -7.0)
	AudioManager.play("bow", 1.7, 0.08, -15.0)
