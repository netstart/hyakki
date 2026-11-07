extends RefCounted
## 7ª fase, Osorezan (恐山), e o Sai no Kawara (賽の河原), o Kakuriyo dela (data/stages.json,
## data/bosses.json, data/biomes.json "osorezan*", scripts/game/terrain_layout.gd _osorezan,
## scripts/app/journey_geo.gd, scripts/app/app.gd stories_after, scripts/app/screens/story_screen.gd):
##   - dados (sem autoloads): ordem 7 e liberada pela vitória na fase secreta (ach_win_secret
##     "stage:osorezan"), oculta no mapa enquanto bloqueada (JourneyGeo.HIDDEN) e com estrada própria;
##     Masakado aos 5:00, Datsue-ba (Guardião do Limiar) aos 7:30 e a Gashadokuro aos 10:00, com a
##     Sombra da Datsue-ba no Kakuriyo; conquistas (Kuon e a arma inicial pela Gashadokuro, a lanterna
##     da balsa pela vitória, que existe em HyakkiGame.LANTERN_TINTS); diálogos da Datsue-ba (aparte
##     da Hana) e da Gashadokuro (aparte do Tora); a história kuon_freed (5 painéis, música própria) e
##     osorezan_ending (3 painéis); músicas da fase, do Sai no Kawara, do chefe e da libertação;
##     inimigos novos (gaki, funayūrei, gasha_crawler que se parte em gasha_bones) e os reaproveitados;
##   - terreno: o rio Sanzu (água no canal B, sem sólido dentro) corre ao sul do início em todos os
##     chunks que ele cruza, igual em qualquer semente para a mesma semente, com pilhas de pedras e
##     lanternas nas margens; o início fica livre;
##   - partida (com a árvore): a fase carrega com a música dela, o terreno e o rio montados; Masakado
##     entra calado aos 5:00; a Datsue-ba abre o diálogo aos 7:30 (4 falas com Aki, 3 com Hana); no
##     Tokoyo a Gashadokuro abre o diálogo aos 10:00 e depois toca a música dela;
##   - história: App.stories_after enfileira kuon_freed na 1ª partida com a Gashadokuro vencida
##     (vitória ou não) e osorezan_ending depois dela na 1ª vitória; as flags vistas tiram as duas;
##     a tela da história toca a música da sequência e desenha as cenas "osorezan" e "sanzu";
##   - layout da tela da história em todas as resoluções × idiomas × furo dos dois lados: caixa do
##     texto, retrato e botões dentro da área segura e o texto cabendo na caixa.
## run_unit() roda sem autoloads (tests/run_tests.gd); run() precisa da árvore
## (tests/integration_tests.gd; sozinho: `-- --suites=OsorezanTests`).

const TerrainTests := preload("res://tests/terrain_tests.gd")
const DeviceProfiles := preload("res://tests/device_profiles.gd")
const TestShards := preload("res://tests/test_shards.gd")
const AudioFiles := preload("res://scripts/autoload/audio_manager.gd")
const GAME_SCENE := "res://scenes/game/Game.tscn"
const STORY := "res://scripts/app/screens/story_screen.gd"
const STEP := 1.0 / 60.0
const STAGE := "osorezan"
## Músicas novas (assets/audio/music/<id>.ogg|mp3).
const MUSIC: Array[String] = ["stage_osorezan", "sanzu", "lament", "boss_gashadokuro"]

var _check: Callable
var _host: Node


static func _json(name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % name))


static func _by_id(rows: Array) -> Dictionary:
	var out := {}
	for r: Dictionary in rows:
		out[String(r["id"])] = r
	return out


# --- Dados (sem autoloads) ----------------------------------------------------------------

