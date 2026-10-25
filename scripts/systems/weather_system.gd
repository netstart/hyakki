class_name WeatherSystem
extends Node2D
## Clima dinâmico da partida: vento com rajadas, chuva em camadas, tempestade com relâmpagos e
## trovão atrasado, poças, lama (jogabilidade) e o clima próprio de cada fase (data/weather.json).
##
## Entra na partida como o nó "Weather" de scenes/game/Game.tscn (nenhuma linha no game.gd).
## O estado vem de WeatherModel: função pura da semente da partida (world.seed_value), da fase e
## de GameClock.game_time. Por isso o clima é o mesmo em 1x/2x/3x e ao continuar uma partida.
##
## Camadas:
##   - WeatherGround (z -17, no mundo): lama, poças, pegadas, respingos; abaixo dos atores.
##   - WeatherSky (CanvasLayer 4): gotas, flocos, areia, névoa e gradação do céu; acima do
##     mundo, abaixo da escuridão da lanterna (5) e da HUD (10).
##   - clarão dos relâmpagos (CanvasLayer 7): acima da escuridão, abaixo da HUD.
##
## Contrato com os shaders do terreno (globais declarados em project.godot [shader_globals],
## atualizados a cada quadro): wind_dir (vec2 normalizado), wind_strength (0..1, com rajadas),
## wetness (0..1, chão molhado) e weather_time (segundos de simulação).
##
## Jogabilidade: as superfícies lentas (lama que cresce com a chuva, barro, pântano, óleo,
## piche, areia movediça) ficam no filho "Surfaces" (SurfaceSystem + SurfaceField).
##
## Linha de comando (depois de "--"): --weather=calm|breeze|gale|drizzle|storm|clearing força o
## estado (capturas e testes; o chão já começa molhado conforme o estado).

const NODE_NAME := "Weather"
const AMBIENCE_DIR := "res://assets/audio/ambience/"
const RAIN_FILES: Array[String] = ["rain", "rain2", "rain3"]
const WIND_FILES: Array[String] = ["wind", "wind2"]
const PAUSED_DB := -10.0
const SILENT_DB := -60.0

var game: HyakkiGame
var model: WeatherModel
## Estado forçado pela linha de comando ou pelos testes (-1 = ciclo normal).
var forced_state: int = -1

var surfaces: SurfaceSystem

var _ground: WeatherGround
var _sky: WeatherSky
var _model_key: Array = []
var _last_t: float = -1.0
var _rain_player: AudioStreamPlayer
var _wind_player: AudioStreamPlayer
var _storm_player: AudioStreamPlayer
## Trovões agendados: [tempo de simulação, volume dB, pitch].
var _thunders: Array = []


## Sistema de clima da partida (ou null fora de uma partida montada pela cena).
static func of(p_game: Node) -> WeatherSystem:
	if p_game == null:
		return null
	return p_game.get_node_or_null(NodePath(NODE_NAME)) as WeatherSystem


func _ready() -> void:
	name = NODE_NAME
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--weather="):
			forced_state = WeatherModel.state_from_name(arg.get_slice("=", 1))
	surfaces = SurfaceSystem.new()
	surfaces.weather = self
	add_child(surfaces)
	_ground = WeatherGround.new()
	_ground.weather = self
	add_child(_ground)
	_sky = WeatherSky.new()
	_sky.weather = self
	add_child(_sky)
	_rain_player = _make_player()
	_wind_player = _make_player()
	_storm_player = _make_player()
	Settings.changed.connect(_on_settings_changed)


func _exit_tree() -> void:
	# Fora da partida (menus), a grama volta a ficar quieta e o chão seco.
	_set_globals(Vector2.RIGHT, 0.0, 0.0, 0.0)


func _on_settings_changed(key: String) -> void:
	if key == GfxQuality.changed_signal_key():
		apply_quality()


## Troca ao vivo do nível gráfico: refaz os orçamentos das camadas.
func apply_quality() -> void:
	_sky.apply_quality()
	_ground.apply_quality()


# --- Modelo --------------------------------------------------------------------------

## Garante o modelo da partida atual (refeito quando a fase, a semente ou o estado forçado mudam).
func ensure_model() -> WeatherModel:
	if game == null:
		game = get_parent() as HyakkiGame
	var stage_id := "village"
	var run_seed := 0
	var stage_data: Dictionary = {}
	if game != null and game.world != null:
		stage_data = game.stage
		stage_id = String(stage_data.get("id", "village"))
		run_seed = game.world.seed_value
	var key := [stage_id, run_seed, forced_state]
	if model == null or key != _model_key:
		_model_key = key
		model = WeatherModel.new(stage_id, run_seed, stage_data, forced_state)
		var bounds := game.world.bounds if game != null and game.world != null else Vector2.ZERO
		surfaces.set_field(SurfaceField.new(stage_id, run_seed, model, bounds))
		_thunders.clear()
		_last_t = -1.0
		if _ground != null:
			_ground.reset()
		if _sky != null:
			_sky.reset()
	return model


## Força um estado ("storm", "drizzle"...; "" volta ao ciclo). Para capturas e testes.
func force_state(state_name: String) -> void:
	forced_state = WeatherModel.state_from_name(state_name) if state_name != "" else -1
	ensure_model()


func sim_time() -> float:
	return GameClock.game_time


