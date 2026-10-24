extends Node
## Roda tests/credits_screen_tests.gd sozinho, com os autoloads e arquivos de save e opções
## próprios dos testes (o perfil do jogador não é tocado):
##   godot --headless --path . res://tests/credits_screen_tests.tscn
## Com `-- --shots=<pasta>` (sem --headless) grava capturas dos Créditos em PNG (678x305):
## topo, meio, parte de baixo e fim da rolagem, em pt_BR e ja (`--langs=pt_BR,en` troca os idiomas).

const CreditsScreenTests := preload("res://tests/credits_screen_tests.gd")

var _count: int = 0
var _failures: int = 0
var _real_files: Dictionary = {}


func _ready() -> void:
	for path: String in [SaveManager.PATH, SaveManager.BACKUP_PATH, Settings.PATH]:
		_real_files[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	SaveManager.use_test_files()
	Settings.use_test_file()
	var shots := ""
	var langs: PackedStringArray = ["pt_BR", "ja"]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
		elif arg.begins_with("--langs="):
			langs = arg.trim_prefix("--langs=").split(",")
	if shots != "":
		await _screenshots(shots, langs)
	else:
		await CreditsScreenTests.new().run(self, _check)
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
	var tests := CreditsScreenTests.new()
	tests.set("_host", self)
	tests.set("_check", _check)
	for lang: String in langs:
		Locale.set_language(lang, false)
		var ctx: Array = await tests.open_screen()
		var screen := ctx[1] as Control
		var scroll := screen.get("_scroll") as ScrollContainer
		var content := scroll.get_child(0) as Control
		var stops := {"top": 0, "middle": int((content.size.y - scroll.size.y) * 0.4),
				"lower": int((content.size.y - scroll.size.y) * 0.75), "end": int(content.size.y)}
		for stop: String in stops:
			scroll.scroll_vertical = int(stops[stop])
			await get_tree().create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var path := dir.path_join("credits_%s_%s.png" % [stop, lang])
			image.save_png(path)
			print("captura: %s (%dx%d)" % [path, image.get_width(), image.get_height()])
		await tests.close(ctx)
	Locale.set_language("pt_BR", false)
