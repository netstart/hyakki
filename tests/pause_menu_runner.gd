extends Node
## Roda tests/pause_menu_tests.gd sozinho, com os autoloads e arquivos de save e opções
## próprios dos testes (o perfil do jogador não é tocado):
##   godot --headless --path . res://tests/pause_menu_tests.tscn
## Com `-- --shots=<pasta>` (sem --headless) grava capturas em PNG: a pausa sobre uma partida
## de verdade (pt_BR, de, ru e ja em 20:9, pt_BR em 16:9), a confirmação de desistir e o canto
## da HUD (pausa + velocidade em 1x e 3x, ampliado 4x).

const PauseMenuTests := preload("res://tests/pause_menu_tests.gd")
const DeviceProfiles := preload("res://tests/device_profiles.gd")
const GAME_SCENE := "res://scenes/game/Game.tscn"

var _count: int = 0
var _failures: int = 0
var _real_files: Dictionary = {}


func _ready() -> void:
	for path: String in [SaveManager.PATH, SaveManager.BACKUP_PATH, Settings.PATH]:
		_real_files[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	SaveManager.use_test_files()
	Settings.use_test_file()
	var shots := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
	if shots != "":
		await _screenshots(shots)
	else:
		await PauseMenuTests.new().run(self, _check)
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


func _screenshots(dir: String) -> void:
	SaveManager.data = SaveManager.default_profile()
	SaveManager.data["stats"]["runs"] = 3
	var window := get_window()
	var native := window.size
	# Janela 2x de cada resolução de tests/device_profiles.gd (k = 2 dá a mesma tela lógica).
	var items: Array = []
	for view: Vector2 in DeviceProfiles.shot_views():
		for lang: String in ["pt_BR", "de", "ru", "ja"]:
			items.append([lang, Vector2i(view) * 2])
	for item: Array in items:
		Locale.set_language(String(item[0]), false)
		DisplayServer.window_set_size(item[1])
		await get_tree().create_timer(0.3).timeout
		PixelScaler.call("_apply")
		await get_tree().process_frame
		print("janela %s -> tela %s" % [window.size, get_tree().root.get_visible_rect().size])
		await get_tree().process_frame
		await get_tree().process_frame
		var view := get_tree().root.content_scale_size
		var game := await _game()
		var tag := "%s_%dx%d" % [item[0], view.x, view.y]
		if String(item[0]) == "pt_BR" and item[1] == Vector2i(DeviceProfiles.main_view()) * 2:
			for speed: int in [1, 3]:
				GameClock.speed = speed
				game.hud.refresh_speed()
				await _wait(0.4)
				_corner(dir.path_join("hud_corner_%dx.png" % speed))
				await _save(dir.path_join("hud_%dx.png" % speed))
			GameClock.speed = 1
			game.hud.refresh_speed()
		game.open_pause()
		await _wait(0.5)
		await _save(dir.path_join("pause_%s.png" % tag))
		if String(item[0]) in ["pt_BR", "de"]:
			(game.hud.pause_menu().get("_quit") as Button).pressed.emit()
			await _wait(0.4)
			await _save(dir.path_join("pause_confirm_%s.png" % tag))
		game.queue_free()
		GameClock.paused = false
		await get_tree().process_frame
	window.size = native
	Locale.set_language("pt_BR", false)


## Partida com 6 armas (uma evoluída) e itens, depois de alguns segundos de jogo.
func _game() -> HyakkiGame:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = {"hero": "aki", "stage": "village", "moon": 3, "mode": "normal", "seed": 9, "speed": 1}
	add_child(game)
	await get_tree().process_frame
	game.player.god_mode = true
	var added := 0
	for id: StringName in DB.ids("weapons"):
		if added >= 5 or game.weapons.size() >= 6:
			break
		if String(DB.weapon(id).get("kind", "base")) == "base" and not game.has_weapon(id):
			game.add_weapon(id)
			added += 1
	for i: int in range(game.weapons.size()):
		for k: int in range(i % 4 + (7 if i == 1 else 0)):
			game.weapons[i].level_up()
	for id: StringName in DB.ids("weapons"):
		if String(DB.weapon(id).get("kind", "base")) != "base" and game.weapons.size() < 6:
			game.add_weapon(id)
			break
	var n := 0
	for id: StringName in DB.passives:
		if n >= 4:
			break
		game.level_up.passive_levels[id] = 1 + n
		n += 1
	game.level_up.apply_stats()
	game.level = 17
	game.tracker.kills = 2843
	game.tracker.ryo = 512
	GameClock.paused = false
	await _wait(4.0)
	return game


func _corner(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var w := 110
	var crop := image.get_region(Rect2i(image.get_width() - w, 0, w, 48))
	crop.resize(w * 4, 48 * 4, Image.INTERPOLATE_NEAREST)
	crop.save_png(path)
	print("captura: " + path)


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("captura: " + path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw
