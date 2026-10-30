extends RefCounted
## Missões do Santuário (data/missions.json, scripts/meta/mission_book.gd, RunTracker, MetaProgress):
##   - dados: ids únicos, as 40 conquistas intactas, categorias, referências (fase, herói, chefe,
##     arma, Kami, item), recompensas conhecidas e textos montados em todos os idiomas;
##   - cada tipo de condição pelo caminho real (RunTracker + MissionBook.record_run + check_missions):
##     sem onigiri, Lua Vermelha por fase, Kakuriyo, vitória/nível/evolução por herói, evolução e
##     união por arma, chefe vencido / sem golpe / rápido, abates fora da luz, breu, Kami, Noite Sem
##     Fim, abates, Desafio Diário e coleção;
##   - recompensas (ryō, lanterna, reforço da próxima partida) dadas uma vez;
##   - save 1 → 2 (recordes) e a conferência única das missões que o progresso antigo já cumpre;
##   - Próximas metas: determinísticas, abertas, liberadas, variadas e as mais perto primeiro;
##     "+N" do apply_run;
##   - partida de verdade guiada pelo bot (sem --bot: com save) que conclui missões no amanhecer.
## Chamado por tests/integration_tests.gd e por tests/mission_runner.gd (já nos arquivos de teste
## do SaveManager).

const GAME_SCENE := "res://scenes/game/Game.tscn"
const ResultsLayoutTests := preload("res://tests/results_layout_tests.gd")
const STEP := 1.0 / 60.0
const LANGS: Array[String] = ["pt_BR", "en", "es", "de", "fr", "ru", "id", "ja", "ko", "zh_TW", "zh_CN"]
const KNOWN_REWARDS: Array[String] = ["ryo", "hero", "weapon", "passive", "stage", "cosmetic", "next_run"]
## Lanternas que existem no jogo (HyakkiGame.LANTERN_TINTS).
const COSMETICS: Array[String] = ["golden_lantern", "crimson_lantern", "jade_lantern", "azure_lantern",
		"violet_lantern"]

var _check: Callable
var _host: Node


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var saved := SaveManager.data
	_test_data()
	_test_texts()
	_test_stage_trackers()
	_test_hero_trackers()
	_test_weapon_trackers()
	_test_boss_trackers()
	_test_lantern_trackers()
	_test_kami_endless_daily()
	_test_kills_collection()
	_test_rewards()
	_test_tracker_snapshot()
	_test_migration()
	_test_next_goals()
	_test_goals_delta()
	await _test_bot_run()
	await _test_title_tap()
	await _test_results_animation()
	SaveManager.data = saved
	Locale.set_language("pt_BR", false)


func _fresh() -> void:
	SaveManager.data = SaveManager.default_profile()
	MissionBook.records()["synced"] = true


static func _result(extra: Dictionary = {}) -> Dictionary:
	var r := {"victory": true, "gave_up": false, "hero": "aki", "stage": "village", "mode": "normal", "moon": 0,
			"time": 900.0, "level": 20, "kills": 0, "endless": false, "daily": false, "realm": false,
			"revived_by_ad": false, "speed_min": 1, "speed_max": 1}
	r.merge(extra, true)
	return r


## Grava a partida e confere as missões; devolve as concluídas agora.
static func _play(result: Dictionary, tracker: RunTracker) -> Array[StringName]:
	MissionBook.record_run(result, tracker)
	return MissionBook.check_missions(false)


func _done(id: String) -> bool:
	return MissionBook.is_done(StringName(id))


# --- Dados -------------------------------------------------------------------------------

