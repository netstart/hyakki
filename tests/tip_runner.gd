extends Node
## Roda tests/tip_tests.gd sozinho (catálogo, regras, balão do título, cartão dos Resultados e a
## opção "Dicas"), com os arquivos de save e opções próprios dos testes (o perfil do jogador não é
## tocado):
##   godot --headless --path . res://tests/tip_tests.tscn

const TipTests := preload("res://tests/tip_tests.gd")

var _count: int = 0
var _failures: int = 0


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	TipTests.new().run_unit(_check)
	await TipTests.new().run(self, _check)
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