func run_unit(check: Callable) -> void:
	_check = check
	var stages := _by_id(_json("stages"))
	var s: Dictionary = stages.get(STAGE, {})
	_check.call(int(s.get("order", 0)) == 7 and String(s.get("music", "")) == "stage_osorezan",
			"osorezan: 7ª fase com a música dela")
	var bosses: Array = s.get("bosses", [])
	_check.call(bosses.size() == 2 and String(bosses[0]["id"]) == "masakado"
			and is_equal_approx(float(bosses[0]["t"]), 300.0)
			and String(bosses[1]["id"]) == "gashadokuro" and is_equal_approx(float(bosses[1]["t"]), 600.0),
			"osorezan: Masakado aos 5:00 e a Gashadokuro aos 10:00")
	_check.call(String((s.get("midboss", {}) as Dictionary).get("id", "")) == "datsueba"
			and String((s.get("midboss2", {}) as Dictionary).get("id", "")) == "datsueba_kage",
			"osorezan: Datsue-ba no limiar e a Sombra dela no Kakuriyo")
	var ow: Dictionary = s.get("otherworld", {})
	_check.call(String(ow.get("biome", "")) == "osorezan_ura" and String(ow.get("kanji", "")) == "賽の河原"
			and String(ow.get("music", "")) == "sanzu", "osorezan: Sai no Kawara com a balsa do Sanzu")
	_check.call(float(s.get("difficulty", 0.0)) > float((stages["secret"] as Dictionary)["difficulty"]),
			"osorezan: mais difícil que a fase secreta")
	for id: String in MUSIC:
		var file := AudioFiles.MUSIC_DIR + String(AudioFiles.MUSIC_FILES.get(id, id))
		_check.call(ResourceLoader.exists(file + ".ogg") or ResourceLoader.exists(file + ".mp3"),
				"osorezan: música %s existe", id)
	var boss_rows := _by_id(_json("bosses"))
	for id: String in ["masakado", "datsueba", "gashadokuro", "datsueba_kage"]:
		var b: Dictionary = boss_rows.get(id, {})
		_check.call(not b.is_empty() and ResourceLoader.exists(String((b.get("sprite", {}) as Dictionary).get("path", ""))),
				"osorezan: chefe %s com arte", id)
	_check.call(String((boss_rows.get("gashadokuro", {}) as Dictionary).get("music", "")) == "boss_gashadokuro",
			"osorezan: a Gashadokuro com a música dela")
	_test_rewards()
	_test_dialogues()
	_test_story()
	_test_enemies()
	_test_journey()
	_test_terrain()


func _test_rewards() -> void:
	var ach := _by_id(_json("achievements"))
	_check.call(String((ach["ach_win_secret"] as Dictionary)["reward"]).split(",").has("stage:osorezan"),
			"osorezan: liberada pela vitória na fase secreta")
	var gasha: Dictionary = ach.get("ach_boss_gashadokuro", {})
	_check.call(String(gasha.get("reward", "")) == "hero:kuon,weapon:shiryo_fuda"
			and String((gasha.get("condition", {}) as Dictionary).get("boss", "")) == "gashadokuro",
			"osorezan: vencer a Gashadokuro liberta Kuon e o Shiryō-fuda")
	var win: Dictionary = ach.get("ach_win_osorezan", {})
	_check.call(String(win.get("reward", "")).split(",").has("cosmetic:ferry_lantern")
			and HyakkiGame.LANTERN_TINTS.has("ferry_lantern"), "osorezan: a lanterna da balsa existe e é da vitória")
	var missions := _by_id(_json("missions"))
	for id: String in ["m_noheal_osorezan", "m_moon1_osorezan", "m_moon3_osorezan", "m_realm_osorezan",
			"m_tokoyo_osorezan", "m_boss_masakado", "m_boss_datsueba", "m_boss_gashadokuro"]:
		_check.call(missions.has(id), "osorezan: missão %s", id)


func _test_dialogues() -> void:
	var scripts: Dictionary = _json("dialogues")
	for row: Array in [["datsueba", "hana"], ["gashadokuro", "tora"]]:
		var lines: Array = (scripts.get(row[0], {}) as Dictionary).get("lines", [])
		var whos: Array = lines.map(func(l: Dictionary) -> String: return String(l["who"]))
		var skips: Array = (lines[2] as Dictionary).get("skip", []) if lines.size() > 2 else []
		_check.call(whos == ["boss", "hero", row[1], "boss"] and skips.has(row[1]),
				"osorezan: diálogo de %s com o aparte de %s (%s)", [row[0], row[1], whos])
	_check.call(not scripts.has("masakado"), "osorezan: Masakado (5:00) entra calado")


func _test_story() -> void:
	var story := _by_id(_json("story"))
	var freed: Dictionary = story.get("kuon_freed", {})
	var ending: Dictionary = story.get("osorezan_ending", {})
	_check.call((freed.get("panels", []) as Array).size() == 5 and String(freed.get("music", "")) == "lament",
			"história: a libertação de Kuon com 5 painéis e o Lamento")
	_check.call((ending.get("panels", []) as Array).size() == 3, "história: epílogo do Osorezan com 3 painéis")
	var scenes := {}
	for p: Dictionary in (freed.get("panels", []) as Array) + (ending.get("panels", []) as Array):
		scenes[String(p["scene"])] = true
		var face := String(p.get("face", ""))
		_check.call(face.is_empty() or face.contains("/kuon/") or ResourceLoader.exists(face),
				"história: retrato %s existe", face)
	_check.call(scenes.has("osorezan") and scenes.has("sanzu"), "história: cenas osorezan e sanzu")


