class_name MissionBook
extends RefCounted
## Missões do Santuário: as 40 conquistas de data/achievements.json (condições e recompensas de
## sempre, conferidas pelo fim da partida em MetaProgress) mais as missões de data/missions.json,
## agrupadas por categoria (fases, guardiões, armas, chefes, lanterna, Kami, Noite Sem Fim,
## abates, Desafio Diário e coleção). Todas guardam a conclusão no mesmo
## SaveManager.data["achievements"] ({id: unix}), então saves antigos continuam valendo.
##
## As missões novas são conferidas só pelo perfil: cada partida grava recordes em
## SaveManager.data["records"] (record_run, chamado por MetaProgress.apply_run) e a missão fica
## pronta quando progress() chega no alvo. Assim cada missão tem barra de progresso, saves antigos
## ganham as que já cumpriram (catch_up, uma vez) e nada disso mexe na simulação: os dados vêm do
## RunTracker e do resultado, lidos depois do fim da partida.
##
## Nomes e descrições das missões novas saem de modelos por tipo de condição
## ("mission.<tipo>.name/desc"), preenchidos com os nomes do jogo (fase, herói, chefe, arma, Kami).
## next_goals() escolhe as 3 metas mais alcançáveis (determinístico, variando as categorias).

const CATEGORIES: Array[StringName] = [&"stages", &"heroes", &"weapons", &"bosses", &"lantern", &"kami",
		&"endless", &"kills", &"daily", &"collection"]
const CATEGORY_ICONS := {
	&"stages": "res://assets/art/ui/icons/meteo/Sun.png",
	&"heroes": "res://assets/art/ui/icons/items/Helmet.png",
	&"weapons": "res://assets/art/ui/icons/spell/MagicWeapon.png",
	&"bosses": "res://assets/art/ui/icons/spell/Death.png",
	&"lantern": "res://assets/art/ui/icons/spell/BookDarkness.png",
	&"kami": "res://assets/art/ui/icons/spell/OrbLight.png",
	&"endless": "res://assets/art/items/object/Hourglass.png",
	&"kills": "res://assets/art/ui/icons/spell/Cut.png",
	&"daily": "res://assets/art/ui/icons/meteo/Rain.png",
	&"collection": "res://assets/art/items/scroll/Scroll.png",
}
## Categoria das 40 conquistas antigas, pelo tipo da condição.
const LEGACY_CATEGORY := {
	"survive": &"stages", "win_stage": &"stages", "win_moon": &"stages", "win_mode": &"stages",
	"win_speed": &"stages", "win_slow_moon": &"stages", "no_damage": &"stages",
	"win_hero": &"heroes", "win_all_heroes": &"heroes", "level_reach": &"heroes", "ultimates_run": &"heroes",
	"evolve_count": &"weapons", "union_any": &"weapons", "boss_defeat": &"bosses", "dark_survive": &"lantern",
	"win_no_kami": &"kami", "endless_reach": &"endless", "kills_total": &"kills", "kills_burst": &"kills",
	"daily_complete": &"daily", "codex_entries": &"collection", "ryo_total": &"collection",
	"chests_total": &"collection",
}
## Tipos cujo progresso é tempo (mostrado como mm:ss).
const TIME_TYPES: Array[String] = ["survive", "dark_survive", "no_damage", "endless_reach", "endless_time",
		"dark_streak"]
const COIN_ICON := "res://assets/art/ui/icons/items/Money.png"
const COSMETIC_ICON := "res://assets/art/ui/icons/spell/OrbLight.png"
const RUN_LENGTH := 900.0
## Peso de um desbloqueio na dificuldade (desempate de next_goals), em ryō.
const UNLOCK_WEIGHT := 500
## Recordes das missões no perfil (SaveManager.default_profile()["records"]).
const DEFAULT_RECORDS := {
	"hero_wins": {}, "hero_level": {}, "hero_time": {}, "hero_evolve": {},
	"stage_no_item": {}, "stage_realm": {}, "boss_clean": {}, "boss_time": {}, "kami": {},
	"dark_kills": 0, "dark_kills_run": 0, "dark_streak": 0.0, "no_damage": 0.0, "kami_pacts": 0,
	"kills_run": 0, "ultimates_run": 0, "daily_runs": 0, "no_kami_wins": 0, "synced": false,
}


# --- Catálogo ----------------------------------------------------------------------------

## Todas as missões, na ordem do Diário: as conquistas antigas e depois as novas.
static func ids() -> Array[StringName]:
	var list := DB.ids("achievements")
	list.append_array(DB.ids("missions"))
	return list


static func has(id: StringName) -> bool:
	return DB.achievements.has(id) or DB.missions.has(id)


static func data(id: StringName) -> Dictionary:
	if DB.achievements.has(id):
		return DB.achievements[id]
	return DB.missions.get(id, {})


## Conquista antiga (data/achievements.json): conferida pela partida, texto próprio.
static func is_legacy(id: StringName) -> bool:
	return DB.achievements.has(id)


static func condition(id: StringName) -> Dictionary:
	return data(id).get("condition", {})


static func category(id: StringName) -> StringName:
	if is_legacy(id):
		return LEGACY_CATEGORY.get(String(condition(id).get("type", "")), &"stages")
	return StringName(String(data(id).get("cat", "stages")))


## Missões de uma categoria, na ordem do catálogo.
static func in_category(cat: StringName) -> Array[StringName]:
	var list: Array[StringName] = []
	for id: StringName in ids():
		if category(id) == cat:
			list.append(id)
	return list


static func is_done(id: StringName) -> bool:
	return (SaveManager.data["achievements"] as Dictionary).has(String(id))


static func records() -> Dictionary:
	if not SaveManager.data.has("records"):
		SaveManager.data["records"] = DEFAULT_RECORDS.duplicate(true)
	return SaveManager.data["records"]


# --- Textos e ícones ---------------------------------------------------------------------

static func title(id: StringName) -> String:
	if is_legacy(id):
		return TranslationServer.translate("achievement.%s.name" % id)
	var c := condition(id)
	return _fill(TranslationServer.translate("mission.%s.name" % c["type"]), _name_args(c))


static func description(id: StringName) -> String:
	if is_legacy(id):
		return TranslationServer.translate("achievement.%s.desc" % id)
	var c := condition(id)
	return _fill(TranslationServer.translate("mission.%s.desc" % c["type"]), _desc_args(c))


static func category_name(cat: StringName) -> String:
	return TranslationServer.translate("mission.cat.%s" % cat)


## Ícone: o do arquivo; senão, o rosto do herói ou do chefe, o ícone da arma ou do Kami.
static func icon(id: StringName) -> String:
	var row := data(id)
	if row.has("icon"):
		return String(row["icon"])
	var c: Dictionary = row.get("condition", {})
	if c.has("hero"):
		return String(DB.heroes.get(StringName(String(c["hero"])), {}).get("face", ""))
	if c.has("boss"):
		return boss_face(StringName(String(c["boss"])))
	if c.has("weapon"):
		return UiIcons.skill_path("weapons", String(c["weapon"]))
	if c.has("kami"):
		return UiIcons.skill_path("kami", String(c["kami"]))
	return String(CATEGORY_ICONS.get(category(id), ""))


## O ícone é um retrato (rosto de herói ou chefe), recortado no meio pelo cartão do Diário.
static func icon_is_face(id: StringName) -> bool:
	var c := condition(id)
	return not data(id).has("icon") and (c.has("hero") or c.has("boss"))


static func boss_face(boss: StringName) -> String:
	var b: Dictionary = DB.bosses.get(boss, {})
	if b.has("faceset"):
		return String(b["faceset"])
	var sprite: Dictionary = b.get("sprite", {})
	return String(sprite.get("path", "")).get_base_dir().path_join("Faceset.png")


static func _fill(template: String, args: Array) -> String:
	return template % args if template.count("%s") == args.size() else template


static func _stage(c: Dictionary) -> String:
	return TranslationServer.translate("stage.%s.name" % c["stage"])


static func _hero(c: Dictionary) -> String:
	return TranslationServer.translate("hero.%s.name" % c["hero"])


static func _boss(c: Dictionary) -> String:
	return TranslationServer.translate("boss.%s.name" % c["boss"])


static func _weapon(id: String) -> String:
	return TranslationServer.translate("weapon.%s.name" % id)


static func _num(c: Dictionary, key: String = "count") -> String:
	return Locale.format_number(int(c.get(key, 0)))


