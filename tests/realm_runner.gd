extends Node
## Roda tests/realm_tests.gd sozinho (dados, travessia, outro mundo, retomada e cenários), com os
## arquivos de save e opções próprios dos testes (o perfil do jogador não é tocado):
##   godot --headless --path . res://tests/realm_tests.tscn
## Com `-- --shots=<pasta>` (sem --headless) grava, em 678x305 e para cada fase, o Guardião do
## Limiar (entrada com o painel e em campo, de perto), o portal com os dois baús, a seta do portal
## fora da tela, o redemoinho, o título da travessia e o outro mundo; depois, no Kakuriyo, o torii
## dourado da Sombra com os baús, a seta dourada, o redemoinho e o título do Tokoyo e o Tokoyo;
## `--stages=village,yomi` escolhe as fases.

const RealmTests := preload("res://tests/realm_tests.gd")
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
	var stages: PackedStringArray = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
		elif arg.begins_with("--stages="):
			stages = arg.trim_prefix("--stages=").split(",")
	if shots != "":
		await _screenshots(shots, stages)
	else:
		RealmTests.new().run_unit(_check)
		await RealmTests.new().run(self, _check)
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


func _screenshots(dir: String, stages: PackedStringArray) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	SaveManager.data["tutorial_done"] = true
	await DeviceProfiles.set_window_view(self, DeviceProfiles.main_view())
	for id: StringName in DB.ids("stages"):
		if not stages.is_empty() and not stages.has(String(id)):
			continue
		var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
		game.config = {"hero": "aki", "stage": String(id), "moon": 0, "mode": "normal", "seed": 77, "speed": 1}
		add_child(game)
		await get_tree().process_frame
		# A janela da captura perde o foco no Windows; isso não pode abrir a pausa.
		game.set("_ad_in_progress", true)
		await _midboss_shots(game, dir, String(id))
		game.apply_scenario("portal")
		game.rift.portal_age = 2.0  # já aberto: o loop, não o primeiro quadro da abertura
		game.enemies.reset()
		GameClock.paused = true
		await get_tree().create_timer(0.8).timeout
		await _shot(dir.path_join("%s_1_portal.png" % id))
		game.player.sim_pos += Vector2(-420.0, 160.0)
		game.player.prev_pos = game.player.sim_pos
		await get_tree().create_timer(0.4).timeout
		await _shot(dir.path_join("%s_2_seta.png" % id))
		game.pickups.items.clear()
		game.rift.portal_pos = game.player.sim_pos
		GameClock.paused = false
		await get_tree().process_frame
		await get_tree().create_timer(RiftPortal.CROSS_IN * 0.6).timeout
		await _shot(dir.path_join("%s_3_redemoinho.png" % id))
		await get_tree().create_timer(RiftPortal.CROSS_IN * 0.4 + 0.35).timeout
		await _shot(dir.path_join("%s_4_titulo.png" % id))
		await get_tree().create_timer(RiftPortal.CROSS_HOLD + RiftPortal.CROSS_OUT).timeout
		game.enemies.reset()
		GameClock.paused = true
		await get_tree().create_timer(0.6).timeout
		await _shot(dir.path_join("%s_5_kakuriyo.png" % id))
		await _tokoyo_shots(game, dir, String(id))
		game.queue_free()
		await get_tree().process_frame


## No Kakuriyo: o torii dourado com os dois baús, a seta dourada fora da tela, a travessia para o
## Tokoyo (redemoinho e título) e o Tokoyo.
func _tokoyo_shots(game: HyakkiGame, dir: String, id: String) -> void:
	GameClock.paused = false
	game.apply_scenario("portal2")
	game.rift.portal_age = 2.0
	game.enemies.reset()
	GameClock.paused = true
	await get_tree().create_timer(0.8).timeout
	await _shot(dir.path_join("%s_6_torii_dourado.png" % id))
	game.player.sim_pos += Vector2(-420.0, 160.0)
	game.player.prev_pos = game.player.sim_pos
	await get_tree().create_timer(0.4).timeout
	await _shot(dir.path_join("%s_7_seta_dourada.png" % id))
	game.pickups.items.clear()
	game.rift.portal_pos = game.player.sim_pos
	GameClock.paused = false
	await get_tree().process_frame
	await get_tree().create_timer(RiftPortal.CROSS_IN * 0.6).timeout
	await _shot(dir.path_join("%s_8_redemoinho_tokoyo.png" % id))
	await get_tree().create_timer(RiftPortal.CROSS_IN * 0.4 + 0.35).timeout
	await _shot(dir.path_join("%s_9_titulo_tokoyo.png" % id))
	await get_tree().create_timer(RiftPortal.CROSS_HOLD + RiftPortal.CROSS_OUT).timeout
	game.enemies.reset()
	GameClock.paused = true
	await get_tree().create_timer(0.6).timeout
	await _shot(dir.path_join("%s_10_tokoyo.png" % id))


## O Guardião da fase entra perto da guardiã (painel de entrada) e, depois, parado em campo.
func _midboss_shots(game: HyakkiGame, dir: String, id: String) -> void:
	var mid := RiftPortal.midboss_of(game.stage)
	GameClock.paused = true
	game.bosses.spawn(StringName(mid["id"]), false)
	var i := int(game.bosses.bosses[0]["index"])
	game.enemies.pos[i] = game.player.sim_pos + Vector2(70.0, -6.0)
	game.enemies.prev[i] = game.enemies.pos[i]
	game.enemies.born[i] = GameClock.game_time - 5.0
	await get_tree().create_timer(1.0).timeout
	await _shot(dir.path_join("%s_0a_guardiao_entrada.png" % id))
	await get_tree().create_timer(3.0).timeout
	await _shot(dir.path_join("%s_0b_guardiao.png" % id))
	game.bosses.reset()
	game.enemies.despawn(i)
	game.hud.hide_boss()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("captura: %s" % path)
