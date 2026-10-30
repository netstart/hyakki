extends RefCounted
## Dicas 心得 (data/tips.json, scripts/systems/tip_book.gd, tip_deck.gd e scripts/ui/tip_balloon.gd):
##   - dados (sem autoloads, run_unit): catálogo com ids únicos, categorias, condições e motivos
##     conhecidos; toda chave (dica, categoria, modelo, argumento) existe nos 11 idiomas do CSV com
##     os mesmos %s; as geradas cobrem toda arma com evolução e toda união e citam os nomes certos
##     (relíquia que evolui duas armas, desbloqueios pela conquista certa); condições (Android,
##     partidas, vitórias, mortes, já evoluiu, ryō para o Santuário, guardiã, liberado/bloqueado);
##     iniciante primeiro, sem repetir até esgotar o ciclo, determinismo pela semente, backup na
##     frente e espaçado; opção desligada sem dica; estado antigo migrado; motivos da derrota e a
##     dica "faltou";
##   - jogo (com a árvore, run): save antigo sem "tips" migra; "Dicas" ligada por padrão e
##     desligada esconde balão e cartão; textos traduzidos em todos os idiomas; o balão no título
##     aparece depois da entrada sem tirar o foco do Jogar, toque completa e passa, × fecha até
##     abrir de novo, troca sozinho em tempo real, sem pop com "Reduzir clarões"; cartão dos
##     Resultados pelo motivo da derrota; linha "Dicas" nas Opções liga, desliga e persiste.
## O layout do balão em todas as resoluções (tests/device_profiles.gd), nos 11 idiomas e com o furo
## dos dois lados fica em tests/title_layout_tests.gd; o do cartão, em tests/results_layout_tests.gd.

const LANGS: Array[String] = ["pt_BR", "en", "es", "de", "fr", "ru", "id", "ja", "ko", "zh_TW", "zh_CN"]
const ResultsLayout := preload("res://tests/results_layout_tests.gd")
const MenusLayout := preload("res://tests/menus_layout_tests.gd")

var _check: Callable
var _host: Node


static func _json(name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % name))


## Linhas do CSV: {chave: [11 textos]}.
static func _csv() -> Dictionary:
	var rows := {}
	var file := FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	if file == null:
		return rows
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() > 1:
			rows[row[0]] = row.slice(1)
	return rows


static func _catalog() -> Array[Dictionary]:
	return TipBook.build_catalog(_json("tips"), _json("weapons"), _json("passives"), _json("achievements"))


static func _ctx(extra: Dictionary = {}) -> Dictionary:
	var ctx := TipBook.default_context()
	var weapons: Array = []
	for w: Dictionary in _json("weapons"):
		if String(w.get("kind", "")) == "base" and String(w.get("unlock", "")).is_empty():
			weapons.append(String(w["id"]))
	var passives: Array = []
	for p: Dictionary in _json("passives"):
		if String(p.get("unlock", "")).is_empty():
			passives.append(String(p["id"]))
	ctx["available"] = {"weapons": weapons, "passives": passives}
	ctx.merge(extra, true)
	return ctx


static func _ids(list: Array) -> Array[String]:
	var out: Array[String] = []
	for tip: Dictionary in list:
		out.append(String(tip["id"]))
	return out


static func _find(catalog: Array[Dictionary], id: String) -> Dictionary:
	for tip: Dictionary in catalog:
		if tip["id"] == id:
			return tip
	return {}


static func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


# --- Dados e regras (sem autoloads) -------------------------------------------------------------

func run_unit(check: Callable) -> void:
	_check = check
	var raw: Dictionary = _json("tips")
	var catalog := _catalog()
	_test_catalog(raw, catalog)
	_test_texts(catalog)
	_test_generated(catalog)
	_test_conditions(catalog)
	_test_rotation(catalog)
	_test_backup(catalog)
	_test_state()
	_test_result_tags()
	var settings := load("res://scripts/autoload/settings.gd") as GDScript
	var defaults: Dictionary = settings.get_script_constant_map()["DEFAULTS"]
	_check.call(defaults.get("tips") == true, "dicas: opção \"tips\" vem ligada por padrão")


