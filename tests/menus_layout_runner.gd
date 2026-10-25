extends Node
## Roda tests/menus_layout_tests.gd sozinho (Guardiões, Opções, Diário e botão "voltar"), com
## os arquivos de save e opções próprios dos testes (o perfil do jogador não é tocado):
##   godot --headless --path . res://tests/menus_layout_tests.tscn
## Com `-- --shots=<pasta>` (sem --headless) grava capturas das três telas em 678x305 e
## 480x270, nos níveis gráficos Baixa e Alta, para conferir o visual.

const MenusLayoutTests := preload("res://tests/menus_layout_tests.gd")

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
		await MenusLayoutTests.new().run(self, _check)
	GfxQuality.clear_override()
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


## Capturas: cada tela em pt_BR (e alguns idiomas longos) nos dois tamanhos e níveis.
## `--only=heroes|options|codex` limita a uma tela; `--langs=pt_BR,de` aos idiomas dados.
func _screenshots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var only := ""
	var langs: PackedStringArray = ["pt_BR"]
	var variants: Array[String] = MenusLayoutTests.SHOT_VARIANTS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		elif arg.begins_with("--langs="):
			langs = arg.trim_prefix("--langs=").split(",")
		elif arg.begins_with("--variants="):
			variants.assign(arg.trim_prefix("--variants=").split(","))
	var tests := MenusLayoutTests.new()
	for lang: String in langs:
		Locale.set_language(lang, false)
		for level: int in [GfxQuality.LOW, GfxQuality.HIGH]:
			GfxQuality.set_override(level)
			var tag := "low" if level == GfxQuality.LOW else "high"
			for view: Vector2 in [Vector2(678, 305), Vector2(480, 270)]:
				for variant: String in variants:
					var screen_name := variant.get_slice(":", 0)
					if only != "" and screen_name != only:
						continue
					get_window().size = Vector2i(view) * 2
					get_window().content_scale_size = Vector2i(view)
					await get_tree().process_frame
					var opened: Control = await tests.open_screen(self, view, screen_name, true)
					await tests.prepare_variant(self, opened, variant)
					await get_tree().create_timer(0.9).timeout
					await RenderingServer.frame_post_draw
					var image := get_viewport().get_texture().get_image()
					image.crop(int(view.x), int(view.y))
					var path := dir.path_join("%s_%s_%dx%d_%s.png" % [variant.replace(":", "_"), lang,
							view.x, view.y, tag])
					image.save_png(path)
					print("captura: " + path)
					tests.close_screen(opened)
					await get_tree().process_frame
	Locale.set_language("pt_BR", false)
