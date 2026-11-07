extends RefCounted
## Guia do Diário (scripts/systems/guide_book.gd, scripts/ui/guide_page.gd, marcador "Guia" de
## scripts/app/screens/codex_screen.gd):
##   - dados (run_data): os 11 capítulos montam dos dados nos 11 idiomas, sem chave crua nem %s
##     sobrando; os números batem com data/*.json e com as constantes do código (noite, cartas,
##     espaços, níveis máximos, chances e ryō dos baús, itens do chão, horários dos chefes, aviso
##     do Guardião do Limiar, Santuário, Kami, Lua Vermelha, Noite Sem Fim, modo Brisa, Desafio
##     Diário, Altares do Selo e afixos, terrenos, perigos da fase e do Kakuriyo); a descoberta
##     esconde receitas, chefes, guardiãs, fases, o Kakuriyo, afixos e o Shinigami como o Diário
##     (Discovery); backup do Google só
##     no Android; toda dica do catálogo aparece, fica guardada (spoiler) ou é da outra
##     plataforma, e com tudo descoberto só as de "bloqueado" ficam de fora;
##   - tela (run): o Guia é o primeiro marcador e abre na primeira vez; um cartão por capítulo;
##     escolher capítulo troca a página; "Ver no Diário" e os chips abrem a categoria/o item; o
##     Diário lembra o último marcador; o contador "x/y descobertos" não conta o Guia;
##   - layout (check_layout, chamado por tests/menus_layout_tests.gd em cada resolução de
##     tests/device_profiles.gd, nos 11 idiomas e com o furo da câmera dos dois lados): cada
##     capítulo inteiro na página, sem texto cortado nem passando da largura, botões com altura
##     de toque, dicas e textos ricos dentro da área de rolagem.

const LANGS: Array[String] = ["pt_BR", "en", "es", "de", "fr", "ru", "id", "ja", "ko", "zh_TW", "zh_CN"]
const MenusLayout := preload("res://tests/menus_layout_tests.gd")

var _check: Callable


static func _json(name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % name))


func _ok(condition: bool, label: String, args: Variant = null) -> void:
	_check.call(condition, label, args)


## Perfil com tudo descoberto (os nomes mais longos aparecem no lugar de "???").
static func full_profile() -> void:
	var d := SaveManager.data
	for w: StringName in DB.ids("weapons"):
		var kind := String(DB.weapon(w).get("kind", "base"))
		if kind == "evolution":
			(d["stats"]["evolved"] as Array).append(String(w))
		elif kind == "union":
			if not (d["stats"] as Dictionary).has("unions"):
				d["stats"]["unions"] = []
			(d["stats"]["unions"] as Array).append(String(w))
		elif String(DB.weapon(w).get("unlock", "")) != "":
			(d["unlocked"]["weapons"] as Array).append(String(w))
	for p: StringName in DB.ids("passives"):
		(d["unlocked"]["passives"] as Array).append(String(p))
	for b: StringName in DB.ids("bosses"):
		(d["stats"]["bosses_defeated"] as Dictionary)[String(b)] = 1
	for s: StringName in DB.ids("stages"):
		if not (d["unlocked"]["stages"] as Array).has(String(s)):
			(d["unlocked"]["stages"] as Array).append(String(s))
	# Tokoyo de todas as fases visto (Discovery.tokoyo_known: recorde "stage_tokoyo" das Missões).
	for s: StringName in DB.ids("stages"):
		(d["records"]["stage_tokoyo"] as Dictionary)[String(s)] = true
	d["stats"]["affixes_seen"] = Array(EliteAffixes.IDS).map(func(a: StringName) -> String: return String(a))
	SaveManager.stage_best(&"village")["endless_best"] = Spawner.SHINIGAMI_TIME
	SaveManager.unlock_all_heroes()


static func chapter_text(ch: Dictionary) -> String:
	var out: PackedStringArray = []
	for b: Dictionary in ch.get("blocks", []):
		out.append(String(b.get("text", "")))
	return "\n".join(out)


# --- Dados -----------------------------------------------------------------------------

func run_data(check: Callable) -> void:
	_check = check
	var original := SaveManager.data
	SaveManager.data = SaveManager.default_profile()
	_test_all_languages()
	Locale.set_language("pt_BR", false)
	_test_numbers()
	_test_discovery()
	_test_abilities()
	_test_modes()
	_test_altars()
	_test_realm()
	_test_platform()
	_test_tips()
	SaveManager.data = original
	Locale.set_language("pt_BR", false)


func _test_all_languages() -> void:
	var book := GuideBook.new()
	book.platform_override = "android"
	var bad: Array[String] = []
	for lang: String in LANGS:
		Locale.set_language(lang, false)
		_ok(book.entries().size() == GuideBook.CHAPTERS.size() and GuideBook.CHAPTERS.size() == 11,
				"Guia [%s]: 11 capítulos", lang)
		for id: StringName in GuideBook.CHAPTERS:
			var ch := book.chapter(id)
			var blocks: Array = ch.get("blocks", [])
			if String(ch.get("title", "")).is_empty() or blocks.is_empty() or not ResourceLoader.exists(String(ch["icon"])):
				bad.append("%s %s vazio" % [lang, id])
			for b: Dictionary in blocks:
				var text := String(b.get("text", ""))
				if not String(b["type"]) in ["h", "p", "rich", "tip", "link"]:
					bad.append("%s %s tipo %s" % [lang, id, b["type"]])
				if text.strip_edges().is_empty() and String(b["type"]) != "rich":
					bad.append("%s %s bloco vazio" % [lang, id])
				if text.contains("%s") or text.contains("%d") or text.contains("guide.") or text.contains("tip.") \
						or text.contains("moon.rule") or text.contains("powerup.") or text.contains("mission.") \
						or text.contains("goals.") or text.contains("omikuji."):
					bad.append("%s %s: %s" % [lang, id, text.left(60)])
	_ok(bad.is_empty(), "Guia: todos os capítulos montam nos 11 idiomas, sem chave crua nem %%s %s", [bad.slice(0, 6)])


