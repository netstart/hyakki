extends RefCounted
## Guardião do Limiar, portal e Kakuriyo (scripts/systems/rift_portal.gd, scripts/ui/realm_card.gd,
## scripts/game/bot_pilot.gd, data/stages.json "midboss"/"otherworld", data/bosses.json "midboss",
## biomas "<fase>_ura" de data/biomes.json):
##   - dados: toda fase tem o Guardião aos RUN_LENGTH/2, com vida entre a dos chefes dos 5:00 e
##     dos 10:00, padrões próprios, kanji e selo; nenhum evento da fase cai na janela da entrada;
##     todo reino tem bioma do outro mundo (6 materiais, layout válido, sprites existentes),
##     kanji, tinta, luz, música e clima existentes; a mistura da fase com o reino;
##   - agenda ao vivo: aviso 4 s antes, entrada com selo 門 e respiro do spawner;
##   - morte: dois baús de chefe em pontos livres e separados e o portal livre longe deles (em
##     cima de casas reais da vila), sem o baú comum; os dois baús abrem um depois do outro;
##   - portal: selo afasta inimigos e só o toque da guardiã atravessa; ele nunca se move, nunca
##     cresce e nunca força a travessia (só chama: aviso e brilho), e o amanhecer com ele aberto
##     vence no primeiro mapa e o fecha; o bot anda até ele e entra;
##   - outro mundo de verdade: layout, chão, decoração, luz e clima diferentes da fase de origem;
##   - travessia: relógio para e volta, bioma e semente novos, guardiã na origem livre, campo
##     limpo, brasas viram XP, baús vão para a fila, chefe ativo vem junto;
##   - o outro mundo segue: chefe dos 10:00, amanhecer (vitória com "realm") e Noite Sem Fim;
##   - partida suspensa: reino, portal aberto e Guardião em campo voltam do snapshot;
##   - cenários de depuração "midboss", "portal" e "realm";
##   - arte própria: cada Guardião usa a folha de assets/art/midbosses/<fase>/ (sem tinta nem
##     montagem provisória), com retrato do códice, tamanho de chefe e, nas folhas "dir4" (Onikuma,
##     Onmoraki), o lado certo para onde anda e investe; o portal usa portal_open → portal_loop e o
##     torii importados, e o zumbido toca com o portal aberto e para ao fechar, atravessar,
##     reiniciar, retomar sem portal e no fim da partida.
## run_unit() roda sem autoloads (tests/run_tests.gd); run() precisa da árvore
## (tests/integration_tests.gd).

const GAME_SCENE := "res://scenes/game/Game.tscn"
const STEP := 1.0 / 60.0
## Janela em volta do Guardião onde nenhum evento da fase pode cair (aviso, entrada e respiro).
const QUIET_BEFORE := RiftPortal.WARN_LEAD + 6.0
const QUIET_AFTER := 8.0

var _check: Callable
var _host: Node


static func _json(name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % name))


# --- Dados (sem autoloads) ----------------------------------------------------------------

func run_unit(check: Callable) -> void:
	_check = check
	var stages: Array = _json("stages")
	var bosses := {}
	for b: Dictionary in _json("bosses"):
		bosses[String(b["id"])] = b
	var biomes: Dictionary = (_json("biomes") as Dictionary)["biomes"]
	var sprites: Dictionary = (_json("biomes") as Dictionary)["sprites"]
	var weather: Dictionary = (_json("weather") as Dictionary)["stages"]
	var seen := {}
	for s: Dictionary in stages:
		var id := String(s["id"])
		_test_midboss_data(s, bosses, seen)
		_test_quiet_window(s)
		_test_realm_data(id, s, biomes, sprites, weather)
	_check.call(seen.size() == stages.size(), "limiar: um Guardião diferente por fase (%d)" % seen.size())
	_test_realm_stage(stages[0])
	_test_arrow_rect()


