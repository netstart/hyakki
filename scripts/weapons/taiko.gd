class_name Taiko
extends Weapon
## Tambor Taiko / Trovão Ritual: onda de choque circular que pulsa (plano 4.5).
## A evolução solta duas ondas seguidas que atordoam.


func fire(origin: Vector2) -> void:
	var r := raw("radius") * area()
	var stun := float(flags.get("stun", 0.0))
	game.areas.ring(id, origin, r, damage(), duration(), knockback(), stun)
	if bool(flags.get("double", false)):
		game.areas.ring(id, origin, r * 1.25, damage(), duration(), knockback(), stun, 0.25)
	AudioManager.play("impact", 0.7, 0.05, -2.0)
	game.shake(1.0)
