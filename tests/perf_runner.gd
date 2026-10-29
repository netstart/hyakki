extends Node
## Roda sozinhos os testes de desempenho e rolagem (tests/perf_tests.gd) e os do fundo dos
## menus (tests/menu_backdrop_tests.gd), com os arquivos de save e opções dos testes:
##   godot --headless --path . res://tests/perf_tests.tscn

const PerfTests := preload("res://tests/perf_tests.gd")
const MenuBackdropTests := preload("res://tests/menu_backdrop_tests.gd")

var _count: int = 0
var _failures: int = 0


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	PerfTests.new().run_unit(_check)
	await MenuBackdropTests.new().run(self, _check)
	await PerfTests.new().run(self, _check)
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
