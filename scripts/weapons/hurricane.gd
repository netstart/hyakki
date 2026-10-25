class_name HurricaneWeapon
extends Weapon
## Furacão de Fūjin (evolução do Leque): um furacão que passeia perto da guardiã,
## suga inimigos e brasas e causa dano contínuo (plano 4.7).


func fire(origin: Vector2) -> void:
	for _k: int in range(amount()):
		var at := origin + Vector2.from_angle(game.rng.randf() * TAU) * 40.0
		game.areas.hurricane(id, at, raw("radius") * area(), damage(), raw("tick"), duration(),
				raw("speed"), raw("pull"))
	WeaponSfx.launch(self)
