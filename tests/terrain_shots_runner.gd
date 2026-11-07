extends Node
## Capturas do chão dos biomas (não roda no run_checks; serve para revisar a arte do terreno antes e
## depois de mexer em tilesets, data/biomes.json ou shaders/terrain_ground.gdshader). Rodar SEM
## --headless, com APPDATA isolado (usa os arquivos de teste do save e das opções):
##   godot --path . res://tests/terrain_shots.tscn -- --stage=village --level=2 --shot=<arquivo.png>
## Opções (depois de "--"):
##   --stage=<fase>       fase de data/stages.json (padrão village)
##   --level=0|1|2        mundo dos vivos, Kakuriyo ou Tokoyo (padrão 0)
##   --at=x,y             onde a guardiã fica (padrão: 0,0; no Tokoyo, um espelho d'água do 1º anel)
##   --gfx=low|medium|high qualidade gráfica (padrão high)
##   --res=WxH            tela lógica (padrão 678x305), janela 2x
##   --shot=<arquivo.png> captura; grava também <arquivo>_b.png 0,5 s depois (água animada)
## Sem inimigos e sem HUD: só o terreno, a decoração e a guardiã parada.

const GAME_SCENE := "res://scenes/game/Game.tscn"
const DeviceProfiles := preload("res://tests/device_profiles.gd")

var _game: HyakkiGame
var _shot := "user://terrain.png"
var _frames := 0
var _at := Vector2.INF
var _ready_done := false


func _ready() -> void:
	process_priority = 10
	SaveManager.use_test_files()
	Settings.use_test_file()
	var stage := "village"
	var level := 0
	var gfx := "high"
	var res := Vector2(678, 305)
	for arg: String in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--stage="):
			stage = value
		elif arg.begins_with("--level="):
			level = value.to_int()
		elif arg.begins_with("--at="):
			_at = Vector2(value.get_slice(",", 0).to_float(), value.get_slice(",", 1).to_float())
		elif arg.begins_with("--gfx="):
			gfx = value
		elif arg.begins_with("--res="):
			res = Vector2(value.get_slice("x", 0).to_float(), value.get_slice("x", 1).to_float())
		elif arg.begins_with("--shot="):
			_shot = value
	GfxQuality.set_override(int(GfxQuality.MODE_LEVEL.get(gfx, GfxQuality.HIGH)))
	await DeviceProfiles.set_window_view(self, res)
	_game = (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	_game.config = {"hero": "aki", "stage": stage, "moon": 0, "mode": "normal", "seed": 5, "speed": 1}
	add_child(_game)
	await get_tree().process_frame
	_game.player.god_mode = true
	if level > 0:
		_game.rift.enter_realm(level)
	if _at == Vector2.INF:
		# Tokoyo: o espelho d'água do 1º anel no setor de 3π/8 (sem ilha), como em TerrainLayout._toko_ponds.
		var ring_r := _game.world.layout.toko_ring_radius()
		_at = (Vector2.from_angle(PI * 3.0 / 8.0) * (TerrainLayout.TOKO_PLAZA_RIM + ring_r) * 0.5).round() \
				if level >= 2 else Vector2.ZERO
	_place()
	_game.hud.visible = false
	_ready_done = true


func _place() -> void:
	_game.player.sim_pos = _at
	_game.player.prev_pos = _at
	_game.player.position = _at
	_game.player.velocity = Vector2.ZERO
	_game.enemies.reset()


func _process(_delta: float) -> void:
	if not _ready_done:
		return
	if _game.hud.pause_open():
		_game.close_pause()  # janela sem foco abre a pausa; a captura quer a partida
	_game.hud.visible = false
	_game.player.move_input = Vector2.ZERO
	_place()
	_frames += 1
	if _frames == 60 or _frames == 90:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := _shot if _frames < 90 else _shot.get_basename() + "_b.png"
		img.save_png(path)
		print("SCREENSHOT %s" % path)
		if _frames >= 90:
			get_tree().quit()
