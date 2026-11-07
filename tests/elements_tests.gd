extends RefCounted
## Fogo, gelo e clones (.ai/06-fogo-gelo-clones.md), chamado por tests/integration_tests.gd:
## - dados das 9 armas, 3 relíquias, 2 itens, missões, textos, ícones, cores e atributos;
## - Queimadura (tique, dano creditado à arma, reaplicar sem somar, bônus "burn", chefe queima,
##   sem crítico), Frio (lentidão, 5 pilhas → congela, parado, chefe não congela, bônus "chill",
##   pilhas que somem com a lentidão), Estilhaçar e Choque Térmico (fogo em congelado, gelo em quem
##   queima, recarga, Hitodama, tique contínuo não conta);
## - Hōroku-biya (voo em arco, explosão, chão em brasa, Kagutsuchi espalhando as chamas), Tsurara
##   (leque, perfuração, pilhas; anel do Sopro da Yuki-onna), Kage Bunshin (clones nascem, cortam,
##   somem, teto, Mil Sombras permanentes e o clone extra no abate), as 3 uniões e os itens
##   "inferno" e "clones"; o gancho on_kill genérico (Procissão Invertida igual);
## - marcas de estado (queimando, congelado sem as estrelas) num quadro desenhado de verdade;
## - nenhum polígono do motor nos scripts novos (_check_no_polygons);
## - E2E: partida do bot com o arsenal novo (base → evolução → união), mesmo estado na Baixa e na
##   Alta, e o arsenal forçado (--arsenal) com as armas novas causando dano.

const AbilityTests := preload("res://tests/ability_tests.gd")
const Look := preload("res://scripts/systems/enemy_look.gd")
const DT := 1.0 / 60.0
const BASES := ["horokubiya", "tsurara", "kage_bunshin"]
const EVOLUTIONS := {"horokubiya": "kagutsuchi", "tsurara": "yukionna", "kage_bunshin": "senkage"}
const RELICS := {"horokubiya": "hiuchi_ishi", "tsurara": "yuki_kushi", "kage_bunshin": "yata_kagami"}
const UNIONS := {"onmyo_taikyoku": ["kagutsuchi", "yukionna"], "kitsune_yomeiri": ["kagutsuchi", "senkage"],
		"hyokyo": ["yukionna", "senkage"]}
const NEW_SCRIPTS := ["res://scripts/weapons/horokubiya.gd", "res://scripts/weapons/tsurara.gd",
		"res://scripts/weapons/kage_bunshin.gd", "res://scripts/weapons/taikyoku.gd",
		"res://scripts/systems/element_system.gd", "res://scripts/systems/enemy_look.gd",
		"res://scripts/systems/area_effects.gd"]
## Passos da partida do bot com o arsenal novo (base → evolução → união).
const BOT_STEPS := 1600
const EVOLVE_AT := 600
const UNION_AT := 1000

var _check: Callable
var _t: AbilityTests


func run(host: Node, check: Callable) -> void:
	_check = check
	_t = AbilityTests.new()
	_t._check = check
	_check_data()
	var game := await _t._new_game(host, "aki", 31)
	_check_burn(game)
	_check_chill(game)
	_check_shock(game)
	_check_shatter(game)
	_check_horokubiya(game)
	_check_tsurara(game)
	_check_kage_bunshin(game)
	_check_unions(game)
	_check_items(game)
	_check_hooks(game)
	await _check_marks(host, game)
	game.queue_free()
	await host.get_tree().process_frame
	_check_no_polygons()
	await _check_bot_arsenal(host)
	GameClock.paused = false
	await host.get_tree().process_frame


# --- Dados ---------------------------------------------------------------------------------