func _test_data() -> void:
	var ach := DB.ids("achievements")
	var missions := DB.ids("missions")
	_check.call(ach.size() == 41, "missões: as 41 conquistas de sempre continuam (%d)" % ach.size())
	_check.call(missions.size() >= 110, "missões: ao menos 110 missões novas (%d)" % missions.size())
	_check.call(MissionBook.ids().size() >= 150, "missões: ~150 no total (%d)" % MissionBook.ids().size())
	for id: StringName in [&"ach_first_steps", &"ach_win_village", &"ach_boss_red_oni", &"ach_win_moon5"]:
		_check.call(DB.achievements.has(id), "missões: conquista antiga %s mantida" % id)
	_check.call(String(DB.achievements[&"ach_win_village"]["reward"]) == "stage:bamboo,hero:hana"
			and String(DB.achievements[&"ach_survive_10"]["reward"]) == "hero:kenta"
			and String(DB.achievements[&"ach_win_moon5"]["reward"]) == "ryo:3000,cosmetic:crimson_lantern",
			"missões: recompensas antigas intactas")
	var per_cat := {}
	for id: StringName in MissionBook.ids():
		var cat := MissionBook.category(id)
		per_cat[cat] = int(per_cat.get(cat, 0)) + 1
		_check.call(MissionBook.CATEGORIES.has(cat), "missão %s: categoria conhecida (%s)" % [id, cat])
		_check.call(MissionBook.icon(id) != "" and ResourceLoader.exists(MissionBook.icon(id)),
				"missão %s: ícone existe (%s)" % [id, MissionBook.icon(id)])
		_check.call(MissionBook.raw_progress(id).y > 0.0, "missão %s: alvo positivo" % id)
	for cat: StringName in MissionBook.CATEGORIES:
		_check.call(int(per_cat.get(cat, 0)) >= 4, "missões: categoria %s com ao menos 4 (%d)" % [cat,
				int(per_cat.get(cat, 0))])
	for id: StringName in missions:
		_check.call(not DB.achievements.has(id), "missão %s: id não repete uma conquista" % id)
		var c := MissionBook.condition(id)
		_check.call(_refs_exist(c), "missão %s: referências existem (%s)" % [id, c])
		for part: String in String(MissionBook.data(id)["reward"]).split(",", false):
			var kv := part.split(":")
			_check.call(kv.size() == 2 and KNOWN_REWARDS.has(kv[0]), "missão %s: recompensa conhecida %s" % [id, part])
			if kv[0] == "ryo":
				_check.call(kv[1].to_int() >= 100, "missão %s: ryō ≥ 100" % id)
			elif kv[0] == "cosmetic":
				_check.call(COSMETICS.has(kv[1]), "missão %s: lanterna existe %s" % [id, kv[1]])
			elif kv[0] == "next_run":
				_check.call(DB.shop.has(StringName(kv[1])) and String(DB.shop[StringName(kv[1])]["reward"]) == "next_run",
						"missão %s: reforço da Loja existe %s" % [id, kv[1]])
		# Sem missão impossível de registrar: toda condição nova tem recorde no perfil.
		_check.call(_tracked(c), "missão %s: condição %s registrada pelo perfil" % [id, c["type"]])


static func _refs_exist(c: Dictionary) -> bool:
	if c.has("stage") and not DB.stages.has(StringName(String(c["stage"]))):
		return false
	if c.has("hero") and not DB.heroes.has(StringName(String(c["hero"]))):
		return false
	if c.has("boss") and (not DB.bosses.has(StringName(String(c["boss"]))) or String(c["boss"]) == "shinigami"):
		return false
	if c.has("kami") and not DB.kami.has(StringName(String(c["kami"]))):
		return false
	if c.has("item") and not DB.items.has(StringName(String(c["item"]))):
		return false
	if String(c["type"]) == "weapon_evolve":
		return String(DB.weapon(StringName(String(c["weapon"]))).get("kind", "")) == "evolution"
	if String(c["type"]) == "weapon_union":
		return String(DB.weapon(StringName(String(c["weapon"]))).get("kind", "")) == "union"
	return true


## O tipo tem progresso lido do perfil (não cai no 0/1 genérico do fim de raw_progress).
static func _tracked(c: Dictionary) -> bool:
	return String(c["type"]) in ["stage_no_item", "stage_moon", "stage_realm", "realm_count", "hero_win",
			"hero_level", "hero_evolve", "weapon_evolve", "weapon_union", "boss_kill", "boss_clean", "boss_fast",
			"dark_kills", "dark_kills_run", "dark_streak", "kami_accept", "kami_pacts", "endless_time",
			"endless_stages", "kills_total", "kills_run", "kills_burst_best", "daily_runs", "codex_entries",
			"chests_total", "ryo_total"]


## Nome, descrição, categoria e recompensas montados (sem chave crua nem %s) em todos os idiomas.
func _test_texts() -> void:
	_fresh()
	for lang: String in LANGS:
		Locale.set_language(lang, false)
		var raw: Array[String] = []
		for id: StringName in MissionBook.ids():
			for text: String in [MissionBook.title(id), MissionBook.description(id),
					MissionBook.category_name(MissionBook.category(id))]:
				if text.contains("%s") or text.contains("mission.") or text.contains("achievement.") or text.is_empty():
					raw.append("%s: %s" % [id, text])
			for part: Dictionary in MissionBook.reward_parts(id):
				if String(part["text"]).contains(".") and not String(part["text"]).contains(" "):
					raw.append("%s recompensa: %s" % [id, part["text"]])
		_check.call(raw.is_empty(), "missões [%s]: textos montados (%s)" % [lang, raw.slice(0, 3)])
		_check.call(TranslationServer.translate("codex.achievements") != "codex.achievements",
				"missões [%s]: marcador do Diário traduzido" % lang)
	Locale.set_language("pt_BR", false)
	var village := TranslationServer.translate("stage.village.name")
	_check.call(MissionBook.title(&"m_moon3_village") == "%s · Lua III" % village,
			"missões: modelo do nome com fase e lua em romano")
	_check.call(MissionBook.description(&"m_fast_tanuki").contains("01:00"), "missões: tempo do chefe em mm:ss")


