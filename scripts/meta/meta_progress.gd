class_name MetaProgress
extends RefCounted
## Meta-progressão (plano 4.10, 4.12 e 15.5): Santuário (power-ups com preço crescente e
## reembolso total), conquistas que desbloqueiam conteúdo, códex e registro da partida.

const CODEX_KILLS := 100
const ENDLESS_GOLD := 1.5
const TELEMETRY_HEADER := "date,hero,stage,mode,moon,time,level,kills,ryo,result,weapons,damage_taken,cause"


static func powerup_price(id: StringName) -> int:
	var data: Dictionary = DB.powerups[id]
	var total_bought := 0
	for key: String in SaveManager.data["powerups"]:
		total_bought += int(SaveManager.data["powerups"][key])
	var next_level := SaveManager.powerup_level(id) + 1
	return roundi(float(data["price"]) * (1.0 + 0.1 * total_bought) * next_level)


static func can_buy(id: StringName) -> bool:
	var data: Dictionary = DB.powerups[id]
	return SaveManager.powerup_level(id) < int(data["max"]) and SaveManager.ryo() >= powerup_price(id)


static func buy(id: StringName) -> bool:
	if not can_buy(id):
		return false
	var price := powerup_price(id)
	SaveManager.add_ryo(-price)
	SaveManager.data["powerups"][String(id)] = SaveManager.powerup_level(id) + 1
	SaveManager.data["spent"] = int(SaveManager.data.get("spent", 0)) + price
	SaveManager.save_profile()
	return true


## Reembolso total: devolve exatamente o que foi gasto (plano 4.10).
static func refund_all() -> int:
	var refunded := int(SaveManager.data.get("spent", 0))
	SaveManager.data["powerups"] = {}
	SaveManager.data["spent"] = 0
	SaveManager.data["ryo"] = SaveManager.ryo() + refunded
	SaveManager.save_profile()
	return refunded


## Modificadores de todos os power-ups comprados, para o StatBlock.
static func powerup_modifiers() -> Dictionary:
	var mods: Dictionary = {}
	for id: StringName in DB.ids("powerups"):
		var level := SaveManager.powerup_level(id)
		if level <= 0:
			continue
		var data: Dictionary = DB.powerups[id]
		var stat := String(data["stat"])
		mods[stat] = float(mods.get(stat, 0.0)) + float(data["per_level"]) * level
	return mods


static func is_hero_unlocked(id: StringName) -> bool:
	return SaveManager.is_unlocked("heroes", id)


static func is_stage_unlocked(id: StringName) -> bool:
	return SaveManager.is_unlocked("stages", id)


static func is_content_available(kind: String, id: StringName, data: Dictionary) -> bool:
	var unlock := String(data.get("unlock", ""))
	return unlock.is_empty() or SaveManager.is_unlocked(kind, id)


## Aplica o resultado da partida ao perfil. Devolve as conquistas novas e os desbloqueios.
static func apply_run(result: Dictionary, tracker: RunTracker) -> Dictionary:
	var data := SaveManager.data
	var stats: Dictionary = data["stats"]
	var ryo := tracker.ryo
	if bool(result.get("endless", false)):
		ryo = roundi(ryo * ENDLESS_GOLD)
	if tracker.doubled_ryo:
		ryo *= 2
	SaveManager.add_ryo(ryo)
	stats["runs"] = int(stats["runs"]) + 1
	stats["kills"] = int(stats["kills"]) + tracker.kills
	stats["time_played"] = float(stats["time_played"]) + float(result["time"])
	stats["chests"] = int(stats["chests"]) + tracker.chests
	stats["max_level"] = maxi(int(stats["max_level"]), int(result["level"]))
	stats["max_kills_10s"] = maxi(int(stats["max_kills_10s"]), tracker.max_kills_10s)
	if bool(result["victory"]):
		stats["wins"] = int(stats["wins"]) + 1
	else:
		stats["deaths"] = int(stats["deaths"]) + 1
	var by_enemy: Dictionary = stats["kills_by_enemy"]
	for id: StringName in tracker.kills_by_enemy:
		by_enemy[String(id)] = int(by_enemy.get(String(id), 0)) + int(tracker.kills_by_enemy[id])
	var bosses: Dictionary = stats["bosses_defeated"]
	for id: StringName in tracker.bosses:
		bosses[String(id)] = int(bosses.get(String(id), 0)) + 1
	var evolved: Array = stats["evolved"]
	for id: StringName in tracker.evolutions:
		if not evolved.has(String(id)):
			evolved.append(String(id))
	if not stats.has("unions"):
		stats["unions"] = []
	for id: StringName in tracker.unions:
		if not (stats["unions"] as Array).has(String(id)):
			(stats["unions"] as Array).append(String(id))
	var stage_id := StringName(result["stage"])
	var best := SaveManager.stage_best(stage_id)
	best["best_time"] = maxf(float(best["best_time"]), float(result["time"]))
	if bool(result["victory"]):
		if String(result["mode"]) == "brisa":
			best["won_brisa"] = true
		else:
			best["won"] = true
			best["max_moon"] = maxi(int(best["max_moon"]), int(result["moon"]))
		if not stats.has("won_heroes"):
			stats["won_heroes"] = []
		if not (stats["won_heroes"] as Array).has(String(result["hero"])):
			(stats["won_heroes"] as Array).append(String(result["hero"]))
		(data["defeat_streak"] as Dictionary)[String(stage_id)] = 0
	else:
		var streak: Dictionary = data["defeat_streak"]
		streak[String(stage_id)] = int(streak.get(String(stage_id), 0)) + 1
	if bool(result.get("endless", false)):
		best["endless_best"] = maxf(float(best["endless_best"]), float(result["time"]))
	if bool(result.get("daily", false)):
		var daily: Dictionary = data["daily"]
		daily["date"] = String(result.get("daily_date", ""))
		daily["best_time"] = maxf(float(daily["best_time"]), float(result["time"]))
		daily["best_kills"] = maxi(int(daily["best_kills"]), tracker.kills)
	var new_achievements := check_achievements(result, tracker)
	SaveManager.save_profile()
	_append_telemetry(tracker.csv_line(result))
	return {"ryo": ryo, "achievements": new_achievements}