func _test_midboss_data(s: Dictionary, bosses: Dictionary, seen: Dictionary) -> void:
	var id := String(s["id"])
	var mid := RiftPortal.midboss_of(s)
	_check.call(not mid.is_empty(), "limiar %s: fase tem Guardião" % id)
	if mid.is_empty():
		return
	_check.call(is_equal_approx(float(mid["t"]), HyakkiGame.RUN_LENGTH * 0.5),
			"limiar %s: Guardião no meio da noite (%.0f s)" % [id, float(mid["t"])])
	var boss: Dictionary = bosses.get(String(mid["id"]), {})
	seen[String(mid["id"])] = true
	_check.call(bool(boss.get("midboss", false)), "limiar %s: %s marcado midboss" % [id, mid["id"]])
	var hp := float(boss.get("hp", 0))
	var first := float((bosses[String(s["bosses"][0]["id"])] as Dictionary)["hp"])
	var last := float((bosses[String(s["bosses"][1]["id"])] as Dictionary)["hp"])
	_check.call(hp > first and hp < last, "limiar %s: vida %.0f entre %.0f e %.0f" % [id, hp, first, last])
	var patterns := 0
	for phase: Dictionary in boss.get("phases", []):
		patterns += (phase["patterns"] as Array).size()
	patterns += (boss.get("patterns", []) as Array).size()
	_check.call(patterns >= 4, "limiar %s: padrões próprios (%d)" % [id, patterns])
	_check.call(String(boss.get("kanji", "")).length() >= 2 and String(boss.get("seal", "")) == "門",
			"limiar %s: kanji e selo 門" % id)
	var sheet: Dictionary = boss.get("sprite", {})
	var sprite := String(sheet.get("path", ""))
	_check.call(ResourceLoader.exists(sprite), "limiar %s: sprite existe (%s)" % [id, sprite])
	_check.call(sprite.begins_with("res://assets/art/midbosses/%s/" % id), "limiar %s: arte própria do Guardião" % id)
	_check.call(not boss.has("tint") and not sheet.has("composite"), "limiar %s: sem tinta nem montagem provisória" % id)
	_check.call(ResourceLoader.exists(String(boss.get("faceset", ""))), "limiar %s: retrato do códice existe" % id)
	var frame: Array = sheet.get("frame", [0, 0])
	var tall := maxf(float(frame[0]), float(frame[1])) * float(boss.get("scale", 1.0))
	_check.call(tall >= 44.0 and tall <= 100.0, "limiar %s: tamanho de chefe intermediário (%.0f px)" % [id, tall])
	_check.call(String(boss.get("music", "")) == "midboss", "limiar %s: música do Guardião" % id)
	_check.call(String((s.get("otherworld", {}) as Dictionary).get("music", "")) == "kakuriyo",
			"reino %s: música do Kakuriyo na chegada" % id)


## Nenhum evento (onda especial, elite, cerco) cai na entrada do Guardião; nem chefe nem Kami.
func _test_quiet_window(s: Dictionary) -> void:
	var t := float(RiftPortal.midboss_of(s).get("t", 450.0))
	var clash: Array = []
	for e: Dictionary in s.get("events", []):
		var et := float(e["t"])
		if et > t - QUIET_BEFORE and et < t + QUIET_AFTER:
			clash.append(et)
	for b: Dictionary in s.get("bosses", []):
		if absf(float(b["t"]) - t) < 60.0:
			clash.append(float(b["t"]))
	for k: Variant in s.get("kami", []):
		if absf(float(k) - t) < 30.0:
			clash.append(float(k))
	_check.call(clash.is_empty(), "limiar %s: nada colide com a entrada do Guardião %s" % [s["id"], clash])