# --- API pública ---------------------------------------------------------------------

## Vento: direção normalizada × força (0..1, com rajadas).
func wind_vector() -> Vector2:
	return ensure_model().wind_vector_at(sim_time())


func wind_dir() -> Vector2:
	return ensure_model().wind_dir_at(sim_time())


func wind_strength() -> float:
	return ensure_model().wind_strength_at(sim_time())


## Chuva que molha (0 nas fases secas).
func rain_amount() -> float:
	return ensure_model().rain_at(sim_time())


## O que cai na fase (chuva, neve, areia, cinza, almas), 0..1.
func precip_amount() -> float:
	return ensure_model().precip_at(sim_time())


## Chão molhado 0..1.
func wetness() -> float:
	return ensure_model().wetness_at(sim_time())


func state_name() -> String:
	return ensure_model().state_name_at(sim_time())


func profile() -> Dictionary:
	return ensure_model().profile


## Lama da chuva 0..1 (as manchas "rain" do SurfaceField crescem com ela).
func mud_level() -> float:
	return ensure_model().mud_level_at(sim_time())


# --- Quadro --------------------------------------------------------------------------

func _process(delta: float) -> void:
	ensure_model()
	if game == null or game.player == null:
		return
	var t := sim_time()
	var wind := model.wind_dir_at(t)
	var strength := model.wind_strength_at(t)
	var wet := model.wetness_at(t)
	_set_globals(wind, strength, wet, t)
	_update_lightning(t)
	_update_audio(t, strength)
	var dt := 0.0 if GameClock.paused else delta * float(GameClock.speed)
	_sky.tick(dt, t)
	_ground.tick(dt, t)


func _set_globals(dir: Vector2, strength: float, wet: float, t: float) -> void:
	RenderingServer.global_shader_parameter_set(&"wind_dir", dir.normalized())
	RenderingServer.global_shader_parameter_set(&"wind_strength", strength)
	RenderingServer.global_shader_parameter_set(&"wetness", wet)
	RenderingServer.global_shader_parameter_set(&"weather_time", t)


## Relâmpagos que passaram desde o último quadro: clarão agora, trovão depois (mais longe =
## mais atraso e mais baixo). Nada disso afeta a simulação.
func _update_lightning(t: float) -> void:
	if _last_t < 0.0 or t < _last_t or t - _last_t > 1.0:
		_last_t = t
		return
	for strike: Array in model.strikes_between(_last_t, t):
		var dist := float(strike[2])
		_sky.flash(strike)
		_thunders.append([float(strike[0]) + 0.35 + dist * 2.6, lerpf(-2.0, -15.0, dist), lerpf(0.68, 0.48, dist)])
	_last_t = t
	for k: int in range(_thunders.size() - 1, -1, -1):
		var th: Array = _thunders[k]
		if t >= float(th[0]):
			AudioManager.play("thunder", float(th[2]), 0.04, float(th[1]))
			_thunders.remove_at(k)


func pending_thunders() -> int:
	return _thunders.size()


# --- Áudio de ambiente ---------------------------------------------------------------

func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"Ambience"
	p.volume_db = SILENT_DB
	add_child(p)
	return p


## Chuva e vento acompanham a intensidade (volume e pitch); o ronco da tempestade entra nos
## relâmpagos e na tempestade de areia. Cada faixa troca de variação ao terminar.
func _update_audio(t: float, strength: float) -> void:
	var precip := model.precip_at(t)
	var p := model.profile
	var wet_stage := float(p.get("rain_scale", 1.0)) > 0.0
	var rain_level := precip if wet_stage else 0.0
	var storm_level := maxf(model.lightning_at(t) * 0.8, precip * 0.9 if not wet_stage and String(
			p.get("precip", "")) == "sand" else 0.0)
	var wind_level := smoothstep(0.08, 0.9, strength)
	var pause_db := PAUSED_DB if GameClock.paused else 0.0
	_drive(_rain_player, RAIN_FILES, rain_level, -3.0 + pause_db, 0.92 + 0.12 * rain_level)
	_drive(_wind_player, WIND_FILES, wind_level, -4.0 + pause_db, 0.82 + 0.36 * strength)
	_drive(_storm_player, ["storm"], storm_level, -6.0 + pause_db, 0.9 + 0.1 * storm_level)


func _drive(player: AudioStreamPlayer, files: Array, level: float, top_db: float, pitch: float) -> void:
	var target := SILENT_DB if level < 0.02 else top_db + linear_to_db(level)
	player.volume_db = move_toward(player.volume_db, target, 0.6)
	player.pitch_scale = clampf(pitch, 0.5, 1.6)
	if target > SILENT_DB + 1.0 and not player.playing:
		player.stream = load(AMBIENCE_DIR + String(files.pick_random()) + ".wav") as AudioStream
		if player.stream != null:
			player.play()
	elif player.playing and player.volume_db <= SILENT_DB + 0.5:
		player.stop()


## Volumes atuais das faixas (testes): {"rain", "wind", "storm"} em dB.
func ambience_db() -> Dictionary:
	return {"rain": _rain_player.volume_db, "wind": _wind_player.volume_db, "storm": _storm_player.volume_db}


func sky() -> WeatherSky:
	return _sky


func ground() -> WeatherGround:
	return _ground