func _test_numbers() -> void:
	SaveManager.data = SaveManager.default_profile()
	full_profile()
	var book := GuideBook.new()
	var stages: Array = _json("stages")
	var weapons: Array = _json("weapons")
	var items: Array = _json("items")
	var powerups: Array = _json("powerups")
	var play := chapter_text(book.chapter(&"play"))
	_ok(play.contains(str(roundi(HyakkiGame.RUN_LENGTH / 60.0))) and play.contains("15"),
			"Guia números: a noite dura RUN_LENGTH (15 min)")
	_ok(play.contains(GuideBook.pct(LanternSystem.MAX_BOOST)), "Guia números: luz da lanterna de LanternSystem")
	var max_level := 0
	for w: Dictionary in weapons:
		if String(w.get("kind", "base")) == "base":
			max_level = maxi(max_level, (w.get("levels", []) as Array).size())
	_ok(GuideBook.weapon_max_level() == max_level and max_level == 8, "Guia números: nível máximo das armas dos dados (8)")
	var levels := chapter_text(book.chapter(&"levels"))
	var weapons_line := TranslationServer.translate("guide.levels.weapons") % [LevelUpSystem.MAX_WEAPONS, max_level]
	_ok(levels.contains(weapons_line), "Guia números: %s", weapons_line)
	_ok(levels.contains(TranslationServer.translate("guide.levels.up") % [LevelUpSystem.BASE_CARDS,
			LevelUpSystem.BASE_CARDS + 1]), "Guia números: cartas por nível de LevelUpSystem")
	for pu: Dictionary in powerups:
		if String(pu["id"]) in ["pu_reroll", "pu_skip", "pu_banish"]:
			_ok(levels.contains(TranslationServer.translate("powerup.%s.name" % pu["id"]) + ": +" + str(int(pu["per_level"]))),
					"Guia números: cargas de %s dos dados", pu["id"])
	var chests := chapter_text(book.chapter(&"chests"))
	var one := 1.0 - ChestSystem.BASE_THREE - ChestSystem.BASE_FIVE
	_ok(chests.contains("70%") and chests.contains("25%") and chests.contains("5%")
			and chests.contains(GuideBook.pct(one)) and chests.contains(str(ChestSystem.RYO_PER_ITEM)),
			"Guia números: chances 70/25/5 e ryō por melhoria do ChestSystem")
	_ok(chests.contains(TranslationServer.translate("guide.chests.boss") % [ChestSystem.BOSS_MIN_ITEMS,
			ChestSystem.BOSS_RYO_MULT, RiftPortal.MIDBOSS_CHESTS]), "Guia números: baú de chefe e do Guardião do Limiar")
	# Omikuji: uma sorte por contagem de ChestSystem.COUNTS (吉 1, 中吉 3, 大吉 5), o 凶 e os generosos.
	var fortunes := book.fortune_lines()
	_ok(fortunes.size() == ChestSystem.COUNTS.size(), "Guia omikuji: uma sorte por contagem do baú")
	var seals: Array[String] = []
	for i: int in fortunes.size():
		var line: Array = fortunes[i]
		seals.append(String((line[0] as Dictionary).get("seal", "")))
		_ok(GuideBook.plain(line).ends_with(str(ChestSystem.COUNTS[i])),
				"Guia omikuji: %s mostra %d melhorias", [seals[i], ChestSystem.COUNTS[i]])
	_ok(seals == ["吉", "中吉", "大吉"], "Guia omikuji: selos 吉, 中吉 e 大吉 %s", [seals])
	_ok(chests.contains(TranslationServer.translate("guide.chests.kyo") % [GuideBook.pct(Omikuji.KYO_CHANCE),
			Omikuji.KYO_RYO, Omikuji.GENEROUS_CHESTS, TranslationServer.translate("omikuji.chukichi")]),
			"Guia omikuji: chance e consolo do 凶 e baús generosos do Omikuji")
	var evo_count := 0
	for w: Dictionary in weapons:
		if String(w.get("kind", "base")) == "base" and w.has("evolution"):
			evo_count += 1
	_ok(book.evolution_lines().size() == evo_count and evo_count > 0,
			"Guia: uma receita por arma base com evolução (%d)", evo_count)
	var union_count := weapons.filter(func(w: Dictionary) -> bool: return String(w.get("kind", "")) == "union").size()
	_ok(book.union_lines().size() == union_count, "Guia: uma linha por união (%d)", union_count)
	var items_text := chapter_text(book.chapter(&"items"))
	var total := 0.0
	for it: Dictionary in items:
		total += float(it.get("weight", 0))
	for it: Dictionary in items:
		if float(it.get("weight", 0)) <= 0.0:
			continue
		var name := TranslationServer.translate("item.%s.name" % it["id"])
		var chance := GuideBook.pct(float(it["weight"]) / total)
		_ok(items_text.contains("%s: %s (%s)" % [name, book.item_effect(it), chance]),
				"Guia números: item %s com efeito e chance dos dados (%s)", [it["id"], chance])
		if String(it["effect"]) in ["heal", "ryo", "freeze", "solar"]:
			_ok(book.item_effect(it).contains(str(int(it["value"]))), "Guia números: valor de %s", it["id"])
	_ok(items_text.contains(str(BossDirector.BOSS_RYO)) and items_text.contains(GuideBook.pct(PickupManager.COIN_CHANCE)),
			"Guia números: ryō por chefe e chance de moeda do jogo")
	var bosses := chapter_text(book.chapter(&"bosses"))
	var times_ok := true
	for s: Dictionary in stages:
		for b: Dictionary in s["bosses"]:
			times_ok = times_ok and bosses.contains(Screen.format_time(float(b["t"])) + " " \
					+ TranslationServer.translate("boss.%s.name" % b["id"]))
		var mid: Dictionary = s.get("midboss", {})
		if not mid.is_empty():
			times_ok = times_ok and bosses.contains(Screen.format_time(float(mid["t"])) + " " \
					+ TranslationServer.translate("boss.%s.name" % mid["id"]) + " · " + TranslationServer.translate("midboss.title"))
	_ok(times_ok, "Guia números: horário de cada chefe e Guardião do Limiar de data/stages.json")
	_ok(bosses.contains(TranslationServer.translate("guide.bosses.mid") % [Screen.format_time(450.0), "4",
			RiftPortal.MIDBOSS_CHESTS]) and is_equal_approx(RiftPortal.WARN_LEAD, 4.0),
			"Guia números: aviso do Guardião do Limiar (RiftPortal.WARN_LEAD)")
	# Três níveis: a Sombra do Guardião no Kakuriyo (selo 隠世) e o último chefe só no Tokoyo (selo
	# 常世) no relógio de cada fase; os parágrafos com os números dos dados e das constantes.
	var kakuriyo := RiftPortal.REALM_GLYPHS[RiftPortal.DEPTH_KAKURIYO]
	var tokoyo := RiftPortal.REALM_GLYPHS[RiftPortal.DEPTH_TOKOYO]
	var levels_ok := true
	for s: Dictionary in stages:
		var mid2: Dictionary = s.get("midboss2", {})
		if not mid2.is_empty():
			levels_ok = levels_ok and bosses.contains("%s %s · %s %s" % [Screen.format_time(float(mid2["t"])),
					_t("boss.%s.name" % mid2["id"]), _t("midboss2.title"), kakuriyo])
		var last: Dictionary = (s["bosses"] as Array).back()
		levels_ok = levels_ok and bosses.contains("%s %s · %s" % [Screen.format_time(float(last["t"])),
				_t("boss.%s.name" % last["id"]), tokoyo])
	_ok(levels_ok, "Guia números: Sombra do Guardião (隠世) e último chefe (常世) no relógio de cada fase")
	_ok(bosses.contains(_t("guide.bosses.levels") % [kakuriyo, tokoyo]), "Guia: os três níveis com os selos 隠世 e 常世")
	var first: Dictionary = stages[0]
	var m2: Dictionary = first["midboss2"]
	var shadow: Dictionary = DB.bosses[StringName(String(m2["id"]))]
	var fury := float(((shadow["phases"] as Array).back() as Dictionary)["below"])
	_ok(String(shadow["seal"]) == "影" and fury > 0.0 and fury < 0.5
			and is_equal_approx(GuideBook.fury_below(StringName(String(m2["id"]))), fury)
			and bosses.contains(_t("guide.bosses.mid2") % [String(shadow["seal"]), Screen.format_time(float(m2["t"])),
			GuideBook._num(float(m2["after"])), GuideBook.pct(fury), RiftPortal.MIDBOSS_CHESTS]),
			"Guia números: Sombra do Guardião (midboss2.t, after, fúria e baús dos dados)")
	var last0: Dictionary = (first["bosses"] as Array).back()
	_ok(bosses.contains(_t("guide.bosses.final") % [tokoyo, Screen.format_time(float(last0["t"])),
			GuideBook._num(Spawner.FINAL_AFTER), GuideBook._num(Spawner.FINAL_WARN),
			Screen.format_time(HyakkiGame.RUN_LENGTH)]),
			"Guia números: luta final no Tokoyo (Spawner.FINAL_AFTER/FINAL_WARN e o amanhecer)")
	# Nenhum texto diz mais que o chefe das 10:00 aparece em qualquer mapa (só no Tokoyo).
	var final_at := Screen.format_time(float(last0["t"]))
	var stale: Array[String] = []
	for lang: String in LANGS:
		Locale.set_language(lang, false)
		if _t("tip.boss_times").contains(final_at.trim_prefix("0")) or _t("tip.boss_times").contains(final_at):
			stale.append(lang)
	Locale.set_language("pt_BR", false)
	_ok(stale.is_empty(), "Guia: a dica dos horários não marca mais o último chefe em qualquer mapa %s", [stale])
	var stronger := chapter_text(book.chapter(&"stronger"))
	var pmax := 0
	for pu: Dictionary in powerups:
		pmax = maxi(pmax, int(pu["max"]))
	_ok(stronger.contains(TranslationServer.translate("guide.stronger.sanctuary") % [powerups.size(), pmax,
			GuideBook.pct(MetaProgress.PRICE_STEP), TranslationServer.translate("sanctuary.refund")]),
			"Guia números: Santuário (tipos, níveis, passo do preço)")
	# Missões do Santuário: total, categorias e concluídas de MissionBook, como a aba do Diário.
	var done := 0
	for id: StringName in MissionBook.ids():
		done += int(MissionBook.is_done(id))
	_ok(stronger.contains(TranslationServer.translate("guide.stronger.missions") % [MissionBook.ids().size(),
			MissionBook.CATEGORIES.size(), done]),
			"Guia missões: total, categorias e concluídas (%d)", MissionBook.ids().size())
	var sections := CodexMissions.sections(CodexMissions.entries())
	var cats_ok := sections.size() == MissionBook.CATEGORIES.size()
	for sec: Dictionary in sections:
		cats_ok = cats_ok and stronger.contains(TranslationServer.translate("guide.stronger.mission_cat")
				% [sec["title"], sec["done"], sec["total"]])
	_ok(cats_ok, "Guia missões: uma linha por categoria com o progresso do Diário")
	var goals_ok := true
	for id: StringName in MissionBook.next_goals(3):
		goals_ok = goals_ok and stronger.contains(MissionBook.title(id)) and stronger.contains(MissionBook.progress_text(id))
	_ok(goals_ok, "Guia missões: as próximas 3 metas com progresso")
	var kami: Array = (stages[0] as Dictionary)["kami"]
	_ok(stronger.contains(TranslationServer.translate("guide.stronger.kami") % [Screen.format_time(float(kami[0])),
			Screen.format_time(float(kami[-1])), KamiSystem.OFFER_COUNT]), "Guia números: horários e pactos dos Kami")
	_ok(stronger.contains(GuideBook.roman(HyakkiGame.MAX_MOON)) and stronger.contains(GuideBook.pct(HyakkiGame.MOON_HP))
			and stronger.contains(RedMoon.rule_text(RedMoon.FEW_PACTS)), "Guia números: Lua Vermelha do jogo")
	# Regras da Lua Vermelha: as 5, com os números das constantes, e o parágrafo de que elas se somam.
	var rules_ok := RedMoon.RULES == HyakkiGame.MAX_MOON
	for rule: int in range(1, RedMoon.RULES + 1):
		rules_ok = rules_ok and stronger.contains(RedMoon.rule_text(rule))
	_ok(rules_ok and stronger.contains("+%d%%" % roundi((RedMoon.ELITE_MULT - 1.0) * 100.0))
			and stronger.contains(str(RedMoon.PACTS)) and stronger.contains(GuideBook.pct(RedMoon.SHADE_LIGHT_CHANCE)),
			"Guia números: as %d regras da Lua Vermelha com os números das constantes", RedMoon.RULES)
	_ok(stronger.contains(TranslationServer.translate("guide.stronger.moon_rules") % [GuideBook.roman(HyakkiGame.MAX_MOON),
			GuideBook._num(RedMoon.ECLIPSE_DELAY), RedMoon.ECLIPSE_RING_COUNT]),
			"Guia números: as regras se somam e o Eclipse (atraso e círculos do anel)")
	var surfaces: Dictionary = _json("surfaces")
	var terrain := chapter_text(book.chapter(&"stages"))
	var surf_ok := true
	for sid: String in (surfaces["stages"] as Dictionary):
		for spot: Dictionary in surfaces["stages"][sid]:
			var slow := 1.0 - float(surfaces["types"][spot["type"]]["slow"])
			surf_ok = surf_ok and terrain.contains(GuideBook.pct(slow))
	_ok(surf_ok, "Guia números: lentidão de cada terreno de data/surfaces.json")
	for s: Dictionary in stages:
		var hazard: Dictionary = s.get("hazard", {})
		if not hazard.is_empty():
			_ok(terrain.contains(book.hazard_text(hazard)) and book.hazard_text(hazard) != "",
					"Guia: perigo de %s descrito", s["id"])
	for s: Dictionary in stages:
		var hz: Dictionary = s.get("hazard", {})
		if String(hz.get("type", "")) == "lava":
			_ok(book.hazard_text(hz).contains(str(int(hz["damage"]))), "Guia números: dano da lava dos dados")