static func _name_args(c: Dictionary) -> Array:
	match String(c["type"]):
		"stage_no_item", "stage_realm":
			return [_stage(c)]
		"stage_moon":
			return [_stage(c), roman(int(c["moon"]))]
		"hero_win", "hero_evolve":
			return [_hero(c)]
		"hero_level":
			return [_hero(c), str(int(c["level"]))]
		"weapon_evolve", "weapon_union":
			return [_weapon(String(c["weapon"]))]
		"boss_kill", "boss_clean", "boss_fast":
			return [_boss(c)]
		"kami_accept":
			return [TranslationServer.translate("kami.%s.name" % c["kami"])]
		"endless_time":
			return [Screen.format_time(float(c["seconds"]))]
		"dark_kills", "kami_pacts", "kills_total", "kills_run", "daily_runs", "codex_entries", "chests_total", \
				"ryo_total":
			return [_num(c)]
	return []


static func _desc_args(c: Dictionary) -> Array:
	match String(c["type"]):
		"stage_no_item":
			return [_stage(c), TranslationServer.translate("item.%s.name" % c["item"])]
		"stage_realm":
			return [_stage(c)]
		"hero_evolve":
			var base := String(DB.heroes.get(StringName(String(c["hero"])), {}).get("weapon", ""))
			return [_hero(c), _weapon(String(DB.weapon(StringName(base)).get("evolution", base)))]
		"boss_fast":
			return [_boss(c), Screen.format_time(float(c["seconds"]))]
		"dark_streak":
			return [Screen.format_time(float(c["seconds"]))]
		"endless_stages":
			return [Screen.format_time(float(c["seconds"])), _num(c)]
		"realm_count", "dark_kills_run", "kills_burst_best":
			return [_num(c)]
	return _name_args(c)


static func roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]


# --- Recompensas -------------------------------------------------------------------------

