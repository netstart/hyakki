class_name GuideBook
extends RefCounted
## Guia do Diário (manual dentro do jogo): monta os capítulos a partir dos dados (data/*.json
## pelo DB), das constantes do código e do save, no idioma atual. Nenhum número é repetido aqui:
## duração da noite (HyakkiGame.RUN_LENGTH), cartas por nível e espaços (LevelUpSystem), chances
## e ryō dos baús (ChestSystem), itens do chão (data/items.json), horários dos chefes e dos Kami
## (data/stages.json), aviso do Guardião do Limiar (RiftPortal), Santuário (data/powerups.json,
## MetaProgress.PRICE_STEP), Lua Vermelha (HyakkiGame), clima e terreno (data/weather.json,
## data/surfaces.json, "hazard" das fases) e as dicas 心得 (TipDeck).
##
## Descoberta: o que o Diário ainda esconde fica escondido aqui pelas mesmas regras (Discovery):
## receitas com "???" e chip "?", chefes não vencidos, guardiãs e fases bloqueadas sem nome;
## dicas que citam arma ou relíquia desconhecida ficam guardadas (só a contagem aparece).
##
## Capítulo: {id, title, icon, blocks}. Blocos:
## - {type: "h", text}: título de seção;
## - {type: "p", parts, text}: parágrafo; parts = trechos do modelo traduzido com os valores
##   (cada %s vira um trecho destacado, na ordem do idioma); text = o parágrafo inteiro;
## - {type: "rich", lines, text}: linhas com chips; cada linha é uma lista de trechos;
## - {type: "tip", tip, text}: dica 心得 (TipDeck) com o visual do balão;
## - {type: "link", category, text}: botão que abre a categoria no Diário.
## Trechos: {t: texto}, {n: valor destacado}, {seal: kanji num selo vermelho},
## {ref: {category, id, known, icon, name, face}}
## (chip com nome, toque abre o item no Diário), {chip: caminho, known, kind ("skill"|"face"|
## "plain")} (só o ícone).

const CHAPTERS: Array[StringName] = [&"play", &"levels", &"chests", &"items", &"bosses", &"stronger",
		&"stages", &"saving", &"tips"]
const ICONS := {
	&"play": "res://assets/art/ui/icons/items/Boot.png",
	&"levels": "res://assets/art/ui/icons/spell/Upgrade.png",
	&"chests": "res://assets/art/ui/icons/items/Money.png",
	&"items": "res://assets/art/ui/icons/job/Dish.png",
	&"bosses": "res://assets/art/ui/icons/spell/Death.png",
	&"stronger": "res://assets/art/ui/icons/spell/AttackUpgrade.png",
	&"stages": "res://assets/art/ui/icons/meteo/Rain.png",
	&"saving": "res://assets/art/ui/icons/items/Guard.png",
	&"tips": "res://assets/art/ui/icons/job/Talk.png",
}
## Condições de "when" que escondem conteúdo (spoiler): as outras (partidas, vitórias...) só
## decidem quando o balão mostra a dica, e no Guia a dica vale como conselho.
const SPOILER_KEYS: Array[String] = ["platform", "unlocked", "locked", "evolved"]

## Testes: "android" ou "desktop" no lugar da plataforma real ("" = TipDeck.platform()).
var platform_override := ""


func platform() -> String:
	return platform_override if platform_override != "" else TipDeck.platform()


## Títulos dos capítulos, na ordem.
func titles() -> Array[String]:
	return [tr("guide.ch.play"), tr("guide.ch.levels"), tr("guide.ch.chests"), tr("guide.ch.items"),
			tr("guide.ch.bosses"), tr("guide.ch.stronger"), tr("guide.ch.stages"), tr("guide.ch.saving"),
			tr("guide.ch.tips")]


## Entradas da página esquerda do Diário (uma por capítulo).
func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var names := titles()
	for i: int in CHAPTERS.size():
		out.append({"id": String(CHAPTERS[i]), "title": names[i], "known": true, "icon": ICONS[CHAPTERS[i]],
				"guide": CHAPTERS[i], "number": i + 1})
	return out


func chapter(id: StringName) -> Dictionary:
	var index := CHAPTERS.find(id)
	if index < 0:
		return {}
	var blocks: Array[Dictionary] = []
	match id:
		&"play":
			blocks = _play()
		&"levels":
			blocks = _levels()
		&"chests":
			blocks = _chests()
		&"items":
			blocks = _items()
		&"bosses":
			blocks = _bosses()
		&"stronger":
			blocks = _stronger()
		&"stages":
			blocks = _stages()
		&"saving":
			blocks = _saving()
		&"tips":
			blocks = _tips()
	return {"id": String(id), "title": titles()[index], "icon": ICONS[id], "blocks": blocks}


# --- Capítulos -------------------------------------------------------------------------

func _play() -> Array[Dictionary]:
	var hero := _hero()
	var data: Dictionary = DB.heroes[hero]
	var mode := String(Settings.get_value("joystick_mode"))
	var side := String(Settings.get_value("joystick_side"))
	var lantern := LanternSystem.MAX_BOOST
	return [
		_h(tr("guide.play.first_h")),
		_p(tr("guide.play.first")),
		_h(tr("guide.play.goal_h")),
		_p(tr("guide.play.goal"), [str(roundi(HyakkiGame.RUN_LENGTH / 60.0))]),
		_h(tr("guide.play.move_h")),
		_p(tr("guide.play.move"), [tr("options.joystick_fixed") if mode == "fixed" else tr("options.joystick_floating"),
				tr("options.side_right") if side == "right" else tr("options.side_left")]),
		_p(tr("guide.play.modes"), [tr("options.joystick_fixed"), tr("options.joystick_floating")]),
		_h(tr("guide.play.attack_h")),
		_p(tr("guide.play.attack"), [{"ref": Discovery.recipe_ref(&"weapons", String(data["weapon"]))}]),
		_h(tr("guide.play.lantern_h")),
		_p(tr("guide.play.lantern"), [pct(lantern), pct(1.0 - LanternSystem.BOSS_EAT)]),
		_p(tr("guide.play.ultimate"), [tr("hero.%s.name" % hero),
				tr("ultimate.%s.name" % String((data["ultimate"] as Dictionary)["type"]))]),
		_h(tr("guide.play.pause_h")),
		_p(tr("guide.play.pause")),
	]


func _levels() -> Array[Dictionary]:
	var hero_weapon := String((DB.heroes[_hero()] as Dictionary)["weapon"])
	var first_relic := String(DB.ids("passives")[0])
	var lines: Array = [
		[{"chip": UiIcons.skill_path("weapons", hero_weapon), "known": true, "kind": "skill"}, {"t": " "}]
				+ _parts(tr("guide.levels.weapons"), [str(LevelUpSystem.MAX_WEAPONS), str(weapon_max_level())]),
		[{"chip": UiIcons.skill_path("passives", first_relic), "known": true, "kind": "skill"}, {"t": " "}]
				+ _parts(tr("guide.levels.relics"), [str(LevelUpSystem.MAX_PASSIVES), str(relic_max_level())]),
	]
	var tools: Array = []
	for id: StringName in [&"pu_reroll", &"pu_skip", &"pu_banish"]:
		var pu: Dictionary = DB.powerups.get(id, {})
		if pu.is_empty():
			continue
		var level := SaveManager.powerup_level(id)
		tools.append([{"chip": String(pu["icon"]), "known": true, "kind": "skill"}, {"t": " "}]
				+ _parts(tr("guide.levels.charges"), [tr("powerup.%s.name" % id), _num(float(pu["per_level"])),
				str(int(pu["max"])), _num(float(pu["per_level"]) * level)]))
	return [
		_h(tr("guide.levels.embers_h")),
		_p(tr("guide.levels.embers")),
		_h(tr("guide.levels.up_h")),
		_p(tr("guide.levels.up"), [str(LevelUpSystem.BASE_CARDS), str(LevelUpSystem.BASE_CARDS + 1)]),
		_rich(lines),
		_h(tr("guide.levels.tools_h")),
		_p(tr("guide.levels.tools"), [tr("title.sanctuary")]),
		_rich(tools),
	]


