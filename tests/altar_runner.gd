extends Node
## Roda tests/altar_tests.gd e tests/elite_affix_tests.gd sozinhos (regras, ritual, Elite, poderes,
## emboscada, retomada e o bot), com os arquivos de save e opções próprios dos testes:
##   godot --headless --path . res://tests/altar_tests.tscn
## Com `-- --shots=<pasta>` (sem --headless) grava, em 678x305, o ritual, o estouro, o Elite
## surgindo, o rugido com o letreiro, os poderes e a morte; `--affixes=raijin,kongo` escolhe os
## afixos e `--gfx=low` confere a qualidade Baixa.

const AltarTests := preload("res://tests/altar_tests.gd")
const EliteAffixTests := preload("res://tests/elite_affix_tests.gd")
const DeviceProfiles := preload("res://tests/device_profiles.gd")
const GAME_SCENE := "res://scenes/game/Game.tscn"

var _count: int = 0
var _failures: int = 0
## Lista também as verificações que passaram (-- --verbose).
var _verbose: bool = "--verbose" in OS.get_cmdline_user_args()


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	var shots := ""
	var list: Array[StringName] = [&"raijin", &"kongo"]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
		elif arg.begins_with("--affixes="):
			list.clear()
			for id: String in arg.trim_prefix("--affixes=").split(",", false):
				list.append(StringName(id))
	if shots != "":
		await _screenshots(shots, list)
	else:
		AltarTests.new().run_unit(_check)
		EliteAffixTests.new().run_unit(_check)
		await AltarTests.new().run(self, _check)
		await EliteAffixTests.new().run(self, _check)
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


## A sequência inteira em tempo real, com a guardiã parada no círculo (invencível).
func _screenshots(dir: String, list: Array[StringName]) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	SaveManager.data["tutorial_done"] = true
	await DeviceProfiles.set_window_view(self, DeviceProfiles.main_view())
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = {"hero": "aki", "stage": "village", "moon": 0, "mode": "normal", "seed": 91, "speed": 1}
	add_child(game)
	await get_tree().process_frame
	game.set("_ad_in_progress", true)
	game.player.god_mode = true
	GameClock.game_time = 540.0
	game.spawner.skip_until(540.0)
	game.spawner.fixed_target = 24
	var at := game.altars.place_altar(game.player.sim_pos + Vector2(0, -26)) # chave
	var pos := game.player.sim_pos + Vector2(0, -26)
	game.altars.force_outcome = &"elite"
	game.altars.force_affixes = list
	var t0 := Time.get_ticks_msec()
	var marks := [[1.8, "1_ritual"], [3.62, "2_estouro"], [3.95, "3_raios"], [4.45, "4_surgindo"],
			[4.98, "5_rugido"], [5.6, "6_letreiro"], [9.0, "7_poderes"], [12.0, "8_poderes"]]
	for mark: Array in marks:
		while (Time.get_ticks_msec() - t0) / 1000.0 < float(mark[0]):
			game.player.move_input = Vector2.ZERO
			await get_tree().process_frame
		await _shot(dir.path_join("altar_%s.png" % mark[1]))
	print("altar %s estado %d" % [at, game.altars.state_at(pos)])
	for k: int in game.altars.affixes.records.keys():
		game.enemies.shield[k] = 0.0
		game.deal_damage(&"katana", k, 1e9, Vector2.RIGHT, 0.0)
	await get_tree().create_timer(0.12).timeout
	await _shot(dir.path_join("altar_9_morte.png"))
	await get_tree().create_timer(0.35).timeout
	await _shot(dir.path_join("altar_10_saque.png"))
	game.queue_free()
	await get_tree().process_frame


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("captura: %s" % path)
