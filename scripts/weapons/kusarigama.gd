class_name Kusarigama
extends Weapon
## Kusarigama / Corrente do Ceifador: arremesso que vai e volta, como bumerangue (plano 4.5).
## A evolução lança 3 correntes que voltam em espiral.


func fire(origin: Vector2) -> void:
	var count := amount()
	var target := game.enemies.nearest(origin, raw("range") * 1.5)
	var aim := game.player.facing
	if target >= 0:
		aim = (game.enemies.pos[target] - origin).normalized()
	var spd := proj_speed()
	var life := 2.0 * raw("range") * area() / maxf(spd, 1.0)
	var spiral := bool(flags.get("spiral", false))
	for k: int in range(count):
		var dir := aim.rotated(TAU * k / float(count)) if count > 1 else aim
		var p := game.projectiles.spawn(id, "reaper_hook" if spiral else "hook", origin, dir * spd, damage(),
				6.0 * area(), -1,
				life, knockback(),
				ProjectileManager.Move.SPIRAL if spiral else ProjectileManager.Move.BOOMERANG,
				2.4 if spiral else 0.0)
		if spiral and p >= 0:
			# Em espiral: vira continuamente e também retorna na segunda metade.
			game.projectiles.move[p] = ProjectileManager.Move.SPIRAL
	game.fx.muzzle(id, origin, aim)
	WeaponSfx.launch(self)