func _test_enemies() -> void:
	var enemies := _by_id(_json("enemies"))
	for id: String in ["gaki", "funayurei", "gasha_crawler", "gasha_bones"]:
		var e: Dictionary = enemies.get(id, {})
		_check.call(ResourceLoader.exists(String(e.get("sprite", ""))) and (e.get("stages", []) as Array).has(STAGE),
				"osorezan: inimigo %s com folha e na fase", id)
	_check.call(String(((enemies["gasha_crawler"] as Dictionary)["ai"] as Dictionary)["split_into"]) == "gasha_bones"
			and not bool((enemies["gasha_bones"] as Dictionary).get("codex", true)),
			"osorezan: o rastejante de ossos se parte em ossos soltos (fora do Diário)")
	for id: String in ["skull_blue", "yurei", "skeleton_demon", "skeleton_peasant", "shade_ghost", "yomi_eye",
			"yomi_beast_dark"]:
		_check.call(((enemies[id] as Dictionary)["stages"] as Array).has(STAGE), "osorezan: %s reaproveitado", id)
	var s: Dictionary = _by_id(_json("stages"))[STAGE]
	var missing: Array = []
	for w: Dictionary in s["waves"]:
		for id: String in (w["mix"] as Dictionary):
			if not enemies.has(id):
				missing.append(id)
	_check.call(missing.is_empty(), "osorezan: ondas só com inimigos que existem %s", [missing])


func _test_journey() -> void:
	_check.call(JourneyGeo.STAGES.has(&"osorezan") and JourneyGeo.VIA.has(&"osorezan")
			and JourneyGeo.HIDDEN.has(&"osorezan") and JourneyGeo.HIDDEN.has(&"secret"),
			"jornada: Osorezan no extremo norte, com estrada e oculta até ser liberada")
	var oso: Vector2 = JourneyGeo.STAGES[&"osorezan"]
	for id: StringName in JourneyGeo.STAGES:
		_check.call(id == &"osorezan" or (JourneyGeo.STAGES[id] as Vector2).y < oso.y,
				"jornada: Osorezan fica ao norte de %s", id)


func _test_terrain() -> void:
	var w := TerrainTests._world(STAGE, 41)
	_check.call(w.layout.kind == "osorezan", "terreno: layout próprio do Osorezan")
	var river := 0
	var wet_solids := 0
	var cairns := 0
	for cx: int in range(-2, 2):
		for cy: int in range(-1, 3):
			var d := w.chunk_data(Vector2i(cx, cy))
			for op: Array in d["paint"]:
				if String(op[0]) == "line" and int(op[1]) == 2:
					river += 1
			for sol: Array in d["solids"]:
				var p: Vector2 = sol[0]
				if absf(p.y - w.layout.sanzu_y(p.x)) < TerrainLayout.SANZU_HALF - 2.0:
					wet_solids += 1
			for it: Dictionary in d["items"]:
				if String(it["s"]).begins_with("cairn"):
					cairns += 1
	_check.call(river >= 4 * 9, "terreno: o Sanzu corre por todos os chunks que cruza (%d trechos)", river)
	_check.call(wet_solids == 0, "terreno: nada sólido dentro do rio (%d)", wet_solids)
	_check.call(cairns >= 6, "terreno: pilhas de pedras nas margens (%d)", cairns)
	var top := TerrainLayout.SANZU_Y - TerrainLayout.SANZU_WAVE.x - TerrainLayout.SANZU_WAVE.y - TerrainLayout.SANZU_HALF
	_check.call(top > TerrainLayout.SAFE_RADIUS, "terreno: o rio passa longe do início (%.0f px)", top)
	var other := TerrainTests._world(STAGE, 41)
	_check.call(is_equal_approx(other.layout.sanzu_y(123.0), w.layout.sanzu_y(123.0))
			and not is_equal_approx(TerrainTests._world(STAGE, 7).layout.sanzu_y(123.0), w.layout.sanzu_y(123.0)),
			"terreno: o curso do rio sai da semente")


# --- Partida e história (com a árvore) ------------------------------------------------------

func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var saved: Dictionary = SaveManager.data
	var always: Variant = Settings.get_value("dialogues_always")
	Settings.set_value("dialogues_always", false)
	if TestShards.runs_rest(&"OsorezanTests"):
		await _test_run()
		_test_story_queue()
		await _test_story_screen()
	await _test_story_layout()
	Settings.set_value("dialogues_always", always)
	SaveManager.data = saved
	GameClock.paused = false
	await _host.get_tree().process_frame


