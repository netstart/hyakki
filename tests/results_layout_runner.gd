extends Node
## Roda tests/results_layout_tests.gd sozinho, com os autoloads e arquivos de save e opções
## próprios dos testes (o perfil do jogador não é tocado):
##   godot --headless --path . res://tests/results_layout_tests.tscn
## Com `-- --shots=<pasta>` (sem --headless) também grava capturas da tela de Resultados
## (vitória, derrota e desistência) em PNG nessa pasta, em cada resolução de
## tests/device_profiles.gd, para conferir o visual.

const ResultsLayoutTests := preload("res://tests/results_layout_tests.gd")
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
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
	if shots != "":
		await _screenshots(shots)
	else:
		await ResultsLayoutTests.new().run(self, _check)
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


## Capturas: cada variante em pt_BR e alguns idiomas longos, com a entrada já terminada.
func _screenshots(dir: String) -> void:
	var tests := ResultsLayoutTests.new()
	tests.set("_host", self)
	tests.set("_check", _check)
	var cases := [["pt_BR", "defeat", 6], ["pt_BR", "victory", 6], ["pt_BR", "gave_up", 0],
			["de", "defeat", 10], ["ru", "victory", 4], ["ja", "defeat", 5], ["fr", "victory", 6]]
	var native := get_window().size
	for target: Vector2 in DeviceProfiles.views():
		var view: Vector2 = await DeviceProfiles.set_window_view(self, target)
		tests.use_case(view, Vector2.ZERO)
		for item: Array in cases:
			await _shot(dir, tests, item, view)
	DisplayServer.window_set_size(native)
	Locale.set_language("pt_BR", false)


func _shot(dir: String, tests: ResultsLayoutTests, item: Array, view: Vector2) -> void:
	Locale.set_language(String(item[0]), false)
	SaveManager.data = SaveManager.default_profile()
	SaveManager.data["stats"]["kills"] = 640
	var r := ResultsLayoutTests.make_result(String(item[1]), int(item[2]))
	if String(item[1]) == "defeat":
		r["prev_best_time"] = 300.0
	var screen: Control = await tests.call("_open", r)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := dir.path_join("results_%s_%s_%d_%dx%d.png" % [item[0], item[1], item[2], view.x, view.y])
	image.save_png(path)
	print("captura: " + path)
	tests.call("_close", screen)
	await get_tree().process_frame
