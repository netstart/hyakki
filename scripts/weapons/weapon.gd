class_name Weapon
extends RefCounted
## Base das armas (plano 4.5): lê os valores e os níveis em data/weapons.json e aplica os
## atributos da guardiã (Poder, Área, Recarga, Quantidade, Duração, Vel. de projétil).
## - Deltas "damage", "amount" e "pierce" somam direto.
## - Deltas "area", "speed", "duration" e "cooldown" são frações (+0,25 = +25%).
## Com a Sombra Dupla do Kenta, cada disparo também sai da posição do clone.

const FRACTION_KEYS := ["area", "speed", "duration", "cooldown"]

var id: StringName
var data: Dictionary = {}
var flags: Dictionary = {}
var tags: Array = []
var level: int = 1
var max_level: int = 8
var game: HyakkiGame

var _timer: float = 0.3
var _sums: Dictionary = {}


func _init(p_game: HyakkiGame, p_id: StringName) -> void:
	game = p_game
	id = p_id
	data = DB.weapon(p_id)
	flags = data.get("flags", {})
	tags = data.get("tags", [])
	max_level = maxi(1, (data.get("levels", [{}]) as Array).size())
	_recalculate()


func is_evolved() -> bool:
	return String(data.get("kind", "base")) != "base"


func level_up() -> void:
	level = mini(level + 1, max_level)
	_recalculate()


func _recalculate() -> void:
	_sums.clear()
	var levels: Array = data.get("levels", [])
	for l: int in range(mini(level, levels.size())):
		var deltas: Dictionary = levels[l]
		for key: String in deltas:
			_sums[key] = float(_sums.get(key, 0.0)) + float(deltas[key])


## Valor da arma no nível atual, sem os atributos da guardiã.
func raw(key: String) -> float:
	var base := float((data.get("base", {}) as Dictionary).get(key, 0.0))
	var sum := float(_sums.get(key, 0.0))
	if FRACTION_KEYS.has(key):
		return base * (1.0 + sum)
	return base + sum


func stats() -> StatBlock:
	return game.player.stats


func damage() -> float:
	return raw("damage") * stats().get_stat("might") * game.damage_bonus()


func area() -> float:
	return raw("area") * stats().get_stat("area") if raw("area") > 0.0 else stats().get_stat("area")


func cooldown() -> float:
	return maxf(0.05, raw("cooldown") * stats().get_stat("cooldown"))


func amount() -> int:
	var tag_bonus := 0
	for tag: Variant in tags:
		tag_bonus += game.tag_amount_bonus(String(tag))
	return maxi(1, int(raw("amount")) + int(stats().get_stat("amount")) + game.hero_amount_bonus() + tag_bonus)


func duration() -> float:
	return raw("duration") * stats().get_stat("duration")


func proj_speed() -> float:
	return raw("speed") * stats().get_stat("proj_speed")


func knockback() -> float:
	return raw("knockback")


func step(dt: float) -> void:
	_timer -= dt
	if _timer <= 0.0:
		_timer += cooldown()
		fire_all()


func fire_all() -> void:
	fire(game.player.sim_pos)
	if game.player.clone_time > 0.0:
		fire(game.player.clone_position())


## Implementado por cada arma. `origin` é a posição da guardiã (ou do clone).
func fire(_origin: Vector2) -> void:
	pass


## Desenho opcional da arma (órbitas, aura), chamado pela camada de armas.
func draw(_canvas: CanvasItem) -> void:
	pass


func on_removed() -> void:
	pass
