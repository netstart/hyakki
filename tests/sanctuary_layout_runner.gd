extends Node
## Roda tests/sanctuary_layout_tests.gd sozinho, com os autoloads e arquivos de save e opções
## próprios dos testes (o perfil do jogador não é tocado):
##   godot --headless --path . res://tests/sanctuary_layout_tests.tscn
## Com `-- --shots=<pasta>` (sem --headless) grava capturas do Santuário em PNG, em cada caso de
## tests/device_profiles.gd (sem recorte e com o furo da câmera de cada lado), em pt_BR e de
## (`--langs=pt_BR,ru` troca os idiomas).

const SanctuaryLayoutTests := preload("res://tests/sanctuary_layout_tests.gd")
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
		await SanctuaryLayoutTests.new().run(self, _check)
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


## Capturas: o perfil dos testes (comprável, sem ryō e no máximo) com um item selecionado.
func _screenshots(dir: String, langs: PackedStringArray) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var original := SaveManager.data
	var native := get_window().size
	for target: Vector2 in DeviceProfiles.views():
		var view: Vector2 = await DeviceProfiles.set_window_view(self, target)
		for c: Dictionary in DeviceProfiles.layout_cases():
			if c["view"] != target:
				continue
			DeviceProfiles.simulate_insets(c["insets"])
			for lang: String in langs:
				await _shot(dir, lang, view, c["insets"])
	DeviceProfiles.clear_insets()
	DisplayServer.window_set_size(native)
	SaveManager.data = original
	Locale.set_language("pt_BR", false)


func _shot(dir: String, lang: String, view: Vector2, insets: Vector2) -> void:
	Locale.set_language(lang, false)
	SaveManager.data = SaveManager.default_profile()
	SaveManager.data["ryo"] = 2500
	SaveManager.data["powerups"] = {"pu_might": 2, "pu_greed": 5, "pu_amount": 1}
	var app := App.new()
	add_child(app)
	await get_tree().process_frame
	# Sem a abertura do jogo por cima (o teste de layout não a vê, mas a captura sim).
	for node: Node in app.find_children("*", "SplashScreen", true, false):
		node.get_parent().queue_free()
	app.go(&"sanctuary")
	await get_tree().process_frame
	var screen := (app.get("_screens") as Dictionary)[&"sanctuary"] as Control
	screen.call("_select", &"pu_amount")
	await get_tree().create_timer(0.4).timeout
	# Faixa do furo da câmera pintada por cima, para ver o que ficaria embaixo dela.
	var band := ColorRect.new()
	band.color = Color(1, 0, 1, 0.35)
	band.size = Vector2(maxf(insets.x, insets.y), view.y)
	band.position.x = 0.0 if insets.x > 0.0 else view.x - insets.y
	band.visible = insets != Vector2.ZERO
	var layer := CanvasLayer.new()
	layer.layer = 128
	layer.add_child(band)
	add_child(layer)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var side := "sem_recorte" if insets == Vector2.ZERO else ("camera_esq" if insets.x > 0.0 else "camera_dir")
	var path := dir.path_join("sanctuary_%s_%s_%dx%d.png" % [lang, side, view.x, view.y])
	image.save_png(path)
	print("captura: " + path)
	layer.queue_free()
	app.queue_free()
	await get_tree().process_frame
