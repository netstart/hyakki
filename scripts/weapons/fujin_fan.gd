class_name FujinFan
extends Weapon
## Leque de Fūjin: cone de vento à frente, com empurrão forte (plano 4.5).
## Com Quantidade 2, também sopra para trás.

var _hits: Array[int] = []


## Golpe em volta do corpo: sai de sim_pos, não da mão.
func from_hand() -> bool:
	return false


func fire(origin: Vector2) -> void:
	var reach := raw("range") * area()
	var half_angle := raw("angle") * 0.5
	var dirs: Array[Vector2] = [game.player.facing]
	if amount() >= 2:
		dirs.append(-game.player.facing)
	for dir: Vector2 in dirs:
		game.enemies.query_circle(origin, reach, _hits)
		for i: int in _hits:
			var to := game.enemies.pos[i] - origin
			if to.length() < 1.0 or absf(dir.angle_to(to)) <= half_angle:
				game.deal_damage(id, i, damage(), dir, knockback())
		game.fx.play_anim("smoke", origin + dir * reach * 0.5, reach / 30.0, dir.angle(),
				Color(0.85, 1.0, 0.9, 0.8), 18.0)
	AudioManager.play("whoosh2", 0.8, 0.1, -6.0)