func _test_discovery() -> void:
	SaveManager.data = SaveManager.default_profile()
	var book := GuideBook.new()
	var lines := book.evolution_lines()
	var all_hidden := true
	var bases_known := true
	for line: Array in lines:
		all_hidden = all_hidden and not bool(line[2]["ref"]["known"]) and String(line[2]["ref"]["name"]) == "???"
		# As exclusivas da Kuon (bloqueada no save novo) ficam como ???; as outras armas base, conhecidas.
		var base: Dictionary = line[0]["ref"]
		bases_known = bases_known and bool(base["known"]) != MetaProgress.exclusive_locked(DB.weapon(StringName(base["id"])))
	_ok(all_hidden and bases_known, "Guia descoberta: save novo mostra as armas base e as evoluções como ???")
	var chests := chapter_text(book.chapter(&"chests"))
	_ok(not chests.contains(TranslationServer.translate("weapon.dawn_blade.name"))
			and chests.contains(TranslationServer.translate("guide.chests.unknown")),
			"Guia descoberta: evolução não vista sem nome e com a dica de como descobrir")
	_ok(not chests.contains(TranslationServer.translate("passive.rosary.name")),
			"Guia descoberta: relíquia bloqueada como ???")
	var bosses := chapter_text(book.chapter(&"bosses"))
	var leaked: Array[String] = []
	for b: StringName in DB.ids("bosses"):
		if bosses.contains(TranslationServer.translate("boss.%s.name" % b)):
			leaked.append(String(b))
	_ok(leaked.is_empty() and bosses.contains("???"), "Guia descoberta: chefes não vencidos escondidos %s", [leaked])
	_ok(not bosses.contains(TranslationServer.translate("stage.bamboo.name"))
			and bosses.contains(TranslationServer.translate("stage.village.name")), "Guia descoberta: fase bloqueada sem nome")
	var terrain := chapter_text(book.chapter(&"stages"))
	_ok(not terrain.contains(TranslationServer.translate("stage.yomi.name")) and terrain.contains("???"),
			"Guia descoberta: fases bloqueadas como ???")
	(SaveManager.data["stats"]["evolved"] as Array).append("dawn_blade")
	(SaveManager.data["stats"]["bosses_defeated"] as Dictionary)["tanuki"] = 1
	SaveManager.data["unlocked"]["heroes"] = ["aki"]
	chests = chapter_text(book.chapter(&"chests"))
	bosses = chapter_text(book.chapter(&"bosses"))
	_ok(chests.contains(TranslationServer.translate("weapon.dawn_blade.name")),
			"Guia descoberta: evolução descoberta mostra o nome")
	_ok(bosses.contains(TranslationServer.translate("boss.tanuki.name"))
			and not bosses.contains(TranslationServer.translate("boss.kappa_elder.name")),
			"Guia descoberta: chefe vencido mostra o nome")
	var stronger: Dictionary = book.chapter(&"stronger")
	var heroes_known := 0
	var kami_known := 0
	for b: Dictionary in stronger["blocks"]:
		if String(b["type"]) != "rich":
			continue
		for line: Array in b["lines"]:
			for part: Dictionary in line:
				if part.has("ref") and String(part["ref"]["category"]) == "heroes":
					heroes_known += int(bool(part["ref"]["known"]))
					_ok(bool(part["ref"]["known"]) == (String(part["ref"]["name"]) != "???"),
							"Guia descoberta: guardiã %s", part["ref"]["id"])
				if part.has("chip") and String(part["chip"]).contains("/kami/") and String(part.get("kind", "")) == "skill":
					kami_known += int(bool(part["known"]))
	_ok(heroes_known == 1, "Guia descoberta: só as guardiãs liberadas com rosto e nome (%d)", heroes_known)
	_ok(kami_known == DB.ids("kami").size(), "Guia descoberta: Kami pela regra do Diário (todos conhecidos)")


