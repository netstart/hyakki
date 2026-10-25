class_name Taiko
extends Weapon
## Tambor Taiko / Trovão Ritual: onda de choque circular que pulsa (plano 4.5).
## A evolução solta duas ondas seguidas que atordoam.


## Golpe em volta do corpo: sai de sim_pos, não da mão.
func from_hand() -> bool:
	return false


func fire(origin: Vector2) -> void:
	var r := raw("radius") * area()
	var stun := float(flags.get("stun", 0.0))
	game.areas.ring(id, origin, r, damage(), duration(), knockback(), stun)
	if bool(flags.get("double", false)):
		game.areas.ring(id, origin, r * 1.25, damage(), duration(), knockback(), stun, 0.25)
	_drum_fx(origin, r)
	# Tambor de verdade; o Trovão Ritual soma o aro e um trovão grave ao toque duplo.
	WeaponSfx.launch(self)
	game.shake(1.0 * FxLayer.shake_mult)


## Batida: clarão no corpo, onda de choque (distorção na Alta) e poeira; o Trovão Ritual
## soma raio no centro e faíscas elétricas.
func _drum_fx(origin: Vector2, r: float) -> void:
	var fx := game.fx
	var ritual := is_evolved()
	fx.distort(origin, r * 1.1, 0.8 if ritual else 0.5, duration())
	fx.flash(origin, 22.0, Color(fx_hot(), 0.7), 0.12)
	fx.dust(origin, 8.0, Color(0.85, 0.75, 0.55), [2, 6, 10][FxLayer.wfx], 70.0)
	if ritual:
		fx.play_anim("thunder", origin - Vector2(0, 12), 1.6, 0.0, Color(1.0, 0.95, 0.6), 20.0, false, true)
		fx.sparks(origin, Vector2.ZERO, Color(1.0, 0.95, 0.6), 4 * FxLayer.wfx, 160.0, PI, 0.2)