func _check_data() -> void:
	for id: String in BASES + EVOLUTIONS.values() + UNIONS.keys():
		var w := DB.weapon(StringName(id))
		_check.call(not w.is_empty(), "arma %s existe" % id)
		_check.call(HyakkiGame.WEAPON_BEHAVIORS.has(String(w.get("behavior", ""))), "%s tem comportamento registrado" % id)
		_check.call(String(w.get("icon", "")) == UiIcons.skill_path("weapons", id)
				and ResourceLoader.exists(String(w["icon"])),
				"%s: ícone no caminho final e existe" % id)
		_check.call(String(w.get("unlock", "")) == "", "%s entra no pool sem desbloqueio" % id)
		for key: String in ["weapon.%s.name" % id, "weapon.%s.desc" % id]:
			_check.call(TranslationServer.translate(key) != key, "texto %s existe" % key)
		var sfx: Dictionary = w.get("sfx", {})
		_check.call(WeaponSfx.CUES.has(String(sfx.get("launch", ""))) and HitSounds.MIX.has(String(sfx.get("impact", ""))),
				"%s: som de lançamento e impacto existentes" % id)
	for base: String in BASES:
		var data := DB.weapon(StringName(base))
		var evo := DB.weapon(StringName(EVOLUTIONS[base]))
		_check.call(String(data["kind"]) == "base" and String(data["evolution"]) == EVOLUTIONS[base]
				and String(data["evolves_with"]) == RELICS[base], "%s → %s com %s" % [base, EVOLUTIONS[base], RELICS[base]])
		_check.call(String(evo["kind"]) == "evolution" and String(evo["from"]) == base,
				"%s vem de %s" % [EVOLUTIONS[base], base])
		_check.call((data["levels"] as Array).size() == 8, "%s tem 8 níveis" % base)
		_check.call(WeaponSfx.launch_cue(evo) != WeaponSfx.launch_cue(data), "%s soa diferente da base" % EVOLUTIONS[base])
		_check.call(WeaponStyle.of(evo)["color"] != WeaponStyle.of(data)["color"], "%s tem cor própria" % EVOLUTIONS[base])
	for union: String in UNIONS:
		var data := DB.weapon(StringName(union))
		_check.call(String(data["kind"]) == "union" and Array(data["requires"]) == UNIONS[union],
				"união %s pede %s" % [union, UNIONS[union]])
	var h := DB.weapon(&"horokubiya")["base"] as Dictionary
	_check.call(float(h["damage"]) == 12.0 and float(h["cooldown"]) == 2.4 and float(h["burn"]) == 3.0
			and float(h["burn_time"]) == 3.0 and float(h["radius"]) == 26.0, "Hōroku-biya: 12, 2,4 s, raio 26, queima 3 por 3 s")
	var t := DB.weapon(&"tsurara")["base"] as Dictionary
	_check.call(float(t["damage"]) == 7.0 and int(t["amount"]) == 3 and int(t["pierce"]) == 1 and int(t["chill"]) == 1,
			"Tsurara: 7, 3 pingentes, perfura 1, 1 pilha")
	var k := DB.weapon(&"kage_bunshin")["base"] as Dictionary
	_check.call(float(k["damage"]) == 8.0 and float(k["cooldown"]) == 7.0 and float(k["duration"]) == 5.0
			and float(k["radius"]) == 20.0, "Kage Bunshin: 8, 7 s, 5 s, raio 20")
	_check.call(int(DB.weapon(&"yukionna")["base"]["amount"]) == 15 and bool(DB.weapon(&"yukionna")["flags"]["shatter"]),
			"Sopro da Yuki-onna: 15 pingentes e Estilhaçar")
	_check.call(bool(DB.weapon(&"senkage")["flags"]["permanent"])
			and float(DB.weapon(&"senkage")["flags"]["clone_on_kill"]) == 0.25,
			"Mil Sombras: permanentes e 25% de clone extra")
	_check.call(float(DB.weapon(&"kagutsuchi")["flags"]["burn_spread"]) == 36.0, "Kagutsuchi espalha as chamas a 36 px")
	var relic_stats := {"hiuchi_ishi": {"burn": 0.15}, "yuki_kushi": {"chill": 0.1},
			"yata_kagami": {"duration": 0.05, "might": 0.05}}
	for relic: String in relic_stats:
		var p: Dictionary = DB.passives.get(StringName(relic), {})
		_check.call(int(p.get("max", 0)) == 5 and p.get("per_level", {}) == relic_stats[relic],
				"relíquia %s: %s" % [relic, relic_stats[relic]])
		_check.call(TranslationServer.translate("passive.%s.name" % relic) != "passive.%s.name" % relic,
				"nome da relíquia %s" % relic)
	for stat: String in ["burn", "chill"]:
		_check.call(StatBlock.DEFS.has(stat) and PauseMenu.STATS.has(stat), "atributo %s na guardiã e na pausa" % stat)
		for key: String in ["stat.%s" % stat, "statname.%s" % stat, "delta.%s" % stat]:
			_check.call(TranslationServer.translate(key) != key, "texto %s existe" % key)
	_check.call(TranslationServer.translate("delta.burn_time") != "delta.burn_time", "texto delta.burn_time existe")
	var items := {"fire_jar": ["inferno", 4], "mirror_shard": ["clones", 10]}
	for item: String in items:
		var row: Dictionary = DB.items.get(StringName(item), {})
		_check.call(String(row.get("effect", "")) == items[item][0] and int(row.get("value", 0)) == items[item][1]
				and int(row.get("weight", 0)) == 4, "item %s: %s %s, peso 4" % [item, items[item][0], items[item][1]])
		for key: String in ["item.%s.name" % item, "item.%s.toast" % item]:
			_check.call(TranslationServer.translate(key) != key, "texto %s existe" % key)
	for id: String in EVOLUTIONS.values():
		_check.call(DB.missions.has(StringName("m_evo_" + id)), "missão m_evo_%s" % id)
	for id: String in UNIONS:
		_check.call(DB.missions.has(StringName("m_union_" + id)), "missão m_union_%s" % id)
	var tags := []
	for entry: Array in LevelUpPanel.ELEMENTS:
		tags.append(entry[0])
	_check.call(tags.has("ice") and tags.has("shadow") and tags.find("ice") < tags.find("projectile")
			and tags.find("shadow") < tags.find("blade"), "cartas: cores de gelo e sombra antes de projétil e lâmina")
	_check.call(LevelUpPanel.element_color(["projectile", "ice"]) == Color("8fe0ff"), "carta da Tsurara na cor do gelo")
	_check.call(ProjectileManager.KINDS.has("icicle"), "projétil icicle existe")
	for cue: String in ["thermal_shock", "shatter"]:
		_check.call(WeaponSfx.CUES.has(cue), "som %s existe" % cue)
	var guide := GuideBook.new()
	var text := ""
	for block: Dictionary in guide.element_blocks():
		text += String(block["text"]) + "\n"
	for number: String in [GuideBook.pct(EnemyManager.CHILL_SLOW), str(EnemyManager.CHILL_STACKS_TO_FREEZE),
			GuideBook._num(EnemyManager.FREEZE_TIME), GuideBook._num(EnemyManager.SHATTER_DAMAGE),
			GuideBook._num(EnemyManager.BURN_TICK), GuideBook.pct(EnemyManager.THERMAL_SHOCK_MULT)]:
		_check.call(text.contains(number), "Guia: Fogo, gelo e sombra mostra %s das constantes" % number)
	var chests := ""
	for block: Dictionary in guide.chapter(&"chests")["blocks"]:
		chests += str(block.get("text", "")) + "\n"
	_check.call(chests.contains(TranslationServer.translate("guide.elements.title")), "Guia: seção no capítulo de baús")
	for item: String in items:
		var effect := guide.item_effect(DB.items[StringName(item)])
		_check.call(not effect.is_empty() and effect.contains(str(items[item][1])),
				"Guia: efeito do %s (%s)" % [item, effect])