func _test_catalog(raw: Dictionary, catalog: Array[Dictionary]) -> void:
	var cats: Array = raw.get("categories", [])
	var written: Array = raw.get("tips", [])
	_check.call(written.size() >= 40 and written.size() <= 64,
			"dicas: %d dicas escritas (40 a 60 e poucas)" % written.size())
	var seen := {}
	for tip: Dictionary in catalog:
		var id := String(tip["id"])
		_check.call(not seen.has(id), "dicas: id %s único" % id)
		seen[id] = true
		_check.call(cats.has(tip["cat"]), "dicas: %s com categoria conhecida (%s)" % [id, tip["cat"]])
		for key: String in (tip["when"] as Dictionary):
			_check.call(TipBook.WHEN_KEYS.has(key), "dicas: %s com condição conhecida (%s)" % [id, key])
		for tag: String in tip["after"]:
			_check.call(TipBook.AFTER_TAGS.has(tag), "dicas: %s com motivo conhecido (%s)" % [id, tag])
		_check.call(int(tip["tier"]) >= 0 and int(tip["tier"]) < TipBook.TIER_RUNS.size(), "dicas: %s com nível válido" % id)
		for ref: String in tip["icons"]:
			_check.call(_icon_exists(ref), "dicas: %s com ícone %s existente" % [id, ref])
	for cat: Variant in cats:
		var used := catalog.any(func(t: Dictionary) -> bool: return t["cat"] == cat)
		_check.call(used, "dicas: categoria %s tem dicas" % cat)
	var tags := {}
	for tip: Dictionary in catalog:
		for tag: String in tip["after"]:
			tags[tag] = true
	for tag: String in TipBook.AFTER_TAGS:
		_check.call(tags.has(tag), "dicas: motivo da derrota %s tem dica" % tag)
	var backups := catalog.filter(func(t: Dictionary) -> bool: return t["cat"] == "backup")
	_check.call(backups.size() >= 2 and backups.size() <= 3, "dicas: 2 a 3 dicas de backup (%d)" % backups.size())
	for tip: Dictionary in backups:
		_check.call(String((tip["when"] as Dictionary).get("platform", "")) == "android",
				"dicas: %s só no Android" % tip["id"])


static func _icon_exists(ref: String) -> bool:
	var parts := ref.split(":")
	if parts.size() != 2:
		return false
	var table := {"weapon": "weapons", "passive": "passives", "item": "items", "kami": "kami"}
	if not table.has(parts[0]):
		return false
	for row: Dictionary in _json(table[parts[0]]):
		if String(row["id"]) == parts[1]:
			return ResourceLoader.exists(String(row.get("icon", "")))
	return false


func _test_texts(catalog: Array[Dictionary]) -> void:
	var csv := _csv()
	var placeholder := RegEx.create_from_string("%[sd]")
	var keys: Array[String] = ["options.tips", "tip.close", "tip.next", "results.tip"]
	for cat: Variant in (_json("tips") as Dictionary)["categories"]:
		keys.append("tip.cat.%s" % cat)
	for tip: Dictionary in catalog:
		keys.append(String(tip["key"]))
		keys.append_array(tip["args"])
	var missing: Array[String] = []
	var bad: Array[String] = []
	for key: String in keys:
		var row: Array = csv.get(key, [])
		if row.size() < LANGS.size():
			missing.append(key)
			continue
		for i: int in LANGS.size():
			if String(row[i]).strip_edges().is_empty():
				missing.append("%s [%s]" % [key, LANGS[i]])
		var base := placeholder.search_all(String(row[0])).size()
		for i: int in LANGS.size():
			if placeholder.search_all(String(row[i])).size() != base:
				bad.append("%s [%s]" % [key, LANGS[i]])
	_check.call(missing.is_empty(), "dicas: todas as chaves nos 11 idiomas (faltam %s)" % [missing])
	_check.call(bad.is_empty(), "dicas: mesmos %%s em todos os idiomas (%s)" % [bad])
	for tip: Dictionary in catalog:
		var row: Array = csv.get(String(tip["key"]), [""])
		var count := placeholder.search_all(String(row[0])).size()
		_check.call(count == (tip["args"] as Array).size(),
				"dicas: %s com um %%s por argumento (%d e %d)" % [tip["id"], count, (tip["args"] as Array).size()])
	var pt := func(key: String) -> String: return String((csv.get(key, [key]) as Array)[0])
	var sample := TipBook.text(_find(catalog, "evo.katana"), pt)
	_check.call(sample == "Katana no nível máx. + Saquê Sagrado = Lâmina do Amanhecer no próximo baú!",
			"dicas: texto gerado da Katana em português (%s)" % sample)


