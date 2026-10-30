extends Node
## Roda tests/hud_layout_tests.gd sozinho, com os arquivos de save e opções próprios dos testes
## (o perfil do jogador não é tocado):
##   godot --headless --path . res://tests/hud_layout_tests.tscn
## Com `-- --shots=<pasta>` (sem --headless) abre uma partida de verdade (6 armas, 6 passivas,
## números grandes, joystick fixo) e grava capturas da HUD, do diálogo antes do chefe e do painel de Kami em cada
## resolução de tests/device_profiles.gd, sem recorte e com o furo da câmera de cada lado (a
## faixa do recorte aparece em vermelho); `--langs=pt_BR,de` troca os idiomas e
## `--views=678x305,480x270` limita as resoluções. O painel de Kami sai parado, com uma placa
## destacada e, em 678x305 sem recorte, quadros do voo das recompensas até a guardiã (pacto
## selado e "Continuar" de um baú).

const HudLayoutTests := preload("res://tests/hud_layout_tests.gd")
const DeviceProfiles := preload("res://tests/device_profiles.gd")
const TitleRunner := preload("res://tests/title_layout_runner.gd")
const LevelChestTests := preload("res://tests/level_chest_tests.gd")
## Quadros do voo (segundos depois do toque).
const FLIGHT_FRAMES := [0.1, 0.3, 0.5, 0.7, 0.9]

var _count: int = 0
var _failures: int = 0
var _real_files: Dictionary = {}