## Partes da recompensa: {kind, id, amount, icon, text, face}. "next_run" é um reforço da Loja
## guardado para a próxima partida (o mesmo da vaga por anúncio).
static func reward_parts(id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for part: String in String(data(id).get("reward", "")).split(",", false):
		var kv := part.split(":")
		if kv.size() != 2:
			continue
		var kind := kv[0]
		var value := kv[1]
		var row := {"kind": kind, "id": value, "amount": 0, "icon": "", "text": "", "face": false}
		match kind:
			"ryo":
				row["amount"] = value.to_int()
				row["icon"] = COIN_ICON
				row["text"] = TranslationServer.translate("mission.reward_ryo") % Locale.format_number(value.to_int())
			"hero":
				row["icon"] = String(DB.heroes.get(StringName(value), {}).get("face", ""))
				row["face"] = true
				row["text"] = TranslationServer.translate("hero.%s.name" % value)
			"weapon":
				row["icon"] = UiIcons.skill_path("weapons", value)
				row["text"] = _weapon(value)
			"passive":
				row["icon"] = UiIcons.skill_path("passives", value)
				row["text"] = TranslationServer.translate("passive.%s.name" % value)
			"stage":
				row["icon"] = String(CATEGORY_ICONS[&"stages"])
				row["text"] = TranslationServer.translate("stage.%s.name" % value)
			"cosmetic":
				row["icon"] = COSMETIC_ICON
				row["text"] = TranslationServer.translate("cosmetic.%s" % value)
			"next_run":
				row["icon"] = String(DB.shop.get(StringName(value), {}).get("icon", ""))
				row["text"] = TranslationServer.translate("shop.%s.name" % value)
		out.append(row)
	return out


## Peso da missão (ryō da recompensa, desbloqueio = UNLOCK_WEIGHT): desempate das metas.
static func difficulty(id: StringName) -> int:
	var total := 0
	for part: Dictionary in reward_parts(id):
		total += int(part["amount"]) if part["kind"] == "ryo" else UNLOCK_WEIGHT
	return total


# --- Progresso ---------------------------------------------------------------------------

## [atual, alvo] da missão a partir do perfil; concluída = [alvo, alvo].
static func progress(id: StringName) -> Vector2:
	var raw := raw_progress(id)
	if is_done(id):
		return Vector2(raw.y, raw.y)
	return Vector2(minf(raw.x, raw.y), raw.y)


static func ratio(id: StringName) -> float:
	var p := progress(id)
	return clampf(p.x / p.y, 0.0, 1.0) if p.y > 0.0 else 0.0


## "312 / 500" (tempos em mm:ss).
static func progress_text(id: StringName) -> String:
	var p := progress(id)
	return format_progress(id, p.x, p.y)


static func format_progress(id: StringName, current: float, target: float) -> String:
	if TIME_TYPES.has(String(condition(id).get("type", ""))):
		return "%s / %s" % [Screen.format_time(current), Screen.format_time(target)]
	return "%s / %s" % [Locale.format_number(floori(current)), Locale.format_number(floori(target))]


## Valor atual e alvo sem considerar a conclusão (pode passar do alvo).
static func raw_progress(id: StringName) -> Vector2:
	var c := condition(id)
	var stats: Dictionary = SaveManager.data["stats"]
	var rec := records()
	match String(c.get("type", "")):
		"survive":
			var best := _best_time() if not c.has("hero") else float((rec["hero_time"] as Dictionary).get(c["hero"], 0.0))
			return Vector2(best, float(c["seconds"]))
		"win_stage":
			var b := SaveManager.stage_best(StringName(String(c["stage"])))
			return _flag(bool(b["won"]) or bool(b["won_brisa"]))
		"kills_total":
			return Vector2(float(stats["kills"]), float(c["count"]))
		"kills_burst", "kills_burst_best":
			return Vector2(float(stats["max_kills_10s"]), float(c["count"]))
		"evolve_count":
			return Vector2(float((stats["evolved"] as Array).size()), float(c["count"]))
		"union_any":
			return _flag(not (stats.get("unions", []) as Array).is_empty())
		"boss_defeat", "boss_kill":
			return _flag((stats["bosses_defeated"] as Dictionary).has(String(c["boss"])))
		"level_reach":
			return Vector2(float(stats["max_level"]), float(c["level"]))
		"ryo_total":
			return Vector2(float(SaveManager.data["ryo_total"]), float(c["count"]))
		"chests_total":
			return Vector2(float(stats["chests"]), float(c["count"]))
		"win_no_kami":
			return _flag(int(rec["no_kami_wins"]) > 0)
		"dark_survive", "dark_streak":
			return Vector2(float(rec["dark_streak"]), float(c["seconds"]))
		"no_damage":
			return Vector2(float(rec["no_damage"]), float(c["seconds"]))
		"win_moon":
			return Vector2(float(clampi(_max_moon(), 0, int(c["moon"]))), float(c["moon"]))
		"win_mode":
			return _flag(_any_brisa())
		"endless_reach", "endless_time":
			return Vector2(_best_endless(), float(c["seconds"]))
		"ultimates_run":
			return Vector2(float(rec["ultimates_run"]), float(c["count"]))
		"codex_entries":
			return Vector2(float(MetaProgress.codex_count()), float(c["count"]))
		"win_all_heroes":
			return Vector2(float((stats.get("won_heroes", []) as Array).size()), float(DB.ids("heroes").size()))
		"win_hero", "hero_win":
			return _flag((stats.get("won_heroes", []) as Array).has(String(c["hero"]))
					or int((rec["hero_wins"] as Dictionary).get(c["hero"], 0)) > 0)
	return _raw_new(c, stats, rec)


static func _raw_new(c: Dictionary, stats: Dictionary, rec: Dictionary) -> Vector2:
	match String(c.get("type", "")):
		"stage_no_item":
			return _flag((rec["stage_no_item"] as Dictionary).has("%s:%s" % [c["stage"], c["item"]]))
		"stage_moon":
			var moon := int(SaveManager.stage_best(StringName(String(c["stage"])))["max_moon"])
			return Vector2(float(clampi(moon, 0, int(c["moon"]))), float(c["moon"]))
		"stage_realm":
			return _flag((rec["stage_realm"] as Dictionary).has(String(c["stage"])))
		"realm_count":
			return Vector2(float((rec["stage_realm"] as Dictionary).size()), float(c["count"]))
		"hero_level":
			return Vector2(float((rec["hero_level"] as Dictionary).get(c["hero"], 0)), float(c["level"]))
		"hero_evolve":
			return _flag((rec["hero_evolve"] as Dictionary).has(String(c["hero"])))
		"weapon_evolve":
			return _flag((stats["evolved"] as Array).has(String(c["weapon"])))
		"weapon_union":
			return _flag((stats.get("unions", []) as Array).has(String(c["weapon"])))
		"boss_clean":
			return _flag((rec["boss_clean"] as Dictionary).has(String(c["boss"])))
		"boss_fast":
			var best := float((rec["boss_time"] as Dictionary).get(c["boss"], INF))
			return _flag(best <= float(c["seconds"]))
		"dark_kills":
			return Vector2(float(rec["dark_kills"]), float(c["count"]))
		"dark_kills_run":
			return Vector2(float(rec["dark_kills_run"]), float(c["count"]))
		"kami_accept":
			return _flag((rec["kami"] as Dictionary).has(String(c["kami"])))
		"kami_pacts":
			return Vector2(float(rec["kami_pacts"]), float(c["count"]))
		"endless_stages":
			var count := 0
			for s: StringName in DB.ids("stages"):
				count += int(float(SaveManager.stage_best(s)["endless_best"]) >= float(c["seconds"]))
			return Vector2(float(count), float(c["count"]))
		"kills_run":
			return Vector2(float(rec["kills_run"]), float(c["count"]))
		"daily_runs":
			return Vector2(float(rec["daily_runs"]), float(c["count"]))
	# Condições só da partida (sem recorde): 0 ou 1.
	return Vector2(0.0, 1.0)


static func _flag(on: bool) -> Vector2:
	return Vector2(1.0 if on else 0.0, 1.0)


static func _best_time() -> float:
	var best := 0.0
	for s: String in (SaveManager.data["stage_best"] as Dictionary):
		best = maxf(best, float((SaveManager.data["stage_best"][s] as Dictionary).get("best_time", 0.0)))
	return best


static func _best_endless() -> float:
	var best := 0.0
	for s: String in (SaveManager.data["stage_best"] as Dictionary):
		best = maxf(best, float((SaveManager.data["stage_best"][s] as Dictionary).get("endless_best", 0.0)))
	return best


static func _max_moon() -> int:
	var best := -1
	for s: String in (SaveManager.data["stage_best"] as Dictionary):
		best = maxi(best, int((SaveManager.data["stage_best"][s] as Dictionary).get("max_moon", -1)))
	return best


static func _any_brisa() -> bool:
	for s: String in (SaveManager.data["stage_best"] as Dictionary):
		if bool((SaveManager.data["stage_best"][s] as Dictionary).get("won_brisa", false)):
			return true
	return false


## Progresso atual de todas as missões ({id: atual}), para o "+N" dos Resultados.
static func snapshot() -> Dictionary:
	var out := {}
	for id: StringName in ids():
		out[String(id)] = progress(id).x
	return out


# --- Partida e conclusão -----------------------------------------------------------------

## Grava os recordes da partida no perfil (fim da partida, antes de conferir as missões). Só lê
## o resultado e o RunTracker: não toca na simulação.
static func record_run(result: Dictionary, tracker: RunTracker) -> void:
	var rec := records()
	var hero := String(result.get("hero", ""))
	var stage := String(result.get("stage", ""))
	var victory := bool(result.get("victory", false))
	var normal := String(result.get("mode", "normal")) != "brisa"
	var levels: Dictionary = rec["hero_level"]
	levels[hero] = maxi(int(levels.get(hero, 0)), int(result.get("level", 1)))
	var times: Dictionary = rec["hero_time"]
	times[hero] = maxf(float(times.get(hero, 0.0)), float(result.get("time", 0.0)))
	if victory:
		(rec["hero_wins"] as Dictionary)[hero] = int((rec["hero_wins"] as Dictionary).get(hero, 0)) + 1
		if tracker.kami.is_empty():
			rec["no_kami_wins"] = int(rec["no_kami_wins"]) + 1
		if normal:
			for item: String in ["onigiri"]:
				if int(tracker.items.get(StringName(item), 0)) == 0:
					(rec["stage_no_item"] as Dictionary)["%s:%s" % [stage, item]] = true
	var base := DB.weapon(StringName(String(DB.heroes.get(StringName(hero), {}).get("weapon", ""))))
	if base.has("evolution") and tracker.evolutions.has(StringName(String(base["evolution"]))):
		(rec["hero_evolve"] as Dictionary)[hero] = true
	if bool(result.get("realm", false)) or tracker.realm_reached:
		(rec["stage_realm"] as Dictionary)[stage] = true
	for boss: StringName in tracker.boss_results:
		var fight: Dictionary = tracker.boss_results[boss]
		if bool(fight["clean"]):
			(rec["boss_clean"] as Dictionary)[String(boss)] = true
		var fastest: Dictionary = rec["boss_time"]
		fastest[String(boss)] = minf(float(fastest.get(String(boss), INF)), float(fight["time"]))
	rec["dark_kills"] = int(rec["dark_kills"]) + tracker.dark_kills
	rec["dark_kills_run"] = maxi(int(rec["dark_kills_run"]), tracker.dark_kills)
	rec["dark_streak"] = maxf(float(rec["dark_streak"]), tracker.max_dark_streak)
	if not tracker.revived_by_ad:
		rec["no_damage"] = maxf(float(rec["no_damage"]), tracker.max_no_damage)
	rec["kami_pacts"] = int(rec["kami_pacts"]) + tracker.kami.size()
	for k: StringName in tracker.kami:
		(rec["kami"] as Dictionary)[String(k)] = int((rec["kami"] as Dictionary).get(String(k), 0)) + 1
	rec["kills_run"] = maxi(int(rec["kills_run"]), tracker.kills)
	rec["ultimates_run"] = maxi(int(rec["ultimates_run"]), tracker.ultimates)
	if bool(result.get("daily", false)):
		rec["daily_runs"] = int(rec["daily_runs"]) + 1


## Conclui as missões novas (data/missions.json) que chegaram ao alvo: marca, dá a recompensa e
## avisa (Events.achievement_unlocked, com `notify`). Devolve as concluídas agora.
static func check_missions(notify: bool = true) -> Array[StringName]:
	var unlocked: Array[StringName] = []
	var done: Dictionary = SaveManager.data["achievements"]
	for id: StringName in DB.ids("missions"):
		if done.has(String(id)):
			continue
		var p := raw_progress(id)
		if p.y > 0.0 and p.x >= p.y:
			done[String(id)] = Time.get_unix_time_from_system()
			unlocked.append(id)
			MetaProgress.grant(String(data(id).get("reward", "")))
			if notify:
				Events.achievement_unlocked.emit(id)
	return unlocked


## Uma vez por perfil (saves de antes das missões): conclui, em silêncio, as missões que o
## progresso guardado já cumpre (fases vencidas, chefes, evoluções, Lua Vermelha...).
## Devolve as concluídas.
static func catch_up() -> Array[StringName]:
	var rec := records()
	if bool(rec.get("synced", false)):
		return []
	rec["synced"] = true
	return check_missions(false)


## Migração do save 1 → 2: recordes que dá para tirar do que o perfil já guardava.
static func migrate_records(profile: Dictionary) -> void:
	if not profile.has("records"):
		profile["records"] = DEFAULT_RECORDS.duplicate(true)
	var rec: Dictionary = profile["records"]
	var stats: Dictionary = profile.get("stats", {})
	for hero: Variant in stats.get("won_heroes", []):
		var wins: Dictionary = rec["hero_wins"]
		wins[String(hero)] = maxi(int(wins.get(String(hero), 0)), 1)


# --- Próximas metas ----------------------------------------------------------------------

## As `count` missões mais alcançáveis ainda abertas: maior progresso (com uma estimativa para as
## de sim/não), depois a mais fácil (difficulty) e a ordem do catálogo; uma por categoria
## enquanto der. Só conteúdo liberado. Determinístico (só o perfil).
static func next_goals(count: int = 3) -> Array[StringName]:
	var rows: Array[Dictionary] = []
	var all := ids()
	for i: int in all.size():
		var id := all[i]
		if is_done(id) or not is_available(id):
			continue
		rows.append({"id": id, "score": achievability(id), "cost": difficulty(id), "index": i})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["score"]), float(b["score"])):
			return float(a["score"]) > float(b["score"])
		if int(a["cost"]) != int(b["cost"]):
			return int(a["cost"]) < int(b["cost"])
		return int(a["index"]) < int(b["index"]))
	var picked: Array[StringName] = []
	var cats: Array[StringName] = []
	for row: Dictionary in rows:
		var cat := category(row["id"])
		if not cats.has(cat):
			cats.append(cat)
			picked.append(row["id"])
			if picked.size() >= count:
				return picked
	for row: Dictionary in rows:
		if not picked.has(row["id"]):
			picked.append(row["id"])
			if picked.size() >= count:
				break
	return picked