func _chests() -> Array[Dictionary]:
	var one := 1.0 - ChestSystem.BASE_THREE - ChestSystem.BASE_FIVE
	var evolutions: Array = []
	var unions: Array = []
	var hidden := false
	for line: Array in evolution_lines():
		evolutions.append(_parts(tr("guide.chests.line"), line))
		hidden = hidden or line.any(func(part: Dictionary) -> bool: return not bool(part["ref"]["known"]))
	for line: Array in union_lines():
		unions.append(_parts(tr("guide.chests.line"), line))
		hidden = hidden or line.any(func(part: Dictionary) -> bool: return not bool(part["ref"]["known"]))
	var out: Array[Dictionary] = [
		_h(tr("guide.chests.drop_h")),
		_p(tr("guide.chests.drop"), [str(ChestSystem.COUNTS[0]), str(ChestSystem.COUNTS[1]), str(ChestSystem.COUNTS[2]),
				pct(one), pct(ChestSystem.BASE_THREE), pct(ChestSystem.BASE_FIVE), str(ChestSystem.RYO_PER_ITEM)]),
		_p(tr("guide.chests.boss"), [str(ChestSystem.BOSS_MIN_ITEMS), str(ChestSystem.BOSS_RYO_MULT),
				str(RiftPortal.MIDBOSS_CHESTS)]),
		_h(tr("guide.chests.omikuji_h")),
		_p(tr("guide.chests.omikuji")),
		_rich(fortune_lines()),
		_p(tr("guide.chests.kyo"), [pct(Omikuji.KYO_CHANCE), str(Omikuji.KYO_RYO), str(Omikuji.GENEROUS_CHESTS),
				tr("omikuji.chukichi")]),
		_h(tr("guide.chests.evo_h")),
		_p(tr("guide.chests.evo"), [str(weapon_max_level())]),
		_rich(evolutions),
		_h(tr("guide.chests.union_h")),
		_p(tr("guide.chests.union")),
		_rich(unions),
	]
	if hidden:
		out.append(_p(tr("guide.chests.unknown")))
	out.append(_link(&"weapons", tr("guide.link.weapons")))
	out.append(_link(&"relics", tr("guide.link.relics")))
	return out


## Sortes do omikuji e quantas melhorias cada uma mostra (Omikuji.fortune_for sobre
## ChestSystem.COUNTS): [selo, leitura (significado) = quantidade].
func fortune_lines() -> Array:
	var out: Array = []
	var names := {Omikuji.KICHI: ["吉", "omikuji.kichi", "omikuji.kichi_meaning"],
			Omikuji.CHUKICHI: ["中吉", "omikuji.chukichi", "omikuji.chukichi_meaning"],
			Omikuji.DAIKICHI: ["大吉", "omikuji.daikichi", "omikuji.daikichi_meaning"]}
	for count: int in ChestSystem.COUNTS:
		var fortune := Omikuji.fortune_for(count, 1.0)
		var row: Array = names[fortune]
		out.append([{"seal": String(row[0])}, {"t": " "}] + _parts(tr("guide.chests.fortune"),
				[TranslationServer.translate(String(row[1])), {"t": TranslationServer.translate(String(row[2]))},
				str(count)]))
	return out


## Evoluções de cada arma base: [arma, relíquia, evolução] como trechos {ref}.
func evolution_lines() -> Array:
	var out: Array = []
	for w: StringName in DB.ids("weapons"):
		var data := DB.weapon(w)
		if String(data.get("kind", "base")) != "base" or not data.has("evolution"):
			continue
		out.append([{"ref": Discovery.recipe_ref(&"weapons", String(w))},
				{"ref": Discovery.recipe_ref(&"relics", String(data.get("evolves_with", "")))},
				{"ref": Discovery.recipe_ref(&"weapons", String(data["evolution"]))}])
	return out


## Uniões: [evolução, evolução, união] como trechos {ref}.
func union_lines() -> Array:
	var out: Array = []
	for w: StringName in DB.ids("weapons"):
		var data := DB.weapon(w)
		var parts: Array = data.get("requires", [])
		if String(data.get("kind", "")) != "union" or parts.size() < 2:
			continue
		out.append([{"ref": Discovery.recipe_ref(&"weapons", String(parts[0]))},
				{"ref": Discovery.recipe_ref(&"weapons", String(parts[1]))},
				{"ref": Discovery.recipe_ref(&"weapons", String(w))}])
	return out


