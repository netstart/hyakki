extends Node
## Roda tests/mission_tests.gd sozinho (Missões do Santuário: dados, condições, recompensas, save,
## Próximas metas, partida pelo bot, metas no título e nos Resultados), com os arquivos de save e
## opções próprios dos testes (o perfil do jogador não é tocado):
##   godot --headless --path . res://tests/mission_tests.tscn

const MissionTests := preload("res://tests/mission_tests.gd")

var _count: int = 0
var _failures: int = 0
## Lista também as verificações que passaram (-- --verbose).
var _verbose: bool = "--verbose" in OS.get_cmdline_user_args()


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	await MissionTests.new().run(self, _check)
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