# --- Condições ---------------------------------------------------------------------------

func _test_stage_trackers() -> void:
	_fresh()
	var t := RunTracker.new()
	t.items[&"onigiri"] = 2
	_play(_result(), t)
	_check.call(not _done("m_noheal_village"), "sem onigiri: vitória comendo onigiri não vale")
	_play(_result({"mode": "brisa"}), RunTracker.new())
	_check.call(not _done("m_noheal_village"), "sem onigiri: vitória na Brisa não vale")
	_play(_result({"victory": false}), RunTracker.new())
	_check.call(not _done("m_noheal_village"), "sem onigiri: derrota não vale")
	t = RunTracker.new()
	t.items[&"sushi"] = 1
	var got := _play(_result(), t)
	_check.call(got.has(&"m_noheal_village") and not _done("m_noheal_bamboo"),
			"sem onigiri: vitória na Vila sem onigiri conclui só a da Vila")
	# Lua Vermelha por fase: lida do recorde da fase (stage_best.max_moon).
	var best := SaveManager.stage_best(&"bamboo")
	best["won"] = true
	best["max_moon"] = 2
	got = MissionBook.check_missions(false)
	_check.call(got.has(&"m_moon1_bamboo") and not _done("m_moon3_bamboo"), "Lua: I no Bambu sim, III ainda não")
	_check.call(MissionBook.progress(&"m_moon3_bamboo") == Vector2(2, 3), "Lua: progresso 2/3 no Bambu")
	# Kakuriyo por fase e a contagem de fases.
	_play(_result({"stage": "temple", "realm": true, "victory": false}), RunTracker.new())
	var tracker := RunTracker.new()
	tracker.realm_reached = true
	_play(_result({"stage": "dunes", "victory": false}), tracker)
	_check.call(_done("m_realm_temple") and _done("m_realm_dunes") and not _done("m_realm_village"),
			"Kakuriyo: travessia (resultado ou rastreador) conclui a fase certa")
	_check.call(MissionBook.progress(&"m_realm_all") == Vector2(2, 6), "Kakuriyo: 2 de 6 fases")


func _test_hero_trackers() -> void:
	_fresh()
	_play(_result({"hero": "hana", "victory": false, "level": 41}), RunTracker.new())
	_check.call(_done("m_level40_hana") and not _done("m_win_hana"), "herói: nível 41 com Hana conclui o 40, sem vitória")
	_check.call(not _done("m_level40_aki"), "herói: nível de Hana não vale para Aki")
	_play(_result({"hero": "hana"}), RunTracker.new())
	_check.call(_done("m_win_hana"), "herói: vitória com Hana")
	var t := RunTracker.new()
	t.evolutions.append(&"amaterasu_barrier")
	_play(_result({"hero": "goro", "victory": false}), t)
	_check.call(not _done("m_evolve_goro"), "herói: evoluir outra arma não é a inicial do Goro")
	t = RunTracker.new()
	t.evolutions.append(&"temple_smoke")
	_play(_result({"hero": "goro", "victory": false}), t)
	_check.call(_done("m_evolve_goro"), "herói: Goro evolui o Incenso no Templo Fumegante")
	var smoke := TranslationServer.translate("weapon.temple_smoke.name")
	_check.call(MissionBook.description(&"m_evolve_goro").contains(smoke),
			"herói: descrição cita a evolução da arma inicial")


func _test_weapon_trackers() -> void:
	_fresh()
	var t := RunTracker.new()
	t.evolutions.append(&"dawn_blade")
	t.unions.append(&"hundred_blades")
	MetaProgress.apply_run(_result({"victory": false}), t)
	_check.call(_done("m_evo_dawn_blade") and not _done("m_evo_steel_storm"), "arma: evolução registrada pela partida")
	_check.call(_done("m_union_hundred_blades") and not _done("m_union_fujin_raijin"), "arma: união registrada")