func _test_realm_data(id: String, s: Dictionary, biomes: Dictionary, sprites: Dictionary,
		weather: Dictionary) -> void:
	var ow: Dictionary = s.get("otherworld", {})
	_check.call(not ow.is_empty(), "reino %s: fase tem outro mundo" % id)
	var biome: Dictionary = biomes.get(String(ow.get("biome", "")), {})
	_check.call(bool(biome.get("otherworld", false)) and String(ow.get("biome", "")) == id + "_ura",
			"reino %s: bioma %s do outro mundo" % [id, ow.get("biome", "")])
	_check.call(String(biome.get("layout", "")) in ["village", "bamboo", "temple", "dunes", "yomi", "secret"],
			"reino %s: layout válido" % id)
	_check.call((biome.get("materials", []) as Array).size() == 6, "reino %s: 6 materiais" % id)
	_check.call((biome.get("grade", {}) as Dictionary).has("night"), "reino %s: noite própria" % id)
	var missing: Array = []
	for set_v: Dictionary in biome.get("scatter", []):
		for e: Array in set_v["sprites"]:
			if not sprites.has(String(e[0])) and not String(e[0]).begins_with("gen_"):
				missing.append(e[0])
	_check.call(missing.is_empty(), "reino %s: sprites do espalhado existem %s" % [id, missing])
	_check.call(String(ow.get("kanji", "")).length() >= 2, "reino %s: nome em kanji" % id)
	_check.call(String(ow.get("tint", "")).begins_with("#") and String(ow.get("tint")) != String(s.get("tint")),
			"reino %s: tinta própria" % id)
	_check.call(float(ow.get("light_mult", 0.0)) > 0.0, "reino %s: luz definida" % id)
	var music := "res://assets/audio/music/%s" % ow.get("music", "")
	_check.call(ResourceLoader.exists(music + ".mp3") or ResourceLoader.exists(music + ".ogg"),
			"reino %s: música existe" % id)
	_check.call(weather.has(String(ow.get("weather", ""))), "reino %s: clima existe" % id)
	# Outro lugar de verdade, não a mesma fase com outra tinta.
	var origin: Dictionary = biomes.get(id, {})
	_check.call(String(biome.get("layout", "")) != String(origin.get("layout", "")),
			"reino %s: estruturas de outro tipo (%s → %s)" % [id, origin.get("layout"), biome.get("layout")])
	_check.call(String(ow.get("weather", "")) != id, "reino %s: clima de outro tipo" % id)
	var same := 0
	for k: int in 6:
		var a: Dictionary = (origin.get("materials", []) as Array)[k]
		var b: Dictionary = (biome.get("materials", []) as Array)[k]
		if a.get("tiles", a.get("block")) == b.get("tiles", b.get("block")) and a.get("tint") == b.get("tint"):
			same += 1
	_check.call(same == 0, "reino %s: chão todo diferente da origem (%d materiais iguais)" % [id, same])
	_check.call((biome["grade"] as Dictionary)["night"] != (origin["grade"] as Dictionary)["night"]
			and biome.get("tufts") != origin.get("tufts"), "reino %s: luz da noite e vegetação próprias" % id)


func _test_realm_stage(s: Dictionary) -> void:
	var realm := RiftPortal.realm_stage(s)
	var ow: Dictionary = s["otherworld"]
	_check.call(realm["id"] == s["id"] and realm["waves"] == s["waves"], "reino: mesma fase (id, ondas)")
	_check.call(realm["biome"] == ow["biome"] and realm["tint"] == ow["tint"] and realm["music"] == ow["music"],
			"reino: bioma, tinta e música do outro mundo")
	_check.call(not realm.has("kanji") and bool(realm.get("realm", false)), "reino: marcado e sem o kanji")
	_check.call(not s.has("realm") and s["tint"] != realm["tint"], "reino: a fase original não muda")


## A seta do portal cabe na folga de 18 px que Hud.arrow_point deixa da borda.
func _test_arrow_rect() -> void:
	for i: int in 16:
		var dir := Vector2.RIGHT.rotated(TAU * i / 16.0)
		var r := RiftPortal.arrow_rect(Vector2(100, 100), dir)
		_check.call(Rect2(Vector2(100, 100), Vector2.ZERO).grow(17.0).encloses(r),
				"seta do portal para %.0f° cabe na folga da borda (%s)" % [rad_to_deg(dir.angle()), r])


