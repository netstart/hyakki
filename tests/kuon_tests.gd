extends RefCounted
## Kuon (久遠), a 8ª guardiã: servos espectrais (scripts/systems/minion_system.gd), as armas e relíquias
## exclusivas dela, o golpe da lanterna Necro Rite e o progresso.
##   run_unit (tests/run_tests.gd, sem autoloads): dados de data/*.json (7 armas e 2 relíquias com
##     "hero": "kuon", receitas, comportamentos e sons), MetaProgress.fits_hero, atributos novos e as
##     dicas geradas das exclusivas só com a Kuon escolhida;
##   run (tests/integration_tests.gd): fora do perfil padrão; exclusividade (500 sorteios de nível e
##     500 baús por guardiã, também no bot, sem nenhuma exclusiva; a Kuon recebe as dela); listas de
##     exibição (evolui/une, roleta do baú, Diário, Guia); MinionSystem (teto, atributos, perseguir e
##     golpear, tempo de vida e caídos, abate que levanta, Hyakki-shō transformando os servos, save,
##     hash, troca de reino, Necro Rite); cada arma (dano, lentidão, atordoar, parar em sólidos,
##     servos da união) e a condição "minions_raised"; o bot com a Kuon no mesmo estado em 1x, 2x e 3x.

const AbilityTests := preload("res://tests/ability_tests.gd")
const SolidShotTests := preload("res://tests/solid_shot_tests.gd")
const DT := 1.0 / 60.0
const HERO := &"kuon"
const WEAPONS: Array[String] = ["shiryo_fuda", "hone_kaze", "sanzu_nagare", "hyakki_sho", "gasha_kaina",
		"watashimori", "yomi_no_gunzei"]
const RELICS: Array[String] = ["itako_suzu", "senko"]
## Sorteios por guardiã nos testes de exclusividade.
const DRAWS := 500
## Baús seguidos antes de recomeçar o arsenal (para a mão não virar só comida e ryō).
const CHESTS_PER_LOADOUT := 20
## Passos da partida do bot nas três velocidades.
const BOT_STEPS := 900

var _check: Callable
var _t: AbilityTests


# --- Unitários ----------------------------------------------------------------------------------