func _ready() -> void:
	for path: String in [SaveManager.PATH, SaveManager.BACKUP_PATH, Settings.PATH]:
		_real_files[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	SaveManager.use_test_files()
	Settings.use_test_file()
	var shots := ""
	var langs: PackedStringArray = ["pt_BR"]
	var views: PackedStringArray = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
		elif arg.begins_with("--langs="):
			langs = arg.trim_prefix("--langs=").split(",")
		elif arg.begins_with("--views="):
			views = arg.trim_prefix("--views=").split(",")
	if shots != "":
		await _screenshots(shots, langs, views)
	else:
		await HudLayoutTests.new().run(self, _check)
	GameClock.paused = false
	for path: String in SaveManager.TEST_PATHS + [Settings.TEST_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	for path: String in _real_files:
		var now := FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
		_check(now == _real_files[path], "testes não mexeram em %s do jogador" % path)
	print("%d verificações, %d falhas" % [_count, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: " + label)
	elif "--verbose" in OS.get_cmdline_user_args():
		print("ok: " + label)


func _screenshots(dir: String, langs: PackedStringArray, views: PackedStringArray = []) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var native := get_window().size
	Settings.set_value("joystick_mode", "fixed")
	SaveManager.data["stats"]["runs"] = 3
	SaveManager.data["tutorial_done"] = true
	var app := (load("res://scenes/app/App.tscn") as PackedScene).instantiate() as App
	add_child(app)
	await get_tree().process_frame
	for node: Node in app.find_children("*", "SplashScreen", true, false):
		node.get_parent().queue_free()
	for lang: String in langs:
		Locale.set_language(lang, false)
		for r: Dictionary in DeviceProfiles.shot_resolutions():
			if not views.is_empty() and not views.has(String(r["label"])):
				continue
			var view: Vector2 = await DeviceProfiles.set_window_view(self, r["view"])
			var cut := DeviceProfiles.cutout_logical(r)
			for insets: Vector2 in [Vector2.ZERO, Vector2(cut, 0.0), Vector2(0.0, cut)]:
				DeviceProfiles.simulate_insets(insets)
				await _start(app)
				var strip := TitleRunner.ShotStrip.new(view, insets)
				add_child(strip)
				var side := "sem" if insets == Vector2.ZERO else ("esq" if insets.x > 0.0 else "dir")
				await get_tree().create_timer(0.8).timeout
				await _shot(dir.path_join("hud_%s_%s_%dx%d.png" % [lang, side, view.x, view.y]))
				await _dialogue_shots(app, dir, "%s_%s_%dx%d" % [lang, side, view.x, view.y])
				var offer: Array[StringName] = [&"hachiman", &"inari", &"raijin"]
				app.game.open_kami(offer)
				var tag := "%s_%s_%dx%d" % [lang, side, view.x, view.y]
				await get_tree().create_timer(0.35).timeout
				await _shot(dir.path_join("kami_%s_deal.png" % tag))
				await get_tree().create_timer(1.2).timeout
				await _shot(dir.path_join("kami_%s.png" % tag))
				var panel := app.game.hud.kami_panel()
				panel.select(1)
				await get_tree().create_timer(0.5).timeout
				await _shot(dir.path_join("kami_%s_selected.png" % tag))
				if insets == Vector2.ZERO and r == DeviceProfiles.RESOLUTIONS[0]:
					await _flight_frames(app, dir, tag)
				else:
					panel.close_now()
					app.game.call("_on_kami_chosen", &"")
				strip.queue_free()
	DeviceProfiles.clear_insets()
	app.queue_free()
	await get_tree().process_frame
	DisplayServer.window_set_size(native)
	Locale.set_language("pt_BR", false)


## Diálogo antes do chefe: a 1ª fala (o chefe, à direita) subindo e parada, e a resposta da
## guardiã (à esquerda). O bot fecha e a partida volta a ficar parada para as próximas capturas.
func _dialogue_shots(app: App, dir: String, tag: String) -> void:
	var hud := app.game.hud
	app.game.open_dialogue(&"kappa_elder", func() -> void: pass)
	await get_tree().create_timer(0.1).timeout
	await _shot(dir.path_join("dialogue_%s_rise.png" % tag))
	hud.dialogue_panel().finish_intro()
	await get_tree().create_timer(0.5).timeout
	await _shot(dir.path_join("dialogue_%s_boss.png" % tag))
	var hero: Array[Dictionary] = [DialogueScript.build(&"kappa_elder", &"aki")[1]]
	hud.show_dialogue(hero)
	hud.dialogue_panel().finish_intro()
	await get_tree().create_timer(0.5).timeout
	await _shot(dir.path_join("dialogue_%s_hero.png" % tag))
	hud.bot_answer()
	GameClock.paused = true
	await get_tree().create_timer(0.3).timeout


## Pacto selado e "Continuar" de um baú: quadros dos ícones voando até a guardiã.
func _flight_frames(app: App, dir: String, tag: String) -> void:
	var hud := app.game.hud
	# Longe da aurora (a HUD cheia começa em 59:59): a partida segue enquanto os ícones voam.
	GameClock.game_time = 120.0
	hud.kami_panel().confirm()
	await get_tree().create_timer(KamiPanel.STAMP_TIME + 0.1).timeout
	await _shot(dir.path_join("flight_kami_%s_stamp.png" % tag))
	for at: float in FLIGHT_FRAMES:
		await get_tree().create_timer(FLIGHT_FRAMES[0] if at == FLIGHT_FRAMES[0] else 0.2).timeout
		await _shot(dir.path_join("flight_kami_%s_%03d.png" % [tag, roundi(at * 1000.0)]))
	await get_tree().create_timer(0.6).timeout
	GameClock.paused = true
	hud.show_chest(LevelChestTests.sample_rewards(5))
	hud.chest_panel().skip()
	await get_tree().create_timer(0.4).timeout
	await _shot(dir.path_join("flight_chest_%s_before.png" % tag))
	hud.chest_panel().button().pressed.emit()
	for at: float in FLIGHT_FRAMES:
		await get_tree().create_timer(FLIGHT_FRAMES[0] if at == FLIGHT_FRAMES[0] else 0.2).timeout
		await _shot(dir.path_join("flight_chest_%s_%03d.png" % [tag, roundi(at * 1000.0)]))
	await get_tree().create_timer(0.8).timeout
	GameClock.paused = true


## Partida nova com a HUD cheia: 6 armas, 6 passivas, números grandes, sem inimigos por perto.
func _start(app: App) -> void:
	if app.game:
		app.game.queue_free()
		app.game = null
		await get_tree().process_frame
		await get_tree().process_frame
	app.selection["hero"] = "aki"
	app.selection["stage"] = "village"
	app.selection["mode"] = "normal"
	app.start_run()
	for i: int in 3:
		await get_tree().process_frame
	var game := app.game
	# A janela da captura perde o foco no Windows; isso não pode abrir a pausa.
	game.set("_ad_in_progress", true)
	game.player.god_mode = true
	for id: Variant in DB.ids("weapons"):
		if game.weapons.size() >= LevelUpSystem.MAX_WEAPONS:
			break
		if not game.has_weapon(StringName(id)):
			game.add_weapon(StringName(id))
	var passives: Array = DB.ids("passives")
	for i: int in mini(LevelUpSystem.MAX_PASSIVES, passives.size()):
		game.level_up.passive_levels[StringName(passives[i])] = 3
	game.level = 99
	game.xp_needed = Progression.xp_to_next(game.level)
	game.xp = int(game.xp_needed * 0.62)
	game.tracker.kills = 999999
	game.tracker.ryo = 9999999
	game.ultimate.charge = 60.0
	GameClock.game_time = 59.0 * 60.0 + 59.0
	GameClock.paused = true


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("captura: %s" % path)