func _test_generated(catalog: Array[Dictionary]) -> void:
	var weapons: Array = _json("weapons")
	var by_id := {}
	for w: Dictionary in weapons:
		by_id[String(w["id"])] = w
	var evolutions := 0
	for w: Dictionary in weapons:
		var id := String(w["id"])
		if String(w.get("kind", "")) == "base" and not String(w.get("evolution", "")).is_empty():
			evolutions += 1
			var tip := _find(catalog, "evo." + id)
			var want := ["weapon.%s.name" % id, "passive.%s.name" % w["evolves_with"], "weapon.%s.name" % w["evolution"]]
			_check.call(not tip.is_empty() and tip["args"] == want and tip["key"] == TipBook.GEN_EVOLUTION
					and bool(tip["recipe"]) and tip["base"] == id,
					"dicas: evolução de %s cita arma, relíquia e evolução certas" % id)
			_check.call((tip["when"] as Dictionary).get("unlocked", []) == ["weapons:" + id, "passives:%s" % w["evolves_with"]],
					"dicas: evolução de %s só com arma e relíquia liberadas" % id)
		if String(w.get("kind", "")) == "union":
			var tip := _find(catalog, "union." + id)
			var needs: Array = w["requires"]
			_check.call(not tip.is_empty() and tip["args"] == ["weapon.%s.name" % needs[0], "weapon.%s.name" % needs[1],
					"weapon.%s.name" % id], "dicas: união %s cita as duas evoluções" % id)
			var unlocked: Array = (tip.get("when", {}) as Dictionary).get("unlocked", [])
			for need: Variant in needs:
				var base: Dictionary = by_id[String((by_id[String(need)] as Dictionary)["from"])]
				_check.call(unlocked.has("weapons:%s" % base["id"]) and unlocked.has("passives:%s" % base["evolves_with"]),
						"dicas: união %s pede %s e a relíquia dela liberadas" % [id, base["id"]])
		if not String(w.get("unlock", "")).is_empty():
			var tip := _find(catalog, "unlock.weapon." + id)
			_check.call(not tip.is_empty() and (tip["when"] as Dictionary).get("locked", []) == ["weapons:" + id],
					"dicas: %s bloqueada tem dica de como liberar" % id)
			if not tip.is_empty():
				var ach := String(tip["args"][1]).trim_prefix("achievement.").trim_suffix(".desc")
				var gives: bool = (_json("achievements") as Array).any(func(a: Dictionary) -> bool:
					return a["id"] == ach and String(a["reward"]).split(",").has("weapon:" + id))
				_check.call(gives, "dicas: a conquista citada (%s) libera mesmo %s" % [ach, id])
	var evo_tips := catalog.filter(func(t: Dictionary) -> bool: return String(t["id"]).begins_with("evo."))
	_check.call(evo_tips.size() == evolutions,
			"dicas: uma dica por arma com evolução (%d)" % evolutions)
	for pid: String in ["scroll", "jade", "noh_mask"]:
		_check.call(not _find(catalog, "shared." + pid).is_empty(), "dicas: %s evolui duas armas" % pid)
	for p: Dictionary in _json("passives"):
		if not String(p.get("unlock", "")).is_empty():
			_check.call(not _find(catalog, "unlock.passive.%s" % p["id"]).is_empty(),
					"dicas: relíquia %s bloqueada tem dica de como liberar" % p["id"])
	var missed := TipBook.missed_tip([{"id": "shuriken", "level": 3}, {"id": "katana", "level": 8}], weapons)
	_check.call(missed.get("id") == "missed.katana" and missed["args"][1] == "passive.sake.name",
			"dicas: Katana no nível 8 sem evoluir vira a dica \"faltou\"")
	_check.call(TipBook.missed_tip([{"id": "katana", "level": 7}, {"id": "dawn_blade", "level": 1}], weapons).is_empty(),
			"dicas: sem arma no máximo, nada de \"faltou\"")