func _items() -> Array[Dictionary]:
	var total := 0.0
	for id: StringName in DB.ids("items"):
		total += float((DB.items[id] as Dictionary).get("weight", 0.0))
	var lines: Array = []
	for id: StringName in DB.ids("items"):
		var item: Dictionary = DB.items[id]
		var weight := float(item.get("weight", 0.0))
		if weight <= 0.0:
			continue
		lines.append([{"chip": String(item["icon"]), "known": true, "kind": "plain"}, {"t": " "}]
				+ _parts(tr("guide.items.line"), [tr("item.%s.name" % id), {"t": item_effect(item)}, pct(weight / total)]))
	var coin: Dictionary = DB.items.get(&"coin", {})
	return [
		_h(tr("guide.items.ground_h")),
		_p(tr("guide.items.ground")),
		_rich(lines),
		_p(tr("guide.items.coin"), [{"chip": String(coin.get("icon", "")), "known": true, "kind": "plain"},
				str(int(coin.get("value", 0))), pct(PickupManager.COIN_CHANCE)]),
		_h(tr("guide.items.ryo_h")),
		_p(tr("guide.items.ryo"), [str(ChestSystem.RYO_PER_ITEM), str(BossDirector.BOSS_RYO), pct(HyakkiGame.MOON_REWARD)]),
		_p(tr("guide.items.spend"), [tr("title.sanctuary"), tr("title.shop"), str(SaveManager.ryo())]),
	]


## Efeito de um item do chão no idioma atual, com o valor de data/items.json.
func item_effect(item: Dictionary) -> String:
	var value := str(int(item.get("value", 0)))
	match String(item.get("effect", "")):
		"heal":
			return tr("guide.item.heal") % value
		"ryo":
			return tr("guide.item.ryo") % value
		"magnet":
			return tr("guide.item.magnet")
		"bell":
			return tr("guide.item.bell")
		"freeze":
			return tr("guide.item.freeze") % value
		"solar":
			return tr("guide.item.solar") % value
	return ""


func _bosses() -> Array[Dictionary]:
	var out: Array[Dictionary] = [_h(tr("guide.bosses.clock_h")), _p(tr("guide.bosses.intro"))]
	var hidden := false
	for s: StringName in stage_order():
		var stage: Dictionary = DB.stages[s]
		if not Discovery.stage_known(s):
			out.append(_rich([[{"chip": "", "known": false, "kind": "skill"}, {"t": " " + Discovery.UNKNOWN}]]))
			continue
		var lines: Array = [[{"n": tr("stage.%s.name" % s)}]]
		for event: Dictionary in boss_schedule(s):
			var b := StringName(String(event["id"]))
			var known := Discovery.boss_known(b)
			hidden = hidden or not known
			var line: Array = [{"n": Screen.format_time(float(event["t"]))}, {"t": " "}, {"ref": boss_ref(b)}]
			if bool(event["midboss"]):
				line.append({"t": " · " + tr("midboss.title")})
			lines.append(line)
		out.append(_rich(lines))
	if hidden:
		out.append(_p(tr("guide.bosses.unknown")))
	var mid := _first_midboss_time()
	out.append_array([
		_h(tr("midboss.title")),
		_p(tr("guide.bosses.mid"), [Screen.format_time(mid), _num(RiftPortal.WARN_LEAD), str(RiftPortal.MIDBOSS_CHESTS)]),
		_h(tr("guide.bosses.boss_h")),
		_p(tr("guide.bosses.boss"), [str(BossDirector.BOSS_RYO), str(ChestSystem.BOSS_MIN_ITEMS)]),
		_link(&"bosses", tr("guide.link.bosses")),
	])
	return out


## Chefes de uma fase em ordem de horário: [{t, id, midboss}].
func boss_schedule(s: StringName) -> Array[Dictionary]:
	var stage: Dictionary = DB.stages[s]
	var out: Array[Dictionary] = []
	for b: Dictionary in stage.get("bosses", []):
		out.append({"t": float(b["t"]), "id": String(b["id"]), "midboss": false})
	var mid: Dictionary = stage.get("midboss", {})
	if not mid.is_empty():
		out.append({"t": float(mid["t"]), "id": String(mid["id"]), "midboss": true})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	return out


