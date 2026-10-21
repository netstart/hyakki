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
		game.fx.play_anim("smoke_circular", at, r / 14.0)
	AudioManager.play("explosion3", 1.4, 0.1, -12.0)