func _test_conditions(catalog: Array[Dictionary]) -> void:
	var backup := _find(catalog, "backup_enable")
	_check.call(not TipBook.eligible(backup, _ctx({"runs": 5})), "dicas: backup fora do Android não aparece")
	_check.call(not TipBook.eligible(backup, _ctx({"platform": "android", "runs": 2})), "dicas: backup espera 3 partidas")
	_check.call(TipBook.eligible(backup, _ctx({"platform": "android", "runs": 3})),
			"dicas: backup no Android com progresso")
	var union := _find(catalog, "union_rule")
	_check.call(not TipBook.eligible(union, _ctx()) and TipBook.eligible(union, _ctx({"evolved": 1})),
			"dicas: uniões só depois da primeira evolução")
	var spend := _find(catalog, "sanctuary_spend")
	_check.call(not TipBook.eligible(spend, _ctx()) and TipBook.eligible(spend, _ctx({"can_buy": true})),
			"dicas: Santuário só com ryō para gastar")
	var rin := _find(catalog, "hero_rin")
	_check.call(TipBook.eligible(rin, _ctx({"hero": "rin"})) and not TipBook.eligible(rin, _ctx({"hero": "aki"})),
			"dicas: dica da Rin só com a Rin escolhida")
	var brisa := _find(catalog, "brisa_mode")
	_check.call(TipBook.eligible(brisa, _ctx({"deaths": 3}))
			and not TipBook.eligible(brisa, _ctx({"deaths": 3, "wins": 1}))
			and not TipBook.eligible(brisa, _ctx({"deaths": 2})), "dicas: modo Brisa só para quem ainda não venceu e morreu")
	var yumi := _find(catalog, "yumi_pierce")
	var lock := _find(catalog, "unlock.weapon.yumi")
	_check.call(not TipBook.eligible(yumi, _ctx()) and TipBook.eligible(lock, _ctx()),
			"dicas: Yumi bloqueado: só como liberar")
	var open := _ctx()
	(open["available"]["weapons"] as Array).append("yumi")
	_check.call(TipBook.eligible(yumi, open) and not TipBook.eligible(lock, open), "dicas: Yumi liberado: dica da arma")
	var evo := _find(catalog, "evo.fujin_fan")
	_check.call(not TipBook.eligible(evo, _ctx()), "dicas: evolução de arma bloqueada não aparece")
	_check.call(not TipBook.eligible({"when": {"desconhecida": true}}, _ctx()), "dicas: condição desconhecida reprova")
	_check.call(TipBook.tier_of(_find(catalog, "evo.katana"), _ctx({"hero_weapon": "katana"})) == 0
			and TipBook.tier_of(_find(catalog, "evo.kunai"), _ctx({"hero_weapon": "katana"})) == 1,
			"dicas: evolução da arma da guardiã conta como de iniciante")
	var off := _ctx({"enabled": false})
	_check.call(TipBook.pick(catalog, off, TipBook.default_state(), _rng(1)).is_empty()
			and TipBook.pick_for_result(catalog, off, TipBook.default_state(), _rng(1), ["early"],
			_find(catalog, "evo.katana")).is_empty(), "dicas: opção desligada, nenhuma dica")


func _test_rotation(catalog: Array[Dictionary]) -> void:
	var ctx := _ctx({"runs": 4, "wins": 1, "deaths": 3, "evolved": 2, "can_buy": true})
	var level := TipBook.experience(ctx)
	_check.call(level == 1 and TipBook.experience(_ctx()) == 0 and TipBook.experience(_ctx({"runs": 10})) == 2,
			"dicas: nível do jogador pelas partidas")
	var pool: Array[String] = []
	for tip: Dictionary in catalog:
		if TipBook.eligible(tip, ctx) and TipBook.tier_of(tip, ctx) <= level:
			pool.append(String(tip["id"]))
	var state := TipBook.default_state()
	var rng := _rng(42)
	var cycle: Array[String] = []
	var tiers: Array[int] = []
	for i: int in pool.size():
		var tip := TipBook.pick(catalog, ctx, state, rng)
		TipBook.mark_shown(state, tip)
		cycle.append(String(tip["id"]))
		tiers.append(TipBook.tier_of(tip, ctx))
	var unique := {}
	for id: String in cycle:
		unique[id] = true
	_check.call(unique.size() == pool.size(),
			"dicas: um ciclo inteiro sem repetir (%d de %d)" % [unique.size(), pool.size()])
	var sorted := tiers.duplicate()
	sorted.sort()
	_check.call(tiers == sorted, "dicas: iniciante primeiro, avançadas depois")
	var next := TipBook.pick(catalog, ctx, state, rng)
	_check.call(not next.is_empty() and pool.has(String(next["id"])) and next["id"] != cycle.back(),
			"dicas: ciclo esgotado recomeça sem repetir a última")
	var a := _sequence(catalog, ctx, 7, 12)
	_check.call(a == _sequence(catalog, ctx, 7, 12), "dicas: mesma semente, mesma sequência")
	_check.call(a != _sequence(catalog, ctx, 8, 12), "dicas: outra semente, outra sequência")
	var fresh := _ctx()
	var first := _sequence(catalog, fresh, 3, 10)
	var beginner := true
	for id: String in first:
		beginner = beginner and TipBook.tier_of(_find(catalog, id), fresh) == 0
	_check.call(beginner, "dicas: save novo só vê dicas de iniciante")


