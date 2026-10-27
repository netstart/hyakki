extends Node
## Capturas da loja (Google Play): abre o jogo de verdade (App.tscn), leva cada tela ou
## momento de partida ao ponto certo e salva o quadro na tela lógica real do jogo, 678×305
## (a do aparelho alvo, Redmi 2712×1220 em escala 4), sem mexer em nenhum layout. Depois
## tools/make_store_art.gd amplia ×2/×3 (vizinho mais próximo) dentro das molduras 16:9.
##
## Uso (precisa de janela, não roda --headless):
##   Godot_v4.7.2-stable_win64.exe --path . res://tools/store_capture.tscn -- \
##       --out=C:/caminho/absoluto [--lang=pt_BR] [--only=combat,boss] --ads-off
## `--ads-off` (lido pelo AdsManager) deixa a interface como na v1: sem botões de anúncio.
## O save e as opções do jogador não são tocados: usa os arquivos de teste
## (SaveManager.use_test_files / Settings.use_test_file) com um perfil de vitrine.
## Qualidade gráfica forçada em Alta.

const NATIVE := Vector2i(678, 305)

var out_dir := ""
var lang := "pt_BR"
var only: PackedStringArray = []
var app: App


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--lang="):
			lang = arg.trim_prefix("--lang=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",", false)
	if out_dir.is_empty():
		out_dir = ProjectSettings.globalize_path("res://build/store_capture")
	DirAccess.make_dir_recursive_absolute(out_dir)
	if not OS.get_cmdline_user_args().has("--ads-off"):
		push_warning("store_capture: sem --ads-off a interface mostra botões de anúncio")
	# O PixelScaler do jogo usa k = round(altura / 300): na janela 1356×610, k = 2 e a tela
	# lógica fica em 678×305, exatamente a do aparelho alvo.
	DisplayServer.window_set_size(NATIVE * 2)
	await _frames(3)
	if get_tree().root.content_scale_size != NATIVE:
		push_error("store_capture: tela lógica %s (esperado %s)" % [get_tree().root.content_scale_size, NATIVE])
	SaveManager.use_test_files()
	Settings.use_test_file()
	Settings.set_value("graphics_quality", "high")
	Settings.set_value("speed", 1)
	GfxQuality.set_override(GfxQuality.HIGH)
	Locale.set_language(lang, false)
	_seed_profile()
	app = (load("res://scenes/app/App.tscn") as PackedScene).instantiate() as App
	add_child(app)
	await _frames(2)
	_skip_splash()
	await _run_all()
	print("STORE CAPTURE DONE")
	get_tree().quit()


## Quadros em que os números de dano poluiriam a cena (o efeito da arma fala por si).
const QUIET := ["combat", "combat_temple", "combat2", "ult", "boss3"]


## Diz se a captura `name` foi pedida e já ajusta os números de dano para ela.
func _wants(name: String) -> bool:
	var wanted := only.is_empty() or only.has(name)
	if wanted:
		Settings.set_value("damage_numbers", name not in QUIET)
	return wanted


func _run_all() -> void:
	# --- Telas ---------------------------------------------------------------------
	if _wants("title"):
		app.go(&"title")
		await _seconds(3.0)
		await _shot("title")
	if _wants("heroes"):
		app.selection["hero"] = "aki"
		app.go(&"heroes")
		await _seconds(2.5)
		await _shot("heroes")
	if _wants("stages"):
		app.selection["stage"] = "temple"
		app.go(&"stages")
		await _seconds(2.5)
		await _shot("stages")
	if _wants("sanctuary"):
		app.go(&"sanctuary")
		await _seconds(2.5)
		await _shot("sanctuary")
	if _wants("codex"):
		app.go(&"codex")
		await _seconds(2.5)
		await _shot("codex")
	# --- Partidas ------------------------------------------------------------------
	if _wants("combat"):
		await _start("aki", "village", 12.0 * 60.0, ["dawn_blade", "thousand_needles", "raikiri",
				"amaterasu_barrier", "takemikazuchi", "fujin_hurricane"], 5.0)
		app.game.spawner.ring(&"shade_ghost", 56)
		app.game.spawner.ring(&"skeleton_peasant", 44)
		await _seconds(1.6)
		await _shot("combat")
	if _wants("combat_temple"):
		await _start("rin", "temple", 12.5 * 60.0, ["hachiman_arrow", "kunai", "raikiri", "ofuda",
				"ritual_thunder", "hitodama"], 5.0)
		app.game.spawner.ring(&"lantern_obake", 60)
		await _seconds(1.8)
		await _shot("combat_temple")
	if _wants("combat2"):
		await _start("hana", "bamboo", 9.0 * 60.0, ["amaterasu_barrier", "hitodama", "raijin_fury",
				"steel_storm", "ritual_thunder", "smoke_bomb"], 6.0)
		app.game.spawner.procession(&"bamboo_spirit", 60)
		await _seconds(3.0)
		await _shot("combat2")
	if _wants("combat_dunes"):
		await _start("goro", "dunes", 10.5 * 60.0, ["temple_smoke", "reaper_chain", "takemikazuchi",
				"inazuma", "fujin_fan", "shuriken"], 6.0)
		app.game.spawner.ring(&"flame_spirit", 50)
		await _seconds(1.8)
		await _shot("combat_dunes")
	if _wants("ult"):
		await _start("aki", "yomi", 11.0 * 60.0, ["dawn_blade", "thousand_needles", "raikiri",
				"amaterasu_barrier", "takemikazuchi"], 5.0)
		app.game.spawner.ring(&"yurei", 60)
		await _seconds(1.2)
		app.game.ultimate.fill()
		app.game.ultimate.activate()
		await _seconds(0.35)
		await _shot("ult")
		await _seconds(0.5)
		await _shot("ult_b")
	if _wants("pause"):
		await _start("aki", "village", 13.0 * 60.0, ["dawn_blade", "thousand_needles", "raikiri",
				"amaterasu_barrier", "takemikazuchi", "fujin_hurricane"], 4.0)
		app.game.open_pause()
		await _seconds(1.5)
		await _shot("pause")
	if _wants("levelup"):
		await _start("kenta", "dunes", 6.0 * 60.0, ["kunai", "shuriken", "raijin", "taiko"], 6.0)
		app.game.set("_bot", false)
		app.game.set("_pending_levels", 1)
		await _seconds(1.5)
		await _shot("levelup")
	if _wants("boss"):
		await _start("yuki", "temple", 4.6 * 60.0, ["dojigiri", "kaminari", "inazuma", "yumi"], 2.0)
		app.game.bosses.spawn(&"tengu_crow_king")
		await _seconds(6.0)
		await _shot("boss")
	if _wants("boss2"):
		await _start("tora", "yomi", 9.6 * 60.0, ["reaper_chain", "onikiri", "raikiri", "hachiman_arrow",
				"temple_smoke"], 2.0)
		app.game.bosses.spawn(&"red_oni")
		await _seconds(6.0)
		await _shot("boss2")
	if _wants("boss3"):
		await _start("aki", "bamboo", 9.8 * 60.0, ["dawn_blade", "raijin_fury", "thousand_needles",
				"amaterasu_barrier"], 2.0)
		app.game.bosses.spawn(&"kitsune_nine")
		await _seconds(7.0)
		await _shot("boss3")
	if _wants("chest"):
		await _start("goro", "village", 5.2 * 60.0, ["incense", "kusarigama", "ofuda"], 4.0)
		app.game.set("_bot", false)
		(app.game.get("_pending_chests") as Array).append(true)
		await _seconds(3.5)
		await _shot("chest")
	if _wants("dawn") or _wants("results"):
		await _start("aki", "village", HyakkiGame.RUN_LENGTH - 20.0, ["dawn_blade", "thousand_needles",
				"amaterasu_barrier", "raikiri", "takemikazuchi"], 0.0)
		# Sem o piloto automático (ele recomeçaria a partida no fim): anda segurando a direção.
		app.game.set("_bot", false)
		app.game.xp_needed = 1 << 30
		Input.action_press(&"move_right", 0.5)
		await _seconds(13.0)
		if _wants("dawn"):
			await _shot("dawn")
		await _wait_for(func() -> bool: return app.current == &"results", 30.0)
		Input.action_release(&"move_right")
		await _seconds(3.0)
		await _seconds(0.5)
		if _wants("results"):
			await _shot("results")


## Começa uma partida já avançada: tempo, ondas, armas no nível máximo e guardiã invulnerável
## andando sozinha (piloto automático do jogo), e espera `settle` segundos de ação.
func _start(hero: String, stage: String, time: float, weapon_ids: Array, settle: float) -> void:
	if app.game:
		app.game.queue_free()
		app.game = null
		await _frames(2)
	app.selection["hero"] = hero
	app.selection["stage"] = stage
	app.selection["mode"] = "normal"
	app.start_run()
	await _frames(3)
	var game := app.game
	game.set("_bot", true)
	# A janela da captura perde o foco no Windows; isso não pode abrir a pausa.
	game.set("_ad_in_progress", true)
	game.player.god_mode = true
	for id: String in weapon_ids:
		var base := _base_of(StringName(id))
		if base != &"" and game.has_weapon(base):
			game.evolve_weapon(base)
		elif not game.has_weapon(StringName(id)):
			game.add_weapon(StringName(id))
	for weapon: Weapon in game.weapons:
		while weapon.level < weapon.max_level:
			weapon.level_up()
	game.level = 18 + weapon_ids.size() * 3
	game.xp_needed = Progression.xp_to_next(game.level)
	game.xp = int(game.xp_needed * 0.62)
	game.tracker.kills = int(time * 2.1)
	game.tracker.ryo = int(time * 0.9)
	game.ultimate.charge = 60.0
	GameClock.game_time = time
	game.spawner.skip_until(time)
	await _seconds(settle)


static func _base_of(evolved: StringName) -> StringName:
	for id: Variant in DB.weapons.keys():
		if StringName(String((DB.weapons[id] as Dictionary).get("evolution", ""))) == evolved:
			return StringName(String(id))
	return &""


func _skip_splash() -> void:
	for node: Node in app.find_children("*", "SplashScreen", true, false):
		node.get_parent().queue_free()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("SHOT %s %dx%d" % [path, img.get_width(), img.get_height()])


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _wait_for(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await _seconds(0.25)
		t += 0.25
	return false


## Perfil de vitrine: um jogador com algumas noites vencidas (fases, bestiário, Santuário).
func _seed_profile() -> void:
	var d := SaveManager.data
	d["ryo"] = 12840
	d["ryo_total"] = 48210
	d["consent"] = {"asked": true, "personalized": false}
	d["story"] = {"intro_seen": true, "ending_seen": false, "secret_ending_seen": false}
	d["tutorial_done"] = true
	d["launches"] = 30
	d["purchases"]["remove_open_ad"] = true
	var unlocked: Dictionary = d["unlocked"]
	unlocked["stages"] = ["village", "bamboo", "temple", "dunes", "yomi"]
	unlocked["weapons"] = DB.weapons.keys().map(func(k: Variant) -> String: return String(k))
	unlocked["passives"] = DB.passives.keys().map(func(k: Variant) -> String: return String(k))
	var stats: Dictionary = d["stats"]
	stats["kills"] = 48231
	stats["runs"] = 37
	stats["wins"] = 9
	stats["time_played"] = 36000.0
	var kills: Dictionary = {}
	for id: Variant in DB.enemies.keys():
		kills[String(id)] = 180
	stats["kills_by_enemy"] = kills
	var bosses: Dictionary = {}
	for id: Variant in DB.bosses.keys():
		if String(id) not in ["izanami", "shinigami", "kuroe"]:
			bosses[String(id)] = 2
	stats["bosses_defeated"] = bosses
	stats["evolved"] = ["dawn_blade", "thousand_needles", "amaterasu_barrier", "raikiri", "takemikazuchi"]
	var levels := {}
	var i := 0
	for id: Variant in DB.powerups.keys():
		var top := int((DB.powerups[id] as Dictionary).get("max", 1))
		levels[String(id)] = [top, top - 1, 1, 2, top, 0][i % 6] if top > 0 else 0
		i += 1
	d["powerups"] = levels
	for stage: String in ["village", "bamboo", "temple"]:
		var best := SaveManager.stage_best(StringName(stage))
		best["won"] = true
		best["max_moon"] = 1
		best["best_time"] = HyakkiGame.RUN_LENGTH
	d["selected"] = {"hero": "aki", "stage": "village", "moon": 0, "mode": "normal", "cosmetic": ""}
	SaveManager.save_profile()