func _test_boss_trackers() -> void:
	_fresh()
	# Luta limpa e rápida: entra aos 300 s, cai aos 340 s sem nenhum golpe dele.
	var dmg := DamageControl.new()
	var t := RunTracker.new()
	dmg.record(&"slime_rice", 5.0, 290.0)
	t.on_boss_start(&"tanuki", 300.0, dmg)
	dmg.record(&"slime_rice", 5.0, 320.0)
	t.on_boss_defeated(&"tanuki", 340.0, dmg)
	_check.call(t.bosses == [&"tanuki"] and is_equal_approx(float(t.boss_results[&"tanuki"]["time"]), 40.0)
			and bool(t.boss_results[&"tanuki"]["clean"]), "chefe: tempo da luta e sem golpe do chefe")
	# Onikuma acerta a guardiã uma vez: vence, mas não "sem golpe".
	t.on_boss_start(&"onikuma", 450.0, dmg)
	dmg.record(&"onikuma", 9.0, 460.0)
	t.on_boss_defeated(&"onikuma", 600.0, dmg)
	MetaProgress.apply_run(_result(), t)
	_check.call(_done("m_fast_tanuki") and not _done("m_clean_onikuma") and _done("m_boss_onikuma"),
			"chefe: rápido conclui, golpe do Guardião impede o sem golpe")
	_check.call(_done("ach_boss_tanuki"), "chefe: conquista antiga do Tanuki continua valendo")
	t = RunTracker.new()
	t.on_boss_start(&"onikuma", 450.0, dmg)
	t.on_boss_defeated(&"onikuma", 470.0, dmg)
	MetaProgress.apply_run(_result(), t)
	_check.call(_done("m_clean_onikuma"), "chefe: Guardião vencido sem golpe na outra partida")
	t = RunTracker.new()
	t.on_boss_start(&"bamboo_ancestral", 300.0, dmg)
	t.on_boss_defeated(&"bamboo_ancestral", 400.0, dmg)
	MetaProgress.apply_run(_result({"stage": "bamboo"}), t)
	_check.call(_done("m_boss_bamboo_ancestral") and not _done("m_fast_bamboo_ancestral"),
			"chefe: 100 s não cumpre o golpe veloz de 75 s")
	t = RunTracker.new()
	t.on_boss_defeated(&"kappa_elder", 700.0, dmg)
	_check.call(t.boss_results.is_empty() and t.bosses == [&"kappa_elder"], "chefe: sem entrada registrada, só a vitória")


func _test_lantern_trackers() -> void:
	_fresh()
	var t := RunTracker.new()
	for i: int in 320:
		t.on_kill(&"slime_rice", float(i) * 0.5, i % 2 == 0)
	_check.call(t.dark_kills == 160 and t.kills == 320, "lanterna: abates fora da luz contados à parte")
	_play(_result({"victory": false}), t)
	t = RunTracker.new()
	for i: int in 350:
		t.on_kill(&"slime_rice", float(i), true)
	t.max_dark_streak = 301.0
	_play(_result({"victory": false}), t)
	_check.call(int(MissionBook.records()["dark_kills"]) == 510 and _done("m_dark_500"),
			"lanterna: 500 fora da luz no total")
	_check.call(_done("m_dark_run_300") and int(MissionBook.records()["dark_kills_run"]) == 350,
			"lanterna: 300 numa partida (melhor partida)")
	_check.call(_done("m_dark_streak_300"), "lanterna: 5 min seguidos no breu")
	_check.call(MissionBook.progress_text(&"m_dark_2500") == "%s / %s" % [Locale.format_number(510),
			Locale.format_number(2500)], "lanterna: texto do progresso 510 / 2500")
	# Ritmo do registro na partida: step() com pouca luz conta o breu.
	t = RunTracker.new()
	for i: int in 120:
		t.step(1.0, 40.0, 0.0)
	_check.call(is_equal_approx(t.max_dark_streak, 120.0), "lanterna: step soma o tempo com pouca luz")


