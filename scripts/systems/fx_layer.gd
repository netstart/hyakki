class_name FxLayer
extends Node2D
## Efeitos de "juice" (plano 8.5): animações do pacote (cortes, raios, explosões, faíscas),
## partículas, clarões aditivos, ondas de choque, números de dano e o momento cinematográfico
## do golpe da lanterna. Tudo aqui é só desenho: usa randf() próprio e nunca o rng da partida,
## então a simulação (e o hash 1x/2x/3x) não depende do nível gráfico.
##
## Qualidade (GfxQuality, troca ao vivo pela pausa):
## - Baixa: animações do pacote, anéis simples, poucas partículas, sem rastro, brilho nem
##   distorção.
## - Média: faíscas e poeira de impacto, rastros curtos, anéis com borda dupla.
## - Alta: tudo, mais brilho aditivo (camada própria), clarões, distorção da onda de choque e
##   mais partículas.
## Os valores efetivos ficam em variáveis estáticas (wfx, glow, trail_points...) para as armas,
## os projéteis e as áreas lerem sem consultar o GfxQuality a cada desenho.
## Partículas, números e animações seguem o tempo de jogo; números de dano duram o mesmo
## tempo real em qualquer velocidade (4.14).

## Partículas: tipos e capacidade (a maior cota "particles_max"; a cota do nível vale por cima).
enum P { DOT, STREAK, EMBER, GLOW }

