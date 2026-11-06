extends Node
## Roda tests/red_moon_tests.gd sozinho (regras da Lua Vermelha), com os arquivos de save e opções
## próprios dos testes:
##   godot --headless --path . res://tests/red_moon_tests.tscn

const RedMoonTests := preload("res://tests/red_moon_tests.gd")

var _count: int = 0
var _failures: int = 0
## Lista também as verificações que passaram (-- --verbose).
var _verbose: bool = "--verbose" in OS.get_cmdline_user_args()


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	RedMoonTests.new().run_unit(_check)
	await RedMoonTests.new().run(self, _check)
	GameClock.paused = false
	for path: String in SaveManager.TEST_PATHS + [Settings.TEST_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("%d verificações, %d falhas" % [_count, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## `args` (opcional): valores do rótulo, que só é formatado (`label % args`) na falha ou com --verbose.
func _check(condition: bool, label: String, args: Variant = null) -> void:
	_count += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: " + (label if args == null else label % args))
	elif _verbose:
		print("ok: " + (label if args == null else label % args))
