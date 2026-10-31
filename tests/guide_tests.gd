extends RefCounted
## Guia do Diário (scripts/systems/guide_book.gd, scripts/ui/guide_page.gd, marcador "Guia" de
## scripts/app/screens/codex_screen.gd):
##   - dados (run_data): os 9 capítulos montam dos dados nos 11 idiomas, sem chave crua nem %s
##     sobrando; os números batem com data/*.json e com as constantes do código (noite, cartas,
##     espaços, níveis máximos, chances e ryō dos baús, itens do chão, horários dos chefes, aviso
##     do Guardião do Limiar, Santuário, Kami, Lua Vermelha, terrenos, perigos); a descoberta
##     esconde receitas, chefes, guardiãs e fases como o Diário (Discovery); backup do Google só
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


func _ok(condition: bool, label: String) -> void:
	_check.call(condition, label)


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
		_ok(book.entries().size() == GuideBook.CHAPTERS.size() and GuideBook.CHAPTERS.size() == 9,
				"Guia [%s]: 9 capítulos" % lang)
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
	_ok(bad.is_empty(), "Guia: todos os capítulos montam nos 11 idiomas, sem chave crua nem %%s %s" % [bad.slice(0, 6)])


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
	_ok(levels.contains(weapons_line), "Guia números: %s" % weapons_line)
	_ok(levels.contains(TranslationServer.translate("guide.levels.up") % [LevelUpSystem.BASE_CARDS,
			LevelUpSystem.BASE_CARDS + 1]), "Guia números: cartas por nível de LevelUpSystem")
	for pu: Dictionary in powerups:
		if String(pu["id"]) in ["pu_reroll", "pu_skip", "pu_banish"]:
			_ok(levels.contains(TranslationServer.translate("powerup.%s.name" % pu["id"]) + ": +" + str(int(pu["per_level"]))),
					"Guia números: cargas de %s dos dados" % pu["id"])
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
				"Guia omikuji: %s mostra %d melhorias" % [seals[i], ChestSystem.COUNTS[i]])
	_ok(seals == ["吉", "中吉", "大吉"], "Guia omikuji: selos 吉, 中吉 e 大吉 %s" % [seals])
	_ok(chests.contains(TranslationServer.translate("guide.chests.kyo") % [GuideBook.pct(Omikuji.KYO_CHANCE),
			Omikuji.KYO_RYO, Omikuji.GENEROUS_CHESTS, TranslationServer.translate("omikuji.chukichi")]),
			"Guia omikuji: chance e consolo do 凶 e baús generosos do Omikuji")
	var evo_count := 0
	for w: Dictionary in weapons:
		if String(w.get("kind", "base")) == "base" and w.has("evolution"):
			evo_count += 1
	_ok(book.evolution_lines().size() == evo_count and evo_count > 0,
			"Guia: uma receita por arma base com evolução (%d)" % evo_count)
	var union_count := weapons.filter(func(w: Dictionary) -> bool: return String(w.get("kind", "")) == "union").size()
	_ok(book.union_lines().size() == union_count, "Guia: uma linha por união (%d)" % union_count)
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
				"Guia números: item %s com efeito e chance dos dados (%s)" % [it["id"], chance])
		if String(it["effect"]) in ["heal", "ryo", "freeze", "solar"]:
			_ok(book.item_effect(it).contains(str(int(it["value"]))), "Guia números: valor de %s" % it["id"])
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
			"Guia missões: total, categorias e concluídas (%d)" % MissionBook.ids().size())
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
			and stronger.contains(TranslationServer.translate("moon.rule5")), "Guia números: Lua Vermelha do jogo")
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
					"Guia: perigo de %s descrito" % s["id"])
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
		bases_known = bases_known and bool(line[0]["ref"]["known"])
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
	_ok(leaked.is_empty() and bosses.contains("???"), "Guia descoberta: chefes não vencidos escondidos %s" % [leaked])
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
							"Guia descoberta: guardiã %s" % part["ref"]["id"])
				if part.has("chip") and String(part["chip"]).contains("/kami/") and String(part.get("kind", "")) == "skill":
					kami_known += int(bool(part["known"]))
	_ok(heroes_known == 1, "Guia descoberta: só as guardiãs liberadas com rosto e nome (%d)" % heroes_known)
	_ok(kami_known == DB.ids("kami").size(), "Guia descoberta: Kami pela regra do Diário (todos conhecidos)")


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
				"Guia dicas (%s): toda dica do catálogo aparece, fica guardada ou é da outra plataforma" % platform)
		var text := chapter_text(book.chapter(&"tips"))
		var missing: Array[String] = []
		for cat: String in groups["shown"]:
			for tip: Dictionary in groups["shown"][cat]:
				if not text.contains(TipDeck.text(tip)):
					missing.append(String(tip["id"]))
		_ok(missing.is_empty(), "Guia dicas (%s): toda dica mostrada está no capítulo %s" % [platform, missing])
		var leak: Array[String] = []
		for cat: String in groups["shown"]:
			for tip: Dictionary in groups["shown"][cat]:
				for w: StringName in DB.ids("weapons"):
					if not Discovery.weapon_known(w) and TipDeck.text(tip).contains(TranslationServer.translate("weapon.%s.name" % w)):
						leak.append("%s→%s" % [tip["id"], w])
		_ok(leak.is_empty(), "Guia dicas (%s, save novo): nenhuma cita evolução não vista %s" % [platform, leak])
		var backup_shown := (groups["shown"] as Dictionary).has("backup")
		_ok(backup_shown == (platform == "android"), "Guia dicas: Backup só no Android (%s)" % platform)
		_ok(int(groups["hidden"]) > 0 and text.contains(TranslationServer.translate("guide.tips.hidden") % groups["hidden"]),
				"Guia dicas (%s, save novo): dicas com spoiler guardadas e contadas (%d)" % [platform, groups["hidden"]])
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
		if not shown and not (tip["when"] as Dictionary).has("locked"):
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
	(rows[2] as Button).pressed.emit()
	await host.get_tree().process_frame
	_ok(String(page.chapter()["id"]) == "chests" and (rows[2] as GuidePage.ChapterRow).is_selected()
			and not (rows[0] as GuidePage.ChapterRow).is_selected(), "Guia: tocar no capítulo troca a página e o destaque")
	var link := page.find_child("Link_weapons", true, false) as Button
	_ok(link != null and link.is_visible_in_tree(), "Guia: botão Ver armas no Diário")
	if link != null:
		link.pressed.emit()
		await host.get_tree().create_timer(0.5).timeout
		_ok(screen.call("category") == &"weapons" and not page.is_visible_in_tree(), "Guia: Ver no Diário abre Armas")
	screen.call("open_category", &"guide", false)
	screen.call("open_entry", 4)
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
	screen.call("open_entry", 4)
	await host.get_tree().process_frame
	page.ref_pressed.emit(&"weapons", "katana")
	await host.get_tree().create_timer(0.5).timeout
	_ok(screen.call("category") == &"weapons" and int(screen.call("selected")) == int(screen.call("index_of", &"katana")),
			"Guia: tocar num chip abre o item no Diário")
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
			"Guia: capítulo longo monta aos poucos e termina sozinho (%d na hora, %d no fim)" % [sync_children, tips_blocks])
	# Chips da página: textos ricos com imagens, sem nada redesenhando por quadro.
	for i: int in GuideBook.CHAPTERS.size():
		screen.call("open_entry", i)
		await host.get_tree().process_frame
		var procs := 0
		for node: Node in page.find_children("*", "", true, false):
			procs += int(node.is_processing())
		_ok(procs == 0, "Guia: capítulo %d sem _process (página estática)" % (i + 1))
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
		_ok(page.get_child_count() > 0, "%s: página com conteúdo" % st)
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
		_ok(bad.is_empty(), "%s: textos e dicas inteiros na página %s" % [st, bad.slice(0, 3)])
		var row := rows[i] as Control
		var grid_clip := (screen.get("_grid_scroll") as Control).get_global_rect()
		var rr := row.get_global_rect()
		_ok(rr.position.x >= grid_clip.position.x - 0.5 and rr.end.x <= grid_clip.end.x + 0.5
				and row.size.y >= 24.0, "%s: cartão do capítulo na página esquerda" % st)