func _new_game(hero: String = "aki") -> HyakkiGame:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = {"hero": hero, "stage": STAGE, "moon": 0, "mode": "normal", "seed": 707, "speed": 1}
	_host.add_child(game)
	await _host.get_tree().process_frame
	GameClock.paused = true
	game.player.god_mode = true
	return game


func _free(game: HyakkiGame) -> void:
	game.queue_free()
	GameClock.paused = true
	await _host.get_tree().process_frame


## Pula para `from` e anda passo a passo até `cond` (ou `seconds`); outras telas são respondidas
## como o bot, o diálogo não.
func _run_until(game: HyakkiGame, from: float, seconds: float, cond: Callable) -> bool:
	GameClock.game_time = from
	game.spawner.skip_until(from)
	GameClock.paused = false
	for _k: int in roundi(seconds / STEP):
		GameClock.game_time += STEP
		game._on_tick(STEP)
		if game.hud.overlay_open() and not game.hud.dialogue_open():
			game.hud.bot_answer()
			GameClock.paused = false
		if cond.call():
			return true
	return false


func _music() -> String:
	return String(AudioManager.get("_music_id"))


func _test_run() -> void:
	SaveManager.data = SaveManager.default_profile()
	var game := await _new_game()
	_check.call(String(game.stage["id"]) == STAGE and _music() == "stage_osorezan", "partida: Osorezan com a música dela")
	await _host.get_tree().process_frame
	_check.call(game.world.built_views().size() >= 4 and game.world.art.water_slot == 5,
			"partida: terreno montado com o Sanzu na água do material especial")
	var opened := _run_until(game, 298.0, 4.0, func() -> bool: return game.bosses.has_boss(&"masakado"))
	_check.call(opened and not game.hud.dialogue_open() and GameClock.game_time >= 300.0,
			"partida: Masakado entra calado aos 5:00")
	var talk := _run_until(game, 445.0, 8.0, func() -> bool: return game.hud.dialogue_open())
	_check.call(talk and GameClock.game_time >= 450.0 and game.bosses.has_boss(&"datsueba")
			and game.hud.dialogue_panel().lines().size() == 4, "partida: a Datsue-ba fala aos 7:30 (4 falas com Aki)")
	game.hud.bot_answer()
	_check.call(not game.hud.dialogue_open() and _music() == "midboss", "partida: depois, a música do Guardião")
	await _free(game)
	SaveManager.data = SaveManager.default_profile()
	game = await _new_game("hana")
	_run_until(game, 445.0, 8.0, func() -> bool: return game.hud.dialogue_open())
	_check.call(game.hud.dialogue_open() and game.hud.dialogue_panel().lines().size() == 3,
			"partida: com Hana a Datsue-ba fala sem o aparte dela (3 falas)")
	game.hud.bot_answer()
	await _free(game)
	# Gashadokuro: o último chefe só nasce no Tokoyo.
	SaveManager.data = SaveManager.default_profile()
	game = await _new_game()
	game.apply_scenario("tokoyo")
	game.rift.begin_crossing()
	game.rift.finish_crossing_now()
	GameClock.paused = true
	var final := _run_until(game, 598.0, 4.0, func() -> bool: return game.hud.dialogue_open())
	_check.call(final and GameClock.game_time >= 600.0 and game.bosses.has_boss(&"gashadokuro")
			and game.hud.dialogue_panel().lines().size() == 4, "partida: a Gashadokuro fala aos 10:00 no Tokoyo")
	game.hud.bot_answer()
	_check.call(not game.hud.dialogue_open() and _music() == "boss_gashadokuro", "partida: depois, o tema da Gashadokuro")
	await _free(game)