# --- Queimadura ----------------------------------------------------------------------------

func _check_burn(game: HyakkiGame) -> void:
	var e := game.enemies
	_t._clear(game)
	var i := _still(game, Vector2(50, 0))
	var before := float(game.tracker.damage_by_weapon.get(&"horokubiya", 0.0))
	_check.call(e.burn_one(i, 10.0, 3.0, &"horokubiya"), "queimadura: aplica")
	_tick(game, roundi(3.0 / DT) + 2)
	_near(_t._lost(game, i), 30.0, "queimadura: 10 dps por 3 s = 30 de dano em tiques de %.1f s" % EnemyManager.BURN_TICK)
	_near(float(game.tracker.damage_by_weapon.get(&"horokubiya", 0.0)) - before, 30.0, "queimadura: dano creditado à arma")
	_check.call(e.burn_time[i] <= 0.0 and e.burn_dps[i] == 0.0, "queimadura: acaba no tempo")
	# Reaplicar: maior dps e maior tempo, sem somar.
	e.burn_one(i, 10.0, 3.0, &"horokubiya")
	e.burn_one(i, 4.0, 1.0, &"tsurara")
	_check.call(is_equal_approx(e.burn_dps[i], 10.0) and is_equal_approx(e.burn_time[i], 3.0),
			"queimadura: reaplicar mais fraca não muda dps nem tempo")
	e.burn_one(i, 20.0, 1.0, &"kagutsuchi")
	_check.call(is_equal_approx(e.burn_dps[i], 20.0) and is_equal_approx(e.burn_time[i], 3.0)
			and e.burn_sources[e.burn_src[i]] == &"kagutsuchi",
					"queimadura: a mais forte assume o dps e a fonte, o tempo fica o maior")
	# Bônus da Pedra de Fogo (atributo "burn") e sem crítico nos tiques.
	var stats := game.player.stats
	stats.set_source("test", {"burn": 0.5, "crit": 1.0})
	var j := _still(game, Vector2(-50, 0))
	e.burn_one(j, 10.0, 1.0, &"horokubiya")
	_check.call(is_equal_approx(e.burn_dps[j], 15.0), "queimadura: atributo burn +50% → 15 dps")
	_tick(game, roundi(EnemyManager.BURN_TICK / DT) + 1)
	_near(_t._lost(game, j), 15.0 * EnemyManager.BURN_TICK, "queimadura: tique sem crítico mesmo com 100% de chance")
	stats.remove_source("test")
	# Chefe queima.
	var boss := _boss(game, Vector2(0, 60))
	_check.call(e.burn_one(boss, 10.0, 1.0, &"horokubiya"), "queimadura: chefe queima")
	_tick(game, roundi(1.0 / DT) + 2)
	_check.call(_t._lost(game, boss) > 0.0, "queimadura: chefe perde vida queimando")
	_t._clear(game)


# --- Frio e congelamento -------------------------------------------------------------------

func _check_chill(game: HyakkiGame) -> void:
	var e := game.enemies
	_t._clear(game)
	var i := _still(game, Vector2(60, 0))
	_check.call(not e.chill_one(i, 1) and e.chill[i] == 1, "frio: 1 pilha")
	_check.call(e.slow[i] > 0.0 and is_equal_approx(e.slow_mult[i], 1.0 - EnemyManager.CHILL_SLOW),
			"frio: %d%% mais lento" % roundi(EnemyManager.CHILL_SLOW * 100.0))
	var froze := false
	for _k: int in range(EnemyManager.CHILL_STACKS_TO_FREEZE - 1):
		froze = e.chill_one(i, 1)
	_check.call(froze and e.chill[i] == 0 and is_equal_approx(e.frozen[i], EnemyManager.FREEZE_TIME)
			and e.stun[i] >= EnemyManager.FREEZE_TIME, "frio: %d pilhas congelam por %.1f s" % [
				EnemyManager.CHILL_STACKS_TO_FREEZE, EnemyManager.FREEZE_TIME])
	_check.call(not e.chill_one(i, 3) and e.chill[i] == 0, "frio: congelado não soma pilhas")
	e.speed[i] = 60.0
	var at := e.pos[i]
	_tick(game, roundi(1.0 / DT))
	_check.call(e.pos[i].distance_to(at) < 0.5, "frio: congelado fica parado")
	_tick(game, roundi(0.4 / DT))
	_check.call(e.frozen[i] <= 0.0, "frio: o congelamento acaba")
	# Pilhas só valem enquanto a lentidão do frio dura.
	var j := _still(game, Vector2(-60, 0))
	e.chill_one(j, 2)
	e.slow[j] = 0.0
	e.chill_one(j, 1)
	_check.call(e.chill[j] == 1, "frio: sem lentidão, as pilhas recomeçam")
	# Atributo "chill": lentidão mais forte (teto) e congelamento mais longo.
	game.player.stats.set_source("test", {"chill": 0.5})
	var k := _still(game, Vector2(0, -60))
	e.chill_one(k, EnemyManager.CHILL_STACKS_TO_FREEZE)
	_check.call(is_equal_approx(e.frozen[k], EnemyManager.FREEZE_TIME * 1.5), "frio: atributo chill +50% → congela 1,5×")
	_check.call(is_equal_approx(e.slow_mult[k], 1.0 - minf(EnemyManager.CHILL_SLOW_MAX, EnemyManager.CHILL_SLOW * 1.5)),
			"frio: atributo chill fortalece a lentidão")
	game.player.stats.set_source("test", {"chill": 5.0})
	var m := _still(game, Vector2(0, 60))
	e.chill_one(m, 1)
	_check.call(is_equal_approx(e.slow_mult[m], 1.0 - EnemyManager.CHILL_SLOW_MAX), "frio: lentidão no teto de 70%")
	game.player.stats.remove_source("test")
	# Chefe: lento (× BOSS_STUN) e nunca congela.
	var boss := _boss(game, Vector2(80, 80))
	_check.call(not e.chill_one(boss, 20), "frio: chefe não congela")
	_check.call(e.frozen[boss] <= 0.0 and e.chill[boss] == EnemyManager.CHILL_STACKS_TO_FREEZE - 1,
			"frio: pilhas do chefe param uma antes (%d)" % e.chill[boss])
	_check.call(is_equal_approx(e.move_factor(boss), 1.0 - EnemyManager.CHILL_SLOW * EnemyManager.BOSS_STUN),
			"frio: chefe fica lento pelo BossDirector (%.2f)" % e.move_factor(boss))
	_t._clear(game)


