extends Node
## Loja de recompensas (plano 17.3): 6 vagas; cada uma libera uma recompensa ao assistir
## um anúncio até o fim e entra em espera de 6 h. Sem servidor: guarda o horário de
## liberação e o maior horário já visto; se o relógio voltar, a espera não diminui.
## Também vende, com ryō, reforços de uso único para a próxima partida (linhas de
## data/shop.json com "price"). Eles entram na mesma fila de next_run das vagas: no máximo
## 1 de cada por partida, consumidos por take_next_run_bonuses().

signal slot_claimed(slot_id: StringName)

const COOLDOWN := 6 * 3600
const COSMETICS := ["jade_lantern", "azure_lantern", "violet_lantern", "crimson_lantern"]


func now() -> int:
	var real := int(Time.get_unix_time_from_system())
	var shop: Dictionary = SaveManager.data["shop"]
	var seen := int(shop.get("max_seen_unix", 0))
	if real > seen:
		shop["max_seen_unix"] = real
		return real
	# Relógio voltou no tempo: usa o maior horário já visto (não libera antes).
	return seen


func ready_at(slot: StringName) -> int:
	return int((SaveManager.data["shop"]["slots"] as Dictionary).get(String(slot), 0))


func seconds_left(slot: StringName) -> int:
	return maxi(0, ready_at(slot) - now())


func is_ready(slot: StringName) -> bool:
	return seconds_left(slot) <= 0


func any_ready() -> bool:
	for id: StringName in ad_slots():
		if is_ready(id):
			return true
	return false


## Vagas liberadas por anúncio (linhas sem preço), na ordem do arquivo.
func ad_slots() -> Array[StringName]:
	var list: Array[StringName] = []
	list.assign(DB.ids("shop").filter(func(id: StringName) -> bool: return not is_coin_item(id)))
	return list


## Reforços comprados com ryō (linhas com preço), na ordem do arquivo.
func coin_items() -> Array[StringName]:
	var list: Array[StringName] = []
	list.assign(DB.ids("shop").filter(is_coin_item))
	return list


func is_coin_item(id: StringName) -> bool:
	return (DB.shop.get(id, {}) as Dictionary).has("price")


func coin_price(id: StringName) -> int:
	return int((DB.shop.get(id, {}) as Dictionary).get("price", 0))


## Já está guardado para a próxima partida (vale para vagas e reforços).
func is_queued(id: StringName) -> bool:
	return (SaveManager.data["shop"]["next_run"] as Dictionary).has(String(id))


func can_buy_coin(id: StringName) -> bool:
	return is_coin_item(id) and not is_queued(id) and SaveManager.ryo() >= coin_price(id)


## Compra o reforço com ryō e guarda para a próxima partida. Não entra no "spent" do
## Santuário (o reembolso do Santuário não devolve consumíveis).
func buy_coin(id: StringName) -> bool:
	if not can_buy_coin(id):
		return false
	SaveManager.add_ryo(-coin_price(id))
	(SaveManager.data["shop"]["next_run"] as Dictionary)[String(id)] = true
	SaveManager.save_profile()
	return true


## Efeito do reforço em texto, no idioma atual (ex.: "+15% Crescimento").
func coin_effect(id: StringName) -> String:
	var data: Dictionary = DB.shop.get(id, {})
	var parts: PackedStringArray = []
	var mods: Dictionary = data.get("modifiers", {})
	if not mods.is_empty():
		parts.append(LevelUpSystem.describe_stats(mods))
	if int(data.get("start_chest", 0)) > 0:
		parts.append(tr("shop.coin.start_chest"))
	return ", ".join(parts)


## Valor do Saco de Ryō: cresce com o progresso da campanha (150 → 400).
func ryo_value() -> int:
	var data: Dictionary = DB.shop[&"slot_ryo"]
	var won := 0
	for id: StringName in DB.ids("stages"):
		if bool(SaveManager.stage_best(id)["won"]):
			won += 1
	return roundi(lerpf(float(data["value"]), float(data["value_max"]), won / 6.0))


## Assiste ao anúncio e entrega a recompensa. `done(ok)`.
func claim(slot: StringName, done: Callable) -> void:
	if not is_ready(slot):
		done.call(false)
		return
	AdsManager.show_rewarded("shop_" + String(slot), func(rewarded: bool) -> void:
		if not rewarded:
			done.call(false)
			return
		_deliver(slot)
		(SaveManager.data["shop"]["slots"] as Dictionary)[String(slot)] = now() + COOLDOWN
		SaveManager.save_profile()
		slot_claimed.emit(slot)
		done.call(true))


func _deliver(slot: StringName) -> void:
	var data: Dictionary = DB.shop[slot]
	match String(data["reward"]):
		"ryo":
			SaveManager.add_ryo(ryo_value())
		"next_run":
			(SaveManager.data["shop"]["next_run"] as Dictionary)[String(slot)] = true
		"cosmetic":
			var locked: Array[String] = []
			for c: String in COSMETICS:
				if not SaveManager.is_unlocked("cosmetics", StringName(c)):
					locked.append(c)
			if locked.is_empty():
				SaveManager.add_ryo(100)
			else:
				SaveManager.unlock("cosmetics", StringName(locked[randi() % locked.size()]))


## Recompensas guardadas para a próxima partida: no máximo 1 de cada (17.3).
## Consome e devolve os ajustes que entram na configuração da partida.
func take_next_run_bonuses() -> Dictionary:
	var pending: Dictionary = SaveManager.data["shop"]["next_run"]
	var mods: Dictionary = {}
	var result := {"modifiers": mods, "ult_start": 0, "start_chest": 0, "slots": pending.keys()}
	for key: String in pending:
		var data: Dictionary = DB.shop.get(StringName(key), {})
		for stat: String in data.get("modifiers", {}):
			mods[stat] = float(mods.get(stat, 0.0)) + float(data["modifiers"][stat])
		result["ult_start"] = maxi(int(result["ult_start"]), int(data.get("ult_start", 0)))
		result["start_chest"] = int(result["start_chest"]) + int(data.get("start_chest", 0))
	pending.clear()
	SaveManager.save_profile()
	return result


func pending_next_run() -> Array:
	return (SaveManager.data["shop"]["next_run"] as Dictionary).keys()
