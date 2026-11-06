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
## Habilidades dos guardiões (AbilitySystem). `slot` 0..2; `reason` é AbilitySystem.Fail.
## ability_used leva o kanji e o id para o letreiro da UI (o nome é tr("ability.<id>.name")).
signal ability_used(hero_id: StringName, slot: int, ability_id: StringName, kanji: String)
signal ability_failed(slot: int, reason: int)
## A recarga do slot terminou (e ele está liberado).
signal ability_ready(slot: int)
## O guardião chegou ao nível que libera a habilidade do slot (1, 5 e 10).
signal ability_unlocked(slot: int, ability_id: StringName)
## Altares do Selo (AltarSystem): o selo quebrou em `position`; `outcome` é &"elite" ou &"ambush".
signal altar_awakened(position: Vector2, outcome: StringName)
## Um Elite com afixos (EliteAffixes) entrou em campo: índice no EnemyManager, id do inimigo e
## os afixos (Array[StringName], na ordem do nome).
signal elite_spawned(index: int, enemy_id: StringName, affixes: Array)
## O Elite com afixos morreu em `position`.
signal elite_slain(position: Vector2, enemy_id: StringName, affixes: Array)