## Capítulo das habilidades: números de data/abilities.json e do AbilitySystem, a regra da Yuki,
## o link para os guardiões e a descoberta (guardiã bloqueada como ???, sem as habilidades dela).
func _test_abilities() -> void:
	SaveManager.data = SaveManager.default_profile()
	full_profile()
	var book := GuideBook.new()
	var text := chapter_text(book.chapter(&"abilities"))
	var missing: Array[String] = []
	for h: StringName in DB.ids("heroes"):
		var data := DB.hero_abilities(h)
		if not text.contains(TranslationServer.translate("energy.%s.name" % data["energy"]["id"])):
			missing.append("energia de %s" % h)
		for a: Dictionary in data["abilities"]:
			var line := TranslationServer.translate("guide.abilities.ability_line") % [
					TranslationServer.translate("ability.%s.name" % a["id"]), str(int(a["level"])),
					str(roundi(float(a["cost"]))), AbilitySheet.seconds(float(a["cooldown"]))]
			if not text.contains(line) or not text.contains(String(a["kanji"])):
				missing.append(String(a["id"]))
	_ok(missing.is_empty(), "Guia habilidades: energia e nível/custo/recarga de cada habilidade dos dados %s", [missing])
	_ok(text.contains(GuideBook.pct(AbilitySystem.POWER_PER_LEVEL)), "Guia habilidades: poder por nível do AbilitySystem")
	# A guardiã que paga com vida sai dos dados (a energia com "hp_price"), com o nome dela no texto.
	var payer := &""
	for h: StringName in DB.ids("heroes"):
		if float((DB.hero_abilities(h).get("energy", {}) as Dictionary).get("hp_price", 0.0)) > 0.0:
			payer = h
	_ok(payer == &"yuki", "Guia habilidades: a energia paga com vida é a da Yuki nos dados")
	var yuki: Dictionary = DB.hero_abilities(payer)["energy"]
	var blood := TranslationServer.translate("guide.abilities.blood") % [
			TranslationServer.translate("energy.%s.name" % yuki["id"]), TranslationServer.translate("hero.%s.name" % payer),
			str(roundi(1.0 / float(yuki["hp_price"]))), GuideBook.pct(float(yuki["hp_floor"]))]
	_ok(text.contains(blood), "Guia habilidades: Yuki paga com vida (%s)", blood.left(40))
	# Servos espectrais: a guardiã cuja arma inicial levanta servos sai dos dados, com o teto da arma
	# e o absoluto do MinionSystem.
	var raiser := GuideBook.minion_hero()
	_ok(raiser == &"kuon", "Guia habilidades: quem levanta servos é a Kuon nos dados")
	var fuda: Dictionary = DB.weapon(StringName(String(DB.heroes[raiser]["weapon"])))["base"]
	var minions := TranslationServer.translate("guide.abilities.minions") % [
			TranslationServer.translate("hero.%s.name" % raiser), str(int(fuda["minion_cap"])), str(MinionSystem.HARD_CAP)]
	_ok(text.contains(minions), "Guia habilidades: servos da Kuon com o teto dos dados (%s)", minions.left(40))
	var raw_ok := true
	for lang: String in LANGS:
		Locale.set_language(lang, false)
		var t := TranslationServer.translate("guide.abilities.blood")
		raw_ok = raw_ok and not t.contains(TranslationServer.translate("hero.yuki.name")) and t.count("%s") == 4
		var para := chapter_text(book.chapter(&"abilities"))
		raw_ok = raw_ok and para.contains(TranslationServer.translate("hero.yuki.name"))
	Locale.set_language("pt_BR", false)
	_ok(raw_ok, "Guia habilidades: o nome da guardiã chega por %s nos 11 idiomas (sem nome fixo no texto)")
	var count := GuideBook.ability_count()
	_ok(count == (DB.hero_abilities(&"aki")["abilities"] as Array).size()
			and text.contains(TranslationServer.translate("guide.abilities.intro") % count),
			"Guia habilidades: quantidade de habilidades lida dos dados (%d)", count)
	var blocks: Array = book.chapter(&"abilities")["blocks"]
	_ok(blocks.any(func(b: Dictionary) -> bool: return String(b["type"]) == "link" and b["category"] == &"heroes"),
			"Guia habilidades: Ver guardiões no Diário")
	_ok(not text.contains(TranslationServer.translate("guide.abilities.unknown")),
			"Guia habilidades: tudo liberado, sem o aviso dos bloqueados")
	var play := chapter_text(book.chapter(&"play"))
	_ok(play.contains(TranslationServer.translate("energy.%s.name" % DB.hero_abilities(book._hero())["energy"]["id"])),
			"Guia: Como jogar cita as habilidades e a energia da guardiã escolhida")
	SaveManager.data["unlocked"]["heroes"] = ["aki"]
	text = chapter_text(book.chapter(&"abilities"))
	_ok(text.contains(TranslationServer.translate("ability.dawn_step.name")) and text.contains("???")
			and not text.contains(TranslationServer.translate("ability.oni_claw.name"))
			and not text.contains(TranslationServer.translate("energy.shadow.name"))
			and not text.contains(blood) and text.contains(TranslationServer.translate("guide.abilities.unknown")),
			"Guia habilidades descoberta: só a guardiã liberada mostra energia e habilidades; Yuki bloqueada sem a regra")
	_ok(not text.contains(minions), "Guia habilidades descoberta: Kuon bloqueada, sem o parágrafo dos servos")


