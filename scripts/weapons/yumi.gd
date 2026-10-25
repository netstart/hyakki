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
	# Corda do arco solta e o swish da flecha (WeaponSfx "yumi"/"hachiman_arrow").
	game.fx.muzzle(id, origin, aim)
	if golden and FxLayer.wfx > 0:
		game.fx.motes(origin, Color(1.0, 0.85, 0.4), 2 * FxLayer.wfx, 4.0, 25.0)
	WeaponSfx.launch(self)