# --- Partida (com a árvore) -----------------------------------------------------------------

func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	await _test_terrain()
	await _test_schedule()
	await _test_double_chest()
	await _test_portal()
	await _test_touch_only_and_bot()
	await _test_dawn_with_portal_open()
	await _test_realm_continues(false)
	await _test_realm_continues(true)
	await _test_snapshot()
	await _test_scenarios()
	await _test_dir4_facing()
	await _test_portal_art_and_hum()
	GameClock.paused = false
	await _host.get_tree().process_frame


func _new_game(stage_id: String = "village", endless: bool = false) -> HyakkiGame:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = {"hero": "aki", "stage": stage_id, "moon": 0, "mode": "normal", "seed": 909, "speed": 1,
			"endless": endless}
	_host.add_child(game)
	await _host.get_tree().process_frame
	GameClock.paused = true
	game.player.god_mode = true
	return game


func _free(game: HyakkiGame) -> void:
	game.queue_free()
	GameClock.paused = false
	await _host.get_tree().process_frame


## Passos manuais (o relógio do autoload fica parado); telas que abrirem são respondidas como o bot.
func _tick(game: HyakkiGame, count: int) -> void:
	for _k: int in count:
		GameClock.game_time += STEP
		game._on_tick(STEP)
		if game.hud.overlay_open() and not game.rift.crossing():
			game.hud.bot_answer()


func _chests(game: HyakkiGame) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in game.pickups.items:
		if item["id"] == &"chest":
			out.append(item)
	return out


## Os 6 reinos de verdade: estrutura gerada, origem livre para a guardiã nascer, limites.
func _test_terrain() -> void:
	for id: StringName in DB.ids("stages"):
		var realm := RiftPortal.realm_stage(DB.stage(id))
		var w := WorldMap.new()
		w.setup(realm, 4321)
		var solids := 0
		for cy: int in range(-1, 2):
			for cx: int in range(-1, 2):
				solids += (w.chunk_data(Vector2i(cx, cy))["solids"] as Array).size()
		_check.call(bool(w.biome.get("otherworld", false)), "reino %s: mundo monta o bioma do outro lado" % id)
		_check.call(solids > 0, "reino %s: estrutura gerada (%d obstáculos)" % [id, solids])
		_check.call(not w.overlaps_solid(Vector2.ZERO, Player.RADIUS + 2.0), "reino %s: origem livre" % id)
		w.free()
	await _host.get_tree().process_frame


func _test_schedule() -> void:
	var game := await _new_game()
	GameClock.game_time = 440.0
	game.spawner.skip_until(440.0)
	_tick(game, roundi(6.5 / STEP))
	_check.call(String(game.hud.get("_toast").text) == TranslationServer.translate("midboss.warning"),
			"limiar: aviso antes da entrada")
	_check.call(not game.bosses.has_boss(&"onikuma"), "limiar: Guardião ainda não entrou no aviso")
	_tick(game, roundi(4.0 / STEP))
	_check.call(game.bosses.has_boss(&"onikuma"), "limiar: Onikuma entra aos 7:30 na Vila")
	_check.call(game.hud.boss_panel().seal_glyph == "門" and game.hud.boss_panel().kanji == "鬼熊",
			"limiar: painel do chefe com o kanji e o selo do portão")
	var commons := game.enemies.count_common
	game.spawner.hush(2.0)
	_tick(game, 30)
	_check.call(game.enemies.count_common <= commons, "limiar: respiro do spawner segura os comuns")
	await _free(game)


