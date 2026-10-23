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
		game.fx.play_anim("slash_double" if is_evolved() else "slash", center, width / 30.0, 0.0,
				Color(1.0, 0.95, 0.8) if is_evolved() else Color.WHITE, 22.0, side < 0.0)
	AudioManager.play("slash", 1.0, 0.08, -4.0)