## Modo Brisa (Como jogar), Desafio Diário (Como jogar) e Noite Sem Fim com o Shinigami (Ficar
## mais forte): números das constantes e dos dados, Shinigami "???" até a hora dele.
func _test_modes() -> void:
	SaveManager.data = SaveManager.default_profile()
	var book := GuideBook.new()
	var play := chapter_text(book.chapter(&"play"))
	var stats: Dictionary = HyakkiGame.BRISA_STATS
	var brisa := _t("guide.play.brisa") % [_t("stages.title"),
			GuideBook.pct(1.0 - DamageControl.BRISA_MULT), str(int(stats["revive"])), GuideBook.pct(float(stats["magnet"])),
			GuideBook.pct(1.0 - LanternSystem.BRISA_DARKNESS), GuideBook.pct(1.0 - HyakkiGame.BRISA_SPAWN),
			GuideBook.pct(1.0 - HyakkiGame.BRISA_BOSS_HP)]
	_ok(play.contains(brisa) and play.contains(_t("mode.brisa")),
			"Guia Brisa: dano, reviver, ímã, escuridão, inimigos e vida dos chefes das constantes")
	_ok(is_equal_approx(HyakkiGame.BRISA_BOSS_HP, 0.7) and is_equal_approx(HyakkiGame.BRISA_SPAWN, 0.85)
			and is_equal_approx(LanternSystem.BRISA_DARKNESS, 0.6) and int(stats["revive"]) == 1
			and is_equal_approx(float(stats["magnet"]), 0.5),
			"Guia Brisa: constantes com os mesmos valores de antes (simulação igual)")
	_ok(play.contains(_t("guide.play.brisa_win") % _t("stages.endless")),
			"Guia Brisa: vitória à parte (won_brisa)")
	var ryo := 0
	for a: Dictionary in _json("achievements"):
		if String(a["id"]) == "ach_daily":
			ryo = String(a["reward"]).trim_prefix("ryo:").to_int()
	_ok(ryo > 0 and GuideBook.daily_ryo() == ryo and play.contains(_t("guide.play.daily_reward")
			% [Screen.format_time(MetaProgress.DAILY_MIN_TIME), _t("achievement.ach_daily.name"), ryo])
			and play.contains(_t("guide.play.daily") % _t("title.daily")),
			"Guia Desafio Diário: tempo de MetaProgress.DAILY_MIN_TIME e ryō de data/achievements.json (%d)", ryo)
	_ok(is_equal_approx(MetaProgress.DAILY_MIN_TIME, 300.0), "Guia Desafio Diário: 5 minutos (mesmo valor de antes)")
	var stronger := chapter_text(book.chapter(&"stronger"))
	_ok(stronger.contains(_t("guide.stronger.endless") % [_t("stages.endless"),
			_t("stages.title"), GuideBook.pct(HyakkiGame.ENDLESS_HP_PER_MIN), "1.5"])
			and is_equal_approx(MetaProgress.ENDLESS_GOLD, 1.5) and is_equal_approx(HyakkiGame.ENDLESS_HP_PER_MIN, 0.15),
			"Guia Noite Sem Fim: vida por minuto e ryō ×1.5 das constantes")
	var reaper := _t("boss.shinigami.name")
	_ok(not Discovery.reaper_known() and not stronger.contains(reaper)
			and stronger.contains(_t("guide.stronger.reaper_unknown") % Screen.format_time(Spawner.SHINIGAMI_TIME))
			and stronger.contains(Screen.format_time(Spawner.SHINIGAMI_TIME) + "  ???"),
			"Guia Noite Sem Fim: Shinigami escondido (???) até a hora dele")
	_ok(book.boss_schedule(&"village").all(func(e: Dictionary) -> bool: return String(e["id"]) != "shinigami")
			and bool((DB.bosses[&"shinigami"] as Dictionary).get("invincible", false)),
			"Guia Noite Sem Fim: Shinigami fora das escalas das fases e invencível nos dados")
	SaveManager.stage_best(&"bamboo")["endless_best"] = Spawner.SHINIGAMI_TIME - 1.0
	_ok(not Discovery.reaper_known(), "Guia Noite Sem Fim: antes da hora o Shinigami continua desconhecido")
	SaveManager.stage_best(&"bamboo")["endless_best"] = Spawner.SHINIGAMI_TIME
	stronger = chapter_text(book.chapter(&"stronger"))
	_ok(stronger.contains(Screen.format_time(Spawner.SHINIGAMI_TIME) + "  " + reaper)
			and stronger.contains(_t("guide.stronger.reaper") % Screen.format_time(Spawner.SHINIGAMI_TIME)),
			"Guia Noite Sem Fim: Shinigami com nome e regra depois de chegar à hora dele")
	var line: Array = book.reaper_line()
	_ok(line.any(func(part: Dictionary) -> bool: return (part.has("chip") and bool(part["known"])
			and ResourceLoader.exists(String(part["chip"])))), "Guia Noite Sem Fim: retrato do Shinigami")


## Altares do Selo: números do AltarSystem/EliteAffixes, um afixo por EliteAffixes.IDS com o kanji,
## "?" até ver um Elite com ele (registrado pelo RunTracker e gravado no fim da partida).
func _test_altars() -> void:
	SaveManager.data = SaveManager.default_profile()
	var book := GuideBook.new()
	var ch := book.chapter(&"altars")
	var text := chapter_text(ch)
	_ok(text.contains(_t("guide.altars.ritual") % [GuideBook._num(AltarSystem.CHANNEL_TIME), AltarSystem.RUNES,
			GuideBook.pct(AltarSystem.DECAY)]), "Guia altares: leitura (CHANNEL_TIME, RUNES, DECAY)")
	_ok(text.contains(_t("guide.altars.outcome") % [GuideBook.pct(AltarSystem.ELITE_BASE),
			GuideBook.pct(AltarSystem.ELITE_PITY),
			Screen.format_time(AltarSystem.FIRST_ELITE_T)]), "Guia altares: chance de Elite com pena e 1º Elite")
	_ok(text.contains(_t("guide.altars.ambush") % [AltarSystem.ambush_count(0.0), AltarSystem.AMBUSH_CAP,
			_t("item.ryo_bag.name")]), "Guia altares: emboscada (AMBUSH_BASE, AMBUSH_CAP)")
	_ok(text.contains(_t("guide.altars.elite") % [Screen.format_time(EliteAffixes.TWO_AFFIX_T),
			GuideBook.roman(EliteAffixes.HIGH_MOON), EliteAffixes.MAX_AFFIXES, GuideBook.pct(EliteAffixes.HP_PER_AFFIX)]),
			"Guia altares: afixos por tempo e Lua Vermelha (TWO_AFFIX_T, HIGH_MOON, MAX_AFFIXES)")
	_ok(text.contains(_t("guide.altars.fury") % [GuideBook.pct(EliteAffixes.FURY_AT),
			GuideBook.pct(1.0 - EliteAffixes.FURY_CD)]),
			"Guia altares: fúria do Elite (FURY_AT, FURY_CD)")
	_ok(GuideBook.elite_art_count() == 11 and text.contains(_t("guide.altars.elite_look") % [GuideBook.elite_art_count()]),
			"Guia altares: Elites com arte própria (data/enemies.json elite_sprite)")
	_ok(EliteAffixes.affix_count(EliteAffixes.TWO_AFFIX_T - 1.0, 0) == 1
			and EliteAffixes.affix_count(EliteAffixes.TWO_AFFIX_T, 0) == 2
			and EliteAffixes.affix_count(0.0, EliteAffixes.HIGH_MOON) == 2
			and EliteAffixes.affix_count(EliteAffixes.TWO_AFFIX_T, HyakkiGame.MAX_MOON) == EliteAffixes.MAX_AFFIXES,
			"Guia altares: o texto bate com EliteAffixes.affix_count")
	_ok(text.contains(_t("guide.altars.loot") % [AltarSystem.BOSS_CHEST_AFFIXES, GuideBook.pct(AltarSystem.CHEST_CHANCE),
			_t("item.ryo_bag.name")]) and text.contains(_t("guide.altars.no_chest")),
			"Guia altares: saque (BOSS_CHEST_AFFIXES, CHEST_CHANCE) e sem o baú comum")
	var rng := RandomNumberGenerator.new()
	var boss_loot: Array = AltarSystem.loot(AltarSystem.BOSS_CHEST_AFFIXES, rng)
	_ok(boss_loot.size() == 1 and bool((boss_loot[0][2] as Dictionary).get("boss", false))
			and not bool((AltarSystem.loot(AltarSystem.BOSS_CHEST_AFFIXES - 1, rng)[0][2] as Dictionary).get("boss", false)),
			"Guia altares: baú de chefe a partir de BOSS_CHEST_AFFIXES afixos")
	var rare_ok := true
	for id: StringName in AltarSystem.RARE_ITEMS:
		rare_ok = rare_ok and text.contains(_t("item.%s.name" % id))
	_ok(rare_ok, "Guia altares: itens raros de AltarSystem.RARE_ITEMS")
	_ok(chapter_text(book.chapter(&"chests")).contains("os Elites dos altares têm saque próprio"),
			"Guia baús: a frase dos baús cita o saque próprio dos Elites dos altares")
	# Descoberta: save novo, todos os afixos como ?.
	var lines := _affix_lines(ch)
	_ok(lines.size() == EliteAffixes.IDS.size(), "Guia altares: uma linha por afixo (%d)", lines.size())
	var all_hidden := lines.all(func(l: Array) -> bool: return (String((l[0] as Dictionary)["seal"]) == "?"
			and GuideBook.plain(l).contains(Discovery.UNKNOWN)))
	var leaked: Array[String] = []
	for id: StringName in EliteAffixes.IDS:
		var row := book.affix_text(id)
		var full := String(row[0]) % row[1] if not (row[1] as Array).is_empty() else String(row[0])
		if text.contains(full):
			leaked.append(String(id))
	_ok(all_hidden and leaked.is_empty() and text.contains(_t("guide.altars.unknown")),
			"Guia altares descoberta: save novo mostra os afixos como ? %s", [leaked])
	# Registro: um Elite surgiu com Trovão e Diamante; o fim da partida grava os vistos.
	var tracker := RunTracker.new()
	tracker.on_elite_spawned([&"raijin", &"kongo"])
	var restored := RunTracker.new()
	restored.restore(tracker.snapshot())
	_ok(restored.elite_affixes_seen.has(&"raijin") and restored.elite_affixes_seen.has(&"kongo"),
			"Guia altares: afixos vistos sobrevivem à partida suspensa (RunTracker)")
	MetaProgress.apply_run({"victory": false, "gave_up": false, "hero": "aki", "stage": "village", "mode": "normal",
			"moon": 0, "time": 60.0, "level": 1, "kills": 0, "endless": false, "daily": false, "realm": false,
			"revived_by_ad": false, "speed_min": 1, "speed_max": 1}, restored)
	_ok(Discovery.affix_known(&"raijin") and Discovery.affix_known(&"kongo") and not Discovery.affix_known(&"yomi"),
			"Guia altares: fim da partida grava os afixos vistos (stats affixes_seen)")
	ch = book.chapter(&"altars")
	text = chapter_text(ch)
	var raijin := book.affix_text(&"raijin")
	_ok(text.contains(String(raijin[0]) % raijin[1]) and text.contains(str(EliteAffixes.RAIJIN_MARKS))
			and text.contains(GuideBook._num(EliteAffixes.RAIJIN_EVERY)),
			"Guia altares: Trovão visto com os números do EliteAffixes")
	var seals: Array[String] = []
	for l: Array in _affix_lines(ch):
		seals.append(String((l[0] as Dictionary)["seal"]))
	_ok(seals.count("?") == EliteAffixes.IDS.size() - 2 and seals.has(EliteAffixes.kanji_of(&"raijin"))
			and seals.has(EliteAffixes.kanji_of(&"kongo")), "Guia altares: só os afixos vistos com o kanji %s", [seals])
	# Tudo visto: cada afixo com o kanji e o poder; sem o aviso de "?".
	SaveManager.data = SaveManager.default_profile()
	full_profile()
	ch = book.chapter(&"altars")
	text = chapter_text(ch)
	var missing: Array[String] = []
	var i := 0
	for l: Array in _affix_lines(ch):
		var id: StringName = EliteAffixes.IDS[i]
		var row := book.affix_text(id)
		var full := String(row[0]) % row[1] if not (row[1] as Array).is_empty() else String(row[0])
		if String((l[0] as Dictionary)["seal"]) != EliteAffixes.kanji_of(id) or not GuideBook.plain(l).contains(full):
			missing.append(String(id))
		i += 1
	_ok(missing.is_empty() and not text.contains(_t("guide.altars.unknown")),
			"Guia altares: os %d afixos com kanji e poder %s", [EliteAffixes.IDS.size(), missing])
	var nums_ok := text.contains(str(EliteAffixes.FOX_COUNT)) and text.contains(str(EliteAffixes.KASUMI_COUNT)) \
			and text.contains(str(EliteAffixes.KASUMI_CAP)) and text.contains(GuideBook.pct(EliteAffixes.SHIELD_FRACTION)) \
			and text.contains(GuideBook._num(EliteAffixes.KONGO_REGEN)) \
			and text.contains(GuideBook._num(EliteAffixes.KAZE_EVERY))
	_ok(nums_ok, "Guia altares: números dos poderes (Raposa, Névoa, Diamante, Vento) das constantes")


