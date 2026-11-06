class_name GuideBook
extends RefCounted
## Guia do Diário (manual dentro do jogo): monta os capítulos a partir dos dados (data/*.json
## pelo DB), das constantes do código e do save, no idioma atual. Nenhum número é repetido aqui:
## duração da noite (HyakkiGame.RUN_LENGTH), habilidades e energias (data/abilities.json, poder por
## nível de AbilitySystem), cartas por nível e espaços (LevelUpSystem), chances
## e ryō dos baús (ChestSystem), itens do chão (data/items.json), horários dos chefes e dos Kami
## (data/stages.json), os três níveis da fase (Guardião do Limiar, Sombra do Guardião e o último chefe
## no Tokoyo: "midboss", "midboss2", RiftPortal.WARN_LEAD/MIDBOSS_CHESTS, Spawner.FINAL_AFTER/FINAL_WARN),
## Santuário (data/powerups.json,
## MetaProgress.PRICE_STEP), Lua Vermelha (HyakkiGame), clima e terreno (data/weather.json,
## data/surfaces.json, "hazard" das fases, do Kakuriyo e do Tokoyo), modo Brisa (HyakkiGame.BRISA_*,
## DamageControl.BRISA_MULT, LanternSystem.BRISA_DARKNESS), Desafio Diário (MetaProgress.DAILY_MIN_TIME,
## data/achievements.json), Noite Sem Fim (HyakkiGame.ENDLESS_HP_PER_MIN, MetaProgress.ENDLESS_GOLD,
## Spawner.SHINIGAMI_TIME), Altares do Selo e afixos dos Elites (AltarSystem, EliteAffixes) e as
## dicas 心得 (TipDeck).
##
## Descoberta: o que o Diário ainda esconde fica escondido aqui pelas mesmas regras (Discovery):
## receitas com "???" e chip "?", chefes não vencidos, guardiãs e fases bloqueadas sem nome,
## o Kakuriyo de cada fase antes de vencer o Guardião do Limiar dela, o Tokoyo antes de chegar lá
## (Discovery.tokoyo_known), afixos de Elite nunca vistos
## e o Shinigami antes de a Noite Sem Fim chegar à hora dele;
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

const CHAPTERS: Array[StringName] = [&"play", &"abilities", &"levels", &"chests", &"items", &"bosses",
		&"altars", &"stronger", &"stages", &"saving", &"tips"]
