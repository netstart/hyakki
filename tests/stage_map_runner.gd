extends Node
## Roda tests/stage_map_layout_tests.gd sozinho, com os autoloads e arquivos de save e
## opções próprios dos testes (o perfil do jogador não é tocado):
##   godot --headless --path . res://tests/stage_map_layout_tests.tscn
## Com `-- --shots=<pasta>` (sem --headless) grava capturas da Jornada do Guardião em PNG
## (perfil novo; três fases vencidas com Lua II na primeira; idioma ja), em 2x.

const StageMapLayoutTests := preload("res://tests/stage_map_layout_tests.gd")

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
		await StageMapLayoutTests.new().run(self, _check)
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
	var tests := StageMapLayoutTests.new()
	tests.set("_host", self)
	tests.set("_check", _check)
	var cases := [["new", "pt_BR"], ["progress", "pt_BR"], ["progress", "ja"]]
	for extra: String in OS.get_cmdline_user_args():
		if extra.begins_with("--langs="):
			cases = []
			for lang: String in extra.trim_prefix("--langs=").split(","):
				cases.append(["progress", lang])
	for item: Array in cases:
		Locale.set_language(String(item[1]), false)
		if item[0] == "new":
			SaveManager.data = SaveManager.default_profile()
		else:
			SaveManager.data = StageMapLayoutTests.progress_profile(2, ["temple"])
			SaveManager.data["defeat_streak"] = {}
		var ctx: Array = await tests.open_screen("village" if item[0] == "new" else "")
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
		var path := dir.path_join("map_%s_%s.png" % [item[0], item[1]])
		image.save_png(path)
		print("captura: " + path)
		await tests.close(ctx)
	Locale.set_language("pt_BR", false)
