class_name LanternSystem
extends CanvasLayer
## Lanterna do Amanhecer (plano 2.1): brasas coletadas aumentam o raio de luz por um
## tempo (até +60%, decaindo devagar). Fora da luz, os yōkai Sombra ficam translúcidos
## e mais rápidos. Chefes "comem" a luz (−30%).
##
## Desenho (só visual; o raio da jogabilidade é o mesmo): um shader de tela cheia com luz quente
## de queda suave em volta do herói e as luzes do cenário (WorldMap.collect_lights: lanternas de
## pedra, lava, estátuas), cintilando, até GfxQuality "lights_max" (o herói conta como uma).
## Cor da noite, calor e vinheta por bioma (data/biomes.json "grade"; vinheta só com post_fx).
## Na Alta ("glow"), halos aditivos em volta de cada luz, desenhados por cima da escuridão.

const MAX_BOOST := 0.6
const BOOST_PER_XP := 0.012
const DECAY := 0.035
const BOSS_EAT := 0.7
const EXTINGUISHED_RADIUS := 34.0
const BASE_DARKNESS := 0.72
const SHADER_LIGHTS := 24

var game: HyakkiGame
## Raio atual em pixels lógicos (lido pelos inimigos Sombra e pela conquista "Escuridão").
var radius: float = 120.0
var boost: float = 0.0
var darken_time: float = 0.0
var darken_mult: float = 1.0
var extinguished: bool = false
var solar_time: float = 0.0
## Luzes do cenário usadas no último quadro (testes): [pos tela, raio, força, cor].
var frame_lights: Array = []

var _rect: ColorRect
var _material: ShaderMaterial
var _halos: Node2D
var _glow: bool = false
var _lights_max: int = 4
var _vignette: float = 0.0
var _clock: float = 0.0


func _ready() -> void:
	layer = 5
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/lantern_light.gdshader") as Shader
	_rect.material = _material
	add_child(_rect)
	_halos = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_halos.material = add
	_halos.draw.connect(_draw_halos)
	add_child(_halos)
	_apply_quality()
	var settings := get_node_or_null(^"/root/Settings")
	if settings != null:
		settings.connect("changed", func(k: String) -> void:
				if k == GfxQuality.changed_signal_key():
					_apply_quality())


func _apply_quality() -> void:
	_glow = bool(GfxQuality.budget("glow"))
	_lights_max = int(GfxQuality.budget("lights_max"))
	_vignette = 1.0 if bool(GfxQuality.budget("post_fx")) else 0.0
	_halos.visible = _glow


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


func _process(delta: float) -> void:
	_clock += delta
	var view := game.view_size()
	var cam := game.camera.get_screen_center_position()
	var zoom := game.camera.zoom
	var calm := bool(Settings.get_value("reduce_flashes"))
	# Com zoom (a câmera se aproxima na morte), a distância na tela cresce junto.
	var hero := (game.player.position - cam) * zoom + view * 0.5
	_material.set_shader_parameter("hero_px", hero)
	_material.set_shader_parameter("screen_px", view)
	_material.set_shader_parameter("radius_px", radius * zoom.x)
	var flicker := 0.0 if calm else sin(GameClock.game_time * 7.0) * 1.5 + sin(_clock * 13.1) * 0.8
	_material.set_shader_parameter("flicker", flicker)
	var grade: Dictionary = game.world.biome.get("grade", {})
	_material.set_shader_parameter("night_tint", Color(String(grade.get("night", "#0d0a1f"))))
	_material.set_shader_parameter("warm_tint", Color(String(grade.get("warm", "#ffb35c"))))
	_material.set_shader_parameter("vignette", float(grade.get("vignette", 0.4)) * _vignette)
	# Amanhecer: a escuridão some nos últimos 30 s (plano 5.2).
	var left := game.dawn_time() - GameClock.game_time
	var dark := BASE_DARKNESS * float(grade.get("darkness", 1.0))
	var dawn := 1.0
	if left < 30.0 and not game.endless_phase:
		dawn = clampf(left / 30.0, 0.0, 1.0)
	dark *= dawn
	if game.mode == "brisa":
		dark *= 0.6
	_material.set_shader_parameter("darkness", dark)
	_material.set_shader_parameter("warmth", 0.14 * dawn)
	_update_lights(cam, zoom, view, calm, dawn)


## Escolhe as luzes mais perto do centro da tela (lights_max - 1, o herói é a outra).
func _update_lights(cam: Vector2, zoom: Vector2, view: Vector2, calm: bool, dawn: float) -> void:
	var found: Array = game.world.collect_lights(cam, view * 0.5 / zoom + Vector2(40, 40))
	found.sort_custom(func(a: Array, b: Array) -> bool:
			return cam.distance_squared_to(a[0]) < cam.distance_squared_to(b[0]))
	var count := mini(found.size(), mini(_lights_max - 1, SHADER_LIGHTS))
	var lights := PackedVector4Array()
	var colors := PackedVector4Array()
	lights.resize(SHADER_LIGHTS)
	colors.resize(SHADER_LIGHTS)
	frame_lights.clear()
	for i: int in range(count):
		var l: Array = found[i]
		var at: Vector2 = ((l[0] as Vector2) - cam) * zoom + view * 0.5
		var col: Color = l[1]
		var seed_phase := at.x * 0.37 + at.y * 0.11
		var wobble := 0.0 if calm else sin(_clock * 9.0 + seed_phase) * 0.06 + sin(_clock * 23.0 + seed_phase * 2.0) * 0.04
		var strength := float(l[3]) * (1.0 + wobble) * dawn
		var r := float(l[2]) * zoom.x * (1.0 + wobble * 0.5)
		lights[i] = Vector4(at.x, at.y, r, strength)
		colors[i] = Vector4(col.r, col.g, col.b, 1.0)
		frame_lights.append([at, r, strength, col])
	_material.set_shader_parameter("lights", lights)
	_material.set_shader_parameter("light_colors", colors)
	_material.set_shader_parameter("light_count", count)
	if _glow:
		_halos.queue_redraw()


## Halos aditivos (Alta): brilho suave em volta de cada luz e um leve em volta da lanterna.
func _draw_halos() -> void:
	var tex := TerrainArt.halo_texture()
	for l: Array in frame_lights:
		var r := float(l[1]) * 0.7
		var col: Color = l[3]
		var a := clampf(float(l[2]), 0.0, 1.0) * 0.22
		_halos.draw_texture_rect(tex, Rect2((l[0] as Vector2) - Vector2(r, r), Vector2(r, r) * 2.0), false,
				Color(col.r, col.g, col.b, a))
		var core := r * 0.3
		_halos.draw_texture_rect(tex, Rect2((l[0] as Vector2) - Vector2(core, core), Vector2(core, core) * 2.0), false,
				Color(1.0, 0.9, 0.7, a * 0.9))
