class_name OverlayFx
extends Control
## Fundo das telas que param a luta (nova habilidade e baú): o mundo recua sob um véu de
## noite. Em Alta, a cena fica desfocada e dessaturada (shader de 13 amostras na tela), com
## vinheta, raios de luz girando devagar a partir de `ray_origin` e fogos-fátuos subindo.
## Em Média, sem desfoque; em Baixa, um véu liso, poucos raios parados e poucos fogos-fátuos
## (nada de efeito de tela cheia). Troca ao vivo com GfxQuality (Settings.changed).
## `power` (0..1) faz a entrada e a saída; `rays` (0..1) acende os raios.

const VEIL := Color(0.025, 0.018, 0.06)
const MOTE := Color(1.0, 0.82, 0.5)
## [véu sem desfoque, véu com desfoque] por nível.
const VEIL_ALPHA := [0.8, 0.68, 0.5]
const RAY_COUNT := [6, 10, 14]
const MOTE_COUNT := [8, 18, 34]
const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 1.0;
uniform vec4 veil : source_color = vec4(0.025, 0.018, 0.06, 1.0);
uniform float darken = 0.5;
void fragment() {
	vec2 p = SCREEN_PIXEL_SIZE * amount;
	vec3 c = texture(screen_tex, SCREEN_UV).rgb * 0.16;
	c += texture(screen_tex, SCREEN_UV + vec2(1.5, 0.0) * p).rgb * 0.09;
	c += texture(screen_tex, SCREEN_UV - vec2(1.5, 0.0) * p).rgb * 0.09;
	c += texture(screen_tex, SCREEN_UV + vec2(0.0, 1.5) * p).rgb * 0.09;
	c += texture(screen_tex, SCREEN_UV - vec2(0.0, 1.5) * p).rgb * 0.09;
	c += texture(screen_tex, SCREEN_UV + vec2(1.2, 1.2) * p).rgb * 0.06;
	c += texture(screen_tex, SCREEN_UV + vec2(-1.2, 1.2) * p).rgb * 0.06;
	c += texture(screen_tex, SCREEN_UV + vec2(1.2, -1.2) * p).rgb * 0.06;
	c += texture(screen_tex, SCREEN_UV + vec2(-1.2, -1.2) * p).rgb * 0.06;
	c += texture(screen_tex, SCREEN_UV + vec2(3.2, 0.0) * p).rgb * 0.06;
	c += texture(screen_tex, SCREEN_UV - vec2(3.2, 0.0) * p).rgb * 0.06;
	c += texture(screen_tex, SCREEN_UV + vec2(0.0, 3.2) * p).rgb * 0.06;
	c += texture(screen_tex, SCREEN_UV - vec2(0.0, 3.2) * p).rgb * 0.06;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * vec3(0.8, 0.85, 1.1), 0.45 * amount);
	COLOR = vec4(mix(c, veil.rgb, darken * amount), 1.0);
}
"""

static var _blur_shader: Shader

## Entrada/saída (0 = invisível).
var power: float = 0.0:
	set(value):
		power = clampf(value, 0.0, 1.0)
		_sync_blur()
		queue_redraw()
## Intensidade dos raios (0..1) e a cor deles.
var rays: float = 0.0
var ray_color: Color = Color(1.0, 0.85, 0.55)
## Origem dos raios em coordenadas locais; < 0 = centro da tela.
var ray_origin: Vector2 = Vector2(-1, -1)
## Clarão de tela cheia (0..1), que some sozinho (só Média/Alta, menor com "Reduzir flashes").
var flash: float = 0.0
var flash_color: Color = Color.WHITE

var _level: int = GfxQuality.HIGH
var _blur: ColorRect
var _blur_material: ShaderMaterial
var _vignette: GradientTexture2D
var _time: float = 0.0
var _motes: PackedVector2Array = []
var _mote_speed: PackedFloat32Array = []
var _mote_phase: PackedFloat32Array = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_rng.seed = 23
	if _blur_shader == null:
		_blur_shader = Shader.new()
		_blur_shader.code = BLUR_SHADER
	_blur_material = ShaderMaterial.new()
	_blur_material.shader = _blur_shader
	_blur = ColorRect.new()
	_blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur.material = _blur_material
	_blur.show_behind_parent = true
	add_child(_blur)
	_vignette = GradientTexture2D.new()
	_vignette.width = 128
	_vignette.height = 64
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.45)
	_vignette.fill_to = Vector2(1.08, 1.08)
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.add_point(0.5, Color(0, 0, 0, 0.12))
	g.set_color(g.get_point_count() - 1, Color(0.0, 0.0, 0.02, 0.78))
	_vignette.gradient = g


func _ready() -> void:
	apply_quality()
	Settings.changed.connect(func(key: String) -> void:
		if key == GfxQuality.changed_signal_key():
			apply_quality())


## Relê o nível gráfico (também chamado ao abrir cada tela).
func apply_quality() -> void:
	_level = GfxQuality.level()
	var count: int = MOTE_COUNT[_level]
	if _motes.size() != count:
		_seed_motes(count)
	_sync_blur()
	queue_redraw()


func quality_level() -> int:
	return _level


## Desfoque de tela cheia ligado (só Alta).
func blur_on() -> bool:
	return _blur.visible


func mote_count() -> int:
	return _motes.size()


func ray_count() -> int:
	return RAY_COUNT[_level]


func _sync_blur() -> void:
	if _blur == null:
		return
	_blur.visible = _level == GfxQuality.HIGH and power > 0.0
	_blur_material.set_shader_parameter("amount", power)


func _seed_motes(count: int) -> void:
	var view := size if size.x > 0.0 else Vector2(678, 305)
	_motes.resize(count)
	_mote_speed.resize(count)
	_mote_phase.resize(count)
	for i: int in range(count):
		_motes[i] = Vector2(_rng.randf() * view.x, _rng.randf() * view.y)
		_mote_speed[i] = _rng.randf_range(5.0, 14.0)
		_mote_phase[i] = _rng.randf() * TAU


func _process(delta: float) -> void:
	if not is_visible_in_tree() or power <= 0.0:
		return
	_time += delta
	var view := size
	for i: int in range(_motes.size()):
		var p := _motes[i]
		p.y -= _mote_speed[i] * delta
		p.x += sin(_mote_phase[i] + p.y * 0.05) * 4.0 * delta
		if p.y < -4.0:
			p = Vector2(_rng.randf() * view.x, view.y + 4.0)
		_motes[i] = p
		_mote_phase[i] += delta * 1.4
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 3.0)
	queue_redraw()


func _draw() -> void:
	if power <= 0.0:
		return
	var r := Rect2(Vector2.ZERO, size)
	var veil_a: float = VEIL_ALPHA[_level]
	if _blur.visible:
		# O shader já escurece; o véu aqui só assenta a cor.
		draw_rect(r, Color(VEIL, 0.25 * power))
	else:
		draw_rect(r, Color(VEIL, veil_a * power))
	if _level > GfxQuality.LOW:
		draw_texture_rect(_vignette, r, false, Color(1, 1, 1, power))
	_draw_rays()
	for i: int in range(_motes.size()):
		var p := _motes[i].floor()
		var flicker := 0.5 + 0.5 * sin(_mote_phase[i] * 2.1)
		var a := (0.3 + 0.5 * flicker) * power
		if _level > GfxQuality.LOW:
			draw_circle(p + Vector2(0.5, 0.5), 2.5, Color(MOTE, a * 0.14))
		draw_rect(Rect2(p, Vector2(2, 2) if i % 5 == 0 else Vector2.ONE), Color(MOTE, a))
	if flash > 0.0 and _level > GfxQuality.LOW:
		var calm := bool(Settings.get_value("reduce_flashes"))
		draw_rect(r, Color(flash_color, flash * (0.15 if calm else 0.45)))


## Leque de raios de luz (triângulos com borda que some), girando devagar em Média/Alta.
func _draw_rays() -> void:
	if rays <= 0.0:
		return
	var origin := ray_origin if ray_origin.x >= 0.0 else size * 0.5
	var count: int = RAY_COUNT[_level]
	var reach := size.length()
	var spin := 0.0 if _level == GfxQuality.LOW else _time * 0.12
	var strength := rays * power * (0.75 if _level == GfxQuality.LOW else 1.0)
	for i: int in range(count):
		var angle := spin + TAU * float(i) / count
		var width := 0.07 + 0.05 * sin(i * 1.7 + _time * 0.8)
		var a := (0.08 + 0.05 * sin(i * 2.3 + _time * 1.3)) * strength
		var tip := origin
		var left := origin + Vector2.from_angle(angle - width) * reach
		var right := origin + Vector2.from_angle(angle + width) * reach
		draw_polygon(PackedVector2Array([tip, left, right]),
				PackedColorArray([Color(ray_color, a), Color(ray_color, 0.0), Color(ray_color, 0.0)]))
	# Núcleo de luz na origem.
	draw_circle(origin, 26.0, Color(ray_color, 0.08 * strength))
	draw_circle(origin, 14.0, Color(ray_color, 0.1 * strength))