static func _affix_lines(ch: Dictionary) -> Array:
	for b: Dictionary in ch.get("blocks", []):
		if String(b["type"]) != "rich":
			continue
		var lines: Array = b["lines"]
		if not lines.is_empty() and (lines[0] as Array).size() > 0 and ((lines[0] as Array)[0] as Dictionary).has("seal"):
			return lines
	return []


## Kakuriyo de cada fase: clima e perigo do "otherworld" (data/stages.json), escondido até vencer o
## Guardião do Limiar da fase.
func _test_realm() -> void:
	SaveManager.data = SaveManager.default_profile()
	full_profile()
	var book := GuideBook.new()
	var terrain := chapter_text(book.chapter(&"stages"))
	var stages: Array = _json("stages")
	var bad: Array[String] = []
	for s: Dictionary in stages:
		var ow: Dictionary = s.get("otherworld", {})
		if ow.is_empty() or (s.get("midboss", {}) as Dictionary).is_empty():
			continue
		if not terrain.contains(_t("guide.stages.realm") % _t("realm.%s.name" % s["id"])):
			bad.append("%s nome" % s["id"])
		var hz: Dictionary = ow.get("hazard", {})
		if not hz.is_empty():
			var t := book.hazard_text(hz)
			if t == "" or not terrain.contains("· " + t):
				bad.append("%s perigo" % s["id"])
			if hz.has("interval") and not t.contains(GuideBook._num(float(hz["interval"]))):
				bad.append("%s intervalo" % s["id"])
		var precip := String(WeatherModel.profile_for(String(ow.get("weather", s["id"]))).get("precip", ""))
		var sky_prefix := "· " + _t("guide.stages.weather_line").split("%s")[0]
		if precip != "" and not terrain.contains(sky_prefix):
			bad.append("%s clima" % s["id"])
	_ok(bad.is_empty(), "Guia Kakuriyo: nome, clima e perigo do otherworld de cada fase %s", [bad])
	# Tokoyo de cada fase (bloco "tokoyo"): nome, clima e quem reina lá, e a Sombra no Kakuriyo.
	var toko_bad: Array[String] = []
	for s: Dictionary in stages:
		var toko: Dictionary = s.get("tokoyo", {})
		var mid2: Dictionary = s.get("midboss2", {})
		if toko.is_empty() or mid2.is_empty():
			continue
		if not terrain.contains(_t("guide.stages.tokoyo") % _t("realm3.%s.name" % s["id"])):
			toko_bad.append("%s nome" % s["id"])
		var last: Dictionary = (s["bosses"] as Array).back()
		if not terrain.contains("· " + _t("guide.stages.tokoyo_lord") % _t("boss.%s.name" % last["id"])):
			toko_bad.append("%s senhor" % s["id"])
		if not terrain.contains("· " + _t("guide.stages.shadow_line") % _t("boss.%s.name" % mid2["id"])):
			toko_bad.append("%s sombra" % s["id"])
		var hz: Dictionary = toko.get("hazard", {})
		if not hz.is_empty() and not terrain.contains("· " + book.hazard_text(hz)):
			toko_bad.append("%s perigo" % s["id"])
		var lines_toko := book.tokoyo_lines(StringName(String(s["id"])))
		var precip := String(WeatherModel.profile_for(String(toko.get("weather", s["id"]))).get("precip", ""))
		if precip != "" and not lines_toko.any(func(l: Array) -> bool:
				return GuideBook.plain(l).begins_with("· " + _t("guide.stages.weather_line").split("%s")[0])):
			toko_bad.append("%s clima" % s["id"])
	_ok(toko_bad.is_empty(), "Guia Tokoyo: nome, clima, perigo, Sombra e o último chefe de cada fase %s", [toko_bad])
	var temple: Dictionary = (stages.filter(func(s: Dictionary) -> bool: return s["id"] == "temple")[0] as Dictionary)
	_ok(not is_equal_approx(float(temple["hazard"]["interval"]), float(temple["otherworld"]["hazard"]["interval"]))
			and terrain.contains(book.hazard_text(temple["otherworld"]["hazard"])),
			"Guia Kakuriyo: estátuas do Templo Invertido com o próprio intervalo")
	SaveManager.data = SaveManager.default_profile()
	var lines := book.stage_lines(&"village")
	var plain := ""
	for l: Array in lines:
		plain += GuideBook.plain(l) + "\n"
	_ok(plain.contains(_t("guide.stages.realm") % Discovery.UNKNOWN)
			and not plain.contains(_t("realm.village.name")),
			"Guia Kakuriyo descoberta: antes de vencer o Guardião do Limiar, só ???")
	_ok(plain.contains(_t("guide.stages.tokoyo") % Discovery.UNKNOWN)
			and not plain.contains(_t("realm3.village.name")),
			"Guia Tokoyo descoberta: antes de chegar ao Tokoyo, só ???")
	# Kakuriyo conhecido (Guardião vencido), Tokoyo ainda não: a Sombra aparece em silhueta até ser
	# vencida, e o Tokoyo segue ??? até a partida chegar lá (recorde "stage_tokoyo").
	(SaveManager.data["stats"]["bosses_defeated"] as Dictionary)["onikuma"] = 1
	plain = ""
	for l: Array in book.stage_lines(&"village"):
		plain += GuideBook.plain(l) + "\n"
	_ok(plain.contains(_t("guide.stages.realm") % _t("realm.village.name"))
			and plain.contains(_t("guide.stages.shadow_line") % Discovery.UNKNOWN)
			and plain.contains(_t("guide.stages.tokoyo") % Discovery.UNKNOWN),
			"Guia Tokoyo descoberta: Kakuriyo visto, Sombra não vencida e Tokoyo ainda ???")
	(SaveManager.data["records"]["stage_tokoyo"] as Dictionary)["village"] = true
	plain = ""
	for l: Array in book.stage_lines(&"village"):
		plain += GuideBook.plain(l) + "\n"
	_ok(plain.contains(_t("guide.stages.tokoyo") % _t("realm3.village.name"))
			and plain.contains(_t("guide.stages.tokoyo_lord") % Discovery.UNKNOWN)
			and not plain.contains(_t("boss.kappa_elder.name")),
			"Guia Tokoyo descoberta: Tokoyo visto mostra o nome; o último chefe só depois de vencido")
	# Chip "Ver no Diário" das Sombras: o mesmo ref dos outros chefes, que abre o chefe no Diário.
	var ref := book.boss_ref(&"onikuma_kage")
	_ok(ref["category"] == &"bosses" and String(ref["id"]) == "onikuma_kage" and bool(ref["face"])
			and ResourceLoader.exists(String(ref["icon"])), "Guia: chip da Sombra do Guardião com retrato e link do Diário")


