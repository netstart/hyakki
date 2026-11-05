class_name Shuriken
extends Weapon
## Shuriken / Tempestade de Aço: dispara no inimigo mais próximo (plano 4.5).
## A evolução praticamente não tem recarga entre disparos.

const RANGE := 280.0
const SPREAD := 0.18
## Raio de colisão antes do "proj_size" da arma (0,6 no Shuriken e na Tempestade de Aço).
const RADIUS := 4.0


func fire(origin: Vector2) -> void:
	var target := game.enemies.nearest(origin, RANGE)
	var aim := game.player.facing
	if target >= 0:
		aim = (game.enemies.pos[target] - origin).normalized()
	var count := amount()
	for k: int in range(count):
		var angle := (k - (count - 1) * 0.5) * SPREAD
		var p := game.projectiles.spawn(id, "steel_shuriken" if is_evolved() else "shuriken", origin,
				aim.rotated(angle) * proj_speed(), damage(), RADIUS, int(raw("pierce")), duration(), knockback())
		game.projectiles.set_size(p, proj_size())
	game.fx.muzzle(id, origin, aim)
	WeaponSfx.launch(self)