## Quão perto está a missão (0..1): a razão do progresso; nas de sim/não sem progresso, uma
## estimativa pelo que o perfil já fez (fase vencida, tempo na fase, chefe já vencido...).
static func achievability(id: StringName) -> float:
	var p := raw_progress(id)
	var r := clampf(p.x / p.y, 0.0, 1.0) if p.y > 0.0 else 0.0
	if r > 0.0:
		return r
	if p.y != 1.0:
		# Contagem ainda em zero: as de recompensa menor (mais fáceis) vêm antes.
		return 0.25 * (1.0 - clampf(float(difficulty(id)) / 3000.0, 0.0, 1.0))
	var c := condition(id)
	var stage := StringName(String(c.get("stage", "")))
	match String(c.get("type", "")):
		"win_stage":
			return 0.6 * _stage_time(stage) / RUN_LENGTH
		"stage_no_item":
			return 0.5 if bool(SaveManager.stage_best(stage)["won"]) else 0.1
		"stage_realm":
			var mid := String(RiftPortal.midboss_of(DB.stage(stage)).get("id", ""))
			return 0.5 if (SaveManager.data["stats"]["bosses_defeated"] as Dictionary).has(mid) \
					else 0.4 * minf(1.0, _stage_time(stage) / 450.0)
		"win_hero", "hero_win":
			return 0.6 * float((records()["hero_time"] as Dictionary).get(c["hero"], 0.0)) / RUN_LENGTH
		"boss_defeat", "boss_kill":
			var at := _boss_time(StringName(String(c["boss"])))
			return 0.6 * minf(1.0, _stage_time(_boss_stage(StringName(String(c["boss"])))) / at) if at > 0.0 else 0.0
		"boss_clean", "boss_fast":
			return 0.35 if (SaveManager.data["stats"]["bosses_defeated"] as Dictionary).has(String(c["boss"])) else 0.05
		"kami_accept":
			return 0.45
		"hero_evolve", "weapon_evolve", "weapon_union":
			return 0.3
	return 0.2