static func check_achievements(result: Dictionary, tracker: RunTracker) -> Array[StringName]:
	var unlocked: Array[StringName] = []
	var done: Dictionary = SaveManager.data["achievements"]
	for id: StringName in DB.ids("achievements"):
		if done.has(String(id)):
			continue
		var data: Dictionary = DB.achievements[id]
		if _met(data["condition"], result, tracker):
			done[String(id)] = Time.get_unix_time_from_system()
			unlocked.append(id)
			grant(String(data.get("reward", "")))
			Events.achievement_unlocked.emit(id)
	return unlocked


static func _met(c: Dictionary, result: Dictionary, tracker: RunTracker) -> bool:
	var stats: Dictionary = SaveManager.data["stats"]
	var victory := bool(result["victory"])
	var time := float(result["time"])
	match String(c["type"]):
		"survive":
			return time >= float(c["seconds"]) and (not c.has("hero") or String(c["hero"]) == String(result["hero"]))
		"win_stage":
			return victory and String(result["stage"]) == String(c["stage"])
		"kills_total":
			return int(stats["kills"]) >= int(c["count"])
		"kills_burst":
			return tracker.max_kills_10s >= int(c["count"])
		"evolve_count":
			return (stats["evolved"] as Array).size() >= int(c["count"])
		"union_any":
			return not (stats.get("unions", []) as Array).is_empty()
		"boss_defeat":
			return (stats["bosses_defeated"] as Dictionary).has(String(c["boss"]))
		"level_reach":
			return int(result["level"]) >= int(c["level"])
		"ryo_total":
			return int(SaveManager.data["ryo_total"]) >= int(c["count"])
		"chests_total":
			return int(stats["chests"]) >= int(c["count"])
		"win_no_kami":
			return victory and tracker.kami.is_empty()
		"dark_survive":
			return tracker.max_dark_streak >= float(c["seconds"])
		"no_damage":
			return tracker.max_no_damage >= float(c["seconds"])
		"win_moon":
			return victory and String(result["mode"]) != "brisa" and int(result["moon"]) >= int(c["moon"])
		"win_mode":
			return victory and String(result["mode"]) == String(c["mode"])
		"endless_reach":
			return time >= float(c["seconds"])
		"ultimates_run":
			return tracker.ultimates >= int(c["count"])
		"daily_complete":
			return bool(result.get("daily", false)) and time >= 300.0
		"codex_entries":
			return codex_count() >= int(c["count"])
		"win_all_heroes":
			return (stats.get("won_heroes", []) as Array).size() >= DB.ids("heroes").size()
		"win_hero":
			return victory and String(result["hero"]) == String(c["hero"])
		"win_speed":
			var needed := int(c["speed"])
			return victory and int(result.get("speed_max", 1)) >= needed \
					and int(result.get("speed_min", 1)) >= needed
		"win_slow_moon":
			return victory and String(result["stage"]) == String(c["stage"]) \
					and int(result["moon"]) >= int(c["moon"]) and int(result.get("speed_max", 1)) == 1
	return false


## "ryo:100,hero:kenta" → aplica cada desbloqueio.
static func grant(reward: String) -> void:
	for part: String in reward.split(",", false):
		var pieces := part.split(":")
		if pieces.size() != 2:
			continue
		var kind := pieces[0]
		var value := pieces[1]
		match kind:
			"ryo":
				SaveManager.add_ryo(value.to_int())
			"hero":
				SaveManager.unlock("heroes", StringName(value))
			"weapon":
				SaveManager.unlock("weapons", StringName(value))
			"passive":
				SaveManager.unlock("passives", StringName(value))
			"stage":
				SaveManager.unlock("stages", StringName(value))
			"cosmetic":
				SaveManager.unlock("cosmetics", StringName(value))


## Entradas do Diário liberadas: inimigos com 100 abates, chefes vencidos, heróis.
static func codex_count() -> int:
	var count := 0
	var stats: Dictionary = SaveManager.data["stats"]
	for id: StringName in DB.ids("enemies"):
		if is_enemy_entry_unlocked(id):
			count += 1
	count += (stats["bosses_defeated"] as Dictionary).size()
	return count


static func is_enemy_entry_unlocked(id: StringName) -> bool:
	var data := DB.enemy(id)
	if not bool(data.get("codex", true)) or String(data.get("archetype", "")) == "prop":
		return false
	var kills: Dictionary = SaveManager.data["stats"]["kills_by_enemy"]
	return int(kills.get(String(id), 0)) >= CODEX_KILLS


static func _append_telemetry(line: String) -> void:
	var path := "user://runs.csv"
	var exists := FileAccess.file_exists(path)
	if exists and FileAccess.get_file_as_string(path).get_slice("\n", 0).strip_edges() != TELEMETRY_HEADER:
		# Colunas mudaram (dano recebido e causa, plano 4.15): guarda o arquivo antigo e começa outro.
		DirAccess.rename_absolute(path, "user://runs_old.csv")
		exists = false
	var file := FileAccess.open(path, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if file == null:
		return
	if not exists:
		file.store_line(TELEMETRY_HEADER)
	file.seek_end()
	file.store_line(line)
