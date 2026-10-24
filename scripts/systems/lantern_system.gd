class_name LanternSystem
extends CanvasLayer
## Lanterna do Amanhecer (plano 2.1): brasas coletadas aumentam o raio de luz por um
## tempo (até +60%, decaindo devagar). Fora da luz, os yōkai Sombra ficam translúcidos
## e mais rápidos. Chefes "comem" a luz (−30%). O desenho é um shader de tela cheia.

const MAX_BOOST := 0.6
const BOOST_PER_XP := 0.012
const DECAY := 0.035
const BOSS_EAT := 0.7
const EXTINGUISHED_RADIUS := 34.0
const BASE_DARKNESS := 0.72

var game: HyakkiGame
## Raio atual em pixels lógicos (lido pelos inimigos Sombra e pela conquista "Escuridão").
var radius: float = 120.0
var boost: float = 0.0
var darken_time: float = 0.0
var darken_mult: float = 1.0
var extinguished: bool = false
var solar_time: float = 0.0

var _rect: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	layer = 5
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/lantern_light.gdshader") as Shader
	_rect.material = _material
	add_child(_rect)


func reset() -> void:
	boost = 0.0
	darken_time = 0.0
	darken_mult = 1.0
	extinguished = false
	solar_time = 0.0


func on_ember(xp: int) -> void:
	boost = minf(MAX_BOOST, boost + BOOST_PER_XP * xp)


func darken(seconds: float, mult: float) -> void:
	darken_time = maxf(darken_time, seconds)
	darken_mult = mult


func step(dt: float) -> void:
	boost = maxf(0.0, boost - DECAY * dt)
	if darken_time > 0.0:
		darken_time -= dt
	if solar_time > 0.0:
		solar_time -= dt
	var base := game.player.stats.get_stat("light") * float(game.stage.get("light_mult", 1.0))
	var mult := 1.0 + boost
	if game.bosses.active_count() > 0:
		mult *= BOSS_EAT
	if darken_time > 0.0:
		mult *= darken_mult
	if solar_time > 0.0:
		mult = maxf(mult, 1.0 + MAX_BOOST) * 1.2
	radius = base * mult
	if extinguished:
		radius = EXTINGUISHED_RADIUS


func _process(_delta: float) -> void:
	var view := game.view_size()
	var cam := game.camera.get_screen_center_position()
	var hero := game.player.position
	# Com zoom (a câmera se aproxima na morte), a distância na tela cresce junto.
	var uv := (hero - cam) * game.camera.zoom / view + Vector2(0.5, 0.5)
	_material.set_shader_parameter("hero_screen_uv", uv)
	_material.set_shader_parameter("screen_px", view)
	_material.set_shader_parameter("radius_px", radius)
	var flicker := 0.0 if bool(Settings.get_value("reduce_flashes")) else sin(GameClock.game_time * 7.0) * 1.5
	_material.set_shader_parameter("flicker", flicker)
	# Amanhecer: a escuridão some nos últimos 30 s (plano 5.2).
	var left := game.dawn_time() - GameClock.game_time
	var dark := BASE_DARKNESS
	if left < 30.0 and not game.endless_phase:
		dark *= clampf(left / 30.0, 0.0, 1.0)
	if game.mode == "brisa":
		dark *= 0.6
	_material.set_shader_parameter("darkness", dark)