# --- Choque Térmico ------------------------------------------------------------------------

func _check_shock(game: HyakkiGame) -> void:
	var e := game.enemies
	_t._clear(game)
	for id: StringName in [&"horokubiya", &"tsurara", &"hitodama"]:
		game.add_weapon(id)
	var i := _still(game, Vector2(40, 0))
	e.freeze_one(i, 2.0)
	game.deal_damage(&"horokubiya", i, 10.0, Vector2.RIGHT, 0.0)
	_near(_t._lost(game, i), 10.0 * (1.0 + EnemyManager.THERMAL_SHOCK_MULT),
			"choque térmico: fogo em congelado dobra o golpe")
	_check.call(e.frozen[i] <= 0.0 and e.stun[i] <= 0.001 and e.shock_cd[i] > 0.0,
			"choque térmico: consome o congelamento")
	_check.call(e.burn_time[i] > 0.0, "choque térmico: depois, o fogo queima")
	e.freeze_one(i, 2.0)
	var lost := _t._lost(game, i)
	game.deal_damage(&"horokubiya", i, 10.0, Vector2.RIGHT, 0.0)
	_near(_t._lost(game, i) - lost, 10.0,
			"choque térmico: recarga de %.1f s por inimigo" % EnemyManager.THERMAL_SHOCK_COOLDOWN)
	_check.call(e.frozen[i] > 0.0, "choque térmico: na recarga, o congelamento fica")
	var j := _still(game, Vector2(-40, 0))
	e.burn_one(j, 5.0, 3.0, &"horokubiya")
	game.deal_damage(&"tsurara", j, 10.0, Vector2.LEFT, 0.0)
	_near(_t._lost(game, j), 20.0, "choque térmico: gelo em quem queima dobra o golpe")
	_check.call(e.burn_time[j] <= 0.0 and e.chill[j] >= 1, "choque térmico: apaga a queimadura e o gelo gela")
	var k := _still(game, Vector2(0, 40))
	e.freeze_one(k, 2.0)
	game.deal_damage(&"hitodama", k, 10.0, Vector2.DOWN, 0.0)
	_near(_t._lost(game, k), 20.0, "choque térmico: a Hitodama (fogo) também entra")
	var m := _still(game, Vector2(0, -40))
	e.freeze_one(m, 2.0)
	game.deal_damage(&"horokubiya", m, 10.0, Vector2.UP, 0.0, false, true)
	_near(_t._lost(game, m), 10.0, "choque térmico: tique contínuo não conta")
	game.deal_damage(&"katana", m, 10.0, Vector2.UP, 0.0)
	_check.call(e.frozen[m] > 0.0, "choque térmico: arma sem elemento não quebra o gelo")
	_drop_weapons(game)
	_t._clear(game)


# --- Estilhaçar ----------------------------------------------------------------------------

func _check_shatter(game: HyakkiGame) -> void:
	var e := game.enemies
	_t._clear(game)
	var victim := _still(game, Vector2(50, 0), 0.01)
	var near := _still(game, Vector2(62, 0))
	var far := _still(game, Vector2(50 + EnemyManager.SHATTER_RADIUS + 30.0, 0))
	e.freeze_one(victim, 2.0)
	game.deal_damage(&"katana", victim, 1e6, Vector2.RIGHT, 0.0)
	_check.call(e.alive[victim] == 0 and is_zero_approx(_t._lost(game, near)),
			"estilhaçar: sem a arma, congelado morre sem estilhaçar")
	game.add_weapon(&"yukionna")
	victim = _still(game, Vector2(50, 0), 0.01)
	e.freeze_one(victim, 2.0)
	game.deal_damage(&"katana", victim, 1e6, Vector2.RIGHT, 0.0)
	_near(_t._lost(game, near), EnemyManager.SHATTER_DAMAGE,
			"estilhaçar: %d de dano em volta" % EnemyManager.SHATTER_DAMAGE)
	_check.call(e.chill[near] == EnemyManager.SHATTER_CHILL and e.slow[near] > 0.0,
			"estilhaçar: 1 pilha de frio em quem sobrou")
	_check.call(is_zero_approx(_t._lost(game, far)), "estilhaçar: só no raio de %d px" % EnemyManager.SHATTER_RADIUS)
	_check.call(game.elements.mute == 0, "estilhaçar: estados das armas religados depois")
	# Teto de reações em cadeia por passo: sem cota, o congelado morre sem estilhaçar.
	e.cascades_left = 0
	var capped := _still(game, Vector2(-80, 40), 0.01)
	var beside := _still(game, Vector2(-70, 40))
	e.freeze_one(capped, 2.0)
	game.deal_damage(&"katana", capped, 1e6, Vector2.LEFT, 0.0)
	_check.call(is_zero_approx(_t._lost(game, beside)), "estilhaçar: no máximo %d reações em cadeia por passo"
			% EnemyManager.CASCADES_PER_STEP)
	e.cascades_left = EnemyManager.CASCADES_PER_STEP
	var warm := _still(game, Vector2(-50, 0), 0.01)
	game.deal_damage(&"katana", warm, 1e6, Vector2.LEFT, 0.0)
	_check.call(is_zero_approx(_t._lost(game, near) - EnemyManager.SHATTER_DAMAGE), "estilhaçar: só quem morre congelado")
	_drop_weapons(game)
	_t._clear(game)


