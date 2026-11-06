class_name LevelUpSystem
extends RefCounted
## Escolhas de level-up (plano 4.4): 3 cartas (4 com sorte) sorteadas com peso, sem repetir.
## Pesos: item possuído ×1,5; novo ×1,0; possuído com evolução pronta ×1,2 a mais.
## Pular e Banir vêm do Santuário. Rerrolar está sempre à mão: as cargas grátis do Santuário vão
## primeiro e, sem elas, cada rolagem custa ryō da partida (reroll_cost). O texto de cada nível é
## montado dos dados. Com tudo no máximo a mão vira comida ou ryō (is_fallback), que a opção
## "levelup_auto_fallback" pode escolher sozinha (auto_card).

const MAX_WEAPONS := 6
const MAX_PASSIVES := 6
const WEIGHT_OWNED := 1.5
const WEIGHT_NEW := 1.0
const WEIGHT_READY := 1.2
const BASE_CARDS := 3
const MAX_LUCK_CHANCE := 0.4
## Rolagem paga (sem carga grátis): REROLL_BASE_COST ryō na 1ª da partida e +REROLL_STEP a cada
## outra (10, 20, 30...). O bot (sem Santuário nem ganância) junta ~15 ryō aos 3 min e ~45 aos
## 5 min, fora os 100 de cada chefe: a 1ª ou a 2ª paga cabem no meio da partida, rolar sem parar
## não (5 seguidas custam 150).
const REROLL_BASE_COST := 10
const REROLL_STEP := 10
## Opção da escolha automática da mão de comida/moedas: "" (perguntar) | "heal" | "ryo".
const AUTO_SETTING := "levelup_auto_fallback"
const FALLBACK_KINDS: Array[String] = ["heal", "ryo"]

var game: HyakkiGame
var passive_levels: Dictionary = {}
var banished: Array[StringName] = []
var rerolls: int = 0
var skips: int = 0
var banishes: int = 0
## Rolagens pagas com ryō nesta partida (o preço da próxima sobe com elas).
var paid_rerolls: int = 0


func _init(p_game: HyakkiGame) -> void:
	game = p_game


func reset() -> void:
	passive_levels.clear()
	banished.clear()
	apply_stats()
	var stats := game.player.stats
	rerolls = int(stats.get_stat("reroll"))
	skips = int(stats.get_stat("skip"))
	banishes = int(stats.get_stat("banish"))
	paid_rerolls = 0


func card_count() -> int:
	var count := BASE_CARDS + game.extra_choices
	var luck_chance := clampf((game.player.stats.get_stat("luck") - 1.0) / 2.0, 0.0, MAX_LUCK_CHANCE)
	if game.rng.randf() < luck_chance:
		count += 1
	return count


## `exclude`: cartas que já estão na mesa (rerrolar). Elas só voltam se o resto do sorteio não
## bastar para encher a mão.
func build_choices(rng: RandomNumberGenerator, exclude: Array[Dictionary] = []) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var weights: Array[float] = []
	for weapon: Weapon in game.weapons:
		if weapon.level < weapon.max_level:
			var w := WEIGHT_OWNED * (WEIGHT_READY if evolution_ready(weapon) else 1.0)
			pool.append(weapon_card(weapon.id, weapon.level + 1))
			weights.append(w)
	if game.weapons.size() < MAX_WEAPONS:
		for id: StringName in DB.ids("weapons"):
			var data := DB.weapon(id)
			if String(data.get("kind", "")) != "base" or game.has_weapon(id) or banished.has(id):
				continue
			if not game.is_weapon_available(id):
				continue
			pool.append(weapon_card(id, 1))
			weights.append(WEIGHT_NEW)
	for id: StringName in DB.ids("passives"):
		if banished.has(id) or not game.is_passive_available(id):
			continue
		var lv: int = passive_levels.get(id, 0)
		if lv >= int(DB.passives[id].get("max", 5)):
			continue
		if lv == 0 and passive_levels.size() >= MAX_PASSIVES:
			continue
		pool.append(passive_card(id, lv + 1))
		weights.append(WEIGHT_OWNED if lv > 0 else WEIGHT_NEW)
	var reserve: Array[Dictionary] = []
	var reserve_weights: Array[float] = []
	if not exclude.is_empty():
		var shown := {}
		for card: Dictionary in exclude:
			shown[_card_key(card)] = true
		for i: int in range(pool.size() - 1, -1, -1):
			if shown.has(_card_key(pool[i])):
				reserve.push_front(pool[i])
				reserve_weights.push_front(weights[i])
				pool.remove_at(i)
				weights.remove_at(i)
	var picks: Array[Dictionary] = []
	var wanted := card_count()
	_draw_into(picks, wanted, pool, weights, rng)
	_draw_into(picks, wanted, reserve, reserve_weights, rng)
	if picks.is_empty():
		picks = fallback_cards(RedMoon.no_food(game.moon))
	return picks