func _test_kami_endless_daily() -> void:
	_fresh()
	var t := RunTracker.new()
	t.kami.append_array([&"inari", &"raijin"])
	_play(_result({"victory": false}), t)
	_check.call(_done("m_kami_inari") and _done("m_kami_raijin") and not _done("m_kami_susanoo"),
			"Kami: cada pacto aceito")
	_check.call(MissionBook.progress(&"m_pacts_10") == Vector2(2, 10), "Kami: 2 de 10 pactos")
	for i: int in 8:
		t = RunTracker.new()
		t.kami.append(&"ebisu")
		_play(_result({"victory": false}), t)
	_check.call(_done("m_pacts_10"), "Kami: 10 pactos no total")
	_check.call(int(MissionBook.records()["no_kami_wins"]) == 0, "Kami: derrota não conta vitória sem Kami")
	_play(_result(), RunTracker.new())
	_check.call(int(MissionBook.records()["no_kami_wins"]) == 1, "Kami: vitória sem pacto registrada")
	for stage: StringName in [&"village", &"bamboo"]:
		SaveManager.stage_best(stage)["endless_best"] = 1100.0
	MissionBook.check_missions(false)
	_check.call(_done("m_endless_16") and _done("m_endless_18") and not _done("m_endless_19"),
			"Noite Sem Fim: 18:20 conclui 16 e 18 min")
	_check.call(MissionBook.progress(&"m_endless_stages") == Vector2(2, 3), "Noite Sem Fim: 2 de 3 fases em 18 min")
	SaveManager.stage_best(&"temple")["endless_best"] = 1080.0
	MissionBook.check_missions(false)
	_check.call(_done("m_endless_stages") and SaveManager.is_unlocked("cosmetics", &"violet_lantern"),
			"Noite Sem Fim: 3 fases dão a Lanterna Violeta")
	for i: int in 3:
		_play(_result({"daily": true, "victory": false, "time": 30.0}), RunTracker.new())
	_check.call(_done("m_daily_3") and not _done("m_daily_7"), "Diário: 3 participações (mesmo curtas)")


func _test_kills_collection() -> void:
	_fresh()
	var stats: Dictionary = SaveManager.data["stats"]
	stats["kills"] = 50000
	stats["chests"] = 49
	stats["max_kills_10s"] = 150
	SaveManager.data["ryo_total"] = 10000
	var t := RunTracker.new()
	t.kills = 1200
	_play(_result({"victory": false}), t)
	_check.call(_done("m_kills_50000") and not _done("m_kills_100000"), "abates: 50.000 no total")
	_check.call(_done("m_kills_run_1000") and not _done("m_kills_run_2000"), "abates: 1.000 numa partida")
	_check.call(_done("m_burst_150"), "abates: 150 em 10 s (recorde do perfil)")
	_check.call(_done("m_ryo_10000") and not _done("m_chests_50"), "coleção: 10.000 ryō, 49 baús ainda não")
	var kills: Dictionary = stats["kills_by_enemy"]
	for id: StringName in DB.ids("enemies").slice(0, 12):
		kills[String(id)] = 100
	MissionBook.check_missions(false)
	_check.call(MetaProgress.codex_count() >= 10 and _done("m_codex_10"), "coleção: 10 entradas no Diário")
	_check.call(int(MissionBook.raw_progress(&"m_codex_all").y) == MetaProgress.codex_count() + _codex_missing(),
			"coleção: o Diário completo é o total de entradas possíveis")


## Entradas que faltam para o Diário completo.
static func _codex_missing() -> int:
	var missing := 0
	for id: StringName in DB.ids("enemies"):
		var data := DB.enemy(id)
		if bool(data.get("codex", true)) and String(data.get("archetype", "")) != "prop" \
				and not MetaProgress.is_enemy_entry_unlocked(id):
			missing += 1
	for id: StringName in DB.ids("bosses"):
		if id != &"shinigami" and not (SaveManager.data["stats"]["bosses_defeated"] as Dictionary).has(String(id)):
			missing += 1
	return missing


# --- Recompensas, partida suspensa e save ------------------------------------------------

func _test_rewards() -> void:
	_fresh()
	SaveManager.data["ryo"] = 0
	var t := RunTracker.new()
	t.kami.append(&"inari")
	_play(_result({"victory": false}), t)
	_check.call(SaveManager.ryo() == 150, "recompensa: 150 ryō do pacto de Inari (%d)" % SaveManager.ryo())
	MissionBook.check_missions(false)
	_check.call(SaveManager.ryo() == 150, "recompensa: dada uma vez só")
	var t2 := RunTracker.new()
	t2.evolutions.append(&"dawn_blade")
	_play(_result({"victory": false}), t2)
	_check.call(bool((SaveManager.data["shop"]["next_run"] as Dictionary).get("slot_embers", false))
			and SaveManager.ryo() == 150 + 250, "recompensa: evolução inicial dá ryō e as Brasas Vivas (%d)" % SaveManager.ryo())
	var bonus := ShopManager.take_next_run_bonuses()
	_check.call(float((bonus["modifiers"] as Dictionary).get("growth", 0.0)) > 0.0, "recompensa: reforço entra na partida")
	MetaProgress.grant("next_run:slot_chest", false)
	_check.call(not (SaveManager.data["shop"]["next_run"] as Dictionary).has("slot_chest"),
			"recompensa: reaplicar desbloqueios não dá reforço de novo")
	SaveManager.data["achievements"]["m_pacts_60"] = 1
	_check.call(MetaProgress.reapply_achievement_unlocks() and SaveManager.is_unlocked("cosmetics", &"jade_lantern"),
			"recompensa: lanterna de missão reaplicada em save que já tinha a missão")
	var parts := MissionBook.reward_parts(&"m_pacts_60")
	_check.call(parts.size() == 2 and parts[0]["kind"] == "ryo" and int(parts[0]["amount"]) == 1500
			and parts[1]["kind"] == "cosmetic"
					and String(parts[1]["text"]) == TranslationServer.translate("cosmetic.jade_lantern"),
			"recompensa: partes com ícone e texto")
	_check.call(MissionBook.difficulty(&"m_pacts_60") == 1500 + MissionBook.UNLOCK_WEIGHT, "recompensa: peso da missão")
	var events: Array[StringName] = []
	var on_event := func(id: StringName) -> void: events.append(id)
	Events.achievement_unlocked.connect(on_event)
	var t3 := RunTracker.new()
	t3.kami.append(&"raijin")
	MetaProgress.check_achievements(_result({"victory": false}), t3)
	MissionBook.record_run(_result({"victory": false}), t3)
	var news := MetaProgress.check_achievements(_result({"victory": false}), t3)
	Events.achievement_unlocked.disconnect(on_event)
	_check.call(news.has(&"m_kami_raijin") and events.has(&"m_kami_raijin"),
			"recompensa: missão nova vem com as conquistas e avisa (Events)")


func _test_tracker_snapshot() -> void:
	var t := RunTracker.new()
	t.on_kill(&"slime_rice", 1.0, true)
	t.items[&"onigiri"] = 1
	t.kami.append(&"inari")
	t.ultimates = 3
	var dmg := DamageControl.new()
	t.on_boss_start(&"tanuki", 300.0, dmg)
	var copy := RunTracker.new()
	copy.restore(JSON.parse_string(JSON.stringify(t.snapshot())))
	copy.on_boss_defeated(&"tanuki", 330.0, dmg)
	_check.call(copy.dark_kills == 1 and int(copy.items.get(&"onigiri", 0)) == 1 and copy.kami == [&"inari"]
			and copy.ultimates == 3 and bool(copy.boss_results[&"tanuki"]["clean"])
			and is_equal_approx(float(copy.boss_results[&"tanuki"]["time"]), 30.0),
			"partida suspensa: rastreador das missões ida e volta")