## Morte em cima de casas reais da vila: dois baús livres e separados, portal livre e longe.
func _test_double_chest() -> void:
	var game := await _new_game()
	var world := game.world
	var spots: Array[Vector2] = [game.player.sim_pos + Vector2(120, 0)]
	for cy: int in range(-1, 2):
		for cx: int in range(-1, 2):
			for solid: Array in world.chunk_data(Vector2i(cx, cy))["solids"]:
				if spots.size() < 6 and float(solid[1]) >= 10.0:
					spots.append(solid[0])
	var bad := 0
	for at: Vector2 in spots:
		game.pickups.items.clear()
		game.rift.reset()
		game.on_boss_defeated(&"onikuma", at)
		var chests := _chests(game)
		var ok := chests.size() == 2 and game.rift.is_open()
		for c: Dictionary in chests:
			ok = ok and bool(c.get("boss", false)) and not world.overlaps_solid(c["pos"], PickupManager.SPAWN_CLEARANCE)
			ok = ok and (c["pos"] as Vector2).distance_to(game.rift.portal_pos) >= RiftPortal.CLEARANCE
		if chests.size() == 2:
			ok = ok and (chests[0]["pos"] as Vector2).distance_to(chests[1]["pos"]) >= RiftPortal.CHEST_MIN_GAP
		ok = ok and not world.overlaps_solid(game.rift.portal_pos, RiftPortal.CLEARANCE)
		if not ok:
			bad += 1
	_check.call(spots.size() >= 4, "limiar: pontos de morte para testar (%d)" % spots.size())
	_check.call(bad == 0, "limiar: dois baús de chefe livres e separados e o portal livre (%d falhas)" % bad)
	_check.call(game.tracker.bosses.has(&"onikuma") and game.rift.midboss_done, "limiar: Guardião vencido conta")
	# Os dois baús pegos juntos abrem um depois do outro.
	game.rift.close_portal()
	var opened := game.tracker.chests
	for c: Dictionary in _chests(game):
		c["pos"] = game.player.sim_pos
	_tick(game, 3)
	_check.call(game.hud.chest_open() or game.tracker.chests > opened, "limiar: primeiro baú abre")
	_tick(game, 30)
	_check.call(game.tracker.chests == opened + 2, "limiar: os dois baús abrem (%d)" % (game.tracker.chests - opened))
	await _free(game)


func _test_portal() -> void:
	var game := await _new_game()
	var rift := game.rift
	var origin_seed := game.world.seed_value
	game.bosses.spawn(&"tanuki")
	rift.midboss_done = true
	rift.open_portal(game.player.sim_pos + Vector2(70, 0))
	var e := game.enemies.spawn(&"slime_rice", rift.portal_pos, 1000.0, 1.0)
	_tick(game, 1)
	_check.call(game.enemies.pos[e].distance_to(rift.portal_pos) >= rift.portal_radius + RiftPortal.WARD - 0.01,
			"portal: o selo afasta inimigos")
	_check.call(rift.is_open() and not rift.crossing(), "portal: aberto sem a guardiã encostar")
	for k: int in 20:
		game.enemies.spawn(&"slime_rice", game.player.sim_pos + Vector2.from_angle(k) * 60.0, 1000.0, 1.0)
	game.pickups.spawn(game.player.sim_pos + Vector2(200, 40), 7)
	game.pickups.spawn_item(&"chest", game.player.sim_pos + Vector2(-220, 0))
	var xp_before := game.xp + game.level * 1000
	var pending: Array = game.get("_pending_chests")
	var queued := pending.size()
	var time := GameClock.game_time
	game.player.sim_pos = rift.portal_pos
	_tick(game, 1)
	_check.call(rift.crossing() and GameClock.paused and game.hud.overlay_open(),
			"portal: tocar atravessa (relógio parado, travessia na tela)")
	_check.call(game.hud.realm_card().active and game.hud.realm_card().kanji == "裏村", "portal: título do reino")
	rift.finish_crossing_now()
	_check.call(rift.in_realm and rift.reached and game.tracker.realm_reached, "travessia: chegou ao Kakuriyo")
	_check.call(game.world.biome == TerrainArt.biome("village_ura") and game.stage["biome"] == "village_ura",
			"travessia: bioma do outro mundo")
	_check.call(game.world.seed_value == rift.realm_seed and rift.realm_seed != origin_seed, "travessia: semente nova")
	_check.call(game.player.sim_pos == Vector2.ZERO and not game.world.overlaps_solid(Vector2.ZERO, Player.RADIUS),
			"travessia: guardiã na origem livre")
	_check.call(game.enemies.count_common == 0 and game.enemy_shots.count_alive == 0, "travessia: campo limpo")
	_check.call(game.pickups.count_alive == 0 and game.pickups.items.is_empty(), "travessia: nada fica no chão")
	_check.call(game.xp + game.level * 1000 > xp_before, "travessia: brasas viram XP")
	_check.call(pending.size() == queued + 1, "travessia: baú do chão vai para a fila")
	_check.call(game.bosses.has_boss(&"tanuki"), "travessia: chefe ativo vem junto")
	var boss_at: Vector2 = game.enemies.pos[int(game.bosses.bosses[0]["index"])]
	var half := game.view_size() * 0.5
	_check.call(absf(boss_at.x) >= half.x - 1.0 or absf(boss_at.y) >= half.y - 1.0,
			"travessia: chefe reaparece na borda da tela, longe da guardiã (%s, tela %s)" % [boss_at, half * 2.0])
	_check.call(not GameClock.paused and not game.hud.realm_active() and not rift.is_open(),
			"travessia: relógio volta e o portal fecha")
	_check.call(is_equal_approx(GameClock.game_time, time + STEP), "travessia: o tempo da noite continua")
	_check.call(String(game.hud.get("_toast").text) == TranslationServer.translate("realm.entered"),
			"travessia: aviso de chegada")
	await _free(game)