## Chefe como chip de retrato (o ícone do Diário); desconhecido: "?" e "???".
func boss_ref(b: StringName) -> Dictionary:
	var data: Dictionary = DB.bosses.get(b, {})
	var sprite: Dictionary = data.get("sprite", {})
	var face := String(data.get("faceset", String(sprite.get("path", "")).get_base_dir().path_join("Faceset.png")))
	var known := Discovery.boss_known(b)
	return {"category": &"bosses", "id": String(b), "known": known, "icon": face, "face": true,
			"name": tr("boss.%s.name" % b) if known else Discovery.UNKNOWN}


func _first_midboss_time() -> float:
	for s: StringName in stage_order():
		var mid: Dictionary = (DB.stages[s] as Dictionary).get("midboss", {})
		if not mid.is_empty():
			return float(mid["t"])
	return 0.0


func _stronger() -> Array[Dictionary]:
	var ups: Array = []
	var max_level := 0
	for id: StringName in DB.ids("powerups"):
		var pu: Dictionary = DB.powerups[id]
		max_level = maxi(max_level, int(pu["max"]))
		ups.append({"chip": String(pu["icon"]), "known": true, "kind": "skill"})
		ups.append({"t": " "})
	var weapons := _count_available("weapons")
	var relics := _count_available("passives")
	var heroes := [0, 0]
	var faces: Array = []
	for h: StringName in DB.ids("heroes"):
		var known := Discovery.hero_known(h)
		heroes[0] += int(known)
		heroes[1] += 1
		faces.append({"ref": {"category": &"heroes", "id": String(h), "known": known, "face": true,
				"icon": String((DB.heroes[h] as Dictionary)["face"]),
				"name": tr("hero.%s.name" % h) if known else Discovery.UNKNOWN}})
		faces.append({"t": "  "})
	var kami: Array = []
	for k: StringName in DB.ids("kami"):
		kami.append({"chip": UiIcons.skill_path("kami", k), "known": Discovery.kami_known(k), "kind": "skill"})
		kami.append({"t": " "})
	var times: Array = kami_times()
	var moons: Array = []
	for m: int in range(1, HyakkiGame.MAX_MOON + 1):
		moons.append([{"t": "· " + tr("moon.rule%d" % m)}])
	var sections := CodexMissions.sections(CodexMissions.entries())
	var done := 0
	var total := 0
	var cats: Array = []
	for sec: Dictionary in sections:
		done += int(sec["done"])
		total += int(sec["total"])
		cats.append([{"chip": String(sec["icon"]), "known": true, "kind": "plain"}, {"t": " "}]
				+ _parts(tr("guide.stronger.mission_cat"), [String(sec["title"]), str(sec["done"]), str(sec["total"])]))
	var goals: Array = []
	for id: StringName in MissionBook.next_goals(3):
		var line: Array = [{"chip": MissionBook.icon(id), "known": true,
				"kind": "face" if MissionBook.icon_is_face(id) else "plain"}, {"t": " "}, {"n": MissionBook.title(id)},
				{"t": " · " + MissionBook.progress_text(id) + " → "}]
		for part: Dictionary in MissionBook.reward_parts(id):
			line.append({"chip": String(part["icon"]), "known": true, "kind": "face" if bool(part["face"]) else "plain"})
			line.append({"t": " " + String(part["text"]) + " "})
		goals.append(line)
	var shop_slots := ShopManager.ad_slots().size()
	return [
		_h(tr("title.sanctuary")),
		_p(tr("guide.stronger.sanctuary"), [str(DB.ids("powerups").size()), str(max_level), pct(MetaProgress.PRICE_STEP),
				tr("sanctuary.refund")]),
		_rich([ups]),
		_h(tr("guide.stronger.unlock_h")),
		_p(tr("guide.stronger.unlock"), [str(weapons[0]), str(weapons[1]), str(relics[0]), str(relics[1]),
				str(heroes[0]), str(heroes[1])]),
		_rich([faces]),
		_h(tr("guide.stronger.kami_h")),
		_p(tr("guide.stronger.kami"), [Screen.format_time(float(times[0]) if times.size() > 0 else 0.0),
				Screen.format_time(float(times[-1]) if times.size() > 0 else 0.0), str(KamiSystem.OFFER_COUNT)]),
		_rich([kami]),
		_link(&"kami", tr("guide.link.kami")),
		_h(tr("guide.stronger.moon_h")),
		_p(tr("guide.stronger.moon"), [roman(HyakkiGame.MAX_MOON), pct(HyakkiGame.MOON_HP), pct(HyakkiGame.MOON_REWARD)]),
		_rich(moons),
		_h(tr("codex.achievements")),
		_p(tr("guide.stronger.missions"), [str(total), str(sections.size()), str(done)]),
		_rich(cats),
		_h(tr("goals.title")),
		_rich(goals) if not goals.is_empty() else _p(tr("goals.empty")),
		_link(&"achievements", tr("guide.link.achievements")),
		_h(tr("title.shop")),
		_p(tr("guide.stronger.shop"), [str(shop_slots), _num(ShopManager.COOLDOWN / 3600.0)]),
		_p(tr("shop.hint_free") if AdsManager.rewards_are_gifts() else tr("shop.hint")),
		_p(tr("shop.support_hint")),
	]


