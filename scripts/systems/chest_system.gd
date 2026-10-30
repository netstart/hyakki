class_name ChestSystem
extends RefCounted
## Baú Laqueado (plano 4.8): 1, 3 ou 5 melhorias (70/25/5%, a sorte desloca as chances).
## Prioriza uniões e evoluções prontas. Chefes garantem evolução se houver uma pronta.
## Cada baú tira uma sorte do omikuji (Omikuji): só a apresentação da contagem já sorteada,
## mais o 凶 de consolo (fluxo próprio da semente da partida) e os baús generosos do começo
## do save (fora do bot).

const BASE_THREE := 0.25
const BASE_FIVE := 0.05
const RYO_PER_ITEM := 10

var game: HyakkiGame
## Fluxo do omikuji (Omikuji.stream_seed): não mexe no `game.rng` da luta.
var fortune_rng := RandomNumberGenerator.new()
## Sorte do último baú aberto (Omikuji.KICHI...), para a tela.
var last_fortune: StringName = Omikuji.KICHI
## Sortes da partida, em ordem (testes e hash de determinismo).
var fortunes: Array[StringName] = []
## Baús generosos do save (desligado no bot e nos testes de determinismo).
var generous_enabled: bool = false


func _init(p_game: HyakkiGame) -> void:
	game = p_game


## Nova partida: fluxo do omikuji pela semente e se os baús generosos valem.
func reset(run_seed: int, generous: bool) -> void:
	fortune_rng.seed = Omikuji.stream_seed(run_seed)
	fortunes.clear()
	last_fortune = Omikuji.KICHI
	generous_enabled = generous


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
	var generous := not from_boss and generous_enabled and Omikuji.generous_left(SaveManager.data) > 0
	var count := roll_count(Omikuji.min_items(from_boss, 1 if generous else 0))
	if generous:
		Omikuji.use_generous(SaveManager.data)
	var rewards: Array[Dictionary] = []
	for _k: int in range(count):
		var reward := _next_reward()
		if reward.is_empty():
			break
		rewards.append(reward)
	# Um sorteio do fluxo por baú (mesma posição no fluxo, qualquer que seja a contagem).
	last_fortune = Omikuji.fortune_for(rewards.size(), fortune_rng.randf())
	fortunes.append(last_fortune)
	var ryo := RYO_PER_ITEM * count * (2 if from_boss else 1)
	if last_fortune == Omikuji.KYO:
		ryo += Omikuji.KYO_RYO
	game.add_run_ryo(ryo)
	rewards.append({"kind": "ryo", "title": tr("chest.ryo") % ryo, "icon": "res://assets/art/items/object/MoneyBag.png"})
	Events.chest_opened.emit(count)
	game.tracker.chests += 1
	return rewards


## Sortes da partida numa etiqueta curta (k = 吉, c = 中吉, d = 大吉, x = 凶) para o hash.
func fortune_tag() -> String:
	var tag := ""
	for fortune: StringName in fortunes:
		tag += {Omikuji.KICHI: "k", Omikuji.CHUKICHI: "c", Omikuji.DAIKICHI: "d", Omikuji.KYO: "x"}.get(fortune, "?")
	return tag


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