# --- Hōroku-biya e Kagutsuchi ---------------------------------------------------------------

func _check_horokubiya(game: HyakkiGame) -> void:
	var e := game.enemies
	_t._clear(game)
	game.add_weapon(&"horokubiya")
	var w := game.get_weapon(&"horokubiya") as Horokubiya
	_check.call(w != null, "Hōroku-biya nasce com o comportamento")
	if w == null:
		return
	var origin := game.player.sim_pos
	var target := _still(game, origin + Vector2(70, 0))
	w.set("_timer", 999.0)
	w.fire(origin)
	_check.call(w.pots.size() == w.amount() and (w.pots[0]["to"] as Vector2) == e.pos[target],
			"Hōroku-biya: pote voa até o inimigo")
	_near(w.flight_time(), Horokubiya.FLIGHT, "Hōroku-biya: voo de %.2f s" % Horokubiya.FLIGHT)
	_step_weapon(game, w, 0.3)
	_check.call(w.pots.size() == 1 and is_zero_approx(_t._lost(game, target)), "Hōroku-biya: no ar, ainda não explodiu")
	_step_weapon(game, w, 0.3)
	_check.call(w.pots.is_empty() and _t._lost(game, target) >= w.damage() - 0.01, "Hōroku-biya: explode no alvo")
	_check.call(e.burn_time[target] > 0.0, "Hōroku-biya: a explosão queima")
	var pools := game.areas.effects.filter(func(fx: Dictionary) -> bool: return fx.has("burn_dps"))
	_check.call(pools.size() == 1, "Hōroku-biya: deixa o chão em brasa")
	var late := _still(game, e.pos[target] + Vector2(0, 8))
	_step_areas(game, 0.6)
	_check.call(e.burn_time[late] > 0.0, "Hōroku-biya: o chão em brasa queima quem entra")
	_step_areas(game, w.duration() + 0.2)
	_check.call(game.areas.effects.filter(func(fx: Dictionary) -> bool: return fx.has("burn_dps")).is_empty(),
			"Hōroku-biya: o chão em brasa apaga em %.1f s" % w.duration())
	game.areas.reset()
	# Kagutsuchi: quem morre queimando passa as chamas a quem está a burn_spread px.
	_drop_weapons(game)
	_t._clear(game)
	game.add_weapon(&"kagutsuchi")
	var evo := game.get_weapon(&"kagutsuchi") as Horokubiya
	_check.call(evo.amount() == 3, "Kagutsuchi: 3 potes por vez")
	var victim := _still(game, Vector2(50, 0), 0.01)
	var close := _still(game, Vector2(50, 30))
	var away := _still(game, Vector2(50, 90))
	e.burn_one(victim, 5.0, 3.0, &"kagutsuchi")
	game.deal_damage(&"katana", victim, 1e6, Vector2.RIGHT, 0.0)
	_check.call(e.burn_time[close] > 0.0 and e.burn_time[away] <= 0.0, "Kagutsuchi: as chamas passam para quem está perto")
	_drop_weapons(game)
	_t._clear(game)


# --- Tsurara e Sopro da Yuki-onna ------------------------------------------------------------

func _check_tsurara(game: HyakkiGame) -> void:
	var e := game.enemies
	var pm := game.projectiles
	_t._clear(game)
	pm.reset()
	game.add_weapon(&"tsurara")
	var w := game.get_weapon(&"tsurara") as Tsurara
	var origin := game.player.sim_pos
	var target := _still(game, origin + Vector2(60, 0))
	w.fire(origin)
	_check.call(pm.count_alive == w.amount(), "Tsurara: leque de %d pingentes" % w.amount())
	var icicle := ProjectileManager.KINDS.keys().find("icicle")
	var aimed := 0
	for i: int in range(ProjectileManager.CAPACITY):
		if pm.alive[i] == 1:
			_check.call(pm.kind[i] == icicle and pm.pierce[i] == 1, "Tsurara: pingente perfura 1")
			aimed += 1 if pm.vel[i].normalized().dot(Vector2.RIGHT) > 0.9 else 0
	_check.call(aimed >= 1, "Tsurara: mira no inimigo mais próximo")
	for _k: int in range(30):
		pm.step(DT)
	_check.call(_t._lost(game, target) > 0.0 and e.chill[target] >= 1 and e.slow[target] > 0.0, "Tsurara: o acerto gela")
	pm.reset()
	_drop_weapons(game)
	game.add_weapon(&"yukionna")
	var evo := game.get_weapon(&"yukionna") as Tsurara
	evo.fire(origin)
	_check.call(pm.count_alive == 15, "Sopro da Yuki-onna: anel de 12 + 3 no alvo (%d)" % pm.count_alive)
	var octants := {}
	for i: int in range(ProjectileManager.CAPACITY):
		if pm.alive[i] == 1:
			octants[posmod(roundi(pm.vel[i].angle() / (TAU / 8.0)), 8)] = true
	_check.call(octants.size() == 8, "Sopro da Yuki-onna: o anel cobre todas as direções")
	pm.reset()
	_drop_weapons(game)
	_t._clear(game)


# --- Kage Bunshin, Mil Sombras ---------------------------------------------------------------