## Mão de quem já tem tudo no máximo: comida (cura) ou um saco de ryō. `no_food` (Lua Vermelha IV,
## sem bolinhos de arroz): só o saco de ryō.
static func fallback_cards(no_food: bool = false) -> Array[Dictionary]:
	var ryo := {"kind": "ryo", "id": &"ryo_bag", "level": 0, "tag": "",
			"title": TranslationServer.translate("item.ryo_bag.name"),
			"text": TranslationServer.translate("levelup.fallback_ryo"),
			"icon": "res://assets/art/items/object/MoneyBag.png"}
	if no_food:
		return [ryo]
	return [
		{"kind": "heal", "id": &"onigiri", "level": 0, "tag": "",
				"title": TranslationServer.translate("item.onigiri.name"),
				"text": TranslationServer.translate("levelup.fallback_heal"),
				"icon": "res://assets/art/items/food/Onigiri.png"},
		ryo,
	]


func apply(card: Dictionary) -> void:
	var id: StringName = card["id"]
	match String(card["kind"]):
		"weapon_new":
			game.add_weapon(id)
		"weapon_up":
			game.get_weapon(id).level_up()
		"passive":
			passive_levels[id] = int(card["level"])
			apply_stats()
		"heal":
			game.player.heal(30.0, true)
		"ryo":
			game.add_run_ryo(25)


## Preço da próxima rolagem: 0 enquanto houver carga grátis.
func reroll_cost() -> int:
	return 0 if rerolls > 0 else REROLL_BASE_COST + REROLL_STEP * paid_rerolls


func can_reroll() -> bool:
	return rerolls > 0 or game.tracker.ryo >= reroll_cost()


## Gasta uma rolagem: a carga grátis primeiro, senão o ryō da partida (e conta a paga).
## false, sem mexer em nada, se não houver carga nem ryō para pagar.
func spend_reroll() -> bool:
	if rerolls > 0:
		rerolls -= 1
		return true
	var cost := reroll_cost()
	if game.tracker.ryo < cost:
		return false
	game.tracker.spend_ryo(cost)
	paid_rerolls += 1
	return true


## Mão de quem já tem tudo no máximo: só comida e ryō (rerrolar e banir não mudam nada).
static func is_fallback(cards: Array[Dictionary]) -> bool:
	if cards.is_empty():
		return false
	for card: Dictionary in cards:
		if not FALLBACK_KINDS.has(String(card.get("kind", ""))):
			return false
	return true


## Carta que a escolha automática pega nesta mão, ou {} para perguntar (mão normal, opção em
## "Perguntar" ou o bot, que ignora a opção para não mudar o determinismo). Toque esperto: com a
## vida cheia a comida seria desperdiçada, então "Comida" pega o ryō; sem a carta de comida (Lua
## Vermelha IV), também.
func auto_card(cards: Array[Dictionary]) -> Dictionary:
	if game.is_bot() or not is_fallback(cards):
		return {}
	var kind := String(Settings.get_value(AUTO_SETTING))
	if not FALLBACK_KINDS.has(kind):
		return {}
	if kind == "heal" and (game.player.hp >= game.player.max_hp() or not _has_kind(cards, "heal")):
		kind = "ryo"
	for card: Dictionary in cards:
		if String(card["kind"]) == kind:
			return card
	return {}


static func _has_kind(cards: Array[Dictionary], kind: String) -> bool:
	for card: Dictionary in cards:
		if String(card.get("kind", "")) == kind:
			return true
	return false


## Escolha automática de níveis seguidos a partir de `hand` (`pending` pendentes, ao menos 1):
## aplica a carta de cada um e monta a mão do próximo com build_choices, gastando o rng como a
## escolha manual, até acabar os níveis ou a mão não sair sozinha. Devolve quantos resolveu; `hand`
## fica com a mão que sobrou para escolher.
func auto_resolve(hand: Array[Dictionary], pending: int) -> int:
	var done := 0
	var card := auto_card(hand)
	while not card.is_empty():
		apply(card)
		done += 1
		if done >= pending:
			break
		hand.assign(build_choices(game.rng))
		card = auto_card(hand)
	return done


func banish(card: Dictionary) -> void:
	if banishes <= 0:
		return
	banishes -= 1
	banished.append(StringName(card["id"]))