func _sequence(catalog: Array[Dictionary], ctx: Dictionary, seed: int, count: int) -> Array[String]:
	var state := TipBook.default_state()
	var rng := _rng(seed)
	var out: Array[String] = []
	for i: int in count:
		var tip := TipBook.pick(catalog, ctx, state, rng)
		TipBook.mark_shown(state, tip)
		out.append(String(tip.get("id", "")))
	return out


func _test_backup(catalog: Array[Dictionary]) -> void:
	var ctx := _ctx({"platform": "android", "runs": 3})
	var seq := _sequence(catalog, ctx, 5, 40)
	_check.call(seq[0] == "backup_enable", "dicas: backup é a 1ª dica no Android com progresso (%s)" % seq[0])
	var positions: Array[int] = []
	for i: int in seq.size():
		if String(_find(catalog, seq[i]).get("cat", "")) == "backup":
			positions.append(i)
	var spaced := true
	for i: int in range(1, positions.size()):
		spaced = spaced and positions[i] - positions[i - 1] > int(_find(catalog, "backup_restore")["gap"])
	_check.call(positions.size() >= 2 and spaced, "dicas: backup volta de tempos em tempos, espaçado (%s)" % [positions])
	var desktop := _sequence(catalog, _ctx({"runs": 3}), 5, 40)
	_check.call(not desktop.any(func(id: String) -> bool: return id.begins_with("backup")), "dicas: nada de backup no PC")


func _test_state() -> void:
	_check.call(TipBook.migrate_state(null) == TipBook.default_state(), "dicas: estado ausente vira o padrão")
	var old := TipBook.migrate_state({"seen": ["evo_rule"], "count": 3})
	_check.call(old["seen"] == ["evo_rule"] and old["ever"] == [] and int(old["count"]) == 3,
			"dicas: estado antigo completado sem perder o visto")
	var state := TipBook.default_state()
	for i: int in TipBook.RECENT_MAX + 5:
		TipBook.mark_shown(state, {"id": "t%d" % i})
	_check.call((state["recent"] as Array).size() == TipBook.RECENT_MAX and int(state["count"]) == TipBook.RECENT_MAX + 5,
			"dicas: recentes limitadas e total contado")


