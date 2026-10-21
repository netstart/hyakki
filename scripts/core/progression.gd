class_name Progression
extends RefCounted
## Fórmulas de ritmo e dificuldade (plano 4.3, 4.11 e 18.1). Funções puras, com testes.


## XP necessária para sair do nível `level` e chegar ao seguinte.
static func xp_to_next(level: int) -> int:
	if level < 20:
		return 5 + 10 * (level - 1)
	var at_19 := 5 + 10 * 18
	if level < 40:
		var value := at_19 + 13 * (level - 19)
		if level == 20:
			value += 600
		return value
	var at_39 := at_19 + 13 * 20
	var late := at_39 + 16 * (level - 39)
	if level == 40:
		late += 2400
	return late


static func enemy_hp_mult(minute: float) -> float:
	return 1.0 + 0.08 * minute


static func enemy_damage_mult(minute: float) -> float:
	return 1.0 + 0.04 * minute


## Inimigos que podem nascer por segundo. Controla o fluxo de XP: meta de nível 10
## por volta dos 3 min e nível 25 por volta dos 10 min (plano 4.3).
static func spawn_rate(minute: float) -> float:
	return 2.5 + 1.5 * minute


## Quantidade-alvo de inimigos na tela: alvo(m) = round(15 + 22·m + 0,9·m²), com teto.
static func target_count(minute: float, cap: int) -> int:
	return mini(roundi(15.0 + 22.0 * minute + 0.9 * minute * minute), cap)