## Horários dos santuários Kami (data/stages.json "kami", da primeira fase que os tem).
func kami_times() -> Array:
	for s: StringName in stage_order():
		var times: Array = (DB.stages[s] as Dictionary).get("kami", [])
		if not times.is_empty():
			return times
	return []


## [liberadas, total] das armas base ou relíquias (MetaProgress.is_content_available).
func _count_available(kind: String) -> Array[int]:
	var out: Array[int] = [0, 0]
	for id: StringName in DB.ids(kind):
		var data: Dictionary = DB.weapon(id) if kind == "weapons" else DB.passives[id]
		if kind == "weapons" and String(data.get("kind", "base")) != "base":
			continue
		out[1] += 1
		out[0] += int(MetaProgress.is_content_available(kind, id, data))
	return out


func _stages() -> Array[Dictionary]:
	var out: Array[Dictionary] = [_p(tr("guide.stages.intro"))]
	var hinted := false
	for s: StringName in stage_order():
		if not Discovery.stage_known(s):
			# Só a próxima fase diz como abrir (a condição cita a fase anterior, já conhecida).
			var how := "" if hinted else _unlock_hint(s)
			hinted = true
			var line: Array = [{"chip": "", "known": false, "kind": "skill"}, {"t": " " + Discovery.UNKNOWN}]
			if how != "":
				line.append({"t": " · "})
				line.append_array(_parts(tr("guide.stages.locked"), [how]))
			out.append(_rich([line]))
			continue
		out.append(_h(tr("stage.%s.name" % s)))
		out.append(_rich(stage_lines(s)))
	out.append_array([
		_h(tr("guide.stages.weather_h")),
		_p(tr("guide.stages.weather")),
		_p(tr("guide.stages.surfaces")),
	])
	return out


## Clima, perigo e terrenos lentos de uma fase (cada um uma linha de trechos).
func stage_lines(s: StringName) -> Array:
	var lines: Array = []
	var weather: Dictionary = WeatherModel.profile_for(String(s))
	var precip := String(weather.get("precip", ""))
	if precip != "":
		var sky := weather_name(precip)
		if bool(weather.get("lightning", false)):
			sky = tr("guide.weather.thunder") % sky
		lines.append(_parts(tr("guide.stages.weather_line"), [sky]))
	var hazard: Dictionary = (DB.stages[s] as Dictionary).get("hazard", {})
	var text := hazard_text(hazard)
	if text != "":
		lines.append([{"t": text}])
	var surfaces := SurfaceField.data()
	var types: Dictionary = surfaces.get("types", {})
	var seen: Array[String] = []
	for spot: Dictionary in (surfaces.get("stages", {}) as Dictionary).get(String(s), []):
		var kind := String(spot.get("type", ""))
		if seen.has(kind) or not types.has(kind):
			continue
		seen.append(kind)
		var slow := 1.0 - float((types[kind] as Dictionary).get("slow", 1.0))
		lines.append(_parts(tr("guide.stages.surface_line"), [surface_name(kind), pct(slow)]))
	return lines