const ICONS := {
	&"play": "res://assets/art/ui/icons/items/Boot.png",
	&"abilities": "res://assets/art/ui/icons/spell/MagicWeapon.png",
	&"levels": "res://assets/art/ui/icons/spell/Upgrade.png",
	&"chests": "res://assets/art/ui/icons/items/Money.png",
	&"items": "res://assets/art/ui/icons/job/Dish.png",
	&"bosses": "res://assets/art/ui/icons/spell/Death.png",
	&"altars": "res://assets/art/ui/icons/spell/BookThunder.png",
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
	return [tr("guide.ch.play"), tr("guide.ch.abilities"), tr("guide.ch.levels"), tr("guide.ch.chests"),
			tr("guide.ch.items"), tr("guide.ch.bosses"), tr("guide.ch.altars"), tr("guide.ch.stronger"), tr("guide.ch.stages"),
			tr("guide.ch.saving"),
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
		&"abilities":
			blocks = _abilities()
		&"levels":
			blocks = _levels()
		&"chests":
			blocks = _chests()
		&"items":
			blocks = _items()
		&"bosses":
			blocks = _bosses()
		&"altars":
			blocks = _altars()
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
	var out: Array[Dictionary] = [
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
	]
	var energy: Dictionary = DB.hero_abilities(hero).get("energy", {})
	if not energy.is_empty():
		out.append(_p(tr("guide.play.abilities"), [tr("hero.%s.name" % hero), str(ability_count()),
				tr("energy.%s.name" % energy["id"])]))
	out.append(_h(tr("guide.play.pause_h")))
	out.append(_p(tr("guide.play.pause")))
	out.append_array(_brisa())
	out.append_array(_daily())
	return out


## Modo Brisa (escolhido na Jornada): o que fica mais leve, com os números do jogo
## (DamageControl, HyakkiGame, LanternSystem), e como a vitória nele conta.
func _brisa() -> Array[Dictionary]:
	var stats: Dictionary = HyakkiGame.BRISA_STATS
	return [
		_h(tr("mode.brisa")),
		_p(tr("guide.play.brisa"), [tr("stages.title"), pct(1.0 - DamageControl.BRISA_MULT), str(int(stats["revive"])),
				pct(float(stats["magnet"])), pct(1.0 - LanternSystem.BRISA_DARKNESS), pct(1.0 - HyakkiGame.BRISA_SPAWN),
				pct(1.0 - HyakkiGame.BRISA_BOSS_HP)]),
		_p(tr("guide.play.brisa_win"), [tr("stages.endless")]),
	]


## Desafio Diário (botão do título, App._apply_daily): sorteio pela data, regras fixas e a
## conquista do dia (MetaProgress.DAILY_MIN_TIME, recompensa de data/achievements.json).
func _daily() -> Array[Dictionary]:
	return [
		_h(tr("title.daily")),
		_p(tr("guide.play.daily"), [tr("title.daily")]),
		_p(tr("guide.play.daily_reward"), [Screen.format_time(MetaProgress.DAILY_MIN_TIME),
				tr("achievement.ach_daily.name"), str(daily_ryo())]),
	]


## Ryō da conquista do Desafio Diário ("ryo:N" na recompensa de ach_daily).
static func daily_ryo() -> int:
	var reward := String((DB.achievements.get(&"ach_daily", {}) as Dictionary).get("reward", ""))
	for part: String in reward.split(",", false):
		if part.strip_edges().begins_with("ryo:"):
			return part.strip_edges().trim_prefix("ryo:").to_int()
	return 0


## Habilidades por guardiã (data/abilities.json; a maior lista, hoje 3 para todas).
static func ability_count() -> int:
	var best := 0
	for h: StringName in DB.ids("heroes"):
		best = maxi(best, (DB.hero_abilities(h).get("abilities", []) as Array).size())
	return best


## Habilidades e energias: desbloqueio pelo nível, custo, recarga e poder (AbilitySystem), a
## energia e as 3 habilidades de cada guardiã conhecida (data/abilities.json), a regra da Yuki,
## os controles e o link para os guardiões do Diário. Guardiã bloqueada vira "?" (Discovery).
func _abilities() -> Array[Dictionary]:
	var first := DB.hero_abilities(DB.ids("heroes")[0]).get("abilities", []) as Array
	var levels: Array = []
	for row: Variant in first:
		levels.append(str(int((row as Dictionary).get("level", 1))))
	var out: Array[Dictionary] = [
		_p(tr("guide.abilities.intro"), [str(ability_count())]),
		_h(tr("guide.abilities.unlock_h")),
		_p(tr("guide.abilities.unlock"), levels),
		_h(tr("guide.abilities.energy_h")),
		_p(tr("guide.abilities.energy"), [(tr("stat.cooldown") % "").strip_edges(), tr("heroes.attr_might"),
				pct(AbilitySystem.POWER_PER_LEVEL)]),
		_h(tr("guide.abilities.heroes_h")),
		_p(tr("guide.abilities.heroes")),
	]
	var hidden := false
	var blood: Dictionary = {}
	var blood_hero := &""
	for h: StringName in DB.ids("heroes"):
		var data := DB.hero_abilities(h)
		if data.is_empty():
			continue
		var known := Discovery.hero_known(h)
		hidden = hidden or not known
		out.append(_rich(hero_ability_lines(h, known)))
		var energy: Dictionary = data["energy"]
		if known and float(energy.get("hp_price", 0.0)) > 0.0:
			blood = energy
			blood_hero = h
	if not blood.is_empty():
		out.append(_p(tr("guide.abilities.blood"), [tr("energy.%s.name" % blood["id"]), tr("hero.%s.name" % blood_hero),
				_num(1.0 / float(blood["hp_price"])), pct(float(blood.get("hp_floor", 0.0)))]))
	if hidden:
		out.append(_p(tr("guide.abilities.unknown")))
	out.append(_h(tr("guide.abilities.keys_h")))
	out.append(_p(tr("guide.abilities.keys")))
	out.append(_p(tr("guide.abilities.hint")))
	out.append(_link(&"heroes", tr("guide.link.heroes")))
	return out


## Linhas de uma guardiã no capítulo das habilidades: rosto e nome — glifo e nome da energia, como
## ela enche, e uma linha por habilidade (ícone, selo do kanji, nome, nível, custo e recarga).
## Desconhecida: só o chip "?" com "???".
func hero_ability_lines(h: StringName, known: bool) -> Array:
	var ref := {"category": &"heroes", "id": String(h), "known": known, "face": true,
			"icon": String((DB.heroes[h] as Dictionary)["face"]),
			"name": tr("hero.%s.name" % h) if known else Discovery.UNKNOWN}
	if not known:
		return [[{"ref": ref}]]
	var data := DB.hero_abilities(h)
	var energy: Dictionary = data["energy"]
	var energy_name := tr("energy.%s.name" % energy["id"])
	var head := _parts(tr("guide.abilities.hero_line"), [{"ref": ref}, {"n": energy_name}])
	for i: int in head.size():
		if head[i].has("n"):
			head.insert(i, {"t": " "})
			head.insert(i, {"chip": String(energy.get("icon", "")), "known": true, "kind": "plain"})
			break
	var lines: Array = [head, [{"t": tr("energy.%s.desc" % energy["id"])}]]
	for row: Variant in data.get("abilities", []):
		var a: Dictionary = row
		var line: Array = [{"chip": String(a.get("icon", "")), "known": true, "kind": "skill"}, {"t": " "},
				{"seal": String(a.get("kanji", ""))}, {"t": " "}]
		lines.append(line + _parts(tr("guide.abilities.ability_line"), [tr("ability.%s.name" % a["id"]),
				str(int(a.get("level", 1))), str(roundi(float(a.get("cost", 0)))),
				AbilitySheet.seconds(float(a.get("cooldown", 0)))]))
	return lines


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
		# Rerrolar pago com ryō e a escolha automática da mão de comida/moedas.
		_p(tr("guide.levels.reroll_paid"), [str(LevelUpSystem.REROLL_BASE_COST), str(LevelUpSystem.REROLL_STEP),
				tr("levelup.auto_pick")]),
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
			match String(event["kind"]):
				"midboss":
					line.append({"t": " · " + tr("midboss.title")})
				"shadow":
					line.append({"t": " · " + tr("midboss2.title") + " "})
					line.append({"seal": RiftPortal.REALM_GLYPHS[RiftPortal.DEPTH_KAKURIYO]})
				"final":
					line.append({"t": " · "})
					line.append({"seal": RiftPortal.REALM_GLYPHS[RiftPortal.DEPTH_TOKOYO]})
			lines.append(line)
		out.append(_rich(lines))
	if hidden:
		out.append(_p(tr("guide.bosses.unknown")))
	var mid := _first_midboss_time()
	out.append_array([
		_h(tr("guide.bosses.levels_h")),
		_p(tr("guide.bosses.levels"), [{"seal": RiftPortal.REALM_GLYPHS[RiftPortal.DEPTH_KAKURIYO]},
				{"seal": RiftPortal.REALM_GLYPHS[RiftPortal.DEPTH_TOKOYO]}]),
		_h(tr("midboss.title")),
		_p(tr("guide.bosses.mid"), [Screen.format_time(mid), _num(RiftPortal.WARN_LEAD), str(RiftPortal.MIDBOSS_CHESTS)]),
	])
	out.append_array(_shadow_blocks())
	out.append_array([
		_h(tr("guide.bosses.boss_h")),
		_p(tr("guide.bosses.boss"), [str(BossDirector.BOSS_RYO), str(ChestSystem.BOSS_MIN_ITEMS)]),
		_link(&"bosses", tr("guide.link.bosses")),
	])
	return out


## Chefes de uma fase em ordem de horário: [{t, id, midboss, kind}]. `kind`: "boss" (na hora
## marcada, em qualquer nível), "midboss" (Guardião do Limiar, na fase), "shadow" (Sombra do
## Guardião, no Kakuriyo, a partir de "midboss2.t") e "final" (o último chefe, só no Tokoyo, a
## partir da hora dele). As horas do Kakuriyo e do Tokoyo são as mais cedo: quem atravessa tarde
## vê a Sombra e o último chefe depois (Spawner.shadow_time, Spawner.final_time).
func boss_schedule(s: StringName) -> Array[Dictionary]:
	var stage: Dictionary = DB.stages[s]
	var out: Array[Dictionary] = []
	var list: Array = stage.get("bosses", [])
	for i: int in list.size():
		var b: Dictionary = list[i]
		out.append({"t": float(b["t"]), "id": String(b["id"]), "midboss": false,
				"kind": "final" if i == list.size() - 1 else "boss"})
	var mid := RiftPortal.midboss_of(stage)
	if not mid.is_empty():
		out.append({"t": float(mid["t"]), "id": String(mid["id"]), "midboss": true, "kind": "midboss"})
	var mid2 := RiftPortal.midboss2_of(stage)
	if not mid2.is_empty():
		out.append({"t": float(mid2["t"]), "id": String(mid2["id"]), "midboss": true, "kind": "shadow"})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	return out


## A Sombra do Guardião e a luta final no Tokoyo, com os números da primeira fase que os tem
## ("midboss2" e o último de "bosses") e das constantes do RiftPortal e do Spawner.
func _shadow_blocks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: StringName in stage_order():
		var stage: Dictionary = DB.stages[s]
		var mid2 := RiftPortal.midboss2_of(stage)
		var last := RiftPortal.final_boss_of(stage)
		if mid2.is_empty() or last.is_empty():
			continue
		var shadow: Dictionary = DB.bosses.get(StringName(String(mid2["id"])), {})
		out.append_array([
			_h(tr("midboss2.title")),
			_p(tr("guide.bosses.mid2"), [{"seal": String(shadow.get("seal", "影"))},
					Screen.format_time(float(mid2["t"])), _num(float(mid2.get("after", 0.0))),
					pct(fury_below(StringName(String(mid2["id"])))), str(RiftPortal.MIDBOSS_CHESTS)]),
			_h(tr("guide.bosses.final_h")),
			_p(tr("guide.bosses.final"), [{"seal": RiftPortal.REALM_GLYPHS[RiftPortal.DEPTH_TOKOYO]},
					Screen.format_time(float(last["t"])), _num(Spawner.FINAL_AFTER), _num(Spawner.FINAL_WARN),
					Screen.format_time(HyakkiGame.RUN_LENGTH)]),
		])
		break
	return out


## Fração da vida abaixo da qual o chefe entra na última fase (data/bosses.json "phases"; 0 sem fase).
static func fury_below(b: StringName) -> float:
	var phases: Array = (DB.bosses.get(b, {}) as Dictionary).get("phases", [])
	return float((phases.back() as Dictionary).get("below", 0.0)) if phases.size() > 1 else 0.0


## Chefe como chip de retrato (o ícone do Diário); desconhecido: "?" e "???".
func boss_ref(b: StringName) -> Dictionary:
	var known := Discovery.boss_known(b)
	return {"category": &"bosses", "id": String(b), "known": known, "icon": boss_face(b), "face": true,
			"name": tr("boss.%s.name" % b) if known else Discovery.UNKNOWN}


## Retrato de um chefe (data/bosses.json "faceset", ou o Faceset.png ao lado do sprite).
static func boss_face(b: StringName) -> String:
	var data: Dictionary = DB.bosses.get(b, {})
	var sprite: Dictionary = data.get("sprite", {})
	return String(data.get("faceset", String(sprite.get("path", "")).get_base_dir().path_join("Faceset.png")))


func _first_midboss_time() -> float:
	for s: StringName in stage_order():
		var mid: Dictionary = (DB.stages[s] as Dictionary).get("midboss", {})
		if not mid.is_empty():
			return float(mid["t"])
	return 0.0


## Altares do Selo (AltarSystem) e os afixos dos Elites (EliteAffixes): ritual, resultado,
## emboscada, afixos (um por EliteAffixes.IDS, "?" até ver um Elite com ele) e o saque.
func _altars() -> Array[Dictionary]:
	var lines: Array = []
	var hidden := false
	for id: StringName in EliteAffixes.IDS:
		var known := Discovery.affix_known(id)
		hidden = hidden or not known
		lines.append(affix_line(id, known))
	var rare: Array = []
	for id: StringName in AltarSystem.RARE_ITEMS:
		var item: Dictionary = DB.items.get(id, {})
		rare.append({"chip": String(item.get("icon", "")), "known": true, "kind": "plain"})
		rare.append({"t": " " + tr("item.%s.name" % id) + "  "})
	var out: Array[Dictionary] = [
		_p(tr("guide.altars.intro")),
		_h(tr("guide.altars.ritual_h")),
		_p(tr("guide.altars.ritual"), [_num(AltarSystem.CHANNEL_TIME), str(AltarSystem.RUNES), pct(AltarSystem.DECAY)]),
		_p(tr("guide.altars.blocked"), [tr("midboss.title")]),
		_h(tr("guide.altars.outcome_h")),
		_p(tr("guide.altars.outcome"), [pct(AltarSystem.ELITE_BASE), pct(AltarSystem.ELITE_PITY),
				Screen.format_time(AltarSystem.FIRST_ELITE_T)]),
		_p(tr("guide.altars.ambush"), [str(AltarSystem.ambush_count(0.0)), str(AltarSystem.AMBUSH_CAP),
				tr("item.ryo_bag.name")]),
		_h(tr("guide.altars.elite_h")),
		_p(tr("guide.altars.elite"), [Screen.format_time(EliteAffixes.TWO_AFFIX_T), roman(EliteAffixes.HIGH_MOON),
				str(EliteAffixes.MAX_AFFIXES), pct(EliteAffixes.HP_PER_AFFIX)]),
		_rich(lines),
	]
	if hidden:
		out.append(_p(tr("guide.altars.unknown")))
	out.append_array([
		_h(tr("guide.altars.loot_h")),
		_p(tr("guide.altars.loot"), [str(AltarSystem.BOSS_CHEST_AFFIXES), pct(AltarSystem.CHEST_CHANCE),
				tr("item.ryo_bag.name")]),
		_rich([rare]),
		_p(tr("guide.altars.no_chest")),
	])
	return out


## Linha de um afixo: selo do kanji e o poder com os números de EliteAffixes; desconhecido:
## selo "?" e "???".
func affix_line(id: StringName, known: bool) -> Array:
	if not known:
		return [{"seal": "?"}, {"t": " " + Discovery.UNKNOWN}]
	var row := affix_text(id)
	return [{"seal": EliteAffixes.kanji_of(id)}, {"t": " "}] + _parts(String(row[0]), row[1])


## [modelo traduzido, valores] do poder de um afixo (chaves literais para o i18n_keys).
func affix_text(id: StringName) -> Array:
	match id:
		&"raijin":
			return [tr("guide.altars.raijin"), [_num(EliteAffixes.RAIJIN_EVERY), str(EliteAffixes.RAIJIN_MARKS)]]
		&"kitsunebi":
			return [tr("guide.altars.kitsunebi"), [_num(EliteAffixes.FOX_EVERY), str(EliteAffixes.FOX_COUNT)]]
		&"kagero":
			return [tr("guide.altars.kagero"), [_num(EliteAffixes.KAGERO_EVERY)]]
		&"iwa":
			return [tr("guide.altars.iwa"), [_num(EliteAffixes.IWA_EVERY)]]
		&"kasumi":
			return [tr("guide.altars.kasumi"), [_num(EliteAffixes.KASUMI_EVERY), str(EliteAffixes.KASUMI_COUNT),
					str(EliteAffixes.KASUMI_CAP)]]
		&"kongo":
			return [tr("guide.altars.kongo"), [pct(EliteAffixes.SHIELD_FRACTION), _num(EliteAffixes.KONGO_REGEN)]]
		&"yomi":
			return [tr("guide.altars.yomi"), []]
		&"kaze":
			return [tr("guide.altars.kaze"), [_num(EliteAffixes.KAZE_EVERY)]]
	return [String(id), []]


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
	for line: String in RedMoon.rules_text(HyakkiGame.MAX_MOON):
		moons.append([{"t": "· " + line}])
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
		_p(tr("guide.stronger.moon_rules"), [roman(HyakkiGame.MAX_MOON), _num(RedMoon.ECLIPSE_DELAY),
				str(RedMoon.ECLIPSE_RING_COUNT)]),
		_h(tr("stages.endless")),
		_p(tr("guide.stronger.endless"), [tr("stages.endless"), tr("stages.title"), pct(HyakkiGame.ENDLESS_HP_PER_MIN),
				_num(MetaProgress.ENDLESS_GOLD)]),
		_rich([reaper_line()]),
		_p(tr("guide.stronger.reaper") if Discovery.reaper_known() else tr("guide.stronger.reaper_unknown"),
				[Screen.format_time(Spawner.SHINIGAMI_TIME)]),
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


## Shinigami da Noite Sem Fim (fora das escalas das fases e do Diário): hora, retrato e nome,
## ou silhueta e "???" até a Noite Sem Fim chegar à hora dele.
func reaper_line() -> Array:
	var known := Discovery.reaper_known()
	return [{"n": Screen.format_time(Spawner.SHINIGAMI_TIME)}, {"t": " "},
			{"chip": boss_face(&"shinigami"), "known": known, "kind": "face"},
			{"t": " " + (tr("boss.shinigami.name") if known else Discovery.UNKNOWN)}]


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


## Clima, perigo e terrenos lentos de uma fase (cada um uma linha de trechos) e, depois, os do
## Kakuriyo dela ("otherworld": clima de outra fase e perigo próprio, e a Sombra do Guardião que
## guarda o torii dourado), escondido até vencer o Guardião do Limiar da fase, e os do Tokoyo
## ("tokoyo": clima, perigo e quem reina lá), escondido até chegar lá (Discovery.tokoyo_known).
func stage_lines(s: StringName) -> Array:
	var stage: Dictionary = DB.stages[s]
	var lines := world_lines(String(s), stage.get("hazard", {}))
	var ow: Dictionary = stage.get("otherworld", {})
	var mid := RiftPortal.midboss_of(stage)
	if ow.is_empty() or mid.is_empty():
		return lines
	if not Discovery.realm_known(s):
		lines.append(_parts(tr("guide.stages.realm"), [Discovery.UNKNOWN]))
	else:
		lines.append(_parts(tr("guide.stages.realm"), [tr("realm.%s.name" % s)]))
		for line: Array in world_lines(String(ow.get("weather", s)), ow.get("hazard", {})):
			lines.append([{"t": "· "}] + line)
		var mid2 := RiftPortal.midboss2_of(stage)
		if not mid2.is_empty():
			lines.append([{"t": "· "}] + _parts(tr("guide.stages.shadow_line"),
					[{"ref": boss_ref(StringName(String(mid2["id"])))}]))
	lines.append_array(tokoyo_lines(s))
	return lines


## O Tokoyo da fase (bloco "tokoyo", só com a Sombra do Guardião que abre o caminho): o nome, o
## clima e o perigo dele e o último chefe da fase, que reina lá; "???" até chegar lá.
func tokoyo_lines(s: StringName) -> Array:
	var stage: Dictionary = DB.stages[s]
	var toko: Dictionary = stage.get("tokoyo", {})
	if toko.is_empty() or RiftPortal.midboss2_of(stage).is_empty():
		return []
	if not Discovery.tokoyo_known(s):
		return [_parts(tr("guide.stages.tokoyo"), [Discovery.UNKNOWN])]
	var lines: Array = [_parts(tr("guide.stages.tokoyo"), [tr("realm3.%s.name" % s)])]
	for line: Array in world_lines(String(toko.get("weather", s)), toko.get("hazard", {})):
		lines.append([{"t": "· "}] + line)
	var last := RiftPortal.final_boss_of(stage)
	if not last.is_empty():
		lines.append([{"t": "· "}] + _parts(tr("guide.stages.tokoyo_lord"),
				[{"ref": boss_ref(StringName(String(last["id"])))}]))
	return lines


## Clima do perfil `weather_id` (data/weather.json), o perigo e os terrenos lentos do perfil.
func world_lines(weather_id: String, hazard: Dictionary) -> Array:
	var lines: Array = []
	var weather: Dictionary = WeatherModel.profile_for(weather_id)
	var precip := String(weather.get("precip", ""))
	if precip != "":
		var sky := weather_name(precip)
		if bool(weather.get("lightning", false)):
			sky = tr("guide.weather.thunder") % sky
		lines.append(_parts(tr("guide.stages.weather_line"), [sky]))
	var text := hazard_text(hazard)
	if text != "":
		lines.append([{"t": text}])
	var surfaces := SurfaceField.data()
	var types: Dictionary = surfaces.get("types", {})
	var seen: Array[String] = []
	for spot: Dictionary in (surfaces.get("stages", {}) as Dictionary).get(weather_id, []):
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
