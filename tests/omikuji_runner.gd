extends Node
## Roda tests/omikuji_tests.gd sozinho (regras puras e jogo), com os autoloads e arquivos de
## save e opções próprios dos testes (o perfil do jogador não é tocado):
##   godot --headless --path . res://tests/omikuji_tests.tscn
## O layout do omikuji em todas as resoluções fica em tests/level_chest_tests.tscn.

const OmikujiTests := preload("res://tests/omikuji_tests.gd")

var _count: int = 0
var _failures: int = 0
var _real_files: Dictionary = {}


func _ready() -> void:
	for path: String in [SaveManager.PATH, SaveManager.BACKUP_PATH, Settings.PATH]:
		_real_files[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	SaveManager.use_test_files()
	Settings.use_test_file()
	var tests := OmikujiTests.new()
	tests.run_unit(_check)
	await tests.run(self, _check)
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