func weather_name(precip: String) -> String:
	match precip:
		"rain":
			return tr("guide.weather.rain")
		"snow":
			return tr("guide.weather.snow")
		"sand":
			return tr("guide.weather.sand")
		"ash":
			return tr("guide.weather.ash")
		"spirit":
			return tr("guide.weather.spirit")
	return precip


func surface_name(kind: String) -> String:
	match kind:
		"mud":
			return tr("guide.surface.mud")
		"clay":
			return tr("guide.surface.clay")
		"swamp":
			return tr("guide.surface.swamp")
		"oil":
			return tr("guide.surface.oil")
		"tar":
			return tr("guide.surface.tar")
		"quicksand":
			return tr("guide.surface.quicksand")
	return kind


## Perigo da fase (data/stages.json "hazard") no idioma atual, com os números dos dados.
func hazard_text(hazard: Dictionary) -> String:
	match String(hazard.get("type", "")):
		"fog":
			return tr("guide.hazard.fog")
		"statues":
			return tr("guide.hazard.statues") % _num(float(hazard.get("interval", 0.0)))
		"ash_storm":
			return tr("guide.hazard.ash_storm") % [_num(float(hazard.get("interval", 0.0))),
					_num(float(hazard.get("duration", 0.0))), pct(float(hazard.get("slow", 0.0)))]
		"lava":
			return tr("guide.hazard.lava") % _num(float(hazard.get("damage", 0.0)))
	return ""


## Condição de desbloqueio de uma fase (a conquista que a dá), ou "".
func _unlock_hint(s: StringName) -> String:
	for a: StringName in DB.ids("achievements"):
		for part: String in String((DB.achievements[a] as Dictionary).get("reward", "")).split(",", false):
			if part.strip_edges() == "stage:%s" % s:
				return tr("achievement.%s.desc" % a)
	return ""


func _saving() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		_h(tr("guide.saving.auto_h")),
		_p(tr("guide.saving.auto")),
		_p(tr("guide.saving.backup")),
		_h(tr("guide.saving.resume_h")),
		_p(tr("guide.saving.resume"), [tr("title.continue")]),
	]
	if platform() == "android":
		out.append_array([
			_h(tr("guide.saving.phone_h")),
			_p(tr("tip.backup_enable")),
			_p(tr("tip.backup_restore")),
			_p(tr("tip.backup_auto")),
		])
	return out


func _tips() -> Array[Dictionary]:
	var out: Array[Dictionary] = [_p(tr("guide.tips.intro"), [tr("options.tips")])]
	var groups := tip_groups()
	for cat: String in groups["order"]:
		var list: Array = (groups["shown"] as Dictionary).get(cat, [])
		if list.is_empty():
			continue
		out.append(_h(tr("tip.cat.%s" % cat)))
		for tip: Dictionary in list:
			out.append({"type": "tip", "tip": tip, "text": TipDeck.text(tip)})
	if int(groups["hidden"]) > 0:
		out.append(_p(tr("guide.tips.hidden"), [str(groups["hidden"])]))
	return out


## Dicas do catálogo por categoria: {order (categorias de data/tips.json), shown {cat: [dicas]},
## hidden (quantas ficam guardadas por spoiler), other_platform (só da outra plataforma)}.
func tip_groups() -> Dictionary:
	var ctx := TipDeck.context()
	ctx["platform"] = platform()
	var order: Array[String] = []
	for c: Variant in TipDeck.raw().get("categories", []):
		order.append(String(c))
	var shown: Dictionary = {}
	var hidden := 0
	var other := 0
	for tip: Dictionary in TipDeck.catalog():
		var when: Dictionary = tip.get("when", {})
		if when.has("platform") and String(when["platform"]) != platform():
			other += 1
			continue
		if not tip_visible(tip, ctx):
			hidden += 1
			continue
		var cat := String(tip["cat"])
		if not order.has(cat):
			order.append(cat)
		if not shown.has(cat):
			shown[cat] = []
		(shown[cat] as Array).append(tip)
	return {"order": order, "shown": shown, "hidden": hidden, "other_platform": other}