func _test_result_tags() -> void:
	var bosses := {&"tanuki": {"id": &"tanuki"}, &"onikuma": {"id": &"onikuma", "midboss": true},
			&"shinigami": {"id": &"shinigami"}}
	var enemies := {&"yurei": {"archetype": "shade"}, &"oni_red": {"archetype": "chaser"}}
	var weapons := {&"katana": {"kind": "base"}, &"dawn_blade": {"kind": "evolution"}}
	var r := {"victory": false, "time": 90.0, "damage_taken": {"cause": "oni_red"}, "weapons": [{"id": "katana"}]}
	_check.call(TipBook.result_tags(r, bosses, enemies, weapons) == ["early"], "dicas: morte cedo")
	r = {"victory": false, "time": 400.0, "damage_taken": {"cause": "tanuki"}, "weapons": [{"id": "katana"}]}
	var tags := TipBook.result_tags(r, bosses, enemies, weapons)
	_check.call(tags.has("boss") and tags.has("no_evolution") and tags.has("few_weapons") and not tags.has("early"),
			"dicas: chefe, sem evolução e poucas armas (%s)" % [tags])
	r["damage_taken"] = {"cause": "onikuma"}
	r["weapons"] = [{"id": "dawn_blade"}, {"id": "katana"}, {"id": "katana"}]
	tags = TipBook.result_tags(r, bosses, enemies, weapons)
	_check.call(tags == ["midboss"], "dicas: Guardião do Limiar com evolução (%s)" % [tags])
	r["damage_taken"] = {"cause": "shinigami"}
	_check.call(TipBook.result_tags(r, bosses, enemies, weapons) == ["shinigami"], "dicas: Shinigami")
	r["damage_taken"] = {"cause": "yurei"}
	_check.call(TipBook.result_tags(r, bosses, enemies, weapons) == ["dark"], "dicas: Sombra no escuro")
	r["victory"] = true
	_check.call(TipBook.result_tags(r, bosses, enemies, weapons).is_empty(), "dicas: vitória sem motivo")
	var catalog := _catalog()
	var ctx := _ctx({"runs": 4})
	var hits := 0
	for seed: int in range(1, 21):
		var tip := TipBook.pick_for_result(catalog, ctx, TipBook.default_state(), _rng(seed), ["boss"])
		if (tip["after"] as Array).has("boss"):
			hits += 1
	_check.call(hits == 20, "dicas: derrota para chefe traz dica de chefe (%d de 20)" % hits)
	var missed := _find(catalog, "evo.katana")
	_check.call(TipBook.pick_for_result(catalog, ctx, TipBook.default_state(), _rng(1), ["early"], missed) == missed,
			"dicas: a dica \"faltou\" vem antes de tudo")


# --- Jogo (com a árvore) ------------------------------------------------------------------------

func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var saved: Dictionary = SaveManager.data
	var tips_on: Variant = Settings.get_value("tips")
	var calm: Variant = Settings.get_value("reduce_flashes")
	TipDeck.platform_override = "desktop"
	_test_save()
	_test_translations()
	await _test_title()
	await _test_results()
	await _test_options()
	TipDeck.platform_override = ""
	Settings.set_value("tips", tips_on)
	Settings.set_value("reduce_flashes", calm)
	SaveManager.data = saved
	Locale.set_language("pt_BR", false)
	await _host.get_tree().process_frame


func _test_save() -> void:
	_check.call(SaveManager.default_profile()["tips"] == TipBook.default_state(), "dicas: save novo com o histórico vazio")
	var old := SaveManager.default_profile()
	old.erase("tips")
	var migrated := SaveManager.migrate(old)
	_check.call(migrated.get("tips") == TipBook.default_state(), "dicas: save antigo sem \"tips\" migra")
	SaveManager.data = SaveManager.default_profile()
	SaveManager.data["tips"] = "estragado"
	_check.call(TipDeck.state() == TipBook.default_state() and SaveManager.data["tips"] is Dictionary,
			"dicas: histórico estragado vira o padrão")
	Settings.set_value("tips", true)
	SaveManager.data = SaveManager.default_profile()
	var tip := TipDeck.next_tip(11)
	_check.call(not tip.is_empty() and (SaveManager.data["tips"]["seen"] as Array).has(tip["id"]),
			"dicas: dica do título registrada como vista")
	_check.call(TipBook.tier_of(tip, TipDeck.context()) == 0, "dicas: save novo começa por dica de iniciante")
	Settings.set_value("tips", false)
	_check.call(TipDeck.next_tip(11).is_empty() and TipDeck.result_tip({"victory": false, "time": 30.0}).is_empty(),
			"dicas: desligadas, nem título nem resultados")
	Settings.set_value("tips", true)
	_check.call(TipDeck.result_tip({"victory": true, "time": 900.0}).is_empty(), "dicas: vitória sem dica")
	TipDeck.platform_override = "android"
	SaveManager.data["stats"]["runs"] = 3
	_check.call(TipDeck.next_tip(5)["id"] == "backup_enable", "dicas: no Android com 3 partidas, a 1ª é o backup")
	TipDeck.platform_override = "desktop"
	SaveManager.data = SaveManager.default_profile()


