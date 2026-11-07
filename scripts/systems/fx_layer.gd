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
const MAX_ANIMS := 160
const MAX_FLASHES := 48
const MAX_RINGS := 40
## Ondas de distorção ao mesmo tempo (só na Alta: cada uma custa uma cópia de tela).
const MAX_WAVES := 3
## Clarões novos por passo de simulação (centenas de acertos não viram um borrão branco).
const FLASHES_PER_STEP := 6
## Impactos completos por passo: além disto (um corte de área em centenas de inimigos), cada
## acerto solta só uma faísca e o crítico não ganha o "X" (o número de dano aparece igual).
const IMPACTS_PER_STEP := 16
## Impactos de dano contínuo (tiques da Queimadura, do incenso...) por passo: além disto o tique
## solta só uma brasa (centenas de yōkai queimando juntos não enchem o pool de partículas).
const DOT_IMPACTS_PER_STEP := 4
## "X" do crítico por passo (o resto dos críticos do mesmo passo fica só com o número e as faíscas).
const CRIT_ANIMS_PER_STEP := 4
## Faíscas por acerto em cada nível gráfico.
const IMPACT_COUNT := [1, 3, 5]
const RING_LIFETIME := 0.4
## Camada dos números: acima da escuridão da lanterna (5), do clarão do relâmpago (7) e do tom
## da noite (CanvasModulate só pinta a camada 0), abaixo da HUD (10). Cores fiéis à paleta.
const NUMBER_LAYER := 8
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
## Animações opcionais (quadros quadrados: a largura do quadro é a altura da imagem), carregadas só
## se o arquivo existir: pedras do Rocha, corte duplo, explosão grande e impactos (Altares do Selo).
const EXTRA_ANIMS := {
	"rock_burst": "res://assets/art/fx/rock/rock_burst.png",
	"cut_double": "res://assets/art/fx/slash_double/cut_double.png",
	"explosion_big": "res://assets/art/fx/explosion_big/explosion_big.png",
	"impact_0": "res://assets/art/fx/impact/impact_0.png",
	"impact_1": "res://assets/art/fx/impact/impact_1.png",
	"impact_2": "res://assets/art/fx/impact/impact_2.png",
}
## Raio ramificado procedural (lightning_bolt): vida, teto na tela e o tremor do traço.
const BOLT_LIFE := 0.26
const MAX_BOLTS := 16
const BOLT_JAG := 0.11
## Coluna de luz (light_pillar): a arte Raylight (3 raios inclinados lado a lado, branco sobre
## transparente), endireitada com um cisalhamento; entra, fica e some.
const RAY_TEXTURE := "res://assets/art/fx/environment/Raylight.png"
const RAY_REGIONS: Array[Rect2] = [Rect2(0, 0, 72, 102), Rect2(72, 0, 72, 102), Rect2(144, 0, 72, 102)]
const RAY_SKEW := 0.43
const MAX_PILLARS := 6
## Estilhaços de ofuda (paper_burst): papel que voa, gira e cai devagar (assets/art/altar/ofuda.png,
## 4 quadros de 6x10).
const PAPER_TEXTURE := "res://assets/art/altar/ofuda.png"
const PAPER_FRAME := Vector2(6, 10)
const MAX_PAPERS := 64
const PAPER_LIFE := 1.1
## Aberração cromática curta (chroma_pulse): só na Alta e sem "reduzir clarões".
const CHROMA_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
void fragment() {
	vec2 c = SCREEN_UV - vec2(0.5);
	vec2 off = c * COLOR.a * 0.02;
	float r = texture(screen_tex, SCREEN_UV + off).r;
	float g = texture(screen_tex, SCREEN_UV).g;
	float b = texture(screen_tex, SCREEN_UV - off).b;
	COLOR = vec4(r, g, b, 1.0);
}
"""
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
## Números de dano e cura (DamageNumbers, num CanvasLayer que segue a câmera).
var numbers: DamageNumbers

var _sheets: Dictionary = {}

var _p_pos := PackedVector2Array()
var _p_vel := PackedVector2Array()
var _p_life := PackedFloat32Array()
var _p_max := PackedFloat32Array()
var _p_size := PackedFloat32Array()
var _p_color := PackedColorArray()
var _p_kind := PackedByteArray()
var _p_next: int = 0
## Partículas vivas e o índice da mais antiga viva (o anel só tem vivas de _p_oldest até
## _p_next - 1): o passo, o desenho e o brilho percorrem só essa janela, não as 1400 vagas da
## cota Alta a cada quadro (e nada quando não há partícula).
var _p_alive: int = 0
var _p_oldest: int = 0
## Tamanho da janela no último passo e partículas criadas desde então (se passarem da cota, o
## anel deu a volta sobre a janela: desenha o anel inteiro naquele quadro).
var _p_window: int = 0
var _p_emits: int = 0

## Média móvel dos golpes diretos comuns (DamagePalette.next_mean): golpe "alto" e tamanho.
var _hit_mean: float = 0.0
## Golpes mostrados (número novo ou somado); os testes conferem que algo apareceu.
var _n_next: int:
	get:
		return numbers.events if numbers else 0

var _w_pos := PackedVector2Array()
var _w_vel := PackedVector2Array()
var _w_life := PackedFloat32Array()
var _w_next: int = 0

var _anims: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _waves: Array[Dictionary] = []
var _flashes_this_step: int = 0
var _impacts_this_step: int = 0
var _crit_anims_this_step: int = 0
var _dot_impacts_this_step: int = 0
## Números visíveis por tipo (DamagePalette.Kind): "damage_numbers" e a opção do tipo juntas, em
## cache (relidas a cada quadro e quando uma opção muda), sem consultar o Settings a cada acerto.
var _show_kind := PackedByteArray()
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
## Raios ramificados: {"paths", "widths", "color", "width", "branches", "life", "max", "from", "to",
## "rejit"}.
var _bolts: Array[Dictionary] = []
var _pillars: Array[Dictionary] = []
var _ray_tex: Texture2D
var _paper_tex: Texture2D
var _paper_pos := PackedVector2Array()
var _paper_vel := PackedVector2Array()
var _paper_life := PackedFloat32Array()
var _paper_spin := PackedFloat32Array()
var _paper_rate := PackedFloat32Array()
var _paper_frame := PackedInt32Array()
var _paper_next: int = 0
var _papers: int = 0
var _chroma_layer: Node2D
var _chroma_left: float = 0.0
var _chroma_max: float = 0.0
var _chroma_strength: float = 0.0


func _ready() -> void:
	_font = Locale.font if Locale.font else ThemeDB.fallback_font
	game = get_parent() as HyakkiGame
	for name: String in ANIMS:
		var spec: Array = ANIMS[name]
		_sheets[name] = SpriteSheet.load_sheet(spec[0], "strip", Vector2(float(spec[1]), 0.0))
	for name: String in EXTRA_ANIMS:
		if ResourceLoader.exists(EXTRA_ANIMS[name]):
			_sheets[name] = SpriteSheet.load_sheet(EXTRA_ANIMS[name], "strip", Vector2.ZERO)
	_ray_tex = load(RAY_TEXTURE) as Texture2D if ResourceLoader.exists(RAY_TEXTURE) else null
	_paper_tex = load(PAPER_TEXTURE) as Texture2D if ResourceLoader.exists(PAPER_TEXTURE) else null
	for packed: StringName in [&"_paper_pos", &"_paper_vel", &"_paper_life", &"_paper_spin", &"_paper_rate",
			&"_paper_frame"]:
		var list: Variant = get(packed)
		list.resize(MAX_PAPERS)
		set(packed, list)
	for packed: StringName in [&"_p_pos", &"_p_vel", &"_p_life", &"_p_max", &"_p_size", &"_p_color",
			&"_p_kind"]:
		var array: Variant = get(packed)
		array.resize(PARTICLE_CAPACITY)
		set(packed, array)
	_w_pos.resize(MAX_WISPS)
	_w_vel.resize(MAX_WISPS)
	_w_life.resize(MAX_WISPS)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_layer = Node2D.new()
	_glow_layer.material = additive
	_glow_layer.draw.connect(_draw_glow)
	add_child(_glow_layer)
	var layer_node := CanvasLayer.new()
	layer_node.layer = NUMBER_LAYER
	layer_node.follow_viewport_enabled = true
	add_child(layer_node)
	numbers = DamageNumbers.new()
	layer_node.add_child(numbers)
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
	var chroma_material := ShaderMaterial.new()
	var chroma_shader := Shader.new()
	chroma_shader.code = CHROMA_SHADER
	chroma_material.shader = chroma_shader
	_chroma_layer = Node2D.new()
	_chroma_layer.material = chroma_material
	_chroma_layer.z_as_relative = false
	_chroma_layer.z_index = 20
	_chroma_layer.visible = false
	_chroma_layer.draw.connect(_draw_chroma)
	add_child(_chroma_layer)
	_showcase = WeaponShowcase.new()
	refresh_quality()
	_apply_quality()
	_refresh_number_settings()
	Settings.changed.connect(_on_setting)
	reset()


func _on_setting(key: String) -> void:
	if key == GfxQuality.changed_signal_key():
		refresh_quality()
		_apply_quality()
	_refresh_number_settings()


## Relê "damage_numbers" e as opções por tipo (DamagePalette.SETTING_KEYS) para o cache.
func _refresh_number_settings() -> void:
	var all := bool(Settings.get_value("damage_numbers"))
	_show_kind.resize(DamagePalette.SETTING_KEYS.size())
	for kind: int in range(DamagePalette.SETTING_KEYS.size()):
		_show_kind[kind] = 1 if all and bool(Settings.get_value(DamagePalette.SETTING_KEYS[kind])) else 0


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
	_recount_particles()
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
	_p_alive = 0
	_p_oldest = _p_next
	numbers.reset()
	_hit_mean = 0.0
	_w_life.fill(0.0)
	_anims.clear()
	_rings.clear()
	_flashes.clear()
	_waves.clear()
	_bolts.clear()
	_pillars.clear()
	_paper_life.fill(0.0)
	_papers = 0
	_chroma_left = 0.0
	_cine = {}
	_slow_left = 0.0
	time_scale = 1.0


# --- Partículas ------------------------------------------------------------------

func _emit(kind: int, at: Vector2, vel: Vector2, life: float, color: Color, size: float = 1.0) -> void:
	var i := _p_next
	if _p_life[i] <= 0.0:
		_p_alive += 1
	_p_emits += 1
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


## Trechos do anel com partículas vivas, em ordem crescente de índice (a mesma ordem de desenho
## de antes): [mais antiga, _p_next) ou, se a janela dá a volta, [0, _p_next) e [mais antiga, cota).
func _particle_spans() -> Array[Vector2i]:
	if _p_alive <= 0:
		return []
	if _p_oldest == _p_next or _p_window + _p_emits >= particles_max:
		return [Vector2i(0, particles_max)]
	if _p_oldest < _p_next:
		return [Vector2i(_p_oldest, _p_next)]
	return [Vector2i(0, _p_next), Vector2i(_p_oldest, particles_max)]


## Recalcula as vivas e a janela (depois de mudar a cota).
func _recount_particles() -> void:
	_p_alive = 0
	_p_oldest = _p_next
	_p_emits = particles_max
	for k: int in range(particles_max):
		var i := (_p_next + k) % particles_max
		if _p_life[i] > 0.0:
			_p_alive += 1
			if _p_alive == 1:
				_p_oldest = i


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
## `dot`: tique de dano contínuo (poças, furacões, aura); `enemy`: índice do alvo (soma golpes
## seguidos no mesmo inimigo num número só).
func on_hit(weapon_id: StringName, at: Vector2, amount: float, crit: bool, dir: Vector2,
		dot: bool = false, enemy: int = -1) -> void:
	var kind := DamagePalette.classify_hit(amount, crit, dot, _hit_mean)
	add_number(at, amount, kind, _hit_mean, enemy)
	_hit_mean = DamagePalette.next_mean(_hit_mean, amount, kind)
	if dot:
		_dot_impacts_this_step += 1
		if _dot_impacts_this_step > DOT_IMPACTS_PER_STEP:
			_emit(P.EMBER, at, Vector2(randf_range(-10.0, 10.0), randf_range(-24.0, -8.0)), randf_range(0.3, 0.5),
					style(weapon_id)["hot"])
			return
	impact(weapon_id, at, dir, crit)


## Cor e tipo de impacto da arma (data/weapons.json "fx" e HitSounds), em cache.
func style(weapon_id: StringName) -> Dictionary:
	if not _styles.has(weapon_id):
		_styles[weapon_id] = WeaponStyle.of(DB.weapon(weapon_id))
	return _styles[weapon_id]


## Estilo de um dano que não é arma (habilidades dos guardiões): `row` no formato de uma linha
## de data/weapons.json ("fx" com color/hot e "tags"/"sfx.impact" para o tipo de impacto).
func register_style(id: StringName, row: Dictionary) -> void:
	_styles[id] = WeaponStyle.of(row)


## Impacto conforme o tipo do golpe. Na Baixa só uma faísca (e um pouco mais no crítico).
func impact(weapon_id: StringName, at: Vector2, dir: Vector2, crit: bool = false) -> void:
	var s := style(weapon_id)
	var color: Color = s["color"]
	var hot: Color = s["hot"]
	_impacts_this_step += 1
	if _impacts_this_step > IMPACTS_PER_STEP:
		# Além da cota do passo: uma faísca só, da cor quente da arma (sem clarão nem animação).
		var a := (dir.angle() if dir != Vector2.ZERO else randf() * TAU) + randf_range(-0.9, 0.9)
		_emit(P.STREAK, at, Vector2.from_angle(a) * randf_range(60.0, 120.0), randf_range(0.12, 0.2), hot)
		return
	var n: int = IMPACT_COUNT[wfx]
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
		"hit_ice":
			sparks(at, dir, hot, n, 110.0, 1.1, 0.14)
			flash(at, 9.0, Color(color, 0.7), 0.08)
		_:
			burst(at, hot, n)
	if crit and wfx > 0 and _crit_anims_this_step < CRIT_ANIMS_PER_STEP:
		_crit_anims_this_step += 1
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
	_impacts_this_step = 0
	_crit_anims_this_step = 0
	_dot_impacts_this_step = 0
	if _slow_left > 0.0:
		_slow_left -= dt
		time_scale = 0.35
	else:
		time_scale = minf(1.0, time_scale + dt * 3.0)
	var fdt := dt * time_scale
	# Da mais nova para trás, até achar todas as vivas (cada uma é independente: a ordem não muda
	# nada); a última achada é a mais antiga, o começo da janela do desenho.
	var seen := 0
	var alive_before := _p_alive
	var slot := _p_next
	_p_oldest = _p_next
	for k: int in range(particles_max):
		if seen >= alive_before:
			break
		slot = slot - 1 if slot > 0 else particles_max - 1
		if _p_life[slot] <= 0.0:
			continue
		seen += 1
		_p_oldest = slot
		_p_life[slot] -= fdt
		if _p_life[slot] <= 0.0:
			_p_alive -= 1
		var kind := _p_kind[slot]
		var v := _p_vel[slot] * maxf(0.0, 1.0 - float(DRAG[kind]) * fdt)
		v.y += float(LIFT[kind]) * fdt
		_p_vel[slot] = v
		_p_pos[slot] += v * fdt
	_p_emits = 0
	_p_window = 0 if seen == 0 else (_p_next - _p_oldest + particles_max) % particles_max
	if seen > 0 and _p_window == 0:
		_p_window = particles_max
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
	_age(_pillars, fdt)
	_step_bolts(fdt)
	_step_papers(fdt)
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
	_refresh_number_settings()
	numbers.set_colorblind(bool(Settings.get_value("colorblind")))
	numbers.low = wfx == 0
	if game and game.player:
		numbers.guard = game.player.position
	if game and game.enemies:
		numbers.enemies = game.enemies.count_alive
	numbers.step(delta)
	_wave_layer.visible = glow and not _waves.is_empty()
	if _chroma_left > 0.0:
		_chroma_left -= delta
		_chroma_layer.visible = _chroma_left > 0.0 and glow and not _calm
		_chroma_layer.queue_redraw()
	elif _chroma_layer.visible:
		_chroma_layer.visible = false
	queue_redraw()
	if glow:
		_glow_layer.queue_redraw()
	if _wave_layer.visible:
		_wave_layer.queue_redraw()


## Número de dano ou cura em `at` (DamagePalette.Kind). `ref`: média móvel (dano causado) ou
## HP máximo (recebido e cura), para o tamanho; `target`: inimigo (soma golpes seguidos).
## Desligado pela opção "damage_numbers" e, por tipo, pelas opções DamagePalette.SETTING_KEYS
## (em cache, relidas a cada quadro e na troca: a troca nas Opções vale na mesma partida).
func add_number(at: Vector2, amount: float, kind: int = DamagePalette.Kind.HIT, ref: float = 0.0,
		target: int = -1) -> void:
	if _show_kind[kind] == 0:
		return
	numbers.add(global_position + at, amount, kind, ref, target)


## Último número criado ou somado (testes): {"kind", "text", "fill", "size", ...} ou vazio.
func last_number() -> Dictionary:
	return numbers.last()


# --- Desenho ------------------------------------------------------------------------------

## Retângulo do mundo visível (para o clarão de tela e as faixas de cinema).
func _view_rect() -> Rect2:
	var ct := get_viewport().get_canvas_transform()
	var s := ct.get_scale()
	var size := get_viewport_rect().size / s
	return Rect2(-ct.origin / s, size)


func _draw() -> void:
	var additive_particles := glow
	for span: Vector2i in _particle_spans():
		for i: int in range(span.x, span.y):
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
	_draw_papers()
	for bolt: Dictionary in _bolts:
		_draw_bolt(self, bolt, false)
	if not glow:
		for pillar: Dictionary in _pillars:
			_draw_pillar(self, pillar, 0.55)
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
	Stroke.arc(self, ring["pos"], r, 0.0, TAU, segments, Color(color.r, color.g, color.b, a), maxf(1.0, w))
	if wfx >= 1 and r > 6.0:
		Stroke.arc(self, ring["pos"], r - w - 1.0, 0.0, TAU, segments, Color(1.0, 1.0, 1.0, a * 0.35), 1.0)


## Camada aditiva: partículas que brilham, clarões, animações de luz e o brilho das armas.
func _draw_glow() -> void:
	var gain := 0.45 if _calm else 1.0
	for span: Vector2i in _particle_spans():
		for i: int in range(span.x, span.y):
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
	for pillar: Dictionary in _pillars:
		_draw_pillar(_glow_layer, pillar, gain)
	for bolt: Dictionary in _bolts:
		_draw_bolt(_glow_layer, bolt, true)
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
		Stroke.convex(self, PackedVector2Array([p0, p1 + side, p1 - side]),
				Color(color.lerp(Color.WHITE, 0.7), 0.55 * la))


# --- Raio ramificado, coluna de luz, papel e aberração (Altares do Selo) ---------------------

## Raio procedural de `from` a `to`: tronco em zigue-zague (deslocamento do ponto médio) com
## `branches` galhos que saem dele, tudo em primitivas do Stroke (sem polígono por quadro). Na
## metade da vida o traço "pisca" (refaz o zigue-zague uma vez). Baixa: sem galhos nem brilho.
func lightning_bolt(from: Vector2, to: Vector2, color: Color = Color(0.75, 0.88, 1.0), width: float = 2.0,
		branches: int = 2, life: float = BOLT_LIFE) -> void:
	if _bolts.size() >= MAX_BOLTS:
		_bolts.pop_front()
	var bolt := {"from": from, "to": to, "color": color, "width": width, "life": life, "max": life,
			"branches": branches if wfx > 0 else 0, "rejit": false}
	_shape_bolt(bolt)
	_bolts.append(bolt)


## Raios ramificados na tela (testes).
func bolts_alive() -> int:
	return _bolts.size()


func _shape_bolt(bolt: Dictionary) -> void:
	var from: Vector2 = bolt["from"]
	var to: Vector2 = bolt["to"]
	var length := from.distance_to(to)
	var main := _jagged(from, to, clampi(int(length / 9.0), 5, 18))
	var paths: Array[PackedVector2Array] = [main]
	var widths := PackedFloat32Array([float(bolt["width"])])
	var dir := (to - from).normalized()
	for _b: int in int(bolt["branches"]):
		var k := randi_range(1, maxi(1, main.size() - 3))
		var start := main[k]
		var turn := randf_range(0.45, 0.95) * (1.0 if randf() < 0.5 else -1.0)
		var reach := length * randf_range(0.16, 0.32)
		paths.append(_jagged(start, start + dir.rotated(turn) * reach, randi_range(3, 5)))
		widths.append(maxf(1.0, float(bolt["width"]) * 0.5))
	bolt["paths"] = paths
	bolt["widths"] = widths


## Linha quebrada de `a` a `b` em `segments` trechos, com desvio lateral que some nas pontas.
static func _jagged(a: Vector2, b: Vector2, segments: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var side := (b - a).orthogonal().normalized()
	var amp := a.distance_to(b) * BOLT_JAG
	for s: int in range(segments + 1):
		var k := float(s) / segments
		var p := a.lerp(b, k)
		if s > 0 and s < segments:
			p += side * randf_range(-amp, amp) * sin(k * PI)
		out.append(p.round())
	return out


func _step_bolts(dt: float) -> void:
	for k: int in range(_bolts.size() - 1, -1, -1):
		var bolt := _bolts[k]
		bolt["life"] = float(bolt["life"]) - dt
		if float(bolt["life"]) <= 0.0:
			_bolts.remove_at(k)
		elif not bool(bolt["rejit"]) and float(bolt["life"]) < float(bolt["max"]) * 0.55:
			bolt["rejit"] = true
			_shape_bolt(bolt)


## Normal: miolo branco (e, sem brilho, o traço na cor). Aditiva: halo largo e o traço na cor.
func _draw_bolt(canvas: CanvasItem, bolt: Dictionary, additive: bool) -> void:
	var k := clampf(float(bolt["life"]) / float(bolt["max"]), 0.0, 1.0)
	var flicker := 0.75 + 0.25 * sin(float(bolt["life"]) * 90.0)
	var a := k * flicker * (0.5 if _calm else 1.0)
	var color: Color = bolt["color"]
	var paths: Array[PackedVector2Array] = bolt["paths"]
	var widths: PackedFloat32Array = bolt["widths"]
	for p: int in paths.size():
		var w := widths[p]
		if additive:
			Stroke.line(canvas, paths[p], Color(color, 0.3 * a), w * 3.0 + 1.0)
			Stroke.line(canvas, paths[p], Color(color, 0.95 * a), w)
		else:
			if not glow:
				Stroke.line(canvas, paths[p], Color(color, 0.8 * a), w + 1.0)
			Stroke.line(canvas, paths[p], Color(1.0, 1.0, 1.0, a), maxf(1.0, w * 0.5))


## Coluna de luz em `at` (base no chão), `height` px de altura: cresce em 15% da vida, fica e some.
func light_pillar(at: Vector2, color: Color, height: float = 150.0, width: float = 28.0, life: float = 0.9) -> void:
	if _pillars.size() >= MAX_PILLARS:
		_pillars.pop_front()
	_pillars.append({"pos": at, "color": color, "h": height, "w": width, "life": life, "max": life})


func pillars_alive() -> int:
	return _pillars.size()


## Uma coluna: dois raios da arte Raylight endireitados (um largo e um miolo mais claro) e o brilho
## na base. Sem a arte, um degradê suave esticado.
func _draw_pillar(canvas: CanvasItem, pillar: Dictionary, gain: float) -> void:
	var t := 1.0 - float(pillar["life"]) / float(pillar["max"])
	var grow := clampf(t / 0.15, 0.0, 1.0)
	var fade := clampf((1.0 - t) / 0.4, 0.0, 1.0)
	var color: Color = pillar["color"]
	var base: Vector2 = (pillar["pos"] as Vector2).round()
	var h := float(pillar["h"])
	var w := float(pillar["w"]) * (0.3 + 0.7 * grow) * (1.0 + 0.06 * sin(float(pillar["life"]) * 40.0))
	var a := fade * gain
	if _ray_tex != null:
		for layer: int in 2:
			var src := RAY_REGIONS[layer]
			var lw := w * (1.0 if layer == 0 else 0.45)
			var sx := lw / src.size.x
			var sy := h / src.size.y
			# Cisalhamento que deixa o raio inclinado na vertical, centrado na base.
			var xf := Transform2D(Vector2(sx, 0.0), Vector2(RAY_SKEW * sx, sy), base - Vector2(0.0, h))
			canvas.draw_set_transform_matrix(xf)
			var off := -src.size.x * 0.5 - RAY_SKEW * src.size.y * 0.5
			var tint := color.lerp(Color.WHITE, 0.35 * layer)
			canvas.draw_texture_rect_region(_ray_tex, Rect2(Vector2(off, 0.0), src.size), src,
					Color(tint, a * (0.8 - 0.1 * layer)))
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		canvas.draw_texture_rect(soft_texture(), Rect2(base - Vector2(w * 0.5, h), Vector2(w, h * 1.1)), false,
				Color(color, a))
	draw_soft(canvas, base, w * 1.1, Color(color.lerp(Color.WHITE, 0.4), 0.7 * a))


## Estilhaços de ofuda: `count` tiras de papel voando de `at` para cima e para os lados.
func paper_burst(at: Vector2, count: int, speed: float = 90.0) -> void:
	for _k: int in count:
		var i := _paper_next
		if _paper_life[i] <= 0.0:
			_papers += 1
		_paper_next = (_paper_next + 1) % MAX_PAPERS
		var dir := Vector2.from_angle(randf_range(-PI * 0.95, -PI * 0.05))
		_paper_pos[i] = at + dir * randf_range(0.0, 4.0)
		_paper_vel[i] = dir * speed * randf_range(0.5, 1.2)
		_paper_life[i] = PAPER_LIFE * randf_range(0.7, 1.15)
		_paper_spin[i] = randf() * TAU
		_paper_rate[i] = randf_range(-14.0, 14.0)
		_paper_frame[i] = randi_range(0, 3)


func papers_alive() -> int:
	return _papers


func _step_papers(dt: float) -> void:
	if _papers <= 0:
		return
	for i: int in MAX_PAPERS:
		if _paper_life[i] <= 0.0:
			continue
		_paper_life[i] -= dt
		if _paper_life[i] <= 0.0:
			_papers -= 1
			continue
		var v := _paper_vel[i] * maxf(0.0, 1.0 - 2.4 * dt)
		v.y += 70.0 * dt
		v.x += sin(_paper_life[i] * 9.0 + i) * 30.0 * dt
		_paper_vel[i] = v
		_paper_pos[i] += v * dt
		_paper_spin[i] += _paper_rate[i] * dt


func _draw_papers() -> void:
	if _papers <= 0:
		return
	for i: int in MAX_PAPERS:
		if _paper_life[i] <= 0.0:
			continue
		var a := clampf(_paper_life[i] / 0.3, 0.0, 1.0)
		# Papel girando em 3D: a largura encolhe e cresce com o giro.
		var flip := cos(_paper_spin[i])
		draw_set_transform(_paper_pos[i].round(), _paper_spin[i] * 0.35, Vector2(maxf(0.15, absf(flip)), 1.0))
		if _paper_tex != null:
			var src := Rect2(Vector2(_paper_frame[i] * PAPER_FRAME.x, 0.0), PAPER_FRAME)
			draw_texture_rect_region(_paper_tex, Rect2(-PAPER_FRAME * 0.5, PAPER_FRAME), src, Color(1, 1, 1, a))
		else:
			draw_rect(Rect2(-1.5, -2.5, 3.0, 5.0), Color(0.96, 0.92, 0.8, a))
			draw_rect(Rect2(-0.5, -1.5, 1.0, 3.0), Color(0.8, 0.15, 0.1, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Vento que puxa: pontos de luz num anel de `radius` correndo para `at` (chegam juntos).
func gather(at: Vector2, radius: float, color: Color, count: int, life: float = 0.4) -> void:
	var kind := P.GLOW if glow else P.DOT
	var drag := float(DRAG[kind])
	var speed := radius * drag / maxf(0.001, 1.0 - exp(-drag * life))
	for _k: int in count:
		var dir := Vector2.from_angle(randf() * TAU)
		_emit(kind, at + dir * radius * randf_range(0.85, 1.15), -dir * speed, life, color,
				randf_range(1.5, 3.0) if glow else 1.0)


## Aberração cromática da tela inteira por `life` s (Alta, sem "reduzir clarões").
func chroma_pulse(strength: float = 1.0, life: float = 0.28) -> void:
	if not glow:
		return
	_chroma_left = life
	_chroma_max = life
	_chroma_strength = clampf(strength, 0.0, 2.0)


func chroma_active() -> bool:
	return _chroma_left > 0.0


func _draw_chroma() -> void:
	var k := clampf(_chroma_left / maxf(_chroma_max, 0.001), 0.0, 1.0)
	_chroma_layer.draw_rect(_view_rect().grow(4.0), Color(1, 1, 1, clampf(k * k * _chroma_strength * 0.5, 0.0, 1.0)))


## Hit-stop curto (o relógio segura em tempo real; a simulação não muda). Não no bot.
func hitstop(seconds: float) -> void:
	if game != null and game.is_bot():
		return
	GameClock.hitstop(seconds)


## A animação `name` foi carregada (as de EXTRA_ANIMS só existem com o arquivo).
func has_anim(name: String) -> bool:
	return _sheets.has(name)
