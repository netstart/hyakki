class_name Tsurara
extends Weapon
## Tsurara 氷柱 / Sopro da Yuki-onna 雪女 (.ai/06-fogo-gelo-clones.md): leque de pingentes de gelo
## (projétil "icicle") na direção do inimigo mais próximo; cada acerto soma "chill" pilhas de frio
## (Weapon.apply_status). Com "spread" de volta inteira (a evolução), sai um anel de pingentes e
## RING_AIMED no alvo; com "shatter", inimigo morto congelado estilhaça (EnemyManager.shatter).

const RANGE := 260.0
## Pingentes mirados no alvo quando o leque é um anel inteiro, e o ângulo entre eles.
const RING_AIMED := 3
const AIMED_SPREAD := 0.16
const ICICLE_RADIUS := 3.0


func fire(origin: Vector2) -> void:
	var target := game.enemies.nearest(origin, RANGE)
	var aim := game.player.facing
	if target >= 0:
		aim = (game.enemies.pos[target] - origin).normalized()
	var count := amount()
	var spread := raw("spread")
	if spread >= TAU * 0.99:
		var ring := maxi(0, count - RING_AIMED)
		for k: int in range(ring):
			_shoot(origin, aim.rotated(TAU * (k + 0.5) / float(ring)))
		count -= ring
		spread = AIMED_SPREAD
	for k: int in range(count):
		_shoot(origin, aim.rotated((k - (count - 1) * 0.5) * spread))
	game.fx.muzzle(id, origin, aim)
	WeaponSfx.launch(self)


func _shoot(origin: Vector2, dir: Vector2) -> void:
	game.projectiles.spawn(id, "icicle", origin, dir * proj_speed(), damage(), ICICLE_RADIUS, int(raw("pierce")),
			duration(), knockback())


## Estilhaçar (Sopro da Yuki-onna): inimigo morto congelado explode em estilhaços.
func on_kill(at: Vector2, _j: int) -> void:
	if bool(flags.get("shatter", false)) and game.enemies.dying_frozen():
		game.elements.shatter(at, id, EnemyManager.SHATTER_DAMAGE * stats().get_stat("might"))