## Os passivos viram uma fonte de modificadores no StatBlock.
func apply_stats() -> void:
	var player := game.player
	var old_max := player.max_hp()
	var mods: Dictionary = {}
	for id: StringName in passive_levels:
		var per_level: Dictionary = DB.passives[id]["per_level"]
		for stat: String in per_level:
			mods[stat] = float(mods.get(stat, 0.0)) + float(per_level[stat]) * int(passive_levels[id])
	player.stats.set_source("passives", mods)
	if player.max_hp() > old_max:
		player.hp += player.max_hp() - old_max


func has_passive(id: StringName) -> bool:
	return int(passive_levels.get(id, 0)) > 0


## Arma no nível máximo + passivo correspondente = evolução pronta para o próximo baú.
func evolution_ready(weapon: Weapon) -> bool:
	var data := weapon.data
	if String(data.get("kind", "")) != "base" or weapon.level < weapon.max_level:
		return false
	var evolution := StringName(data.get("evolution", ""))
	return evolution != &"" and has_passive(StringName(data.get("evolves_with", ""))) \
			and not game.has_weapon(evolution)


func ready_evolutions() -> Array[Weapon]:
	var list: Array[Weapon] = []
	for weapon: Weapon in game.weapons:
		if evolution_ready(weapon):
			list.append(weapon)
	return list


func ready_unions() -> Array[StringName]:
	var list: Array[StringName] = []
	for id: StringName in DB.ids("weapons"):
		var data := DB.weapon(id)
		if String(data.get("kind", "")) != "union" or game.has_weapon(id):
			continue
		var ok := true
		for need: Variant in data.get("requires", []):
			if not game.has_weapon(StringName(need)):
				ok = false
		if ok:
			list.append(id)
	return list


func weapon_card(id: StringName, next_level: int) -> Dictionary:
	var data := DB.weapon(id)
	var is_new := next_level == 1
	var text := tr("weapon.%s.desc" % id) if is_new else describe_delta(data["levels"][next_level - 1])
	var weapon := game.get_weapon(id)
	var tag := tr("levelup.new") if is_new else tr("levelup.level") % next_level
	if weapon and next_level == weapon.max_level and not game.has_weapon(StringName(data.get("evolution", ""))):
		var passive := StringName(data.get("evolves_with", ""))
		if passive != &"":
			text += "\n" + tr("levelup.evolves_with") % tr("passive.%s.name" % passive)
	return {"kind": "weapon_new" if is_new else "weapon_up", "id": id, "level": next_level,
			"tag": tag, "title": tr("weapon.%s.name" % id), "text": text, "icon": data.get("icon", "")}


func passive_card(id: StringName, next_level: int) -> Dictionary:
	var data: Dictionary = DB.passives[id]
	var is_new := next_level == 1
	return {"kind": "passive", "id": id, "level": next_level,
			"tag": tr("levelup.new") if is_new else tr("levelup.level") % next_level,
			"title": tr("passive.%s.name" % id), "text": describe_stats(data["per_level"]),
			"icon": data.get("icon", "")}


## "+1 projétil, +10% área" a partir de um delta de nível.
static func describe_delta(delta: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key: String in delta:
		var value := float(delta[key])
		if Weapon.FRACTION_KEYS.has(key):
			parts.append(TranslationServer.translate("delta.%s" % key) % _signed_pct(value))
		else:
			parts.append(TranslationServer.translate("delta.%s" % key) % _signed(value))
	return ", ".join(parts)


## "+10% Poder" a partir de modificadores de atributo.
static func describe_stats(mods: Dictionary) -> String:
	var parts: PackedStringArray = []
	for stat: String in mods:
		var value := float(mods[stat])
		var mode: String = StatBlock.DEFS.get(stat, [0.0, "pct"])[1]
		# A chance de crítico é uma fração somada direto, mas se lê melhor em %.
		var number := _signed_pct(value) if mode == "pct" or stat == "crit" else _signed(value)
		parts.append(TranslationServer.translate("stat.%s" % stat) % number)
	return ", ".join(parts)


static func _signed(value: float) -> String:
	var text := str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
	return ("+" if value >= 0.0 else "") + text


static func _signed_pct(value: float) -> String:
	return ("+" if value >= 0.0 else "") + str(roundi(value * 100.0)) + "%"


static func _card_key(card: Dictionary) -> String:
	return "%s:%s" % [card.get("kind", ""), card.get("id", "")]


## Tira cartas de `pool` (com peso) até `picks` ter `wanted`.
static func _draw_into(picks: Array[Dictionary], wanted: int, pool: Array[Dictionary], weights: Array[float],
		rng: RandomNumberGenerator) -> void:
	while picks.size() < wanted and not pool.is_empty():
		var index := _weighted_index(weights, rng)
		picks.append(pool[index])
		pool.remove_at(index)
		weights.remove_at(index)


static func _weighted_index(weights: Array[float], rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w: float in weights:
		total += w
	var roll := rng.randf() * total
	for i: int in range(weights.size()):
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1
