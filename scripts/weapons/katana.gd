class_name Katana
extends Weapon
## Katana Crescente / Lâmina do Amanhecer: corte horizontal à frente; com Quantidade 2,
## também atrás. Perfura tudo (plano 4.5). A evolução cura 1 HP a cada 10 acertos.

var _hits: Array[int] = []
var _hit_counter: int = 0


## Golpe em volta do corpo: sai de sim_pos, não da mão.
func from_hand() -> bool:
	return false


func fire(origin: Vector2) -> void:
	var player := game.player
	var sides: Array[float] = [player.facing_x]
	var count := amount()
	if count >= 2:
		sides.append(-player.facing_x)
	var a := area()
	var width := raw("width") * a
	var height := raw("height") * a
	var dmg := damage()
	var heal_every := int(flags.get("heal_every_hits", 0))
	for k: int in range(sides.size()):
		var side := sides[k]
		var center := origin + Vector2(side * (width * 0.5 + 2.0), -2.0)
		var rect := Rect2(center - Vector2(width, height) * 0.5, Vector2(width, height))
		game.enemies.query_circle(center, width * 0.5 + 4.0, _hits)
		for i: int in _hits:
			if rect.grow(game.enemies.radius[i]).has_point(game.enemies.pos[i]):
				game.deal_damage(id, i, dmg, Vector2(side, 0.0), knockback())
				if heal_every > 0:
					_hit_counter += 1
					if _hit_counter >= heal_every:
						_hit_counter = 0
						player.heal(1.0)
		_slash_fx(center, side, width)
	_slash_sound(sides.size())


## Corte: a animação do pacote, um brilho em meia-lua (Alta) e faíscas na ponta. A Lâmina do
## Amanhecer é dourada, dupla, mais larga e solta pétalas de luz.
func _slash_fx(center: Vector2, side: float, width: float) -> void:
	var fx := game.fx
	var dawn := is_evolved()
	fx.play_anim("slash_double" if dawn else "slash", center, width / 30.0, 0.0,
			Color(1.0, 0.9, 0.6) if dawn else Color.WHITE, 22.0, side < 0.0)
	if FxLayer.wfx == 0:
		return
	var tip := center + Vector2(side * width * 0.45, 0.0)
	fx.sparks(tip, Vector2(side, -0.4), fx_hot(), 2 + 2 * FxLayer.wfx, 120.0, 0.6, 0.16)
	fx.flash(center, width * 0.5, Color(fx_color(), 0.55), 0.1)
	if dawn:
		fx.play_anim("slash_circular", center, width / 34.0, 0.0, Color(1.0, 0.8, 0.4, 0.8), 24.0, side < 0.0, true)
		fx.motes(center, Color(1.0, 0.82, 0.4), 2 * FxLayer.wfx, width * 0.4, 30.0)


## Corte em camadas (WeaponSfx "katana"/"dawn_blade"): o "shing" metálico e o swish de ar,
## acima dos acertos. Cortando dos dois lados, só um swish extra mais grave, sem dobrar.
func _slash_sound(sides: int) -> void:
	WeaponSfx.launch(self)
	if sides >= 2:
		WeaponSfx.play("katana_back")