func _test_story_queue() -> void:
	SaveManager.data = SaveManager.default_profile()
	var lose := {"victory": false, "stage": STAGE}
	var win := {"victory": true, "stage": STAGE}
	_check.call(App.stories_after(lose).is_empty() and App.stories_after(win).size() == 1
			and (App.stories_after(win)[0] as Array)[0] == &"osorezan_ending",
			"história: sem a Gashadokuro vencida, só o epílogo na vitória")
	(SaveManager.data["stats"]["bosses_defeated"] as Dictionary)["gashadokuro"] = 1
	var on_loss: Array = App.stories_after(lose)
	_check.call(on_loss.size() == 1 and (on_loss[0] as Array)[0] == &"kuon_freed",
			"história: a Gashadokuro vencida liberta Kuon mesmo sem a vitória")
	var on_win: Array = App.stories_after(win)
	_check.call(on_win.size() == 2 and (on_win[0] as Array)[0] == &"kuon_freed"
			and (on_win[1] as Array)[0] == &"osorezan_ending",
			"história: na 1ª vitória, a libertação e depois o epílogo")
	SaveManager.data["story"]["kuon_freed_seen"] = true
	SaveManager.data["story"]["osorezan_ending_seen"] = true
	_check.call(App.stories_after(win).is_empty(), "história: já vistas não tocam de novo")
	_check.call(App.stories_after({"victory": true, "stage": "secret"}).size() == 1,
			"história: o final secreto continua na vitória da fase secreta")
	_check.call(SaveManager.default_profile()["story"].has("kuon_freed_seen")
			and SaveManager.default_profile()["story"].has("osorezan_ending_seen"), "história: flags novas no perfil")


func _test_story_screen() -> void:
	var ctx := await _open_story(Vector2(600, 270), Vector2.ZERO)
	var screen: Control = ctx[1]
	_check.call(_music() == "lament", "história: a libertação de Kuon toca o Lamento")
	var seen := {}
	for k: int in 5:
		seen[String(screen.get("_scene_id"))] = true
		await _host.get_tree().process_frame
		if k < 4:
			screen.call("_advance")
	_check.call(seen.has("osorezan") and seen.has("sanzu"), "história: cenas osorezan e sanzu desenhadas (%s)",
			[seen.keys()])
	_close_story(ctx)
	await _host.get_tree().process_frame
	ctx = await _open_story(Vector2(600, 270), Vector2.ZERO, &"osorezan_ending")
	_check.call(_music() == "story", "história: o epílogo usa a música da história")
	_close_story(ctx)
	await _host.get_tree().process_frame


func _open_story(view: Vector2, insets: Vector2, id: StringName = &"kuon_freed") -> Array:
	DeviceProfiles.simulate_insets(insets)
	var area := Control.new()
	area.theme = ThemeFactory.build()
	area.size = view
	area.clip_contents = true
	_host.add_child(area)
	var app := App.new()
	var screen := (load(STORY) as GDScript).new() as Screen
	screen.app = app
	area.add_child(screen)
	await _host.get_tree().process_frame
	screen.call("play", id)
	await _host.get_tree().process_frame
	return [area, screen, app]


func _close_story(ctx: Array) -> void:
	(ctx[0] as Node).queue_free()
	(ctx[2] as Node).free()


## Tela da história: caixa do texto e botões dentro da área segura, em toda resolução, idioma e
## furo; o texto de cada painel da libertação de Kuon cabe na caixa.
func _test_story_layout() -> void:
	var panels: Array = (DB.story.get(&"kuon_freed", {}) as Dictionary).get("panels", [])
	for c: Dictionary in DeviceProfiles.layout_cases():
		var view: Vector2 = c["view"]
		var safe: Rect2 = DeviceProfiles.safe_rect(view, c["insets"])
		for lang: String in c["langs"]:
			Locale.set_language(lang, false)
			var ctx := await _open_story(view, c["insets"])
			var screen: Control = ctx[1]
			var tag := "história [%s, %s]" % [lang, c["label"]]
			var box := screen.find_child("TextBox", true, false) as Control
			var skip := screen.find_child("Skip", true, false) as Control
			var next := screen.find_child("Next", true, false) as Control
			var fits := true
			for k: int in panels.size():
				screen.set("_index", k)
				screen.call("_show_panel")
				await _host.get_tree().process_frame
				var text := screen.get("_text") as Label
				fits = fits and text.get_minimum_size().y <= box.size.y and text.size.x > 120.0
			var area_rect := Rect2(Vector2.ZERO, view)
			for node: Control in [box, skip, next]:
				var r := node.get_global_rect()
				_check.call(safe.grow(0.5).encloses(r) and area_rect.grow(0.5).encloses(r),
						"%s: %s dentro da área segura (%s)", [tag, node.name, r])
			_check.call(not skip.get_global_rect().intersects(next.get_global_rect())
					and not next.get_global_rect().intersects(box.get_global_rect()), "%s: botões sem sobrepor", tag)
			_check.call(fits, "%s: o texto de cada painel cabe na caixa", tag)
			_close_story(ctx)
			await _host.get_tree().process_frame
	DeviceProfiles.clear_insets()
	Locale.set_language("pt_BR", false)
