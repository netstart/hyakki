extends Node
## Roda tests/ability_tests.gd sozinho (energias, AbilitySystem, primitivas, Aki, save e o bot),
## com os arquivos de save e opções próprios dos testes (o perfil do jogador não é tocado):
##   godot --headless --path . res://tests/ability_tests.tscn

const AbilityTests := preload("res://tests/ability_tests.gd")

var _count: int = 0
var _failures: int = 0


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	AbilityTests.new().run_unit(_check)
	await AbilityTests.new().run(self, _check)
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