## O portal espera: em 1,5 minuto aberto não sai do lugar, não cresce, não puxa nem atravessa
## sozinho (só chama); a guardiã andando até ele (pelo controle, como o bot) atravessa no toque.
func _test_touch_only_and_bot() -> void:
	var game := await _new_game()
	var rift := game.rift
	rift.midboss_done = true
	rift.open_portal(game.player.sim_pos + Vector2(160, 30))
	var at := rift.portal_pos
	var me := game.player.sim_pos
	var toasts := 0
	for _k: int in roundi(90.0 / STEP / 30.0):
		_tick(game, 30)
		game.player.sim_pos = me
		if String(game.hud.get("_toast").text) == TranslationServer.translate("portal.invite"):
			toasts += 1
	_check.call(rift.is_open() and not rift.crossing() and not rift.in_realm,
			"portal: 1,5 min sem toque, nada de travessia")
	_check.call(rift.portal_pos == at and rift.portal_radius == RiftPortal.PORTAL_RADIUS and rift.art_scale() == 1.0,
			"portal: nunca se move nem cresce")
	_check.call(rift.beckon() == 1.0 and toasts > 0, "portal: só chama (brilho e aviso de convite)")
	# Andando até ele pelo controle (o mesmo que o joystick faz), a guardiã atravessa no toque.
	var steps := 0
	while not rift.crossing() and steps < 900:
		game.player.move_input = BotPilot.input(game)
		_tick(game, 1)
		steps += 1
	_check.call(rift.crossing() and game.player.sim_pos.distance_to(at) <= RiftPortal.PORTAL_RADIUS + Player.RADIUS + 2.0,
			"bot: anda até o portal e atravessa ao tocar (%.1f s)" % (steps * STEP))
	rift.finish_crossing_now()
	_check.call(rift.in_realm, "portal: o toque leva ao Kakuriyo")
	await _free(game)


## O amanhecer com o portal aberto: vitória no primeiro mapa e o portal fecha.
func _test_dawn_with_portal_open() -> void:
	var game := await _new_game()
	var results: Array[Dictionary] = []
	game.finished.connect(func(r: Dictionary) -> void: results.append(r))
	game.apply_scenario("portal")
	GameClock.game_time = HyakkiGame.RUN_LENGTH - STEP * 2.0
	_tick(game, 4)
	_check.call(results.size() == 1 and bool(results[0]["victory"]) and not bool(results[0]["realm"]),
			"portal: amanhecer antes de entrar vence no primeiro mapa")
	_check.call(not game.rift.is_open() and not game.rift.hum_playing() and not game.rift.in_realm,
			"portal: o amanhecer fecha o portal")
	await _free(game)


## No outro mundo: o chefe dos 10:00 vem, o amanhecer vence (ou abre a Noite Sem Fim).
func _test_realm_continues(endless: bool) -> void:
	var game := await _new_game("bamboo", endless)
	var results: Array[Dictionary] = []
	game.finished.connect(func(r: Dictionary) -> void: results.append(r))
	game.apply_scenario("realm")
	_tick(game, 1)
	game.rift.finish_crossing_now()
	var tag := "Noite Sem Fim" if endless else "amanhecer"
	_check.call(game.rift.in_realm and game.stage["biome"] == "bamboo_ura", "reino (%s): na Planície Nevada da Lua" % tag)
	GameClock.game_time = 599.0
	_tick(game, roundi(1.5 / STEP))
	_check.call(game.bosses.has_boss(&"kitsune_nine"), "reino (%s): chefe dos 10:00 entra no outro mundo" % tag)
	game.bosses.reset()
	GameClock.game_time = HyakkiGame.RUN_LENGTH - STEP * 2.0
	_tick(game, 4)
	if endless:
		_check.call(game.endless_phase and game.running and game.rift.in_realm
				and game.world.biome == TerrainArt.biome("bamboo_ura"), "reino: Noite Sem Fim segue no outro mundo")
		_check.call(results.is_empty(), "reino: Noite Sem Fim não encerra no amanhecer")
	else:
		_check.call(results.size() == 1 and bool(results[0]["victory"]) and bool(results[0]["realm"]),
				"reino: amanhecer no outro mundo é vitória e registra o reino")
	await _free(game)


func _test_snapshot() -> void:
	# No reino.
	var game := await _new_game()
	game.apply_scenario("realm")
	_tick(game, 1)
	game.rift.finish_crossing_now()
	var seed_realm := game.rift.realm_seed
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	await _free(game)
	var again := await _new_game()
	again.restore_snapshot(snap)
	_check.call(again.rift.in_realm and again.world.seed_value == seed_realm
			and again.world.biome == TerrainArt.biome("village_ura"), "retomada: volta ao Kakuriyo com a mesma semente")
	_check.call(again.rift.midboss_done and not again.bosses.has_boss(&"onikuma"), "retomada: Guardião não volta")
	again.close_pause()
	await _free(again)
	# Portal aberto.
	game = await _new_game()
	game.apply_scenario("portal")
	var portal := game.rift.portal_pos
	game.rift.portal_age = 12.5
	snap = JSON.parse_string(JSON.stringify(game.snapshot()))
	await _free(game)
	again = await _new_game()
	again.restore_snapshot(snap)
	_check.call(again.rift.is_open() and again.rift.portal_pos.is_equal_approx(portal)
			and is_equal_approx(again.rift.portal_age, 12.5) and not again.rift.in_realm,
			"retomada: portal aberto no mesmo lugar e tempo")
	await _free(again)
	# Guardião em campo (inimigos não entram no snapshot): volta a ser chamado.
	game = await _new_game()
	GameClock.game_time = 455.0
	game.spawner.skip_until(455.0)
	snap = JSON.parse_string(JSON.stringify(game.snapshot()))
	await _free(game)
	again = await _new_game()
	again.restore_snapshot(snap)
	_check.call(again.bosses.has_boss(&"onikuma"), "retomada: Guardião em campo é chamado de novo")
	await _free(again)


