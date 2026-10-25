extends Node
## Roda tests/level_chest_tests.gd sozinho, com os autoloads e arquivos de save e opções
## próprios dos testes (o perfil do jogador não é tocado):
##   godot --headless --path . res://tests/level_chest_tests.tscn
## Com `-- --shots=<pasta> [--gfx=low|high]` (sem --headless) grava capturas das telas de
## nova habilidade e do baú numa partida de verdade, em 678x305 e 480x270.

const LevelChestTests := preload("res://tests/level_chest_tests.gd")
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
	var langs: Array[String] = ["pt_BR"]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
		if arg.begins_with("--langs="):
			langs.assign(arg.trim_prefix("--langs=").split(","))
	if shots != "":
		await _screenshots(shots, langs)
	else:
		await LevelChestTests.new().run(self, _check)
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


func _screenshots(dir: String, langs: Array[String]) -> void:
	SaveManager.data = SaveManager.default_profile()
	SaveManager.data["stats"]["runs"] = 3
	var gfx := GfxQuality.mode()
	var window := get_window()
	var native := window.size
	var sizes := [native, Vector2i(960, 540)]
	for lang: String in langs:
		for wsize: Vector2i in sizes:
			Locale.set_language(lang, false)
			DisplayServer.window_set_size(wsize)
			await get_tree().create_timer(0.3).timeout
			PixelScaler.call("_apply")
			await get_tree().process_frame
			var view := get_tree().root.content_scale_size
			var tag := "%s_%s_%dx%d" % [gfx, lang, view.x, view.y]
			var game := await _game()
			_unpause(game)
			GameClock.paused = true
			game.hud.show_level_up(LevelChestTests.sample_cards(), 2, 1, 3)
			await _wait(0.3)
			await _save(dir.path_join("levelup_%s_deal.png" % tag))
			await _wait(1.0)
			await _save(dir.path_join("levelup_%s.png" % tag))
			var panel := game.hud.level_up_panel()
			panel.action_buttons()[2].pressed.emit()
			await _wait(0.2)
			await _save(dir.path_join("levelup_%s_banish.png" % tag))
			panel.action_buttons()[2].pressed.emit()
			await _wait(0.4)
			panel.level_cards()[1].pressed.emit()
			game.hud.hide_level_up()
			await _wait(0.12)
			await _save(dir.path_join("levelup_%s_fly.png" % tag))
			await _wait(1.0)
			for count: int in [5, 3, 1]:
				_unpause(game)
				GameClock.paused = true
				game.hud.show_chest(LevelChestTests.sample_rewards(count))
				if count == 5:
					for at: Array in [[0.2, "drop"], [1.15, "shake"], [1.62, "open"], [2.5, "items"]]:
						await _until(game, float(at[0]))
						await _save(dir.path_join("chest%d_%s_%s.png" % [count, tag, at[1]]))
				await _wait_end(game)
				await _wait(0.5)
				await _save(dir.path_join("chest%d_%s.png" % [count, tag]))
				game.hud.chest_panel().button().pressed.emit()
			game.queue_free()
			GameClock.paused = false
			await get_tree().process_frame
	window.size = native
	Locale.set_language("pt_BR", false)


## A janela das capturas perde o foco e o jogo abre a pausa sozinho: fecha.
func _unpause(game: HyakkiGame) -> void:
	if game.hud.pause_open():
		game.hud.hide_pause()


func _until(game: HyakkiGame, t: float) -> void:
	while float(game.hud.chest_panel().get("_t")) < t:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _wait_end(game: HyakkiGame) -> void:
	while game.hud.chest_animating():
		await get_tree().process_frame


## Partida com armas e itens, depois de alguns segundos de jogo (inimigos na tela).
func _game() -> HyakkiGame:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = {"hero": "aki", "stage": "village", "moon": 3, "mode": "normal", "seed": 9, "speed": 1}
	add_child(game)
	await get_tree().process_frame
	game.player.god_mode = true
	for id: StringName in [&"shuriken", &"ofuda", &"raijin"]:
		if not game.has_weapon(id):
			game.add_weapon(id)
	for id: StringName in [&"sake", &"jade"]:
		game.level_up.passive_levels[id] = 2
	game.level_up.apply_stats()
	game.level = 14
	GameClock.paused = false
	await _wait(5.0)
	return game


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("captura: " + path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw
