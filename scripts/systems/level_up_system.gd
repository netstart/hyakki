class_name LevelUpSystem
extends RefCounted
## Escolhas de level-up (plano 4.4): 3 cartas (4 com sorte) sorteadas com peso, sem repetir.
## Pesos: item possuído ×1,5; novo ×1,0; possuído com evolução pronta ×1,2 a mais.
## Rerolar, Pular e Banir vêm do Santuário. O texto de cada nível é montado dos dados.

const MAX_WEAPONS := 6
const MAX_PASSIVES := 6
const WEIGHT_OWNED := 1.5
const WEIGHT_NEW := 1.0
const WEIGHT_READY := 1.2
const BASE_CARDS := 3
const MAX_LUCK_CHANCE := 0.4

var game: HyakkiGame
var passive_levels: Dictionary = {}
var banished: Array[StringName] = []
var rerolls: int = 0
var skips: int = 0
var banishes: int = 0


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


func card_count() -> int:
	var count := BASE_CARDS + game.extra_choices
	var luck_chance := clampf((game.player.stats.get_stat("luck") - 1.0) / 2.0, 0.0, MAX_LUCK_CHANCE)
	if game.rng.randf() < luck_chance:
		count += 1
	return count


func build_choices(rng: RandomNumberGenerator) -> Array[Dictionary]:
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
	var picks: Array[Dictionary] = []
	var wanted := card_count()
	while picks.size() < wanted and not pool.is_empty():
		var index := _weighted_index(weights, rng)
		picks.append(pool[index])
		pool.remove_at(index)
		weights.remove_at(index)
	if picks.is_empty():
		picks.append({"kind": "heal", "id": &"onigiri", "level": 0, "tag": "",
				"title": tr("item.onigiri.name"), "text": tr("levelup.fallback_heal"),
				"icon": "res://assets/art/items/food/Onigiri.png"})
		picks.append({"kind": "ryo", "id": &"ryo_bag", "level": 0, "tag": "",
				"title": tr("item.ryo_bag.name"), "text": tr("levelup.fallback_ryo"),
				"icon": "res://assets/art/items/object/MoneyBag.png"})
	return picks


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
			game.player.heal(30.0)
		"ryo":
			game.add_run_ryo(25)


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
