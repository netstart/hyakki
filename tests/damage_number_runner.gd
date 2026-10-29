extends Node
## Roda tests/damage_number_tests.gd sozinho, com os arquivos de save e opções próprios dos testes:
##   godot --headless --path . res://tests/damage_number_tests.tscn
## Com `-- --shots=<pasta>` (sem --headless) grava, em 678x305, todos os tipos de número na fase
## do bambu e no outro mundo claro (Kakuriyo), na paleta normal e na de daltonismo, no meio do
## soco de escala e já assentados, mais um recorte ampliado 3x em volta da guardiã.

const DamageNumberTests := preload("res://tests/damage_number_tests.gd")
const DamageNumberFlowTests := preload("res://tests/damage_number_flow_tests.gd")
const DamageNumberDensityTests := preload("res://tests/damage_number_density_tests.gd")
const DeviceProfiles := preload("res://tests/device_profiles.gd")
const GAME_SCENE := "res://scenes/game/Game.tscn"
const K := DamagePalette.Kind

var _count: int = 0
var _failures: int = 0


func _ready() -> void:
	SaveManager.use_test_files()
	Settings.use_test_file()
	var shots := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
	if shots != "":
		await _screenshots(shots)
	else:
		DamageNumberTests.new().run_unit(_check)
		DamageNumberDensityTests.new().run_unit(_check)
		await DamageNumberTests.new().run(self, _check)
		await DamageNumberFlowTests.new().run(self, _check)
		await DamageNumberDensityTests.new().run(self, _check)
	GameClock.paused = false
	Settings.set_value("colorblind", false)
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


func _screenshots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	SaveManager.data["tutorial_done"] = true
	await DeviceProfiles.set_window_view(self, DeviceProfiles.main_view())
	for realm: bool in [false, true]:
		var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
		game.config = {"hero": "aki", "stage": "bamboo", "moon": 0, "mode": "normal", "seed": 77, "speed": 1}
		add_child(game)
		await get_tree().process_frame
		# A janela da captura perde o foco no Windows; isso não pode abrir a pausa.
		game.set("_ad_in_progress", true)
		if realm:
			game.apply_scenario("realm")
			await get_tree().create_timer(RiftPortal.CROSS_IN + RiftPortal.CROSS_HOLD + RiftPortal.CROSS_OUT + 0.3).timeout
		game.enemies.reset()
		game.pickups.items.clear()
		var at := game.player.sim_pos
		for k: int in range(4):
			game.enemies.spawn(&"slime_rice", at + Vector2(-90.0 + 60.0 * k, -40.0 + 20.0 * (k % 2)), 99999.0, 1.0)
		GameClock.paused = true
		await get_tree().create_timer(0.3).timeout
		var place := "kakuriyo" if realm else "bambu"
		# Números parados no tempo: a FxLayer não avança; cada captura escolhe a idade.
		game.fx.set_process(false)
		game.fx.numbers.guard = game.player.position
		for colorblind: bool in [false, true]:
			game.fx.numbers.set_colorblind(colorblind)
			var tag := "%s_%s" % [place, "daltonismo" if colorblind else "normal"]
			game.fx.numbers.reset()
			_spawn_all(game, at)
			await _age_shot(game, 0.3, dir.path_join("%s_tipos.png" % tag), at)
		if not realm:
			await _crit_sequence(game, at, dir)
		game.queue_free()
		GameClock.paused = false
		await get_tree().process_frame
	await _crowd_shot(dir)


## Um número de cada tipo (e tamanhos diferentes): dano nos inimigos em volta e recebido/cura
## sobre a guardiã. O crítico já está no HANG nas capturas de tipos.
func _spawn_all(game: HyakkiGame, at: Vector2) -> void:
	var fx := game.fx
	fx.add_number(at + Vector2(-110.0, -52.0), 9.0, K.HIT, 10.0)
	fx.add_number(at + Vector2(-60.0, -32.0), 31.0, K.HIGH, 10.0)
	fx.add_number(at + Vector2(-110.0, -12.0), 95.0, K.HIGH, 10.0)
	fx.add_number(at + Vector2(40.0, -56.0), 24.0, K.CRIT, 10.0)
	fx.add_number(at + Vector2(110.0, -30.0), 4.0, K.DOT)
	fx.add_number(at + Vector2(-16.0, -26.0), 6.0, K.TAKEN, 100.0)
	fx.add_number(at + Vector2(22.0, -26.0), 28.0, K.TAKEN_HEAVY, 100.0)
	fx.add_number(at + Vector2(0.0, 14.0), 30.0, K.HEAL, 100.0)


