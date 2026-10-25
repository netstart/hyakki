class_name SmokeBomb
extends Weapon
## Bomba de Fumaça / Névoa Venenosa: cai num ponto perto dos inimigos e deixa uma poça
## de dano (plano 4.5). A evolução tem poças que crescem e seguem a guardiã.


func fire(origin: Vector2) -> void:
	var r := raw("radius") * area()
	var tint := Color(0.6, 0.95, 0.5, 0.85) if is_evolved() else Color(0.85, 0.85, 0.9, 0.85)
	for _k: int in range(amount()):
		var target := game.enemies.random_alive(origin, 200.0)
		var at := origin + Vector2.from_angle(game.rng.randf() * TAU) * game.rng.randf_range(30.0, 120.0)
		if target >= 0:
			at = game.enemies.pos[target]
		game.areas.pool(id, at, r, damage(), raw("tick"), duration(), float(flags.get("grow", 1.0)),
				float(flags.get("follow", 0.0)), tint)
		_pop_fx(at, r)
	WeaponSfx.launch(self)


## Estouro da bomba: nuvem circular, anel de poeira e (Média/Alta) fumaça espalhando.
func _pop_fx(at: Vector2, r: float) -> void:
	var fx := game.fx
	fx.play_anim("smoke_circular", at, minf(1.6, r / 16.0), 0.0, Color(fx_color(), 0.9))
	fx.add_ring(at, r * 1.1, Color(fx_color(), 0.7), 0.3)
	if FxLayer.wfx > 0:
		fx.play_anim("smoke", at, minf(2.0, r / 18.0), 0.0, Color(fx_color(), 0.75), 14.0)
		fx.dust(at, r * 0.3, Color(fx_color(), 0.8), 4 * FxLayer.wfx, 50.0)
		fx.flash(at, r, Color(fx_hot(), 0.4), 0.1)