func run_unit(check: Callable) -> void:
	_check = check
	var weapons := _json("res://data/weapons.json")
	var passives := _json("res://data/passives.json")
	var by_id := {}
	for w: Variant in weapons:
		by_id[String(w["id"])] = w
	var mine: Array[String] = []
	for w: Variant in weapons:
		if String((w as Dictionary).get("hero", "")) == String(HERO):
			mine.append(String(w["id"]))
	_check.call(mine == WEAPONS, "Kuon: 7 armas exclusivas na ordem (%s)", [mine])
	var relics: Array[String] = []
	for p: Variant in passives:
		if String((p as Dictionary).get("hero", "")) == String(HERO):
			relics.append(String(p["id"]))
	_check.call(relics == RELICS, "Kuon: 2 relíquias exclusivas (%s)", [relics])
	var recipes := {"shiryo_fuda": ["itako_suzu", "hyakki_sho"], "hone_kaze": ["senko", "gasha_kaina"],
			"sanzu_nagare": ["itako_suzu", "watashimori"]}
	for base: String in recipes:
		var w: Dictionary = by_id[base]
		_check.call(String(w["evolves_with"]) == recipes[base][0] and String(w["evolution"]) == recipes[base][1]
				and String((by_id[recipes[base][1]] as Dictionary)["from"]) == base,
				"%s + %s = %s", [base, recipes[base][0], recipes[base][1]])
	_check.call((by_id["yomi_no_gunzei"] as Dictionary)["requires"] == ["hyakki_sho", "gasha_kaina"],
			"Yomi no Gunzei = Hyakki-shō + Gasha-kaina")
	for id: String in WEAPONS:
		var w: Dictionary = by_id[id]
		var behavior := String(w["behavior"])
		_check.call(HyakkiGame.WEAPON_BEHAVIORS.has(behavior) and FileAccess.file_exists(
				"res://scripts/weapons/%s.gd" % behavior), "%s: comportamento %s registrado", [id, behavior])
		_check.call(WeaponSfx.CUES.has(String(w["sfx"]["launch"])), "%s: cue de lançamento", id)
		_check.call(HitSounds.MIX.has(HitSounds.for_weapon(w)), "%s: som de acerto %s", [id, HitSounds.for_weapon(w)])
		var dmg := float(w["base"]["damage"])
		var kind := String(w["kind"])
		var band: Array = {"base": [5.0, 12.0], "evolution": [18.0, 50.0], "union": [28.0, 50.0]}[kind]
		_check.call(dmg >= float(band[0]) and dmg <= float(band[1]),
				"%s: dano %.0f na faixa das armas %s (%s)", [id, dmg, kind, band])
	_check.call(int(by_id["shiryo_fuda"]["base"]["minion_cap"]) < MinionSystem.HARD_CAP
			and float(by_id["hyakki_sho"]["base"]["raise_chance"]) == 1.0, "teto da Shiryō-fuda e o Hyakki-shō sempre levanta")
	var kuon := {"hero": "kuon"}
	_check.call(MetaProgress.fits_hero({}, &"aki") and MetaProgress.fits_hero(kuon, HERO)
			and not MetaProgress.fits_hero(kuon, &"aki") and not MetaProgress.fits_hero(kuon, &""),
			"fits_hero: comuns para todas, exclusivas só para a dona")
	_check.call(MetaProgress.exclusive_hero(kuon) == HERO and MetaProgress.exclusive_hero({}) == &"", "exclusive_hero")
	_check.call(StatBlock.DEFS["minions"] == [0.0, "flat"] and StatBlock.DEFS["minion_power"] == [1.0, "pct"],
			"atributos minions (soma) e minion_power (%)")
	var stats := StatBlock.new()
	stats.set_source("relic", {"minions": 2.0, "minion_power": 0.3})
	_check.call(is_equal_approx(stats.get_stat("minions"), 2.0) and is_equal_approx(stats.get_stat("minion_power"), 1.3),
			"Sino da Itako e Incenso somam no StatBlock")
	for cue: String in ["minion_raise", "minion_fade", "minion_hit", "soul_pickup", "bone_crack", "ab_tamashii_gari",
			"ab_tamashii_gari_hit", "ab_kotsu_heki", "ab_kotsu_heki_hit", "ab_yomigaeri", "ult_necro_rite"]:
		_check.call(WeaponSfx.CUES.has(cue), "cue %s", cue)
	_check.call(UltimateSystem.ULT_COLORS.has("necro_rite"), "Necro Rite tem cor própria")
	var tips := TipBook.generated(weapons, passives, [])
	var aki_ctx := TipBook.default_context()
	var kuon_ctx := TipBook.default_context()
	kuon_ctx["hero"] = "kuon"
	kuon_ctx["available"] = {"weapons": ["shiryo_fuda", "hone_kaze", "sanzu_nagare"], "passives": ["itako_suzu", "senko"]}
	aki_ctx["available"] = kuon_ctx["available"]
	var seen := 0
	for tip: Dictionary in tips:
		var id := String(tip["id"])
		if id in ["evo.shiryo_fuda", "evo.hone_kaze", "evo.sanzu_nagare", "shared.itako_suzu"]:
			seen += 1
			_check.call(String((tip["when"] as Dictionary).get("hero", "")) == "kuon"
					and TipBook.eligible(tip, kuon_ctx) and not TipBook.eligible(tip, aki_ctx),
					"dica %s só com a Kuon escolhida", id)
	_check.call(seen == 4, "dicas geradas das exclusivas (%d)", seen)


