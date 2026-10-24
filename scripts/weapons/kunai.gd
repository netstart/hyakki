class_name Kunai
extends Weapon
## Kunai / Mil Agulhas: dispara na direção do movimento, rápida (plano 4.5).
## A evolução dispara em leque contínuo.


func fire(origin: Vector2) -> void:
	var aim := game.player.facing
	var count := amount()
	var spread := raw("spread")
	for k: int in range(count):
		var offset := (k - (count - 1) * 0.5)
		var dir := aim.rotated(offset * spread) if spread > 0.0 else aim
		var lateral := aim.orthogonal() * offset * 5.0 if spread <= 0.0 else Vector2.ZERO
		game.projectiles.spawn(id, "needle" if is_evolved() else "kunai", origin + lateral,
				dir * proj_speed(), damage(), 3.0, int(raw("pierce")), duration(), knockback())
	AudioManager.play("whoosh", 1.5, 0.1, -13.0)