func _check_kage_bunshin(game: HyakkiGame) -> void:
	_t._clear(game)
	game.add_weapon(&"kage_bunshin")
	var w := game.get_weapon(&"kage_bunshin") as KageBunshin
	var origin := game.player.sim_pos
	w.fire(origin)
	_check.call(w.clone_count() == w.amount() and w.clone_count() == 1, "Kage Bunshin: 1 clone no nível 1")
	_check.call(not w.from_hand(), "Kage Bunshin: clones nascem em volta do corpo")
	var target := _still(game, origin + Vector2(70, 0))
	w.set("_timer", 999.0)
	_step_weapon(game, w, 1.5)
	_check.call(_t._lost(game, target) > 0.0, "Kage Bunshin: o clone corre e corta")
	_check.call(w.c_pos[0].distance_to(game.enemies.pos[target]) < 40.0, "Kage Bunshin: o clone vai até o inimigo")
	_near(float(game.tracker.damage_by_weapon.get(&"kage_bunshin", 0.0)), _t._lost(game, target),
			"Kage Bunshin: dano creditado à arma")
	_step_weapon(game, w, w.duration())
	_check.call(w.clone_count() == 0, "Kage Bunshin: o clone some em %.0f s" % w.duration())
	w._spawn_many(origin, KageBunshin.MAX_CLONES + 5, 5.0, false)
	_check.call(KageBunshin.alive_total(game) == KageBunshin.MAX_CLONES,
			"Kage Bunshin: teto de %d clones" % KageBunshin.MAX_CLONES)
	_check.call(not game.snapshot().has("clones"), "Kage Bunshin: clones fora do save da partida suspensa")
	_drop_weapons(game)
	_t._clear(game)
	# Mil Sombras: 4 permanentes que voltam quando o grupo é desfeito, e o clone extra no abate.
	game.add_weapon(&"senkage")
	var evo := game.get_weapon(&"senkage") as KageBunshin
	evo.fire(origin)
	_check.call(evo.clone_count() == 4, "Mil Sombras: 4 clones")
	evo.set("_timer", 999.0)
	_step_weapon(game, evo, 12.0)
	_check.call(evo.clone_count() == 4, "Mil Sombras: os clones não somem")
	evo.on_removed()
	evo.fire(origin)
	evo.fire(origin)
	_check.call(evo.clone_count() == 4, "Mil Sombras: o grupo desfeito se refaz, sem passar de 4")
	evo.flags = evo.flags.duplicate()
	evo.flags["clone_on_kill"] = 1.0
	var victim := _still(game, origin + Vector2(30, 0), 0.01)
	game.deal_damage(&"katana", victim, 1e6, Vector2.RIGHT, 0.0)
	_check.call(evo.clone_count() == 4, "Mil Sombras: abate de outra arma não cria clone")
	victim = _still(game, origin + Vector2(30, 0), 0.01)
	game.deal_damage(&"senkage", victim, 1e6, Vector2.RIGHT, 0.0)
	_check.call(evo.clone_count() == 5 and evo.c_perm[4] == 0, "Mil Sombras: abate de clone cria um clone extra")
	_near(evo.c_life[4], KageBunshin.EXTRA_CLONE_TIME,
			"Mil Sombras: clone extra dura %.0f s" % KageBunshin.EXTRA_CLONE_TIME)
	_drop_weapons(game)
	_t._clear(game)


# --- Uniões ----------------------------------------------------------------------------------

func _check_unions(game: HyakkiGame) -> void:
	var e := game.enemies
	_t._clear(game)
	# Taikyoku do Onmyō: orbe de fogo queima, de gelo gela, pulso consome os estados.
	game.add_weapon(&"onmyo_taikyoku")
	var tai := game.get_weapon(&"onmyo_taikyoku") as Taikyoku
	_check.call(tai != null and tai.is_fire() and tai.is_ice(), "Taikyoku: fogo e gelo")
	tai.set("_timer", 999.0)
	var center := game.player.sim_pos
	var hot := _still(game, tai.orb_position(0, center))
	var cold := _still(game, tai.orb_position(1, center))
	tai.step(DT)
	_check.call(e.burn_time[hot] > 0.0 and e.chill[hot] == 0, "Taikyoku: orbe de fogo queima")
	_check.call(e.chill[cold] == 2 and e.burn_time[cold] <= 0.0, "Taikyoku: orbe de gelo soma 2 pilhas")
	var r := tai.orbit_radius()
	_check.call(r >= 59.0 * tai.area() and r <= 91.0 * tai.area(), "Taikyoku: raio pulsa entre 60 e 90 (%.0f)" % r)
	_t._clear(game)
	var burning := _still(game, center + Vector2(40, 40))
	var chilled := _still(game, center + Vector2(-40, 40))
	var clean := _still(game, center + Vector2(0, -50))
	e.burn_one(burning, 5.0, 3.0, &"horokubiya")
	e.chill_one(chilled, 1)
	tai.fire(center)
	_near(_t._lost(game, burning), tai.damage(), "Taikyoku: pulso em quem queima")
	_check.call(_t._lost(game, chilled) > 0.0 and is_zero_approx(_t._lost(game, clean)),
			"Taikyoku: pulso só em quem tem fogo ou gelo")
	_check.call(not e.has_element(burning) and not e.has_element(chilled), "Taikyoku: o pulso consome os estados")
	_drop_weapons(game)
	_t._clear(game)
	# Casamento da Raposa: 6 clones de fogo; o corte queima; a explosão fere e o clone renasce.
	game.add_weapon(&"kitsune_yomeiri")
	var fox := game.get_weapon(&"kitsune_yomeiri") as KageBunshin
	fox.fire(center)
	fox.set("_timer", 999.0)
	_check.call(fox.clone_count() == 6, "Casamento da Raposa: 6 clones")
	var prey := _still(game, center + Vector2(60, 0))
	_step_weapon(game, fox, 1.0)
	_check.call(_t._lost(game, prey) > 0.0 and e.burn_time[prey] > 0.0, "Casamento da Raposa: o corte queima")
	fox.c_burst[0] = 0.0
	var lost := _t._lost(game, prey)
	_step_weapon(game, fox, KageBunshin.DASH_TIME + 2.0 * DT)
	_check.call(fox.c_state[0] == KageBunshin.State.GONE and _t._lost(game, prey) > lost,
			"Casamento da Raposa: o clone explode")
	_step_weapon(game, fox, KageBunshin.RESPAWN_TIME + 2.0 * DT)
	_check.call(fox.c_state[0] == KageBunshin.State.RUN and fox.clone_count() == 6,
			"Casamento da Raposa: renasce depois de 1 s")
	_drop_weapons(game)
	_t._clear(game)
	# Espelho de Gelo: o corte gela; o clone estilhaça num leque de pingentes.
	game.projectiles.reset()
	game.add_weapon(&"hyokyo")
	var mirror := game.get_weapon(&"hyokyo") as KageBunshin
	mirror.fire(center)
	mirror.set("_timer", 999.0)
	var target := _still(game, center + Vector2(60, 0))
	_step_weapon(game, mirror, 1.0)
	_check.call(e.chill[target] >= 2 or e.frozen[target] > 0.0, "Espelho de Gelo: o corte gela")
	game.projectiles.reset()
	# Sem alvo (os estilhaços voam livres): o clone estoura onde está.
	game.enemies.despawn(target)
	mirror.c_burst[0] = 0.0
	mirror.c_target[0] = -1
	_step_weapon(game, mirror, KageBunshin.DASH_TIME + 2.0 * DT)
	_check.call(game.projectiles.count_alive >= int(mirror.flags["burst_shards"]),
			"Espelho de Gelo: estilhaça em %d pingentes"
			% int(mirror.flags["burst_shards"]))
	game.projectiles.reset()
	_drop_weapons(game)
	_t._clear(game)


