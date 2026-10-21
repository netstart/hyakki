extends Node
## Barramento de sinais globais (plano 10.3).

## `ai` é EnemyManager.AI (permite distinguir chefe e lanterna destrutível).
signal enemy_killed(position: Vector2, xp: int, color: Color, enemy_id: StringName, was_elite: bool, ai: int)
signal player_hit(damage: float)
signal player_leveled(level: int)
signal boss_spawned(boss_id: StringName)
signal boss_defeated(boss_id: StringName)
signal weapon_evolved(weapon_id: StringName)
signal chest_opened(count: int)
signal item_collected(item_id: StringName)
signal kami_accepted(kami_id: StringName)
signal ultimate_used
signal achievement_unlocked(achievement_id: StringName)