## Folha "dir4" de chefe: a coluna segue o movimento (andando e investindo).
func _test_dir4_facing() -> void:
	var game := await _new_game()
	game.bosses.spawn(&"onikuma")
	var boss: Dictionary = game.bosses.bosses[0]
	var i := int(boss["index"])
	var enemies := game.enemies
	var sheet: SpriteSheet = enemies.type_sheets[enemies.kind[i]]
	_check.call(sheet.layout == "dir4" and sheet.frame_size == Vector2(16, 16), "dir4: folha do Onikuma em 4 direções")
	for dir: int in [SpriteSheet.Dir.LEFT, SpriteSheet.Dir.UP, SpriteSheet.Dir.RIGHT, SpriteSheet.Dir.DOWN]:
		var offset: Vector2 = [Vector2(0, 1), Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0)][dir] * 200.0
		game.player.sim_pos = enemies.pos[i] + offset
		boss["state"] = "move"
		boss["timer"] = 5.0
		_tick(game, 2)
		_check.call(enemies.facing[i] == dir and sheet.region(0, dir).position.x == dir * 16.0,
				"dir4: anda e olha para %s" % ["baixo", "cima", "esquerda", "direita"][dir])
	boss["state"] = "charge"
	boss["timer"] = 1.0
	boss["dir"] = Vector2(-200, 0)
	_tick(game, 1)
	_check.call(enemies.facing[i] == SpriteSheet.Dir.LEFT, "dir4: olha para onde investe")
	await _free(game)


func _test_portal_art_and_hum() -> void:
	var game := await _new_game()
	var rift := game.rift
	_check.call(rift.has_art(), "portal: arte importada (abertura, loop e torii) carregada")
	rift.open_portal(game.player.sim_pos + Vector2(80, 0))
	_check.call((rift.sprite_frame()[0] as Texture2D).resource_path == RiftPortal.SPRITE_OPEN,
			"portal: abre com portal_open")
	rift.portal_age = 2.0
	var pick := rift.sprite_frame()
	_check.call((pick[0] as Texture2D).resource_path == RiftPortal.SPRITE_LOOP and int(pick[1]) < 12,
			"portal: segue no portal_loop")
	_check.call(rift.art_scale() == 1.0, "portal: arte em escala inteira (1x, como os atores)")
	_check.call(rift.hum_playing(), "zumbido: toca com o portal aberto")
	rift.close_portal()
	_check.call(not rift.hum_playing(), "zumbido: para ao fechar")
	rift.open_portal(game.player.sim_pos + Vector2(80, 0))
	game.player.sim_pos = rift.portal_pos
	_tick(game, 1)
	_check.call(rift.crossing() and not rift.hum_playing(), "zumbido: para ao atravessar")
	rift.finish_crossing_now()
	rift.open_portal(game.player.sim_pos + Vector2(200, 0))
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	game.start_run(game.config)
	_check.call(not rift.hum_playing(), "zumbido: para ao reiniciar a partida")
	await _free(game)
	var again := await _new_game()
	snap["realm"]["in_realm"] = false
	again.restore_snapshot(snap)
	_check.call(again.rift.is_open() and again.rift.hum_playing(), "zumbido: volta com o portal retomado")
	again.call("_end_run", false, true)
	_check.call(not again.rift.hum_playing(), "zumbido: para no fim da partida")
	await _free(again)


func _test_scenarios() -> void:
	var game := await _new_game("yomi")
	game.apply_scenario("midboss")
	_check.call(is_equal_approx(GameClock.game_time, 450.0 - RiftPortal.WARN_LEAD - 1.0),
			"cenário midboss: antes do aviso")
	_tick(game, roundi((RiftPortal.WARN_LEAD + 1.5) / STEP))
	_check.call(game.bosses.has_boss(&"yomi_hebi"), "cenário midboss: Yomi-hebi entra no Yomi")
	await _free(game)
	game = await _new_game("secret")
	game.apply_scenario("portal")
	_check.call(game.rift.is_open() and _chests(game).size() == 2, "cenário portal: dois baús e o portal")
	await _free(game)