func _test_translations() -> void:
	var catalog := TipDeck.catalog()
	for lang: String in LANGS:
		Locale.set_language(lang, false)
		var raw: Array[String] = []
		for tip: Dictionary in catalog:
			var text := TipDeck.text(tip)
			if text.contains("tip.") or text.contains("weapon.") or text.contains("passive.") or text.contains("%s"):
				raw.append(String(tip["id"]))
			if TipDeck.category_text(tip).begins_with("tip.cat"):
				raw.append(String(tip["id"]) + " (categoria)")
		_check.call(raw.is_empty(), "dicas [%s]: todas traduzidas e montadas (%s)" % [lang, raw])
	Locale.set_language("pt_BR", false)


func _open_title() -> Array:
	var app := App.new()
	_host.add_child(app)
	await _host.get_tree().process_frame
	var root := app.get("_root") as Control
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.size = Vector2(678, 305)
	app.go(&"title")
	var screen := (app.get("_screens") as Dictionary)[&"title"] as Control
	await _host.get_tree().process_frame
	screen.call("_finish_intro")
	await _host.get_tree().process_frame
	return [app, screen]


func _test_title() -> void:
	Locale.set_language("pt_BR", false)
	SaveManager.data = SaveManager.default_profile()
	Settings.set_value("tips", true)
	Settings.set_value("reduce_flashes", false)
	var opened := await _open_title()
	var app: App = opened[0]
	var screen: Control = opened[1]
	var balloon := screen.call("tip_balloon") as TipBalloon
	var play := screen.get("_play") as Button
	_check.call(balloon != null and not balloon.visible, "balão: escondido logo que o título abre")
	for i: int in 3:
		balloon.call("_process", TipBalloon.APPEAR_DELAY * 0.5)
	await _host.get_tree().process_frame
	_check.call(balloon.is_showing() and not balloon.current_tip().is_empty(), "balão: aparece depois da entrada")
	_check.call(screen.get_viewport().gui_get_focus_owner() == play and balloon.focus_mode == Control.FOCUS_NONE,
			"balão: não tira o foco do Jogar")
	var label := balloon.text_label()
	_check.call(label.visible_characters >= 0 and label.visible_characters < label.get_total_character_count(),
			"balão: texto aparece letra a letra")
	var first := balloon.current_tip()
	balloon.set("_shown_at", 0)
	balloon.tap(balloon.position + Vector2(20, 30))
	_check.call(label.visible_characters == -1 and balloon.current_tip() == first, "balão: toque completa o texto")
	balloon.tap(balloon.position + Vector2(20, 30))
	await _host.get_tree().create_timer(TipBalloon.FADE_TIME + 0.1).timeout
	_check.call(balloon.is_showing() and balloon.current_tip()["id"] != first["id"], "balão: outro toque passa a dica")
	var second := balloon.current_tip()
	balloon.reveal()
	balloon.call("_process", TipBalloon.ROTATE_EVERY + 0.1)
	await _host.get_tree().create_timer(TipBalloon.FADE_TIME + 0.1).timeout
	_check.call(balloon.current_tip()["id"] != second["id"],
			"balão: troca sozinho a cada %d s" % int(TipBalloon.ROTATE_EVERY))
	var close: Rect2 = balloon.layout_rects()["close"]
	balloon.tap(close.get_center())
	await _host.get_tree().create_timer(TipBalloon.FADE_TIME + 0.1).timeout
	_check.call(balloon.is_dismissed() and not balloon.visible, "balão: × fecha")
	balloon.call("_process", 30.0)
	_check.call(not balloon.visible, "balão: fechado não volta sozinho")
	_check.call(int(SaveManager.data["tips"]["count"]) >= 3, "balão: dicas vistas contadas")
	app.go(&"options")
	await _host.get_tree().process_frame
	app.go(&"title")
	_check.call(not balloon.visible and not balloon.is_dismissed(), "balão: título de novo agenda outra dica")
	balloon.call("_process", TipBalloon.APPEAR_DELAY + 0.1)
	_check.call(balloon.is_showing(), "balão: volta quando o título abre de novo")
	# Reduzir clarões: sem pop (escala e transparência finais na hora).
	Settings.set_value("reduce_flashes", true)
	balloon.next_tip()
	_check.call(balloon.scale == Vector2.ONE and is_equal_approx(balloon.modulate.a, 1.0),
			"balão: sem pop com Reduzir clarões")
	Settings.set_value("reduce_flashes", false)
	# Escondido com a tela: para e não troca de dica escondido.
	app.go(&"options")
	await _host.get_tree().process_frame
	var count := int(SaveManager.data["tips"]["count"])
	balloon.call("_process", 60.0)
	_check.call(not balloon.visible and int(SaveManager.data["tips"]["count"]) == count, "balão: some ao sair do título")
	# Opção desligada: nada no título.
	Settings.set_value("tips", false)
	app.go(&"title")
	balloon.call("_process", 5.0)
	_check.call(not balloon.visible, "balão: Dicas desligadas, nenhum balão")
	Settings.set_value("tips", true)
	app.queue_free()
	await _host.get_tree().process_frame