## Leva todos os números à idade `age` e captura.
func _age_shot(game: HyakkiGame, age: float, path: String, at: Vector2) -> void:
	var numbers := game.fx.numbers
	var ages := numbers.get("_age") as PackedFloat32Array
	for i: int in range(ages.size()):
		ages[i] = age
	numbers.set("_age", ages)
	numbers.queue_redraw()
	await _shot(path, at)


## O crítico quadro a quadro: HOLD, SLAM 3x/2x/1x, HANG e SHATTER (normal e na Baixa).
func _crit_sequence(game: HyakkiGame, at: Vector2, dir: String) -> void:
	var frames := [["0_hold", 0.02], ["1_slam3x", 0.07], ["2_slam2x", 0.11], ["3_slam1x", 0.15],
			["4_hang", 0.3], ["5_shatter", 0.58], ["6_shatter", 0.68]]
	for low: bool in [false, true]:
		game.fx.numbers.low = low
		game.fx.numbers.set_colorblind(false)
		game.fx.numbers.reset()
		game.fx.add_number(at + Vector2(40.0, -40.0), 46.0, K.CRIT, 10.0)
		for f: Array in frames:
			await _age_shot(game, float(f[1]), dir.path_join("critico%s_%s.png" % ["_baixa" if low else "", f[0]]), at)
	game.fx.numbers.low = false


## Ondas: começo (30 inimigos), meio (200) e fim (500), e o fim sem a densidade adaptativa
## (travada no nível 0) para comparar antes e depois. Armas de todo tipo e crítico.
func _crowd_shot(dir: String) -> void:
	var late: Array[StringName] = [&"kunai", &"incense", &"smoke_bomb", &"raijin", &"taiko", &"steel_storm",
			&"poison_mist", &"thousand_needles"]
	var mid: Array[StringName] = [&"kunai", &"incense", &"raijin"]
	await _wave_shot(dir, "onda_1_comeco", 30, false, [], 0.0)
	await _wave_shot(dir, "onda_2_meio", 200, false, mid, 0.1)
	await _wave_shot(dir, "onda_3_fim_500", 500, false, late, 0.25)
	await _wave_shot(dir, "onda_3_fim_500_antes", 500, true, late, 0.25)


func _wave_shot(dir: String, name: String, count: int, locked: bool, weapons: Array[StringName], crit: float) -> void:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = {"hero": "aki", "stage": "bamboo", "moon": 0, "mode": "normal", "seed": 21, "speed": 1}
	game.stress_count = count
	add_child(game)
	await get_tree().process_frame
	game.set("_ad_in_progress", true)
	for id: StringName in weapons:
		if not game.has_weapon(id):
			game.add_weapon(id)
	game.player.stats.set_source("shot_crit", {"crit": crit})
	game.player.stats.recalculate()
	var numbers := game.fx.numbers
	if locked:
		numbers.force_level(0, 0.0)
	# Números no passo da simulação (60 fps), como no jogo.
	game.fx.set_process(false)
	for frame: int in range(240):
		GameClock.game_time += 1.0 / 60.0
		game._on_tick(1.0 / 60.0)
		if game.hud.overlay_open():
			game.hud.bot_answer()
		numbers.enemies = game.enemies.count_alive
		numbers.guard = game.player.position
		numbers.step(1.0 / 60.0)
		if frame % 4 == 0:
			await get_tree().process_frame
	await _shot(dir.path_join("%s.png" % name), game.player.sim_pos)
	print("%s: %d inimigos, %.0f números/s, pressão %.2f, nível %d, %d vivos, cobertura %.2f%%" % [name,
			game.enemies.count_alive, numbers.rate, numbers.pressure, numbers.level, numbers.live,
			numbers.screen_area() / (678.0 * 305.0) * 100.0])
	game.queue_free()
	await get_tree().process_frame


func _shot(path: String, at: Vector2) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	print("captura: %s" % path)
	# Recorte 3x em volta da guardiã (centro da tela), com os números lado a lado.
	var view := image.get_size()
	var region := Rect2i(Vector2i(view.x / 2 - 150, view.y / 2 - 80), Vector2i(300, 120))
	var crop := image.get_region(region)
	crop.resize(region.size.x * 3, region.size.y * 3, Image.INTERPOLATE_NEAREST)
	crop.save_png(path.trim_suffix(".png") + "_3x.png")
	print("captura: %s (guardiã em %s)" % [path.trim_suffix(".png") + "_3x.png", at])
