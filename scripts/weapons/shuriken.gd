class_name Shuriken
extends Weapon
## Shuriken / Tempestade de Aço: dispara no inimigo mais próximo (plano 4.5).
## A evolução praticamente não tem recarga entre disparos.

const RANGE := 280.0
const SPREAD := 0.18


func fire(origin: Vector2) -> void:
	var target := game.enemies.nearest(origin, RANGE)
	var aim := game.player.facing
	if target >= 0:
		aim = (game.enemies.pos[target] - origin).normalized()
	var count := amount()
	for k: int in range(count):
		var angle := (k - (count - 1) * 0.5) * SPREAD
		game.projectiles.spawn(id, "shuriken", origin, aim.rotated(angle) * proj_speed(), damage(),
				4.0, int(raw("pierce")), duration(), knockback())
	AudioManager.play("whoosh", 1.3, 0.1, -10.0)