static func _t(key: String) -> String:
	return TranslationServer.translate(key)


func _test_platform() -> void:
	SaveManager.data = SaveManager.default_profile()
	var book := GuideBook.new()
	var enable := TranslationServer.translate("tip.backup_enable")
	book.platform_override = "android"
	_ok(chapter_text(book.chapter(&"saving")).contains(enable), "Guia: Backup do Google no Android")
	book.platform_override = "desktop"
	var desktop := chapter_text(book.chapter(&"saving"))
	_ok(not desktop.contains(enable) and not desktop.contains(TranslationServer.translate("guide.saving.phone_h")),
			"Guia: sem Backup do Google fora do Android")
	_ok(desktop.contains(TranslationServer.translate("title.continue")), "Guia: partida interrompida cita Continuar")
	_ok(not desktop.contains("save.json") and not desktop.contains(".bak"), "Guia: sem nomes de arquivo")


func _test_tips() -> void:
	var catalog := TipDeck.catalog()
	for platform: String in ["android", "desktop"]:
		SaveManager.data = SaveManager.default_profile()
		var book := GuideBook.new()
		book.platform_override = platform
		var groups := book.tip_groups()
		var shown := 0
		for cat: String in groups["shown"]:
			shown += (groups["shown"][cat] as Array).size()
		_ok(shown + int(groups["hidden"]) + int(groups["other_platform"]) == catalog.size(),
				"Guia dicas (%s): toda dica do catálogo aparece, fica guardada ou é da outra plataforma", platform)
		var text := chapter_text(book.chapter(&"tips"))
		var missing: Array[String] = []
		for cat: String in groups["shown"]:
			for tip: Dictionary in groups["shown"][cat]:
				if not text.contains(TipDeck.text(tip)):
					missing.append(String(tip["id"]))
		_ok(missing.is_empty(), "Guia dicas (%s): toda dica mostrada está no capítulo %s", [platform, missing])
		var leak: Array[String] = []
		for cat: String in groups["shown"]:
			for tip: Dictionary in groups["shown"][cat]:
				for w: StringName in DB.ids("weapons"):
					if not Discovery.weapon_known(w) and TipDeck.text(tip).contains(TranslationServer.translate("weapon.%s.name" % w)):
						leak.append("%s→%s" % [tip["id"], w])
		_ok(leak.is_empty(), "Guia dicas (%s, save novo): nenhuma cita evolução não vista %s", [platform, leak])
		var backup_shown := (groups["shown"] as Dictionary).has("backup")
		_ok(backup_shown == (platform == "android"), "Guia dicas: Backup só no Android (%s)", platform)
		_ok(int(groups["hidden"]) > 0 and text.contains(TranslationServer.translate("guide.tips.hidden") % groups["hidden"]),
				"Guia dicas (%s, save novo): dicas com spoiler guardadas e contadas (%d)", [platform, groups["hidden"]])
	SaveManager.data = SaveManager.default_profile()
	full_profile()
	var book := GuideBook.new()
	book.platform_override = "android"
	var groups := book.tip_groups()
	var locked_only := true
	var ctx := TipDeck.context()
	for tip: Dictionary in catalog:
		var shown := false
		for cat: String in groups["shown"]:
			shown = shown or (groups["shown"][cat] as Array).has(tip)
		var when: Dictionary = tip["when"]
		# Fora também: as das exclusivas de outra guardiã (as da Kuon, com outra escolhida).
		if not shown and not when.has("locked") and String(when.get("hero", ctx["hero"])) == String(ctx["hero"]):
			locked_only = false
	_ok(locked_only and int(groups["other_platform"]) == 0,
			"Guia dicas (tudo descoberto): só as de conteúdo bloqueado ficam de fora")
	_ok(ctx is Dictionary, "Guia dicas: contexto do TipDeck")


# --- Tela -------------------------------------------------------------------------------