# --- Itens --------------------------------------------------------------------------------------

func _check_items(game: HyakkiGame) -> void:
	var e := game.enemies
	_t._clear(game)
	# A tela do teste pode ser pequena (headless): posições a partir da metade visível.
	var half := game.view_size() * 0.5
	var on_screen := _still(game, half * Vector2(0.5, 0.3))
	var boss := _boss(game, half * Vector2(-0.5, 0.0))
	var off := _still(game, Vector2(half.x * 2.0 + 60.0, 0))
	game.collect_item(DB.items[&"fire_jar"])
	_check.call(e.burn_time[on_screen] > 0.0 and is_equal_approx(e.burn_dps[on_screen], ElementSystem.INFERNO_DPS),
			"Jarro de Fogo: a tela queima com %.0f dps" % ElementSystem.INFERNO_DPS)
	_check.call(e.burn_time[boss] > 0.0, "Jarro de Fogo: chefe também queima")
	_check.call(e.burn_time[off] <= 0.0, "Jarro de Fogo: fora da tela, não")
	_near(e.burn_time[on_screen], 4.0, "Jarro de Fogo: por 4 s")
	_t._clear(game)
	game.collect_item(DB.items[&"mirror_shard"])
	var clones := game.elements.item_clones
	_check.call(clones != null and clones.clone_count() == ElementSystem.MIRROR_CLONES, "Caco do Espelho: 3 clones")
	var prey := _still(game, Vector2(50, 0))
	for _k: int in range(roundi(1.5 / DT)):
		_reindex_step(game)
		game.elements.step(DT)
	_check.call(_t._lost(game, prey) > 0.0 and float(game.tracker.damage_by_weapon.get(&"mirror_shard", 0.0)) > 0.0,
			"Caco do Espelho: clones cortam e o dano conta para o item")
	for _k: int in range(roundi(9.0 / DT)):
		game.elements.step(DT)
	_check.call(clones.clone_count() == 0, "Caco do Espelho: os clones somem em 10 s")
	_t._clear(game)


# --- Gancho de abate ---------------------------------------------------------------------------

func _check_hooks(game: HyakkiGame) -> void:
	_t._clear(game)
	game.projectiles.reset()
	game.add_weapon(&"inverted_procession")
	var w := game.get_weapon(&"inverted_procession")
	w.flags = w.flags.duplicate()
	w.flags["ally_on_kill"] = 1.0
	var victim := _still(game, Vector2(40, 0), 0.01)
	game.deal_damage(&"katana", victim, 1e6, Vector2.RIGHT, 0.0)
	_check.call(game.projectiles.count_alive == 1, "on_kill genérico: Procissão Invertida segue criando a chama aliada")
	_check.call(game.enemies.dying_index() == -1 and game.enemies.dying_killer() == &"",
			"on_kill: fora de uma morte, sem estado")
	game.projectiles.reset()
	_drop_weapons(game)
	_t._clear(game)


# --- Marcas de estado num quadro desenhado ---------------------------------------------------