## Conteúdo da missão já liberado (herói, fase, armas e relíquias da receita, chefe da fase).
static func is_available(id: StringName) -> bool:
	var c := condition(id)
	if c.has("hero") and not MetaProgress.is_hero_unlocked(StringName(String(c["hero"]))):
		return false
	if c.has("stage") and not MetaProgress.is_stage_unlocked(StringName(String(c["stage"]))):
		return false
	if c.has("boss") and not MetaProgress.is_stage_unlocked(_boss_stage(StringName(String(c["boss"])))):
		return false
	match String(c.get("type", "")):
		"stage_moon":
			return bool(SaveManager.stage_best(StringName(String(c["stage"])))["won"])
		"weapon_evolve":
			return _weapon_ready(StringName(String(c["weapon"])))
		"weapon_union":
			for part: Variant in DB.weapon(StringName(String(c["weapon"]))).get("requires", []):
				if not _weapon_ready(StringName(String(part))):
					return false
		"endless_reach", "endless_time", "endless_stages", "win_moon":
			return _any_won()
	return true


## Evolução cuja arma base e relíquia já saem no jogo.
static func _weapon_ready(evolution: StringName) -> bool:
	var base := StringName(String(DB.weapon(evolution).get("from", "")))
	var row := DB.weapon(base)
	if row.is_empty():
		return false
	var relic := StringName(String(row.get("evolves_with", "")))
	return MetaProgress.is_content_available("weapons", base, row) \
			and (relic == &"" or MetaProgress.is_content_available("passives", relic, DB.passives.get(relic, {})))


