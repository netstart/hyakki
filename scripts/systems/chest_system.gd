class_name ChestSystem
extends RefCounted
## Baú Laqueado (plano 4.8): 1, 3 ou 5 melhorias (70/25/5%, a sorte desloca as chances).
## Prioriza uniões e evoluções prontas. Chefes garantem evolução se houver uma pronta.

const BASE_THREE := 0.25
const BASE_FIVE := 0.05
const RYO_PER_ITEM := 10

var game: HyakkiGame


func _init(p_game: HyakkiGame) -> void:
	game = p_game


func roll_count(min_items: int = 1) -> int:
	var luck := game.player.stats.get_stat("luck")
	var roll := game.rng.randf()
	var count := 1
	if roll < BASE_FIVE * luck:
		count = 5
	elif roll < (BASE_FIVE + BASE_THREE) * luck:
		count = 3
	return maxi(count, mini(5, maxi(min_items, game.chest_min)))


## Sorteia e aplica as recompensas. Devolve a lista para a tela da roleta.
func open(from_boss: bool) -> Array[Dictionary]:
	var count := roll_count(3 if from_boss else 1)
	var rewards: Array[Dictionary] = []
	for _k: int in range(count):
		var reward := _next_reward()
		if reward.is_empty():
			break
		rewards.append(reward)
	var ryo := RYO_PER_ITEM * count * (2 if from_boss else 1)
	game.add_run_ryo(ryo)
	rewards.append({"kind": "ryo", "title": tr("chest.ryo") % ryo, "icon": "res://assets/art/items/object/MoneyBag.png"})
	Events.chest_opened.emit(count)
	game.tracker.chests += 1
	return rewards


func _next_reward() -> Dictionary:
	var levels := game.level_up
	var unions := levels.ready_unions()
	if not unions.is_empty():
		var union_id := unions[0]
		game.apply_union(union_id)
		return {"kind": "union", "id": union_id, "title": tr("weapon.%s.name" % union_id),
				"text": tr("chest.union"), "icon": DB.weapon(union_id).get("icon", "")}
	var ready := levels.ready_evolutions()
	if not ready.is_empty():
		var weapon := ready[0]
		var evolved := StringName(weapon.data["evolution"])
		game.evolve_weapon(weapon.id)
		return {"kind": "evolution", "id": evolved, "title": tr("weapon.%s.name" % evolved),
				"text": tr("chest.evolution"), "icon": DB.weapon(evolved).get("icon", "")}
	var choices := levels.build_choices(game.rng)
	if choices.is_empty():
		return {}
	var card := choices[0]
	levels.apply(card)
	return card
