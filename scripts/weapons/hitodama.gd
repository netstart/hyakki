class_name Hitodama
extends Weapon
## Hitodama / Procissão Invertida: chamas-fantasma teleguiadas que buscam o inimigo com
## mais vida (plano 4.5). Na evolução, inimigos mortos viram hitodama aliados.


func fire(origin: Vector2) -> void:
	for k: int in range(amount()):
		var dir := Vector2.from_angle(TAU * k / float(maxi(1, amount())) + game.rng.randf() * 0.5)
		spawn_flame(origin, dir, "flame")
	if FxLayer.wfx > 0:
		game.fx.play_anim("spirit_blue" if not is_evolved() else "spirit", origin, 0.6, 0.0,
				Color(fx_color(), 0.85), 16.0, false, true)
		game.fx.embers(origin, fx_color(), 2 * FxLayer.wfx)
	WeaponSfx.launch(self)


func spawn_flame(origin: Vector2, dir: Vector2, kind_name: String) -> void:
	game.projectiles.spawn(id, kind_name, origin, dir * proj_speed(), damage(), 4.0, 0,
			duration(), knockback(), ProjectileManager.Move.HOMING, raw("turn"))


## Chance de a vítima virar uma chama aliada (Procissão Invertida).
func on_kill(at: Vector2) -> void:
	var chance := float(flags.get("ally_on_kill", 0.0))
	if chance > 0.0 and game.rng.randf() < chance:
		spawn_flame(at, Vector2.from_angle(game.rng.randf() * TAU), "ally_flame")
		game.fx.play_anim("spirit", at, 0.6, 0.0, Color(0.6, 1.0, 0.6, 0.9), 16.0, false, true)