func _check_marks(host: Node, game: HyakkiGame) -> void:
	var e := game.enemies
	var look := e.look
	_t._clear(game)
	var burning := _still(game, Vector2(-40, 0))
	var frozen := _still(game, Vector2(0, 0) + Vector2(20, 20))
	var plain := _still(game, Vector2(40, -20))
	e.burn_one(burning, 5.0, 9.0, &"horokubiya")
	e.freeze_one(frozen, 9.0)
	_check.call(look.status_flags(burning) == Look.STATUS_BURN, "marca: queimando")
	_check.call(look.status_flags(frozen) == Look.STATUS_FROZEN, "marca: congelado (sem as estrelas do atordoado)")
	_check.call(look.status_flags(plain) == 0, "marca: sem estado")
	var tint := Look.burn_tint(Color(0.4, 0.6, 1.0, 0.5))
	_check.call(tint.r > 0.4 and is_equal_approx(tint.a, 0.5), "marca: queimando puxa o tom para o laranja")
	GameClock.paused = true
	for _k: int in range(3):
		await host.get_tree().process_frame
	_check.call(look.status_drawn == 2, "marca: uma chama e um bloco de gelo desenhados (%d)" % look.status_drawn)
	_t._clear(game)


# --- Sem polígono do motor --------------------------------------------------------------------

func _check_no_polygons() -> void:
	for path: String in NEW_SCRIPTS:
		var source := (load(path) as GDScript).source_code
		var offenders: PackedStringArray = []
		for call: String in ["draw_polygon(", "draw_colored_polygon(", "draw_polyline(", "draw_arc(", "draw_multiline("]:
			if source.contains(call):
				offenders.append(call)
		_check.call(offenders.is_empty(), "%s desenha sem polígono do motor %s" % [path.get_file(), offenders])


# --- E2E do bot -------------------------------------------------------------------------------

## Partida do bot com o arsenal novo nas bases; no passo EVOLVE_AT as três evoluem e no UNION_AT
## Kagutsuchi + Sopro da Yuki-onna viram o Taikyoku do Onmyō. Mesmo estado na Baixa e na Alta.
func _check_bot_arsenal(host: Node) -> void:
	var summaries: Array[String] = []
	for level: int in [GfxQuality.LOW, GfxQuality.HIGH]:
		GfxQuality.set_override(level)
		FxLayer.refresh_quality()
		var game := await _t._new_game(host, "aki", 7, true)
		var cfg := game.config.duplicate()
		cfg["arsenal"] = BASES
		game.start_run(cfg)
		GameClock.paused = true
		game.player.god_mode = true
		for id: String in BASES:
			game.level_up.passive_levels[StringName(RELICS[id])] = 1
		var forced := 0
		for id: String in BASES:
			var w := game.get_weapon(StringName(id))
			forced += 1 if w != null and w.level == w.max_level else 0
		_check.call(forced == BASES.size(), "bot: arsenal forçado nas bases, nível máximo")
		for step: int in range(BOT_STEPS):
			if step == EVOLVE_AT:
				for id: String in BASES:
					game.evolve_weapon(StringName(id))
			elif step == UNION_AT:
				game.apply_union(&"onmyo_taikyoku")
			GameClock.paused = false
			GameClock.game_time += DT
			game._on_tick(DT)
		var damage := game.tracker.damage_by_weapon
		for id: String in BASES + ["onmyo_taikyoku", "senkage"]:
			_check.call(float(damage.get(StringName(id), 0.0)) > 0.0, "bot: %s causa dano na partida (%.0f)" % [id,
					float(damage.get(StringName(id), 0.0))])
		_check.call(game.has_weapon(&"onmyo_taikyoku") and game.has_weapon(&"senkage") and not game.has_weapon(&"kagutsuchi"),
				"bot: base → evolução → união")
		summaries.append(game.state_summary("BOT"))
		game.queue_free()
		await host.get_tree().process_frame
	GfxQuality.clear_override()
	FxLayer.refresh_quality()
	_check.call(summaries[0] == summaries[1],
			"bot com fogo, gelo e clones: mesmo estado na Baixa e na Alta (%s | %s)" % summaries)
	GameClock.paused = true


# --- Auxiliares ---------------------------------------------------------------------------------

## Inimigo parado (velocidade 0) com vida × `hp`.
func _still(game: HyakkiGame, at: Vector2, hp: float = AbilityTests.HP_MULT) -> int:
	var i := game.enemies.spawn(&"slime_rice", at, hp, 1.0)
	game.enemies.speed[i] = 0.0
	_t._reindex(game)
	return i


func _boss(game: HyakkiGame, at: Vector2) -> int:
	for id: StringName in DB.ids("bosses"):
		if not bool(DB.bosses[id].get("invincible", false)):
			var i := game.enemies.spawn(id, at, AbilityTests.HP_MULT, 1.0)
			_t._reindex(game)
			return i
	return -1


## Só o passo dos inimigos (tiques da Queimadura, congelamento).
func _tick(game: HyakkiGame, steps: int) -> void:
	for _k: int in range(steps):
		GameClock.game_time += DT
		game.step_index += 1
		game.enemies.step(DT)


func _reindex_step(game: HyakkiGame) -> void:
	GameClock.game_time += DT
	_t._reindex(game)


## Passo de uma arma (com a grade dos inimigos refeita e o relógio andando).
func _step_weapon(game: HyakkiGame, w: Weapon, seconds: float) -> void:
	for _k: int in range(roundi(seconds / DT)):
		_reindex_step(game)
		w.step(DT)
		game.projectiles.step(DT)
		game.areas.step(DT)


func _step_areas(game: HyakkiGame, seconds: float) -> void:
	for _k: int in range(roundi(seconds / DT)):
		_reindex_step(game)
		game.areas.step(DT)
		game.enemies.step(DT)


## Tira as armas extras (fica só a da guardiã).
func _drop_weapons(game: HyakkiGame) -> void:
	for w: Weapon in game.weapons.duplicate():
		if w.id != StringName(game.player.hero.get("weapon", "katana")):
			w.on_removed()
			game.weapons.erase(w)
	game.areas.reset()


func _near(value: float, expected: float, label: String) -> void:
	_check.call(absf(value - expected) < 0.05, "%s (%.2f, esperado %.2f)" % [label, value, expected])
