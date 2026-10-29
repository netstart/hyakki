extends Node
## Roda tests/title_layout_tests.gd sozinho, com os arquivos de save e opções próprios dos testes
## (o perfil do jogador não é tocado):
##   godot --headless --path . res://tests/title_layout_tests.tscn
## Com `-- --shots=<pasta>` (sem --headless) grava capturas do título em cada resolução de
## tests/device_profiles.gd, sem recorte e com o furo da câmera de cada lado (a faixa do
## recorte aparece em vermelho), com partida suspensa; `--langs=pt_BR,de` troca os idiomas.

const TitleLayoutTests := preload("res://tests/title_layout_tests.gd")
const DeviceProfiles := preload("res://tests/device_profiles.gd")

var _count: int = 0
var _failures: int = 0
var _real_files: Dictionary = {}


func _ready() -> void:
	for path: String in [SaveManager.PATH, SaveManager.BACKUP_PATH, Settings.PATH]:
		_real_files[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	SaveManager.use_test_files()
	Settings.use_test_file()
	var shots := ""
	var langs: PackedStringArray = ["pt_BR", "de"]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
		elif arg.begins_with("--langs="):
			langs = arg.trim_prefix("--langs=").split(",")
	if shots != "":
		await _screenshots(shots, langs)
	else:
		await TitleLayoutTests.new().run(self, _check)
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
	var tests := TitleLayoutTests.new()
	var native := get_window().size
	var original := SaveManager.data
	for r: Dictionary in DeviceProfiles.shot_resolutions():
		var view: Vector2 = await DeviceProfiles.set_window_view(self, r["view"])
		var cut := DeviceProfiles.cutout_logical(r)
		for insets: Vector2 in [Vector2.ZERO, Vector2(cut, 0.0), Vector2(0.0, cut)]:
			DeviceProfiles.simulate_insets(insets)
			for lang: String in langs:
				Locale.set_language(lang, false)
				tests.call("_setup", true, true)
				var app := App.new()
				add_child(app)
				await get_tree().process_frame
				for node: Node in app.find_children("*", "SplashScreen", true, false):
					node.get_parent().queue_free()
				app.go(&"title")
				var screen := (app.get("_screens") as Dictionary)[&"title"] as Control
				await get_tree().process_frame
				screen.call("_finish_intro")
				var strip := ShotStrip.new(view, insets)
				add_child(strip)
				await get_tree().create_timer(0.6).timeout
				await RenderingServer.frame_post_draw
				var side := "sem" if insets == Vector2.ZERO else ("esq" if insets.x > 0.0 else "dir")
				var path := dir.path_join("title_%s_%s_%dx%d.png" % [lang, side, view.x, view.y])
				get_viewport().get_texture().get_image().save_png(path)
				print("captura: %s" % path)
				strip.queue_free()
				app.queue_free()
				await get_tree().process_frame
	DeviceProfiles.clear_insets()
	SaveManager.data = original
	DisplayServer.window_set_size(native)
	Locale.set_language("pt_BR", false)


## Faixa vermelha translúcida onde fica o recorte da câmera (só nas capturas).
class ShotStrip extends CanvasLayer:
	func _init(view: Vector2, insets: Vector2) -> void:
		layer = 120
		for rect: Rect2 in [Rect2(0, 0, insets.x, view.y), Rect2(view.x - insets.y, 0, insets.y, view.y)]:
			if rect.size.x <= 0.0:
				continue
			var strip := ColorRect.new()
			strip.color = Color(1, 0, 0, 0.35)
			strip.position = rect.position
			strip.size = rect.size
			strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(strip)