func run(host: Node, check: Callable) -> void:
	_check = check
	var original := SaveManager.data
	SaveManager.data = SaveManager.default_profile()
	Locale.set_language("pt_BR", false)
	var layout := MenusLayout.new()
	var screen: Control = await layout.open_screen(host, MenusLayout.main_view(), &"codex")
	var cats: Array = screen.get("CATEGORIES")
	_ok(cats[0] == &"guide" and screen.call("category") == &"guide", "Guia: primeiro marcador e aberto na primeira vez")
	var tabs: Array = screen.get("_tabs")
	_ok((tabs[0] as Button).name == "Tab_guide" and (tabs[0] as Button).text == TranslationServer.translate("guide.tab"),
			"Guia: marcador com o nome")
	var rows: Array = screen.call("cards")
	_ok(rows.size() == GuideBook.CHAPTERS.size() and rows[0] is GuidePage.ChapterRow, "Guia: um cartão por capítulo")
	var page := screen.call("guide_page") as GuidePage
	_ok(page.is_visible_in_tree() and String(page.chapter()["id"]) == "play" and int(screen.call("selected")) == 0,
			"Guia: abre no capítulo 1")
	_ok(not (screen.get("_view") as Control).visible
			and (screen.get("_name") as Label).text == TranslationServer.translate("guide.ch.play"),
			"Guia: cabeçalho com o título do capítulo, sem retrato")
	var chests := GuideBook.CHAPTERS.find(&"chests")
	(rows[chests] as Button).pressed.emit()
	await host.get_tree().process_frame
	_ok(String(page.chapter()["id"]) == "chests" and (rows[chests] as GuidePage.ChapterRow).is_selected()
			and not (rows[0] as GuidePage.ChapterRow).is_selected(), "Guia: tocar no capítulo troca a página e o destaque")
	# O capítulo de baús é longo (seção Fogo, gelo e sombra): o resto monta nos quadros seguintes.
	page.complete()
	var link := page.find_child("Link_weapons", true, false) as Button
	_ok(link != null and link.is_visible_in_tree(), "Guia: botão Ver armas no Diário")
	if link != null:
		link.pressed.emit()
		await host.get_tree().create_timer(0.5).timeout
		_ok(screen.call("category") == &"weapons" and not page.is_visible_in_tree(), "Guia: Ver no Diário abre Armas")
	screen.call("open_category", &"guide", false)
	screen.call("open_entry", GuideBook.CHAPTERS.find(&"bosses"))
	await host.get_tree().process_frame
	# Rolagem que começou num chip: o link chega ao soltar o dedo e não pode abrir o item.
	page.set("_press_moved", true)
	page.call("_on_meta", {"category": &"weapons", "id": "katana"})
	await host.get_tree().process_frame
	_ok(screen.call("category") == &"guide", "Guia: soltar o dedo depois de rolar sobre um chip não abre o item")
	page.set("_press_moved", false)
	page.call("_on_meta", {"category": &"weapons", "id": "katana"})
	await host.get_tree().create_timer(0.5).timeout
	_ok(screen.call("category") == &"weapons", "Guia: toque parado num chip abre o item")
	screen.call("open_category", &"guide", false)
	screen.call("open_entry", GuideBook.CHAPTERS.find(&"bosses"))
	await host.get_tree().process_frame
	page.ref_pressed.emit(&"weapons", "katana")
	await host.get_tree().create_timer(0.5).timeout
	_ok(screen.call("category") == &"weapons" and int(screen.call("selected")) == int(screen.call("index_of", &"katana")),
			"Guia: tocar num chip abre o item no Diário")
	# Sombras do Guardião no Diário: logo depois do Guardião da fase, escondidas até serem vencidas, e o
	# chip do Guia abre a entrada certa.
	var boss_rows: Array = screen.call("entries_for", &"bosses")
	var boss_ids: Array[String] = []
	for e: Dictionary in boss_rows:
		boss_ids.append(String(e.get("id", "")))
	var beside := true
	for s: StringName in DB.ids("stages"):
		var mid := String(RiftPortal.midboss_of(DB.stage(s)).get("id", ""))
		var mid2 := String(RiftPortal.midboss2_of(DB.stage(s)).get("id", ""))
		if mid2 != "":
			beside = beside and boss_ids.find(mid) >= 0 and boss_ids.find(mid2) == boss_ids.find(mid) + 1
	_ok(beside and boss_ids.size() == DB.ids("bosses").size() - 1 and not boss_ids.has("shinigami"),
			"Diário: cada Sombra do Guardião logo depois do Guardião da fase %s", [boss_ids])
	var shadow_at := boss_ids.find("onikuma_kage")
	_ok(shadow_at >= 0 and not bool((boss_rows[shadow_at] as Dictionary)["known"])
			and String((boss_rows[shadow_at] as Dictionary)["text"]) == TranslationServer.translate("codex.boss_locked"),
			"Diário: Sombra do Guardião não vencida fica escondida")
	screen.call("open_category", &"guide", false)
	screen.call("open_entry", GuideBook.CHAPTERS.find(&"bosses"))
	await host.get_tree().process_frame
	page.ref_pressed.emit(&"bosses", "onikuma_kage")
	for _f: int in 90:
		if screen.call("category") == &"bosses" and int(screen.call("selected")) == shadow_at:
			break
		await host.get_tree().process_frame
	_ok(screen.call("category") == &"bosses" and int(screen.call("selected")) == shadow_at,
			"Guia: chip da Sombra do Guardião abre a entrada dela no Diário")
	var total: Array = screen.call("discovered_total")
	var expected := 0
	for id: StringName in cats:
		if id != &"guide":
			expected += (screen.call("entries_for", id) as Array).size()
	_ok(total[1] == expected, "Guia: contador de descobertos não conta capítulos")
	screen.call("open_category", &"bosses", false)
	screen.call("on_show")
	await host.get_tree().process_frame
	_ok(screen.call("category") == &"bosses", "Guia: o Diário lembra o último marcador")
	screen.call("open_category", &"guide", false)
	screen.call("open_entry", GuideBook.CHAPTERS.find(&"tips"))
	var sync_children := page.get_child_count()
	for _f: int in 40:
		await host.get_tree().process_frame
	var tips_blocks := (page.chapter()["blocks"] as Array).size()
	_ok(sync_children <= GuidePage.SYNC_BLOCKS and page.is_complete() and page.get_child_count() == tips_blocks,
			"Guia: capítulo longo monta aos poucos e termina sozinho (%d na hora, %d no fim)", [sync_children, tips_blocks])
	# Chips da página: textos ricos com imagens, sem nada redesenhando por quadro.
	for i: int in GuideBook.CHAPTERS.size():
		screen.call("open_entry", i)
		await host.get_tree().process_frame
		var procs := 0
		for node: Node in page.find_children("*", "", true, false):
			procs += int(node.is_processing())
		_ok(procs == 0, "Guia: capítulo %d sem _process (página estática)", (i + 1))
	layout.close_screen(screen)
	await host.get_tree().process_frame
	SaveManager.data = original


# --- Layout -----------------------------------------------------------------------------

## Cada capítulo do Guia na tela aberta (resolução `view`, recorte já ligado em `layout`).
func check_layout(layout: MenusLayout, host: Node, screen: Control, view: Vector2, state: String,
		check: Callable) -> void:
	_check = check
	(screen.call("guide_book") as GuideBook).platform_override = "android"
	screen.call("open_category", &"guide", false)
	await host.get_tree().process_frame
	var area: Rect2 = layout.call("_area", view)
	var rows: Array = screen.call("cards")
	var scroll := screen.get("_detail_scroll") as ScrollContainer
	for i: int in rows.size():
		screen.call("open_entry", i)
		(screen.call("guide_page") as GuidePage).complete()
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		var st := "Guia %s capítulo %d" % [state, i + 1]
		layout.check_common(screen, view, st)
		var clip := scroll.get_global_rect().intersection(area)
		var page := screen.call("guide_page") as GuidePage
		_ok(page.get_child_count() > 0, "%s: página com conteúdo", st)
		var bad: Array[String] = []
		for node: Node in page.find_children("*", "RichTextLabel", true, false):
			var rtl := node as RichTextLabel
			var r := rtl.get_global_rect()
			if r.position.x < clip.position.x - 0.5 or r.end.x > clip.end.x + 0.5:
				bad.append("fora %s em %s" % [r, clip])
			if rtl.get_content_width() > r.size.x + 0.5:
				bad.append("largura %d de %.0f: %s" % [rtl.get_content_width(), r.size.x, rtl.get_parsed_text().left(24)])
			if rtl.get_content_height() > r.size.y + 0.5:
				bad.append("altura %d de %.0f: %s" % [rtl.get_content_height(), r.size.y, rtl.get_parsed_text().left(24)])
		for node: Node in page.find_children("TipNote", "", true, false):
			var r := (node as Control).get_global_rect()
			if r.position.x < clip.position.x - 0.5 or r.end.x > clip.end.x + 0.5:
				bad.append("dica fora %s" % r)
		_ok(bad.is_empty(), "%s: textos e dicas inteiros na página %s", [st, bad.slice(0, 3)])
		var row := rows[i] as Control
		var grid_clip := (screen.get("_grid_scroll") as Control).get_global_rect()
		var rr := row.get_global_rect()
		_ok(rr.position.x >= grid_clip.position.x - 0.5 and rr.end.x <= grid_clip.end.x + 0.5
				and row.size.y >= 24.0, "%s: cartão do capítulo na página esquerda", st)