const PARTICLE_CAPACITY := 1400
const MAX_NUMBERS := 120
const MAX_ANIMS := 160
const MAX_FLASHES := 48
const MAX_RINGS := 40
## Ondas de distorção ao mesmo tempo (só na Alta: cada uma custa uma cópia de tela).
const MAX_WAVES := 3
## Clarões novos por passo de simulação (centenas de acertos não viram um borrão branco).
const FLASHES_PER_STEP := 6
const NUMBER_LIFETIME := 0.6
const RING_LIFETIME := 0.4
## Fiapos de fumaça (a lanterna que se apaga na morte): poucos, lentos, sobem e se desfazem.
const MAX_WISPS := 24
const WISP_LIFETIME := 1.6
const WISP_COLOR := Color(0.62, 0.63, 0.68)
## Arrasto por tipo de partícula (fração da velocidade perdida por segundo).
const DRAG := [5.5, 7.0, 2.2, 4.0]
## Empuxo vertical por tipo (brasas sobem).
const LIFT := [0.0, 0.0, -38.0, 0.0]
## Animações: arquivo e largura do quadro (o quadro tem a altura da imagem).
const ANIMS := {
	"slash": ["res://assets/art/fx/slash_curved/SpriteSheet.png", 32],
	"slash_double": ["res://assets/art/fx/slash_double/SpriteSheet.png", 32],
	"slash_circular": ["res://assets/art/fx/slash_circular/SpriteSheet.png", 32],
	"cut_x": ["res://assets/art/fx/cut_x/SpriteSheet.png", 32],
	"claw": ["res://assets/art/fx/claw/SpriteSheet.png", 32],
	"thunder": ["res://assets/art/fx/thunder/SpriteSheet.png", 16],
	"explosion": ["res://assets/art/fx/explosion/SpriteSheet.png", 40],
	"spark": ["res://assets/art/fx/spark/SpriteSheet.png", 30],
	"spirit": ["res://assets/art/fx/spirit/SpriteSheet.png", 32],
	"spirit_blue": ["res://assets/art/fx/spirit/SpriteSheetBlue.png", 32],
	"circle": ["res://assets/art/fx/circle/SpriteSheetWhite.png", 32],
	"circle_orange": ["res://assets/art/fx/circle/SpriteSheetOrange.png", 32],
	"circle_spark": ["res://assets/art/fx/circle/SpriteSheetSpark.png", 32],
	"circle_spark2": ["res://assets/art/fx/circle/SpriteSheetSpark2.png", 32],
	"aura": ["res://assets/art/fx/aura/SpriteSheet.png", 25],
	"shield": ["res://assets/art/fx/shield/SpriteSheetYellow.png", 24],
	"boost": ["res://assets/art/fx/boost/SpriteSheet.png", 53],
	"smoke": ["res://assets/art/fx/smoke/SpriteSheet.png", 32],
	"smoke_circular": ["res://assets/art/fx/smoke_circular/SpriteSheet.png", 30],
	"rock_spike": ["res://assets/art/fx/rock_spike/SpriteSheet.png", 45],
	"flame": ["res://assets/art/fx/flame/SpriteSheet.png", 25],
	"water_pillar": ["res://assets/art/fx/water_pillar/SpriteSheet.png", 30],
	"ice": ["res://assets/art/fx/ice/SpriteSheet.png", 32],
}
## Distorção da onda de choque: desloca a tela numa faixa em anel (cor do vértice = parâmetros).
const WAVE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d) * 2.0;
	float t = COLOR.r;
	float band = 1.0 - smoothstep(0.0, 0.16, abs(r - t));
	vec2 dir = d / max(length(d), 0.0001);
	vec2 off = dir * band * COLOR.a * 0.012;
	vec4 c = texture(screen_tex, SCREEN_UV - off);
	c.rgb += vec3(band * COLOR.a * 0.12);
	COLOR = vec4(c.rgb, step(0.002, band));
}
"""

## Valores do nível gráfico em uso (refresh_quality()). Lidos pelas armas, projéteis e áreas.
static var wfx: int = 2
static var glow: bool = true
static var trail_points: int = 14
static var particles_max: int = PARTICLE_CAPACITY
static var shake_mult: float = 1.0
static var _soft: Texture2D

var game: HyakkiGame
## Escala de tempo só dos efeitos (câmera lenta visual do golpe da lanterna).
var time_scale: float = 1.0

var _sheets: Dictionary = {}

var _p_pos := PackedVector2Array()
var _p_vel := PackedVector2Array()
var _p_life := PackedFloat32Array()
var _p_max := PackedFloat32Array()
var _p_size := PackedFloat32Array()
var _p_color := PackedColorArray()
var _p_kind := PackedByteArray()
var _p_next: int = 0

var _n_pos := PackedVector2Array()
var _n_life := PackedFloat32Array()
var _n_text := PackedStringArray()
var _n_color := PackedColorArray()
var _n_next: int = 0

var _w_pos := PackedVector2Array()
var _w_vel := PackedVector2Array()
var _w_life := PackedFloat32Array()
var _w_next: int = 0

var _anims: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _waves: Array[Dictionary] = []
var _flashes_this_step: int = 0
## Golpe da lanterna: {"pos", "color", "t", "strength"} ou vazio.
var _cine: Dictionary = {}
var _slow_left: float = 0.0
var _calm: bool = false
var _font: Font
## Camada aditiva (brilho, clarões, faíscas que brilham) acima desta.
var _glow_layer: Node2D
var _wave_layer: Node2D
var _styles: Dictionary = {}
var _showcase: WeaponShowcase


func _ready() -> void:
	_font = Locale.font if Locale.font else ThemeDB.fallback_font
	game = get_parent() as HyakkiGame
	for name: String in ANIMS:
		var spec: Array = ANIMS[name]
		_sheets[name] = SpriteSheet.load_sheet(spec[0], "strip", Vector2(float(spec[1]), 0.0))
	for packed: StringName in [&"_p_pos", &"_p_vel", &"_p_life", &"_p_max", &"_p_size", &"_p_color",
			&"_p_kind"]:
		var array: Variant = get(packed)
		array.resize(PARTICLE_CAPACITY)
		set(packed, array)
	_n_pos.resize(MAX_NUMBERS)
	_n_life.resize(MAX_NUMBERS)
	_n_text.resize(MAX_NUMBERS)
	_n_color.resize(MAX_NUMBERS)
	_w_pos.resize(MAX_WISPS)
	_w_vel.resize(MAX_WISPS)
	_w_life.resize(MAX_WISPS)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_layer = Node2D.new()
	_glow_layer.material = additive
	_glow_layer.draw.connect(_draw_glow)
	add_child(_glow_layer)
	var wave_material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = WAVE_SHADER
	wave_material.shader = shader
	_wave_layer = Node2D.new()
	_wave_layer.material = wave_material
	_wave_layer.z_index = -1
	_wave_layer.visible = false
	_wave_layer.draw.connect(_draw_waves)
	add_child(_wave_layer)
	_showcase = WeaponShowcase.new()
	refresh_quality()
	_apply_quality()
	Settings.changed.connect(_on_setting)
	reset()


func _on_setting(key: String) -> void:
	if key == GfxQuality.changed_signal_key():
		refresh_quality()
		_apply_quality()


## Lê o nível gráfico atual para as variáveis estáticas (também chamado pelos testes).
static func refresh_quality() -> void:
	wfx = int(GfxQuality.budget("weapon_fx"))
	glow = bool(GfxQuality.budget("glow"))
	trail_points = int(GfxQuality.budget("trail_points"))
	particles_max = clampi(int(GfxQuality.budget("particles_max")), 16, PARTICLE_CAPACITY)
	shake_mult = float(GfxQuality.budget("screen_shake"))


## Ao baixar o nível, apaga o que passou da cota nova, o brilho e as distorções.
func _apply_quality() -> void:
	for i: int in range(particles_max, PARTICLE_CAPACITY):
		_p_life[i] = 0.0
	if _p_next >= particles_max:
		_p_next = 0
	if not glow:
		_waves.clear()
	_glow_layer.visible = glow
	_wave_layer.visible = glow and not _waves.is_empty()


## Textura de brilho suave (gradiente radial branco → transparente), uma para o jogo todo.
static func soft_texture() -> Texture2D:
	if _soft == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.35, Color(1, 1, 1, 0.55))
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 32
		tex.height = 32
		_soft = tex
	return _soft


## Brilho suave de raio `r` em `at` (para camadas aditivas).
static func draw_soft(canvas: CanvasItem, at: Vector2, r: float, color: Color) -> void:
	if r < 0.5:
		return
	canvas.draw_texture_rect(soft_texture(), Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, color)


func reset() -> void:
	_p_life.fill(0.0)
	_n_life.fill(0.0)
	_w_life.fill(0.0)
	_anims.clear()
	_rings.clear()
	_flashes.clear()
	_waves.clear()
	_cine = {}
	_slow_left = 0.0
	time_scale = 1.0


# --- Partículas ------------------------------------------------------------------

func _emit(kind: int, at: Vector2, vel: Vector2, life: float, color: Color, size: float = 1.0) -> void:
	var i := _p_next
	_p_pos[i] = at
	_p_vel[i] = vel
	_p_life[i] = life
	_p_max[i] = life
	_p_color[i] = color
	_p_size[i] = size
	_p_kind[i] = kind
	_p_next = (_p_next + 1) % particles_max


## Partículas de morte: pixels da cor do inimigo (decorativo; usa randf, fora da simulação).
func burst(at: Vector2, color: Color, count: int = 5) -> void:
	for k: int in range(count):
		var angle := TAU * (k / float(count)) + randf() * 0.6
		_emit(P.DOT, at, Vector2.from_angle(angle) * randf_range(25.0, 55.0), randf_range(0.25, 0.4),
				color, 1.0 if k % 3 else 2.0)


## Faíscas em risco na direção `dir` (abertura `spread` rad). Brilham na Alta.
func sparks(at: Vector2, dir: Vector2, color: Color, count: int, speed: float = 110.0,
		spread: float = 0.9, life: float = 0.22) -> void:
	var base := dir.angle() if dir != Vector2.ZERO else randf() * TAU
	for _k: int in range(count):
		var a := base + randf_range(-spread, spread)
		_emit(P.STREAK, at, Vector2.from_angle(a) * speed * randf_range(0.55, 1.15),
				life * randf_range(0.7, 1.2), color)


## Brasas que sobem tremulando (fogo, espíritos, veneno).
func embers(at: Vector2, color: Color, count: int, spread: float = 4.0) -> void:
	for _k: int in range(count):
		_emit(P.EMBER, at + Vector2(randf_range(-spread, spread), randf_range(-spread, spread) * 0.5),
				Vector2(randf_range(-14.0, 14.0), randf_range(-26.0, -6.0)), randf_range(0.35, 0.7), color,
				1.0 if randf() < 0.7 else 2.0)


## Poeira/pétalas soltas em volta (anel de `radius`).
func dust(at: Vector2, radius: float, color: Color, count: int, speed: float = 40.0) -> void:
	for k: int in range(count):
		var dir := Vector2.from_angle(TAU * k / float(maxi(count, 1)) + randf() * 0.5)
		_emit(P.DOT, at + dir * radius, dir * speed * randf_range(0.5, 1.1), randf_range(0.25, 0.5),
				color, 1.0 if randf() < 0.6 else 2.0)


## Pontos de luz aditivos (só a Alta os mostra brilhando; nas outras viram pixels).
func motes(at: Vector2, color: Color, count: int, spread: float = 6.0, speed: float = 18.0) -> void:
	for _k: int in range(count):
		var dir := Vector2.from_angle(randf() * TAU)
		_emit(P.GLOW if glow else P.DOT, at + dir * randf() * spread, dir * speed * randf(),
				randf_range(0.3, 0.6), color, randf_range(2.0, 4.0) if glow else 1.0)


## Partículas vivas agora (testes de orçamento).
func particles_alive() -> int:
	var count := 0
	for i: int in range(PARTICLE_CAPACITY):
		if _p_life[i] > 0.0:
			count += 1
	return count


## Fiapos de fumaça cinza subindo de `at` (decorativo; usa randf, fora da simulação).
func add_wisp(at: Vector2, count: int = 5) -> void:
	for k: int in range(count):
		_w_pos[_w_next] = at + Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0))
		_w_vel[_w_next] = Vector2(randf_range(-4.0, 4.0), randf_range(-17.0, -9.0))
		_w_life[_w_next] = WISP_LIFETIME * randf_range(0.75, 1.0)
		_w_next = (_w_next + 1) % MAX_WISPS


## Fiapos ainda no ar (testes).
func wisps_alive() -> int:
	var count := 0
	for i: int in range(MAX_WISPS):
		if _w_life[i] > 0.0:
			count += 1
	return count


# --- Clarões, anéis, ondas ---------------------------------------------------------

## Clarão aditivo curto (Alta); na Média, um disco pequeno e rápido; na Baixa, nada.
func flash(at: Vector2, radius: float, color: Color, life: float = 0.12) -> void:
	if wfx == 0 or _flashes_this_step >= FLASHES_PER_STEP:
		return
	_flashes_this_step += 1
	if _flashes.size() >= MAX_FLASHES:
		_flashes.pop_front()
	_flashes.append({"pos": at, "r": radius if glow else radius * 0.45, "color": color, "life": life,
			"max": life})


func add_ring(at: Vector2, max_radius: float, color: Color = Color(1.0, 0.9, 0.6),
		life: float = RING_LIFETIME, width: float = 2.0) -> void:
	if _rings.size() >= MAX_RINGS:
		_rings.pop_front()
	_rings.append({"pos": at, "r": max_radius, "life": life, "max": life, "color": color, "w": width})


## Onda de choque: anel e, na Alta, a distorção da tela atrás dele.
func shockwave(at: Vector2, radius: float, color: Color, strength: float = 1.0, life: float = 0.45) -> void:
	add_ring(at, radius, color, life, 2.0 + strength)
	if wfx >= 1:
		add_ring(at, radius * 0.7, Color(color, 0.6), life * 0.8, 1.0)
	distort(at, radius * 1.1, strength, life)


## Só a distorção da onda (Alta), para anéis que já têm desenho próprio (Taiko, Kaminari).
func distort(at: Vector2, radius: float, strength: float = 1.0, life: float = 0.45) -> void:
	if not glow:
		return
	if _waves.size() >= MAX_WAVES:
		_waves.pop_front()
	_waves.append({"pos": at, "r": radius, "life": life, "max": life, "s": clampf(strength, 0.2, 2.0)})
	_wave_layer.visible = true


## Ondas de distorção ativas (testes).
func waves_alive() -> int:
	return _waves.size()


# --- Animações ---------------------------------------------------------------------

## `additive`: desenhada na camada de brilho na Alta (raios, faíscas, círculos de luz).
func play_anim(name: String, at: Vector2, scale_factor: float = 1.0, angle: float = 0.0,
		tint: Color = Color.WHITE, fps: float = 16.0, flip: bool = false, additive: bool = false) -> void:
	if not _sheets.has(name) or _anims.size() >= MAX_ANIMS:
		return
	var sheet: SpriteSheet = _sheets[name]
	_anims.append({"sheet": sheet, "pos": at, "scale": scale_factor, "angle": angle, "tint": tint,
			"time": 0.0, "duration": sheet.frames / fps, "fps": fps, "flip": flip, "add": additive})


# --- Acertos ------------------------------------------------------------------------

## Todo acerto de arma (HyakkiGame.deal_damage): número de dano e impacto pelo tipo.
func on_hit(weapon_id: StringName, at: Vector2, amount: float, crit: bool, dir: Vector2) -> void:
	add_number(at, amount, crit)
	impact(weapon_id, at, dir, crit)


## Cor e tipo de impacto da arma (data/weapons.json "fx" e HitSounds), em cache.
func style(weapon_id: StringName) -> Dictionary:
	if not _styles.has(weapon_id):
		_styles[weapon_id] = WeaponStyle.of(DB.weapon(weapon_id))
	return _styles[weapon_id]


## Impacto conforme o tipo do golpe. Na Baixa só uma faísca (e um pouco mais no crítico).
func impact(weapon_id: StringName, at: Vector2, dir: Vector2, crit: bool = false) -> void:
	var s := style(weapon_id)
	var color: Color = s["color"]
	var hot: Color = s["hot"]
	var n: int = [1, 3, 5][wfx]
	if crit:
		n += 3
		flash(at, 14.0, Color(1.0, 0.85, 0.4, 0.8))
	match String(s["impact"]):
		"hit_blade":
			sparks(at, dir.orthogonal() if randf() < 0.5 else -dir.orthogonal(), hot, n, 120.0, 0.5, 0.16)
			flash(at, 9.0, Color(hot, 0.7), 0.08)
		"hit_projectile":
			sparks(at, dir, hot, n, 95.0, 0.7, 0.18)
			flash(at, 7.0, Color(hot, 0.6), 0.07)
		"hit_fire":
			embers(at, color, n + 1)
			flash(at, 11.0, Color(color, 0.7), 0.12)
		"hit_thunder":
			sparks(at, Vector2.ZERO, hot, n + 1, 140.0, PI, 0.12)
			flash(at, 14.0, Color(color, 0.8), 0.1)
		"hit_wind":
			for _k: int in range(n):
				var a := randf() * TAU
				_emit(P.DOT, at + Vector2.from_angle(a) * 4.0, Vector2.from_angle(a + 1.4) * 60.0,
						0.25, Color(hot, 0.85))
		"hit_area":
			dust(at, 3.0, Color(color, 0.85), n, 35.0)
			flash(at, 10.0, Color(hot, 0.55), 0.1)
		"hit_orbit":
			sparks(at, dir, hot, n, 70.0, 1.2, 0.25)
			flash(at, 8.0, Color(color, 0.7), 0.1)
		"hit_poison":
			embers(at, color, n)
		_:
			burst(at, hot, n)
	if crit and wfx > 0:
		play_anim("cut_x", at, 0.45, randf() * TAU, Color(1.0, 0.92, 0.6), 24.0, false, true)


## Disparo de arma: faísca e clarão curtos na mão (ou no corpo) na direção do tiro.
func muzzle(weapon_id: StringName, at: Vector2, dir: Vector2) -> void:
	if wfx == 0:
		return
	var s := style(weapon_id)
	sparks(at, dir, s["hot"], 2 * wfx, 70.0, 0.5, 0.12)
	flash(at, 8.0, Color(s["color"], 0.6), 0.08)


# --- Golpe da lanterna ---------------------------------------------------------------

## Momento cinematográfico: clarão, faixas de cinema, linhas de velocidade, ondas de choque,
## faíscas, tremor (cota "screen_shake") e câmera lenta só dos efeitos. Não toca na simulação.
func cinematic(at: Vector2, color: Color, strength: float = 1.0) -> void:
	_cine = {"pos": at, "color": color, "t": 0.0, "strength": strength}
	_slow_left = 0.3
	var rings: int = [1, 2, 3][wfx]
	for k: int in range(rings):
		shockwave(at, 90.0 + 70.0 * k, color.lerp(Color.WHITE, 0.3 * k), 1.6 - 0.4 * k, 0.5 + 0.12 * k)
	sparks(at, Vector2.ZERO, color.lerp(Color.WHITE, 0.5), [10, 24, 44][wfx], 220.0, PI, 0.45)
	motes(at, color, [0, 12, 30][wfx], 30.0, 60.0)
	flash(at, 90.0, Color(color, 0.9), 0.4)
	if game:
		game.shake(3.0 * shake_mult)


## O golpe cinematográfico está na tela (testes)?
func cinematic_active() -> bool:
	return not _cine.is_empty()


# --- Passo ------------------------------------------------------------------------------

func step(dt: float) -> void:
	if _showcase and _showcase.active():
		_showcase.step(game)
	_flashes_this_step = 0
	if _slow_left > 0.0:
		_slow_left -= dt
		time_scale = 0.35
	else:
		time_scale = minf(1.0, time_scale + dt * 3.0)
	var fdt := dt * time_scale
	for i: int in range(particles_max):
		if _p_life[i] <= 0.0:
			continue
		_p_life[i] -= fdt
		var kind := _p_kind[i]
		var v := _p_vel[i] * maxf(0.0, 1.0 - float(DRAG[kind]) * fdt)
		v.y += float(LIFT[kind]) * fdt
		_p_vel[i] = v
		_p_pos[i] += v * fdt
	for i: int in range(MAX_WISPS):
		if _w_life[i] <= 0.0:
			continue
		_w_life[i] -= dt
		# Sobe perdendo força e ondula de lado, como fumaça.
		_w_pos[i] += (_w_vel[i] + Vector2(sin(_w_life[i] * 6.0 + i) * 4.0, 0.0)) * dt
		_w_vel[i] *= 1.0 - 0.5 * dt
	for k: int in range(_anims.size() - 1, -1, -1):
		var anim := _anims[k]
		anim["time"] = float(anim["time"]) + fdt
		if float(anim["time"]) >= float(anim["duration"]):
			_anims.remove_at(k)
	_age(_rings, fdt)
	_age(_flashes, fdt)
	_age(_waves, fdt)
	if not _cine.is_empty():
		_cine["t"] = float(_cine["t"]) + dt
		if float(_cine["t"]) >= 1.2:
			_cine = {}


func _age(list: Array[Dictionary], dt: float) -> void:
	for k: int in range(list.size() - 1, -1, -1):
		list[k]["life"] = float(list[k]["life"]) - dt
		if float(list[k]["life"]) <= 0.0:
			list.remove_at(k)


func _process(delta: float) -> void:
	_calm = bool(Settings.get_value("reduce_flashes"))
	for i: int in range(MAX_NUMBERS):
		if _n_life[i] > 0.0:
			_n_life[i] -= delta
			_n_pos[i] += Vector2(0.0, -14.0 * delta)
	_wave_layer.visible = glow and not _waves.is_empty()
	queue_redraw()
	if glow:
		_glow_layer.queue_redraw()
	if _wave_layer.visible:
		_wave_layer.queue_redraw()


func add_number(at: Vector2, amount: float, crit: bool = false, color: Color = Color.WHITE) -> void:
	if not bool(Settings.get_value("damage_numbers")):
		return
	_n_pos[_n_next] = at + Vector2(randf_range(-3.0, 3.0), -8.0)
	_n_life[_n_next] = NUMBER_LIFETIME
	_n_text[_n_next] = str(roundi(amount))
	_n_color[_n_next] = Color("ffd166") if crit else color
	_n_next = (_n_next + 1) % MAX_NUMBERS


# --- Desenho ------------------------------------------------------------------------------

## Retângulo do mundo visível (para o clarão de tela e as faixas de cinema).
func _view_rect() -> Rect2:
	var ct := get_viewport().get_canvas_transform()
	var s := ct.get_scale()
	var size := get_viewport_rect().size / s
	return Rect2(-ct.origin / s, size)


func _draw() -> void:
	var additive_particles := glow
	for i: int in range(particles_max):
		if _p_life[i] <= 0.0:
			continue
		var kind := _p_kind[i]
		if additive_particles and (kind == P.STREAK or kind == P.GLOW):
			continue
		_draw_particle(self, i, 1.0)
	for i: int in range(MAX_WISPS):
		if _w_life[i] > 0.0:
			# Cresce de 1 para 3 px enquanto some.
			var k := _w_life[i] / WISP_LIFETIME
			var s := roundf(3.0 - 2.0 * k)
			draw_rect(Rect2(_w_pos[i].round() - Vector2(s, s) * 0.5, Vector2(s, s)),
					Color(WISP_COLOR.r, WISP_COLOR.g, WISP_COLOR.b, 0.6 * k))
	for anim: Dictionary in _anims:
		if not (glow and bool(anim["add"])):
			_draw_anim(self, anim)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for ring: Dictionary in _rings:
		_draw_ring(ring)
	if not glow:
		for f: Dictionary in _flashes:
			var a := float(f["life"]) / float(f["max"]) * (0.35 if _calm else 0.6)
			var c: Color = f["color"]
			# Sem brilho: disco interno mais claro e halo fraco, em vez de um disco chapado.
			var at := (f["pos"] as Vector2).round()
			draw_circle(at, float(f["r"]), Color(c.r, c.g, c.b, c.a * a * 0.35))
			draw_circle(at, float(f["r"]) * 0.5, Color(c.lerp(Color.WHITE, 0.5), c.a * a * 0.6))
	if not _cine.is_empty():
		_draw_cinematic()
	for i: int in range(MAX_NUMBERS):
		if _n_life[i] <= 0.0:
			continue
		var alpha := clampf(_n_life[i] / NUMBER_LIFETIME * 2.0, 0.0, 1.0)
		var at := _n_pos[i].round()
		var color := _n_color[i]
		color.a = alpha
		draw_string_outline(_font, at, _n_text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3,
				Color(0.0, 0.0, 0.0, alpha))
		draw_string(_font, at, _n_text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)


func _draw_particle(canvas: CanvasItem, i: int, gain: float) -> void:
	var k := _p_life[i] / maxf(_p_max[i], 0.001)
	var c := _p_color[i]
	var at := _p_pos[i]
	match _p_kind[i]:
		P.STREAK:
			var tail := _p_vel[i] * 0.035
			canvas.draw_line(at.round(), (at - tail).round(), Color(c.r, c.g, c.b, c.a * k * gain), 1.0)
		P.EMBER:
			var flicker := 0.65 + 0.35 * sin(_p_life[i] * 40.0 + i)
			var s := _p_size[i]
			canvas.draw_rect(Rect2(at.round(), Vector2(s, s)), Color(c.r, c.g, c.b, c.a * minf(1.0, k * 1.6) * flicker))
		P.GLOW:
			draw_soft(canvas, at, _p_size[i] * (0.6 + 0.4 * k), Color(c.r, c.g, c.b, c.a * k * gain))
		_:
			var s := _p_size[i]
			canvas.draw_rect(Rect2(at.round(), Vector2(s, s)), Color(c.r, c.g, c.b, c.a * minf(1.0, k * 2.0)))


func _draw_anim(canvas: CanvasItem, anim: Dictionary) -> void:
	var sheet: SpriteSheet = anim["sheet"]
	var frame := mini(int(float(anim["time"]) * float(anim["fps"])), sheet.frames - 1)
	var src := sheet.region(frame, 0)
	var s := float(anim["scale"])
	canvas.draw_set_transform((anim["pos"] as Vector2).round(), float(anim["angle"]),
			Vector2(-s if bool(anim["flip"]) else s, s))
	canvas.draw_texture_rect_region(sheet.texture, Rect2(-src.size * 0.5, src.size), src, anim["tint"])


func _draw_ring(ring: Dictionary) -> void:
	var t: float = 1.0 - float(ring["life"]) / float(ring["max"])
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	var color: Color = ring["color"]
	var r := float(ring["r"]) * eased
	if r < 1.0:
		return
	var a := color.a * (1.0 - t)
	var segments := clampi(int(r * 0.6), 16, 64)
	var w := float(ring["w"]) * (1.0 - 0.5 * t)
	draw_arc(ring["pos"], r, 0.0, TAU, segments, Color(color.r, color.g, color.b, a), maxf(1.0, w))
	if wfx >= 1 and r > 6.0:
		draw_arc(ring["pos"], r - w - 1.0, 0.0, TAU, segments, Color(1.0, 1.0, 1.0, a * 0.35), 1.0)


## Camada aditiva: partículas que brilham, clarões, animações de luz e o brilho das armas.
func _draw_glow() -> void:
	var gain := 0.45 if _calm else 1.0
	for i: int in range(particles_max):
		if _p_life[i] > 0.0 and (_p_kind[i] == P.STREAK or _p_kind[i] == P.GLOW):
			_draw_particle(_glow_layer, i, gain)
	for f: Dictionary in _flashes:
		var k := float(f["life"]) / float(f["max"])
		var c: Color = f["color"]
		draw_soft(_glow_layer, f["pos"], float(f["r"]) * (1.15 - 0.15 * k), Color(c.r, c.g, c.b, c.a * k * gain))
	for anim: Dictionary in _anims:
		if bool(anim["add"]):
			_draw_anim(_glow_layer, anim)
	_glow_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if game:
		for weapon: Weapon in game.weapons:
			weapon.draw_glow(_glow_layer)
		if game.projectiles:
			game.projectiles.draw_glow(_glow_layer)


func _draw_waves() -> void:
	var tex := soft_texture()
	for w: Dictionary in _waves:
		var t := 1.0 - float(w["life"]) / float(w["max"])
		var r := float(w["r"])
		var strength := float(w["s"]) * (1.0 - t) * (0.4 if _calm else 1.0)
		_wave_layer.draw_texture_rect(tex, Rect2((w["pos"] as Vector2) - Vector2(r, r), Vector2(r, r) * 2.0),
				false, Color(t, 0.0, 0.0, clampf(strength, 0.0, 1.0)))


## Clarão de tela, faixas de cinema e linhas de velocidade do golpe da lanterna.
func _draw_cinematic() -> void:
	var t := float(_cine["t"])
	var view := _view_rect()
	var color: Color = _cine["color"]
	var at: Vector2 = _cine["pos"]
	# Clarão: forte no primeiro décimo de segundo; fraco com "reduzir clarões".
	var flash_a := clampf(1.0 - t / 0.35, 0.0, 1.0) * (0.12 if _calm else 0.5)
	if flash_a > 0.0:
		draw_rect(view, Color(color.lerp(Color.WHITE, 0.6), flash_a))
	# Faixas de cinema: entram em 0,15 s, ficam e saem até 1,2 s.
	var bar := 22.0 * clampf(t / 0.15, 0.0, 1.0) * clampf((1.2 - t) / 0.3, 0.0, 1.0)
	if bar >= 1.0:
		draw_rect(Rect2(view.position, Vector2(view.size.x, bar)).grow(1.0), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(view.position + Vector2(0, view.size.y - bar), Vector2(view.size.x, bar)).grow(1.0),
				Color(0, 0, 0, 0.85))
	# Linhas de velocidade em volta da guardiã.
	var lines: int = [8, 16, 28][wfx]
	var la := clampf(1.0 - t / 0.6, 0.0, 1.0)
	if la <= 0.0:
		return
	var reach := view.size.length() * 0.6
	for k: int in range(lines):
		var a := TAU * k / float(lines) + 0.37 * (k % 3)
		var d := Vector2.from_angle(a)
		var near := 40.0 + 60.0 * t + 14.0 * (k % 4)
		var p0 := at + d * near
		var p1 := at + d * (near + reach * (0.3 + 0.1 * (k % 3)))
		var side := d.orthogonal() * (1.5 + (k % 2))
		draw_colored_polygon(PackedVector2Array([p0, p1 + side, p1 - side]),
				Color(color.lerp(Color.WHITE, 0.7), 0.55 * la))