func _test_migration() -> void:
	var old := {"version": 1, "ryo": 100, "ryo_total": 5000, "achievements": {"ach_win_village": 1},
			"stats": {"kills": 1500, "won_heroes": ["aki", "hana"], "bosses_defeated": {"tanuki": 1, "onikuma": 2},
					"evolved": ["dawn_blade"]},
			"stage_best": {"village": {"won": true, "won_brisa": false, "max_moon": 1, "best_time": 900.0,
					"endless_best": 0.0}},
			"unlocked": {"heroes": ["aki", "hana"], "weapons": [], "passives": [], "stages": ["village", "bamboo"],
					"cosmetics": [], "kami": []}}
	var migrated := SaveManager.migrate(old.duplicate(true))
	_check.call(int(migrated["version"]) == 2 and migrated.has("records")
			and int((migrated["records"]["hero_wins"] as Dictionary).get("hana", 0)) == 1
			and not bool(migrated["records"]["synced"]), "save 1 → 2: recordes criados das vitórias por herói")
	var file := FileAccess.open(SaveManager.path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	SaveManager.load_profile()
	var done: Dictionary = SaveManager.data["achievements"]
	for id: String in ["m_win_aki", "m_win_hana", "m_moon1_village", "m_boss_onikuma", "m_evo_dawn_blade"]:
		_check.call(done.has(id), "save antigo: %s conferida ao carregar" % id)
	_check.call(not done.has("m_moon3_village") and not done.has("m_noheal_village"),
			"save antigo: o que não dá para saber fica aberto")
	var ryo := SaveManager.ryo()
	var paid := 100
	for id: String in done:
		if not DB.achievements.has(StringName(id)):
			for part: Dictionary in MissionBook.reward_parts(StringName(id)):
				paid += int(part["amount"])
	_check.call(ryo == paid and ryo > 100 + 400 * 2, "save antigo: recompensas das missões cumpridas (%d)" % ryo)
	_check.call(bool(MissionBook.records()["synced"]) and done.has("ach_win_village"),
			"save antigo: conferido e conquista mantida")
	SaveManager.save_profile()
	SaveManager.load_profile()
	_check.call(SaveManager.ryo() == ryo, "save antigo: carregar de novo não paga de novo")


# --- Próximas metas ----------------------------------------------------------------------

func _test_next_goals() -> void:
	_fresh()
	var stats: Dictionary = SaveManager.data["stats"]
	stats["kills"] = 950
	var goals := MissionBook.next_goals()
	_check.call(goals.size() == 3 and goals == MissionBook.next_goals(), "metas: 3 e determinísticas")
	_check.call(goals[0] == &"ach_kills_1000", "metas: a mais perto primeiro (950/1000 abates): %s" % [goals])
	var cats := {}
	for id: StringName in goals:
		cats[MissionBook.category(id)] = true
		_check.call(not MissionBook.is_done(id) and MissionBook.is_available(id), "metas: %s aberta e liberada" % id)
	_check.call(cats.size() == 3, "metas: categorias variadas (%s)" % [goals])
	_check.call(not MissionBook.is_available(&"m_noheal_temple") and not MissionBook.is_available(&"m_moon1_bamboo")
			and not MissionBook.is_available(&"m_boss_onmoraki"), "metas: fase bloqueada (e o chefe dela) fica de fora")
	SaveManager.data["unlocked"]["heroes"] = ["aki"]
	_check.call(not MissionBook.is_available(&"m_win_rin") and not MissionBook.next_goals(500).has(&"m_level40_rin"),
			"metas: herói bloqueado fica de fora")
	SaveManager.data["unlocked"]["heroes"] = SaveManager.default_profile()["unlocked"]["heroes"]
	SaveManager.data["achievements"]["ach_kills_1000"] = 1
	_check.call(not MissionBook.next_goals().has(&"ach_kills_1000"), "metas: concluída sai da lista")
	var all := MissionBook.next_goals(500)
	var unique := {}
	for id: StringName in all:
		unique[id] = true
	_check.call(unique.size() == all.size(), "metas: sem repetir")
	for id: StringName in MissionBook.ids():
		SaveManager.data["achievements"][String(id)] = 1
	_check.call(MissionBook.next_goals().is_empty(), "metas: tudo cumprido, lista vazia")


func _test_goals_delta() -> void:
	_fresh()
	SaveManager.data["stats"]["kills"] = 900
	var t := RunTracker.new()
	t.kills = 60
	var applied := MetaProgress.apply_run(_result({"victory": false, "time": 30.0}), t)
	var goals: Array = applied["goals"]
	var kills: Array = goals.filter(func(g: Dictionary) -> bool: return g["id"] == "ach_kills_1000")
	_check.call(goals.size() == 3 and kills.size() == 1, "metas: apply_run devolve as 3 metas (%s)" % [goals])
	if kills.size() == 1:
		_check.call(is_equal_approx(float(kills[0]["before"]), 900.0) and is_equal_approx(float(kills[0]["after"]), 960.0)
				and is_equal_approx(float(kills[0]["target"]), 1000.0), "metas: antes 900, depois 960 de 1000")


# --- Partida pelo bot --------------------------------------------------------------------

## Partida de verdade (sem --bot, então com save): o bot anda 40 s, o Guardião do Limiar entra e cai
## na hora (sem tempo de acertar a guardiã) e o amanhecer encerra: as missões concluem no fim.
func _test_bot_run() -> void:
	_fresh()
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = {"hero": "aki", "stage": "village", "moon": 0, "mode": "normal", "seed": 4242, "speed": 1}
	_host.add_child(game)
	await _host.get_tree().process_frame
	GameClock.paused = true
	game.player.god_mode = true
	var results: Array[Dictionary] = []
	game.finished.connect(func(r: Dictionary) -> void: results.append(r))
	for _k: int in roundi(40.0 / STEP):
		game.player.move_input = BotPilot.input(game)
		_tick(game)
	var kills := game.tracker.kills
	var dark := game.tracker.dark_kills
	_check.call(kills > 0 and dark <= kills, "bot: abates na partida (%d, %d fora da luz)" % [kills, dark])
	game.bosses.spawn(&"onikuma", false)
	_tick(game)
	_check.call(game.tracker.boss_fights.has(&"onikuma"), "bot: entrada do Guardião registrada")
	for boss: Dictionary in game.bosses.bosses:
		game.enemies.damage(int(boss["index"]), 1.0e9, Vector2.ZERO, 0.0)
	for _k: int in 3:
		_tick(game)
	_check.call(game.tracker.boss_results.has(&"onikuma") and bool(game.tracker.boss_results[&"onikuma"]["clean"]),
			"bot: Guardião vencido sem golpe")
	game.ultimate.charge = UltimateSystem.FULL
	_check.call(game.ultimate.activate() and game.tracker.ultimates == 1, "bot: Golpe da Lanterna contado")
	var ate := int(game.tracker.items.get(&"onigiri", 0)) > 0
	GameClock.game_time = HyakkiGame.RUN_LENGTH - STEP * 2.0
	for _k: int in 4:
		_tick(game)
	_check.call(results.size() == 1 and bool(results[0]["victory"]), "bot: amanhecer encerra com vitória")
	if results.size() == 1:
		var news: Array = results[0]["new_achievements"]
		for id: StringName in [&"m_boss_onikuma", &"m_clean_onikuma", &"m_win_aki", &"ach_win_village"]:
			_check.call(news.has(id), "bot: %s concluída no fim da partida" % id)
		_check.call(news.has(&"m_noheal_village") != ate, "bot: sem onigiri só se não comeu (%s)" % ate)
		_check.call((results[0]["goals"] as Array).size() == 3, "bot: 3 próximas metas no resultado")
		_check.call(int(MissionBook.records()["dark_kills"]) == game.tracker.dark_kills
				and int(MissionBook.records()["kills_run"]) == game.tracker.kills, "bot: recordes gravados no perfil")
	game.queue_free()
	GameClock.paused = false
	await _host.get_tree().process_frame


static func _tick(game: HyakkiGame) -> void:
	GameClock.game_time += STEP
	game._on_tick(STEP)
	if game.hud.overlay_open() and not game.rift.crossing():
		game.hud.bot_answer()


# --- Telas -------------------------------------------------------------------------------

## Tocar nas metas do título abre o Diário nas Missões, na primeira meta.
func _test_title_tap() -> void:
	_fresh()
	var app := App.new()
	_host.add_child(app)
	await _host.get_tree().process_frame
	var root := app.get("_root") as Control
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.size = Vector2(678, 305)
	app.go(&"title")
	var title := (app.get("_screens") as Dictionary)[&"title"] as Control
	await _host.get_tree().process_frame
	var goals := title.call("goals") as MissionGoals
	var first := StringName(String(goals.rows[0]["id"])) if not goals.rows.is_empty() else &""
	_check.call(goals.rows.size() == 3 and first == MissionBook.next_goals()[0], "título: metas do perfil, na ordem")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	goals.call("_gui_input", tap)
	for _k: int in 3:
		await _host.get_tree().process_frame
	var codex := (app.get("_screens") as Dictionary).get(&"codex") as Control
	_check.call(app.current == &"codex" and codex != null, "título: tocar nas metas abre o Diário")
	if codex != null:
		await _host.get_tree().create_timer(0.5).timeout
		var entries: Array = codex.call("entries")
		var selected := int(codex.call("selected"))
		_check.call(codex.call("category") == &"achievements" and selected >= 0
				and String((entries[selected] as Dictionary)["id"]) == String(first),
				"título: o Diário abre nas Missões, na meta tocada")
	app.queue_free()
	await _host.get_tree().process_frame


## Resultados: a barra começa no valor de antes da partida, cresce até o de agora e o "+N" aparece.
func _test_results_animation() -> void:
	_fresh()
	var calm: Variant = Settings.get_value("reduce_flashes")
	Settings.set_value("reduce_flashes", false)
	var layout := ResultsLayoutTests.new()
	layout.set("_host", _host)
	layout.set("_check", _check)
	var r := ResultsLayoutTests.make_result("victory", 3)
	var screen: Control = await layout.call("_open", r, false)
	var goals := screen.get("_goals") as MissionGoals
	var row: Dictionary = goals.rows[0]
	var bar := row["bar"] as MissionGoals.GoalBar
	_check.call(is_equal_approx(bar.fill, float(row["before"]) / float(row["target"]))
			and (row["delta"] as Label).modulate.a < 0.5, "resultados: meta começa no valor de antes")
	await _host.get_tree().create_timer(MissionGoals.GROW_TIME + 1.2).timeout
	_check.call(is_equal_approx(bar.fill, float(row["after"]) / float(row["target"]))
			and is_equal_approx((row["delta"] as Label).modulate.a, 1.0), "resultados: barra cresce e o +N aparece")
	layout.call("_close", screen)
	Settings.set_value("reduce_flashes", calm)
	await _host.get_tree().process_frame
