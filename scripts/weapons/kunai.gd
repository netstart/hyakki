class_name Kunai
extends Weapon
## Kunai / Mil Agulhas: dispara na direção do movimento, rápida (plano 4.5).
## A evolução dispara em leque contínuo.

## Raio de colisão antes do "proj_size" da arma (0,8 na Kunai e na Mil Agulhas).
const RADIUS := 3.0


func fire(origin: Vector2) -> void:
	var aim := game.player.facing
	var count := amount()
	var spread := raw("spread")
	for k: int in range(count):
		var offset := (k - (count - 1) * 0.5)
		var dir := aim.rotated(offset * spread) if spread > 0.0 else aim
		var lateral := aim.orthogonal() * offset * 5.0 if spread <= 0.0 else Vector2.ZERO
		var p := game.projectiles.spawn(id, "needle" if is_evolved() else "kunai", origin + lateral,
				dir * proj_speed(), damage(), RADIUS, int(raw("pierce")), duration(), knockback())
		game.projectiles.set_size(p, proj_size())
	game.fx.muzzle(id, origin, aim)
	WeaponSfx.launch(self)