func _test_results() -> void:
	SaveManager.data = SaveManager.default_profile()
	Settings.set_value("tips", true)
	# Anfitrião com o tamanho e o tema do jogo (como em tests/results_layout_tests.gd).
	var area := Control.new()
	area.size = Vector2(678, 305)
	area.theme = ThemeFactory.build()
	_host.add_child(area)
	var app := ResultsLayout.StubApp.new()
	var r := ResultsLayout.make_result("defeat", 1)
	r["weapons"] = [{"id": "katana", "level": 8, "damage": 100.0, "dps": 1.0}]
	app.last_result = r
	var screen := (load(ResultsLayout.RESULTS_SCREEN) as GDScript).new() as Screen
	screen.app = app
	area.add_child(screen)
	screen.on_show()
	await _host.get_tree().process_frame
	var box := screen.get("_tip_box") as Control
	var card := screen.get("_tip") as TipBalloon.Card
	_check.call(box.visible and String((r["tip"] as Dictionary).get("id", "")) == "missed.katana",
			"resultados: Katana no máximo sem evoluir mostra a receita que faltou (%s)" % (r["tip"] as Dictionary).get("id"))
	_check.call(card.text.text == TipDeck.text(r["tip"]) and card.icons.get_child_count() == 3,
			"resultados: cartão 心得 com o texto e os ícones da receita")
	var shown := card.text.text
	screen.call("on_show")
	_check.call(card.text.text == shown, "resultados: a dica não muda ao mostrar de novo")
	var boss := ResultsLayout.make_result("defeat", 0)
	boss["damage_taken"] = {"cause": "tanuki"}
	boss["time"] = 320.0
	app.last_result = boss
	screen.call("on_show")
	_check.call(((boss["tip"] as Dictionary)["after"] as Array).has("boss")
			or ((boss["tip"] as Dictionary)["after"] as Array).has("no_evolution"),
			"resultados: derrota para chefe traz dica de chefe ou de evolução (%s)" % (boss["tip"] as Dictionary)["id"])
	var win := ResultsLayout.make_result("victory", 2)
	app.last_result = win
	screen.call("on_show")
	_check.call(not box.visible, "resultados: sem dica na vitória")
	Settings.set_value("tips", false)
	var off := ResultsLayout.make_result("defeat", 2)
	app.last_result = off
	screen.call("on_show")
	_check.call(not box.visible, "resultados: Dicas desligadas, sem cartão")
	Settings.set_value("tips", true)
	app.free()
	area.queue_free()
	await _host.get_tree().process_frame


func _test_options() -> void:
	Locale.set_language("pt_BR", false)
	Settings.set_value("tips", true)
	var menus := MenusLayout.new()
	var screen := await menus.open_screen(_host, Vector2(678, 305), &"options")
	var toggle := screen.find_child("opt_tips", true, false) as BaseButton
	_check.call(toggle != null and toggle.button_pressed, "opções: linha Dicas existe e vem ligada")
	if toggle != null:
		toggle.button_pressed = false
		_check.call(Settings.get_value("tips") == false, "opções: Dicas desliga")
		Settings.load_settings()
		_check.call(Settings.get_value("tips") == false, "opções: Dicas desligada persiste no arquivo")
		toggle.button_pressed = true
		Settings.load_settings()
		_check.call(Settings.get_value("tips") == true, "opções: Dicas liga de novo e persiste")
	menus.close_screen(screen)
	await _host.get_tree().process_frame