## A dica aparece no Guia: as condições de spoiler do TipBook valem (desbloqueado, bloqueado,
## evolução feita, plataforma) e ela não cita arma ou relíquia que o Diário ainda esconde.
func tip_visible(tip: Dictionary, ctx: Dictionary) -> bool:
	var when: Dictionary = tip.get("when", {})
	var spoiler: Dictionary = {}
	for key: String in when:
		if SPOILER_KEYS.has(key):
			spoiler[key] = when[key]
	if not TipBook.eligible({"when": spoiler}, ctx):
		return false
	for ref: Variant in tip.get("icons", []):
		var parts := String(ref).split(":")
		if parts.size() == 2 and Discovery.ref_hidden(parts[0], parts[1]):
			return false
	for arg: Variant in tip.get("args", []):
		var key := String(arg).split(".")
		if key.size() == 3 and key[2] == "name" and Discovery.ref_hidden(key[0], key[1]):
			return false
	return true


# --- Utilidades ------------------------------------------------------------------------

## Fases na ordem da jornada (data/stages.json "order").
func stage_order() -> Array[StringName]:
	var ids: Array[StringName] = DB.ids("stages").duplicate()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return int((DB.stages[a] as Dictionary).get("order", 0)) < int((DB.stages[b] as Dictionary).get("order", 0)))
	return ids


## Nível máximo das armas base (data/weapons.json "levels").
static func weapon_max_level() -> int:
	var best := 0
	for w: StringName in DB.ids("weapons"):
		var data := DB.weapon(w)
		if String(data.get("kind", "base")) == "base":
			best = maxi(best, (data.get("levels", []) as Array).size())
	return best


## Nível máximo das relíquias (data/passives.json "max").
static func relic_max_level() -> int:
	var best := 0
	for p: StringName in DB.ids("passives"):
		best = maxi(best, int((DB.passives[p] as Dictionary).get("max", 0)))
	return best


func _hero() -> StringName:
	var hero := StringName(String((SaveManager.data.get("selected", {}) as Dictionary).get("hero", "aki")))
	return hero if DB.heroes.has(hero) else &"aki"


## Porcentagem: inteira, ou com uma casa abaixo de 10% quando a conta não fecha (1.2%).
static func pct(value: float) -> String:
	var p := value * 100.0
	if p < 10.0 and not is_equal_approx(p, roundf(p)):
		return "%.1f%%" % p
	return "%d%%" % roundi(p)


static func roman(n: int) -> String:
	const NUMERALS := ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	return NUMERALS[clampi(n, 0, NUMERALS.size() - 1)]


## Número sem casas inúteis (4.5 → "4,5" fica com ponto, como no resto da HUD).
static func _num(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


func _h(text: String) -> Dictionary:
	return {"type": "h", "text": text}


## Parágrafo: o modelo traduzido com os valores (cada %s um trecho destacado).
func _p(template: String, args: Array = []) -> Dictionary:
	var parts := _parts(template, args)
	return {"type": "p", "parts": parts, "text": plain(parts)}


func _rich(lines: Array) -> Dictionary:
	var texts: PackedStringArray = []
	for line: Array in lines:
		texts.append(plain(line))
	return {"type": "rich", "lines": lines, "text": "\n".join(texts)}


func _link(category: StringName, text: String) -> Dictionary:
	return {"type": "link", "category": category, "text": text}


## Trechos de um modelo: o texto entre os %s e cada valor (texto vira {n}, dicionário entra como
## está: {ref}, {chip}).
static func _parts(template: String, args: Array) -> Array:
	var out: Array = []
	var pieces := template.split("%s")
	for i: int in pieces.size():
		if pieces[i] != "":
			out.append({"t": pieces[i]})
		if i < pieces.size() - 1 and i < args.size():
			var arg: Variant = args[i]
			out.append(arg if arg is Dictionary else {"n": str(arg)})
	return out


## Texto puro de uma lista de trechos (testes e acessibilidade).
static func plain(parts: Array) -> String:
	var out := ""
	for part: Dictionary in parts:
		if part.has("t"):
			out += String(part["t"])
		elif part.has("n"):
			out += String(part["n"])
		elif part.has("seal"):
			out += String(part["seal"])
		elif part.has("ref"):
			out += String((part["ref"] as Dictionary)["name"])
	return out
