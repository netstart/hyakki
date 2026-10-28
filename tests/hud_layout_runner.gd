extends Node
## Roda tests/hud_layout_tests.gd sozinho, com os arquivos de save e opções próprios dos testes
## (o perfil do jogador não é tocado):
##   godot --headless --path . res://tests/hud_layout_tests.tscn
## Com `-- --shots=<pasta>` (sem --headless) abre uma partida de verdade (6 armas, 6 passivas,
## números grandes, joystick fixo) e grava capturas da HUD e do painel de Kami em cada
## resolução de tests/device_profiles.gd, sem recorte e com o furo da câmera de cada lado (a
## faixa do recorte aparece em vermelho); `--langs=pt_BR,de` troca os idiomas.

const HudLayoutTests := preload("res://tests/hud_layout_tests.gd")
const DeviceProfiles := preload("res://tests/device_profiles.gd")
const TitleRunner := preload("res://tests/title_layout_runner.gd")

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
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
		elif arg.begins_with("--langs="):
			langs = arg.trim_prefix("--langs=").split(",")
	if shots != "":
		await _screenshots(shots, langs)
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


func _screenshots(dir: String, langs: PackedStringArray) -> void:
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
		for r: Dictionary in DeviceProfiles.RESOLUTIONS:
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
				var offer: Array[StringName] = [&"hachiman", &"inari", &"raijin"]
				app.game.open_kami(offer)
				await get_tree().create_timer(0.3).timeout
				await _shot(dir.path_join("kami_%s_%s_%dx%d.png" % [lang, side, view.x, view.y]))
				strip.queue_free()
	DeviceProfiles.clear_insets()
	app.queue_free()
	await get_tree().process_frame
	DisplayServer.window_set_size(native)
	Locale.set_language("pt_BR", false)


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