static func _json(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Array else []


# --- Integração ---------------------------------------------------------------------------------

func run(host: Node, check: Callable) -> void:
	_check = check
	_t = AbilityTests.new()
	_t._check = check
	_check_profile()
	await _check_exclusive(host)
	_check_display()
	var game := await _new_kuon(host)
	_check_minions(game)
	_check_kill_raise(game)
	_check_weapons(game)
	_check_rite(game)
	await _check_save(host, game)
	_check_realm(game)
	game.queue_free()
	await host.get_tree().process_frame
	_check_progress()
	await _check_bot_speeds(host)
	GameClock.paused = true


func _new_kuon(host: Node, bot: bool = false) -> HyakkiGame:
	var game := await _t._new_game(host, String(HERO), 23, bot)
	GameClock.paused = false
	return game


## Partida montada: sem inimigos, sem servos, só a arma `ids` (a primeira é a de base).
func _fresh(game: HyakkiGame, ids: Array = ["shiryo_fuda"]) -> void:
	_t._clear(game)
	game.minions.reset()
	game.projectiles.reset()
	for weapon: Weapon in game.weapons:
		weapon.on_removed()
	game.weapons.clear()
	for id: Variant in ids:
		game.add_weapon(StringName(String(id)))
	game.player.stats.set_source("test", {})


func _tick(game: HyakkiGame, steps: int) -> void:
	for _k: int in range(steps):
		GameClock.game_time += DT
		game.step_index += 1
		game.player.step(DT)
		game.enemies.step(DT)
		for weapon: Weapon in game.weapons.duplicate():
			weapon.step(DT)
		game.minions.step(DT)
		game.projectiles.step(DT)
		game.enemy_shots.step(DT)
		game.abilities.step(DT)


## Alvo parado e duro (não morre) em `at`; `hp_mult` pequeno faz um alvo que cai no primeiro golpe.
func _dummy(game: HyakkiGame, at: Vector2, hp_mult: float = AbilityTests.HP_MULT) -> int:
	var i := game.enemies.spawn(&"slime_rice", at, hp_mult, 1.0)
	game.enemies.speed[i] = 0.0
	game.enemies.controlled[i] = 1
	game.enemies.resist[i] = 1.0
	_t._reindex(game)
	return i


func _lost(game: HyakkiGame, i: int) -> float:
	return game.enemies.max_hp[i] - game.enemies.hp[i]


# --- Perfil e exclusividade ----------------------------------------------------------------

func _check_profile() -> void:
	var heroes: Array = SaveManager.default_profile()["unlocked"]["heroes"]
	_check.call(not heroes.has(String(HERO)) and heroes.size() == DB.ids("heroes").size() - 1,
			"Kuon fora do perfil padrão (só pela conquista)")
	_check.call(String(DB.heroes[HERO]["unlock"]) == "ach_boss_gashadokuro" and DB.ids("heroes").has(HERO),
			"Kuon liberada pela vitória sobre a Gashadokuro (e o unlock_all_heroes do debug a inclui)")
	_check.call(DB.ids("heroes").size() == 8, "win_all_heroes conta as 8 guardiãs (a Kuon é liberável jogando)")


## 500 mãos de nível e 500 baús para cada outra guardiã (e no bot): nenhuma exclusiva da Kuon.
func _check_exclusive(host: Node) -> void:
	var exclusive := {}
	for id: String in WEAPONS + RELICS:
		exclusive[StringName(id)] = true
	for hero: StringName in DB.ids("heroes"):
		var game := await _t._new_game(host, String(hero), 5)
		var found := {"level": 0, "bot": 0, "chest": 0}
		var own := 0
		for bot: bool in [false, true]:
			game._bot = bot
			for _k: int in range(DRAWS):
				for card: Dictionary in game.level_up.build_choices(game.rng):
					if exclusive.has(StringName(card.get("id", &""))):
						found["bot" if bot else "level"] += 1
		game._bot = false
		for k: int in range(DRAWS):
			if k % CHESTS_PER_LOADOUT == 0:
				_reset_loadout(game)
			for reward: Dictionary in game.chests.open(false):
				if exclusive.has(StringName(reward.get("id", &""))):
					found["chest"] += 1
			for weapon: Weapon in game.weapons:
				if exclusive.has(weapon.id):
					own += 1
		if hero == HERO:
			_check.call(found["level"] > 0 and found["bot"] > 0 and found["chest"] > 0,
					"Kuon recebe as exclusivas dela no nível, no bot e no baú (%s)", [found])
		else:
			_check.call(found["level"] == 0 and found["bot"] == 0 and found["chest"] == 0 and own == 0,
					"%s: nenhuma exclusiva da Kuon em %d sorteios de nível, %d no bot e %d baús (%s)",
					[hero, DRAWS, DRAWS, DRAWS, found])
			for id: StringName in exclusive:
				var available := game.is_weapon_available(id) if DB.weapons.has(id) else game.is_passive_available(id)
				_check.call(not available, "%s: %s indisponível", [hero, id])
		game.queue_free()
		await host.get_tree().process_frame


func _reset_loadout(game: HyakkiGame) -> void:
	for weapon: Weapon in game.weapons:
		weapon.on_removed()
	game.weapons.clear()
	game.add_weapon(StringName(String(game.player.hero.get("weapon", "katana"))))
	game.level_up.reset()


## Listas de exibição: evolui/une, a roleta do baú, o Diário e o Guia.
func _check_display() -> void:
	_check.call(LevelUpPanel.weapons_evolved_by(&"itako_suzu", &"aki").is_empty()
			and LevelUpPanel.weapons_evolved_by(&"itako_suzu", HERO) == [&"shiryo_fuda", &"sanzu_nagare"],
			"Sino da Itako: evolui só armas da Kuon e só para ela")
	_check.call(LevelUpPanel.union_partners(&"hyakki_sho", &"aki").is_empty()
			and LevelUpPanel.union_partners(&"hyakki_sho", HERO).size() == 1, "união da Kuon só para ela")
	for hero: StringName in DB.ids("heroes"):
		for p: StringName in DB.ids("passives"):
			if hero != HERO:
				_check.call(not LevelUpPanel.weapons_evolved_by(p, hero).any(func(w: StringName) -> bool:
					return WEAPONS.has(String(w))), "%s: %s não lista armas da Kuon", [hero, p])
	var panel := ChestPanel.new()
	panel.hero = &"aki"
	var aki_pool := panel.reel_pool().duplicate()
	panel.hero = HERO
	var kuon_pool := panel.reel_pool().duplicate()
	panel.free()
	var fuda := load("res://assets/art/ui/skill_icons/weapons/shiryo_fuda.png") as Texture2D
	_check.call(not aki_pool.has(fuda) and kuon_pool.has(fuda) and kuon_pool.size() > aki_pool.size(),
			"roleta do baú: ícones da Kuon só na partida dela")
	var unlocked: Array = SaveManager.data["unlocked"]["heroes"]
	var had := unlocked.has(String(HERO))
	unlocked.erase(String(HERO))
	_check.call(not Discovery.weapon_known(&"hone_kaze") and not Discovery.passive_known(&"senko")
			and Discovery.exclusive_note(DB.weapon(&"hone_kaze")).is_empty(),
			"Diário/Guia: exclusivas da Kuon escondidas com ela bloqueada")
	var guide := GuideBook.new()
	var hidden_count: Array[int] = guide._count_available("weapons")
	var mission := &"m_evo_watashimori"
	_check.call(not MissionBook.has(mission) or not MissionBook.is_available(mission),
			"Missões: a evolução da Kuon fica fora com ela bloqueada")
	_check.call(Discovery.unlock_achievement(DB.passives[&"senko"]) == "ach_boss_gashadokuro",
			"relíquia escondida diz como liberar a Kuon")
	unlocked.append(String(HERO))
	_check.call(Discovery.weapon_known(&"hone_kaze") and Discovery.passive_known(&"senko")
			and not Discovery.exclusive_note(DB.weapon(&"hone_kaze")).is_empty()
			and Discovery.exclusive_note(DB.weapon(&"katana")).is_empty(),
			"Diário/Guia: com a Kuon liberada, as exclusivas aparecem com a marca")
	var shown_count: Array[int] = guide._count_available("weapons")
	_check.call(not MissionBook.has(mission) or MissionBook._weapon_ready(&"watashimori"),
			"Missões: com a Kuon liberada, a evolução dela entra")
	_check.call(shown_count[1] == hidden_count[1] + 3, "Guia: as 3 armas base da Kuon entram na conta só com ela")
	var note := Discovery.exclusive_note(DB.weapon(&"hone_kaze"))
	var marked := 0
	for block: Dictionary in guide.chapter(&"chests")["blocks"]:
		for line: Variant in block.get("lines", []):
			for part: Variant in line:
				marked += int(part is Dictionary and String((part as Dictionary).get("t", "")).contains(note))
	_check.call(marked == 4, "Guia: 3 evoluções e a união da Kuon marcadas como exclusivas (%d)", marked)
	if not had:
		unlocked.erase(String(HERO))


# --- MinionSystem ----------------------------------------------------------------------------

func _check_minions(game: HyakkiGame) -> void:
	_fresh(game)
	var minions := game.minions
	_check.call(minions.count() == 0 and minions.hash_tag().is_empty(), "sem servos: fora do hash")
	_check.call(minions.cap() == 6, "teto: o minion_cap da Shiryō-fuda (6), veio %d", minions.cap())
	game.player.stats.set_source("test", {"minions": 2.0})
	_check.call(minions.cap() == 8, "teto: +2 do atributo minions (8)")
	var made := 0
	var tracked := game.tracker.minions_raised
	for k: int in range(12):
		made += int(minions.raise(Vector2(k, 0), &"shiryo_fuda", 5.0, 8.0))
	_check.call(made == 8 and minions.count() == 8 and minions.raised_total == 8
			and game.tracker.minions_raised == tracked + 8, "teto respeitado ao levantar (8 de 12)")
	_check.call(minions.raise(Vector2.ZERO, &"yomigaeri", 5.0, 8.0, MinionSystem.Kind.SPIRIT, 0.0, true)
			and minions.count() == 9, "Yomigaeri passa do teto")
	_check.call(not minions.hash_tag().is_empty(), "com servos: no hash")
	# Persegue e golpeia: um servo, um alvo a 60 px.
	_fresh(game)
	var target := _dummy(game, Vector2(60, 0))
	minions.raise(Vector2.ZERO, &"shiryo_fuda", 5.0, 30.0)
	_tick(game, 150)
	_check.call(minions.m_pos[0].distance_to(game.enemies.pos[target]) < 20.0, "servo corre até o yōkai")
	_check.call(_lost(game, target) > 0.0 and float(game.tracker.damage_by_weapon.get(&"shiryo_fuda", 0.0)) > 0.0,
			"servo golpeia e o dano conta para a arma que o levantou")
	# minion_power: dano do golpe × 2.
	var hits: Array[float] = []
	for pw: float in [1.0, 2.0]:
		_fresh(game)
		game.player.stats.set_source("test", {"minion_power": pw - 1.0})
		var e := _dummy(game, Vector2(4, 0))
		minions.raise(Vector2.ZERO, &"shiryo_fuda", 5.0, 30.0)
		minions.m_atk[0] = 0.0
		var before := game.enemies.hp[e]
		game.player.stats.set_source("crit_off", {"crit": -1.0})
		_tick(game, 1)
		hits.append(before - game.enemies.hp[e])
	game.player.stats.set_source("crit_off", {})
	_check.call(hits[0] > 0.0 and is_equal_approx(hits[1], hits[0] * 2.0),
			"minion_power dobra o dano do golpe (%.2f → %.2f)", [hits[0], hits[1]])
	# Tempo de vida: some e vira caído.
	_fresh(game)
	minions.raise(Vector2.ZERO, &"shiryo_fuda", 5.0, 0.4)
	_tick(game, 60)
	_check.call(minions.count() == 0 and minions.fallen == 1, "fim da vida: o servo some e conta como caído")
	_check.call(minions.recall(Vector2.ZERO, &"yomigaeri", 12, 3, 10.0) == 3 and minions.fallen == 0,
			"Yomigaeri chama de volta (no mínimo 3)")
	_check.call(minions.refresh(Vector2.ZERO, 100.0, 50.0) == 3 and minions.m_life[0] == 50.0,
			"Barqueiro: servos perto renovam a vida")


## Abate da ofuda levanta servo (Hyakki-shō: sempre) e a evolução transforma os de pé em samurais.
func _check_kill_raise(game: HyakkiGame) -> void:
	_fresh(game)
	var minions := game.minions
	minions.raise(Vector2(-30, 0), &"shiryo_fuda", 5.0, 30.0)
	var fuda := game.get_weapon(&"shiryo_fuda")
	while fuda.level < fuda.max_level:
		fuda.level_up()
	game.evolve_weapon(&"shiryo_fuda")
	_check.call(game.has_weapon(&"hyakki_sho") and minions.m_kind[0] == MinionSystem.Kind.SAMURAI
			and minions.m_src[0] == &"hyakki_sho", "Hyakki-shō: os servos viram samurais dele")
	var raised := minions.raised_total
	var weak := _dummy(game, Vector2(50, 0), 0.0001)
	game.get_weapon(&"hyakki_sho").fire(game.player.sim_pos)
	for _k: int in range(90):
		_tick(game, 1)
		if game.enemies.alive[weak] == 0:
			break
	_check.call(game.enemies.alive[weak] == 0 and minions.raised_total > raised
			and minions.m_kind[minions.count() - 1] == MinionSystem.Kind.SAMURAI,
			"abate do Hyakki-shō levanta um samurai espectral")


# --- Armas ------------------------------------------------------------------------------------

func _check_weapons(game: HyakkiGame) -> void:
	# Hone-kaze: ossos em órbita ferem quem está no raio.
	_fresh(game, ["hone_kaze"])
	var bone := game.get_weapon(&"hone_kaze") as HoneKaze
	var e := _dummy(game, Vector2(bone.orbit_radius(), 0))
	_tick(game, 120)
	_check.call(_lost(game, e) > 0.0, "Hone-kaze: os ossos ferem na órbita")
	# Sanzu-nagare: a onda fere uma vez, deixa lento e quebra no sólido.
	_fresh(game, ["sanzu_nagare"])
	var wave := game.get_weapon(&"sanzu_nagare") as SanzuNagare
	e = _dummy(game, Vector2(80, 0))
	wave.fire(game.player.sim_pos)
	_tick(game, 130)
	var once := _lost(game, e)
	_check.call(once > 0.0 and game.enemies.slow[e] > 0.0 and wave.waves() == 0,
			"Sanzu-nagare: fere, deixa lento e acaba no fim do percurso")
	_check.call(once >= wave.damage() * 0.99 and once <= wave.damage() * 4.01,
			"Sanzu-nagare: um golpe por onda (%.1f; a recarga solta outras)", once)
	var saved_world := _swap_world(game, [[Vector2(40, 0), 8.0]])
	_fresh(game, ["sanzu_nagare", "shiryo_fuda"])
	e = _dummy(game, Vector2(90, 0))
	(game.get_weapon(&"sanzu_nagare") as SanzuNagare).fire(game.player.sim_pos)
	game.get_weapon(&"shiryo_fuda").fire(game.player.sim_pos)
	_tick(game, 120)
	_check.call(_lost(game, e) == 0.0, "onda e ofuda param na casa: o yōkai atrás dela não leva dano")
	_restore_world(game, saved_world)
	# Gasha-kaina: o braço varre, fere e atordoa.
	_fresh(game, ["gasha_kaina"])
	var arm := game.get_weapon(&"gasha_kaina") as GashaKaina
	e = _dummy(game, Vector2(60, 0))
	arm.fire(game.player.sim_pos)
	var stunned := false
	for _k: int in range(60):
		_tick(game, 1)
		stunned = stunned or game.enemies.stun[e] > 0.0
	_check.call(_lost(game, e) >= arm.damage() * 0.99 and stunned, "Gasha-kaina: a varrida fere e atordoa")
	# Watashimori: a balsa passa, fere aos poucos, deixa lento e renova os servos perto dela.
	_fresh(game, ["watashimori"])
	var ferry := game.get_weapon(&"watashimori") as Watashimori
	e = _dummy(game, Vector2(20, 0))
	game.minions.raise(Vector2(10, 0), &"shiryo_fuda", 5.0, 3.0)
	game.minions.m_life[0] = 1.0
	ferry.fire(game.player.sim_pos)
	# A balsa já no meio da travessia (passando pela guardiã).
	ferry._boats[0]["t"] = ferry.duration() * 0.5
	_tick(game, 30)
	_check.call(_lost(game, e) > 0.0 and game.enemies.slow[e] > 0.0, "Watashimori: fere e deixa lento")
	_check.call(game.minions.count() == 1 and game.minions.m_life[0] > 1.0, "Watashimori: o barqueiro renova o servo")
	# Yomi no Gunzei: samurais se levantam sozinhos e o anel em marcha fere.
	_fresh(game, ["yomi_no_gunzei"])
	var army := game.get_weapon(&"yomi_no_gunzei") as YomiNoGunzei
	e = _dummy(game, Vector2(80, 0))
	_tick(game, 150)
	_check.call(game.minions.count() > 0 and game.minions.m_kind[0] == MinionSystem.Kind.SAMURAI,
			"Yomi no Gunzei: o exército se levanta (%d samurais)", game.minions.count())
	_check.call(_lost(game, e) > 0.0, "Yomi no Gunzei: a marcha fere")
	_check.call(army.march_every() > 0.0, "Yomi no Gunzei: marcha a cada %s s", army.march_every())


func _swap_world(game: HyakkiGame, solids: Array) -> Dictionary:
	var saved := {"chunks": game.world._chunks.duplicate(), "cells": game.world._solid_cells.duplicate(),
			"ready": game.world._solid_ready.duplicate()}
	SolidShotTests.world_with(game.world, solids)
	return saved


func _restore_world(game: HyakkiGame, saved: Dictionary) -> void:
	game.world._chunks = saved["chunks"]
	game.world._solid_cells = saved["cells"]
	game.world._solid_ready = saved["ready"]


# --- Necro Rite -------------------------------------------------------------------------------

func _check_rite(game: HyakkiGame) -> void:
	_fresh(game)
	var weak: Array[int] = []
	# Espalhados pela tela visível (a procissão vai de uma borda à outra).
	var view := game.view_size() * 0.5 - Vector2(12, 12)
	for k: int in range(5):
		weak.append(_dummy(game, Vector2(-view.x + k * view.x * 0.5, -view.y + k * view.y * 0.5), 0.0001))
	var tough := _dummy(game, Vector2(40, 0))
	game.ultimate.charge = UltimateSystem.FULL
	_check.call(game.ultimate.activate() and game.minions.rite_active(), "Necro Rite: a procissão começa")
	var hp := game.enemies.hp[tough]
	var steps := 0
	while game.minions.rite_active() and steps < 600:
		_tick(game, 1)
		steps += 1
	var dead := 0
	for i: int in weak:
		dead += int(game.enemies.alive[i] == 0)
	_check.call(not game.minions.rite_active() and steps <= roundi(5.0 / DT) + 1, "Necro Rite: acaba dentro da duração")
	_check.call(dead == 5 and game.enemies.hp[tough] < hp, "Necro Rite: a procissão atravessa a tela e fere todos")
	_check.call(is_equal_approx(hp - game.enemies.hp[tough], 30.0 * game.player.stats.get_stat("might"))
			or hp - game.enemies.hp[tough] >= 30.0, "Necro Rite: cada yōkai leva o golpe uma vez")
	_check.call(game.minions.count() == mini(5, game.minions.cap()), "Necro Rite: os mortos viram servos (%d)",
			game.minions.count())


# --- Save, hash e reino -----------------------------------------------------------------------

func _check_save(host: Node, game: HyakkiGame) -> void:
	_fresh(game)
	for k: int in range(4):
		game.minions.raise(Vector2(k * 7, 3), &"shiryo_fuda", 5.0, 9.0, k % 2)
	game.minions.fallen = 2
	game.ultimate.charge = UltimateSystem.FULL
	game.ultimate.activate()
	_tick(game, 20)
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	var before := JSON.stringify(game.minions.state())
	var tag := game.minions.hash_tag()
	var second := await _t._new_game(host, String(HERO), 23)
	second.restore_snapshot(snap)
	_check.call(JSON.stringify(second.minions.state()) == before, "partida suspensa: servos e procissão voltam iguais")
	_check.call(second.minions.hash_tag() == tag and not tag.is_empty(), "partida suspensa: mesmo hash dos servos")
	_check.call(second.tracker.minions_raised == game.tracker.minions_raised, "partida suspensa: servos levantados")
	second.queue_free()
	await host.get_tree().process_frame
	GameClock.paused = false


func _check_realm(game: HyakkiGame) -> void:
	game.minions.raise(Vector2.ZERO, &"shiryo_fuda", 5.0, 9.0)
	game.rift.clear_field()
	_check.call(game.minions.count() == 0 and not game.minions.rite_active(), "troca de reino: os servos ficam para trás")


# --- Progresso --------------------------------------------------------------------------------

func _check_progress() -> void:
	var stats: Dictionary = SaveManager.data["stats"]
	var had: Variant = stats.get("minions_raised", null)
	var c := {"type": "minions_raised", "count": 500, "hero": "kuon"}
	var tracker := RunTracker.new()
	stats["minions_raised"] = 499
	_check.call(not MetaProgress._met(c, {"victory": false, "time": 60.0, "hero": "kuon"}, tracker),
			"499 servos: ainda não")
	stats["minions_raised"] = 500
	_check.call(MetaProgress._met(c, {"victory": false, "time": 60.0, "hero": "kuon"}, tracker)
			and not MetaProgress._met(c, {"victory": false, "time": 60.0, "hero": "aki"}, tracker),
			"500 servos com a Kuon: conquista")
	_check.call(MissionBook.LEGACY_CATEGORY.get("minions_raised") == &"heroes", "minions_raised na categoria guardiãs")
	if had == null:
		stats.erase("minions_raised")
	else:
		stats["minions_raised"] = had
	tracker.minions_raised = 7
	var copy := RunTracker.new()
	copy.restore(JSON.parse_string(JSON.stringify(tracker.snapshot())))
	_check.call(copy.minions_raised == 7, "RunTracker: minions_raised no save da partida")


# --- Bot nas três velocidades -----------------------------------------------------------------

## O bot joga com a Kuon (servos, armas e habilidades) e o estado no passo BOT_STEPS é o mesmo em
## 1x, 2x e 3x (o relógio de verdade, quadro a quadro, como na partida).
func _check_bot_speeds(host: Node) -> void:
	var summaries: Array[String] = []
	var raised: Array[int] = []
	for speed: int in [1, 2, 3]:
		var game := await _t._new_game(host, String(HERO), 7, true)
		game.config["speed"] = speed
		game.start_run(game.config)
		game.player.god_mode = true
		game.level = 10
		var got: Array[String] = []
		var grab := func(_dt: float) -> void:
			if got.is_empty() and game.step_index >= BOT_STEPS:
				got.append(game.state_summary("BOT"))
		GameClock.ticked.connect(grab)
		GameClock.paused = false
		var frames := 0
		while got.is_empty() and frames < BOT_STEPS * 2:
			await host.get_tree().process_frame
			frames += 1
		GameClock.ticked.disconnect(grab)
		GameClock.paused = true
		summaries.append(got[0] if not got.is_empty() else "sem estado")
		raised.append(game.minions.raised_total)
		_check.call(GameClock.speed == speed and not got.is_empty(), "bot com a Kuon em %dx chega ao passo %d",
				[speed, BOT_STEPS])
		game.queue_free()
		await host.get_tree().process_frame
	_check.call(raised[0] > 0, "bot com a Kuon levanta servos (%d)", raised[0])
	_check.call(summaries[0] == summaries[1] and summaries[1] == summaries[2] and summaries[0].contains("servos="),
			"bot com a Kuon: mesmo estado em 1x, 2x e 3x (%s)", summaries[0])
