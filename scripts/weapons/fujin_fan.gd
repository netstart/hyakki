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
		_gust_fx(origin, dir, reach, half_angle)
	WeaponSfx.launch(self)


## Rajada: nuvem de vento no cone e riscos de ar (e folhas na Alta) varrendo para fora.
func _gust_fx(origin: Vector2, dir: Vector2, reach: float, half_angle: float) -> void:
	var fx := game.fx
	fx.play_anim("smoke", origin + dir * reach * 0.5, minf(2.4, reach / 30.0), dir.angle(), Color(fx_color(), 0.75), 18.0)
	if FxLayer.wfx == 0:
		return
	fx.sparks(origin + dir * 8.0, dir, Color(fx_hot(), 0.8), 5 * FxLayer.wfx, reach * 3.2, half_angle, 0.3)
	if FxLayer.wfx >= 2:
		for _k: int in range(3):
			fx.dust(origin + dir * reach * randf_range(0.3, 0.8), 2.0, Color(0.55, 0.8, 0.4), 1, 60.0)