static func _any_won() -> bool:
	for s: String in (SaveManager.data["stage_best"] as Dictionary):
		if bool((SaveManager.data["stage_best"][s] as Dictionary).get("won", false)):
			return true
	return false


static func _stage_time(stage: StringName) -> float:
	var all: Dictionary = SaveManager.data["stage_best"]
	return float((all.get(String(stage), {}) as Dictionary).get("best_time", 0.0))


## Primeira fase em que o chefe aparece (chefe ou Guardião do Limiar) e o instante dele.
static func _boss_stage(boss: StringName) -> StringName:
	for s: StringName in DB.ids("stages"):
		var row: Dictionary = DB.stages[s]
		if String((row.get("midboss", {}) as Dictionary).get("id", "")) == String(boss):
			return s
		for b: Variant in row.get("bosses", []):
			if String((b as Dictionary)["id"]) == String(boss):
				return s
	return &"village"


static func _boss_time(boss: StringName) -> float:
	var row: Dictionary = DB.stages.get(_boss_stage(boss), {})
	var mid: Dictionary = row.get("midboss", {})
	if String(mid.get("id", "")) == String(boss):
		return float(mid["t"])
	for b: Variant in row.get("bosses", []):
		if String((b as Dictionary)["id"]) == String(boss):
			return float((b as Dictionary)["t"])
	return 0.0
