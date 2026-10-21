class_name Raijin
extends Weapon
## Raio de Raijin / Fúria de Raijin: relâmpagos em inimigos aleatórios (plano 4.5).
## A evolução encadeia cada raio em 3 alvos.

const RANGE := 260.0


func fire(origin: Vector2) -> void:
	var r := raw("radius") * area()
	var chain := int(flags.get("chain", 0))
	var chain_range := float(flags.get("chain_range", 70.0))
	for _k: int in range(amount()):
		var target := game.enemies.random_alive(origin, RANGE)
		if target < 0:
			return
		game.areas.lightning(id, target, damage(), r, chain, chain_range)
