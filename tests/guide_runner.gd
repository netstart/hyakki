extends Node
## Roda tests/guide_tests.gd sozinho (dados do Guia, tela e o layout de cada capítulo na
## resolução de referência), com os arquivos de save e opções próprios dos testes:
##   godot --headless --path . res://tests/guide_tests.tscn
## O layout em todas as resoluções, idiomas e com o furo dos dois lados roda em
## tests/menus_layout_tests.tscn (e em tests/integration_tests.tscn).

const GuideTests := preload("res://tests/guide_tests.gd")
const MenusLayoutTests := preload("res://tests/menus_layout_tests.gd")

var _count: int = 0
var _failures: int = 0


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	GuideTests.new().run_data(_check)
	await GuideTests.new().run(self, _check)
	var layout := MenusLayoutTests.new()
	layout.set("_host", self)
	layout.set("_check", _check)
	SaveManager.data = SaveManager.default_profile()
	await layout.call("_test_guide", MenusLayoutTests.main_view(), "pt_BR [referência]")
	for path: String in SaveManager.TEST_PATHS + [Settings.TEST_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("%d verificações, %d falhas" % [_count, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: " + label)
	elif "--verbose" in OS.get_cmdline_user_args():
		print("ok: " + label)
