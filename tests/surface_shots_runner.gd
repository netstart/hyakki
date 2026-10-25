extends Node
## Capturas das superfícies lentas (não roda no run_checks): herói atravessando uma mancha do
## tipo pedido, com inimigos em volta. Uso (depois de "--"):
##   --type=mud|clay|swamp|oil|tar|quicksand  --gfx=low|high  --shot=arquivo.png  [--weather=storm]
## A fase vem de SurfaceTests.STAGE_OF.

const GAME_SCENE := "res://scenes/game/Game.tscn"
const SurfaceTests := preload("res://tests/surface_tests.gd")

var _game: HyakkiGame
var _type: String = "mud"
var _shot: String = "user://surface.png"
var _weather: String = ""
var _start: Vector2
var _frames: int = 0


func _ready() -> void:
	process_priority = 10
	for arg: String in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--type="):
			_type = value
		elif arg.begins_with("--shot="):
			_shot = value
		elif arg.begins_with("--weather="):
			_weather = value
	_game = (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	_game.config = {"hero": "aki", "stage": String(SurfaceTests.STAGE_OF.get(_type, "village")), "moon": 0,
			"mode": "normal", "seed": 5, "speed": 1}
	add_child(_game)
	await get_tree().process_frame
	_game.player.god_mode = true
	var weather := WeatherSystem.of(_game)
	weather.force_state(_weather if _weather != "" else ("storm" if _type == "mud" else "breeze"))
	GameClock.game_time = 200.0
	_game.spawner.skip_until(200.0)
	var tests := SurfaceTests.new()
	var spot: Array = tests._spot(_game, _type)
	var center: Vector2 = spot[0] if not spot.is_empty() else Vector2.ZERO
	_start = center - Vector2(26, 3)
	_game.player.sim_pos = _start
	_game.player.prev_pos = _start
	_game.enemies.reset()
	for k: int in range(7):
		var at := center + Vector2.from_angle(TAU * k / 7.0) * (44.0 + 10.0 * (k % 2))
		_game.enemies.spawn(&"slime_rice" if k % 2 == 0 else &"skeleton_peasant", at, 1000.0, 0.0, k == 3)


func _process(_delta: float) -> void:
	if _game == null or _game.player == null:
		return
	if _game.hud.pause_open():
		_game.close_pause()  # janela sem foco abre a pausa; a captura quer a partida
	_game.player.move_input = Vector2.RIGHT
	_frames += 1
	if _frames == 50:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shot)
		# Recorte ampliado (3x) em volta da guardiã, para julgar o detalhe do solo.
		var vs := Vector2(img.get_size())
		var view := _game.view_size()
		var hero := (_game.player.position - _game.camera.get_screen_center_position()) / view * vs + vs * 0.5
		var box := Vector2(226, 102) * vs.x / view.x
		var crop := img.get_region(Rect2i(Rect2(hero - box * 0.5, box)).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
		crop.resize(678, 306, Image.INTERPOLATE_NEAREST)
		crop.save_png(_shot.get_basename() + "_zoom.png")
		print("SCREENSHOT %s" % _shot)
		get_tree().quit()
