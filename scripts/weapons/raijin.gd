class_name Raijin
extends Weapon
## Raio de Raijin / Fúria de Raijin: relâmpagos em inimigos aleatórios (plano 4.5).
## A evolução encadeia cada raio em 3 alvos.

const RANGE := 260.0
## Trovão de fundo: mais agudo e baixo que o do Kaminari, no máximo a cada THUNDER_GAP s.
const THUNDER_GAP := 0.8

var _last_thunder: float = -100.0


func fire(origin: Vector2) -> void:
	var r := raw("radius") * area()
	var chain := int(flags.get("chain", 0))
	var chain_range := float(flags.get("chain_range", 70.0))
	# Herói com mão: o raio sai dela (origin já é a mão); sem mão, só cai do céu.
	var source := origin if game.player.has_hand() else Vector2.INF
	for _k: int in range(amount()):
		var target := game.enemies.random_alive(origin, RANGE)
		if target < 0:
			return
		game.areas.lightning(id, target, damage(), r, chain, chain_range, source, fx_color())
		WeaponSfx.launch(self)
		var now := GameClock.game_time
		if now - _last_thunder >= THUNDER_GAP:
			_last_thunder = now
			WeaponSfx.play("raijin_thunder", 0.92 if is_evolved() else 1.0)
