class_name EnemyFx
extends Node2D
## Efeitos visuais dos inimigos e chefes, num laço só e em arrays (sem Node por partícula):
## entrada (fumaça, fogo-fátuo, portal de névoa), morte por tipo (brasas do oni, névoa do
## fantasma, respingo do slime, ossos, folhas, penas, pedra, cinzas com alma que sobe),
## poeira do recuo e das pisadas, vapor dos onis e faíscas das elites.
##
## Só desenho: usa RNG próprio e nunca escreve na simulação (o hash da partida é o mesmo em
## qualquer nível gráfico). A cota sai de GfxQuality ("particles_max" × SHARE e "enemy_fx") e
## acompanha a troca ao vivo. As partículas andam no tempo de jogo (param na pausa e seguem
## 1x/2x/3x) e aceitam câmera lenta só delas (time_scale), usada na morte dos chefes.

enum Kind { PIXEL, GLOW, SMOKE, SOUL, RING, SHARD }

## Teto absoluto do buffer; a cota viva é particles_max × SHARE (o resto fica para as armas).
const CAPACITY := 900
const SHARE := 0.5
## Mortes com som: no máximo uma a cada SOUND_GAP_MS, para a horda não virar ruído.
const SOUND_GAP_MS := 90
const SOUND_DB := -13.0
## Estilos de morte e de entrada (data/enemies.json "death"/"spawn"; senão, pelo arquétipo).
const DEATH_STYLES: Array[String] = ["ash", "embers", "mist", "splash", "bones", "leaves", "feathers", "stone"]
const SPAWN_STYLES: Array[String] = ["smoke", "wisp", "portal"]
## Sons gerados (tools/gen_enemy_sfx.py) por estilo de morte; 3 variações cada.
const DEATH_SOUND := {"ash": "e_die_ash", "embers": "e_die_ember", "mist": "e_die_mist",
		"splash": "e_die_splat", "bones": "e_die_bone", "leaves": "e_die_ash", "feathers": "e_die_mist",
		"stone": "e_die_bone"}

## Partículas por morte em cada nível de "enemy_fx" (0, 1, 2).
const DEATH_COUNT: Array[int] = [4, 9, 16]

var game: HyakkiGame
## Nível de detalhe ("enemy_fx": 0, 1 ou 2), cota viva de partículas e brilho aditivo.
var detail: int = 2
var cap: int = CAPACITY
var glow: bool = true
## Câmera lenta só dos efeitos (morte de chefe): 1 = normal.
var time_scale: float = 1.0

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _max_life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _grav := PackedFloat32Array()
var _rot := PackedFloat32Array()
var _color := PackedColorArray()
var _kind := PackedByteArray()
var _next: int = 0
var _alive: int = 0
var _slow_left: float = 0.0
var _last_sound_ms: int = -1000
var _look := RandomNumberGenerator.new()
var _soft: Texture2D
var _add_layer: Node2D


func _ready() -> void:
	for packed: StringName in [&"_pos", &"_vel", &"_life", &"_max_life", &"_size", &"_grav", &"_rot",
			&"_color", &"_kind"]:
		var array: Variant = get(packed)
		array.resize(CAPACITY)
		set(packed, array)
	_soft = soft_texture()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add_layer = Node2D.new()
	_add_layer.material = additive
	_add_layer.draw.connect(_draw_additive)
	add_child(_add_layer)
	_look.randomize()
	apply_quality()
	var settings := get_node_or_null(^"/root/Settings")
	if settings:
		settings.connect("changed", func(k: String) -> void:
			if k == GfxQuality.changed_signal_key():
				apply_quality())
	reset()


## Disco branco com borda degradê (32×32), compartilhado: sombras suaves, brilhos e névoa.
static func soft_texture() -> Texture2D:
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	tex.gradient = g
	return tex


## Cota de partículas num nível (testes e apply_quality).
static func cap_for(level: int) -> int:
	return clampi(int(float(GfxQuality.budget_at("particles_max", level)) * SHARE), 16, CAPACITY)


func apply_quality() -> void:
	detail = int(GfxQuality.budget("enemy_fx"))
	glow = bool(GfxQuality.budget("glow")) or detail >= 1
	cap = cap_for(GfxQuality.level())
	# Ao baixar, apaga o que passou da cota nova.
	for i: int in range(cap, CAPACITY):
		if _life[i] > 0.0:
			_life[i] = 0.0
			_alive -= 1
	if _next >= cap:
		_next = 0
	_alive = maxi(_alive, 0)


func reset() -> void:
	_life.fill(0.0)
	_alive = 0
	_next = 0
	time_scale = 1.0
	_slow_left = 0.0


func alive_count() -> int:
	return _alive


## Câmera lenta só dos efeitos por `seconds` (tempo real).
func slow_motion(seconds: float, scale_to: float = 0.3) -> void:
	_slow_left = maxf(_slow_left, seconds)
	time_scale = scale_to


# --- Emissão ----------------------------------------------------------------------------

func add(kind: int, at: Vector2, vel: Vector2, life: float, size: float, color: Color,
		grav: float = 0.0, rot: float = 0.0) -> void:
	if cap <= 0:
		return
	var i := _next
	if _life[i] <= 0.0:
		_alive += 1
	_pos[i] = at
	_vel[i] = vel
	_life[i] = life
	_max_life[i] = life
	_size[i] = size
	_color[i] = color
	_kind[i] = kind
	_grav[i] = grav
	_rot[i] = rot
	_next = (_next + 1) % cap


func _rand_dir(spread: float = PI, base: float = -PI * 0.5) -> Vector2:
	return Vector2.from_angle(base + _look.randf_range(-spread, spread))


## Estilo de morte de um inimigo (campo "death" ou pelo id/arquétipo).
static func death_style(data: Dictionary) -> String:
	var style := String(data.get("death", ""))
	if style in DEATH_STYLES:
		return style
	var id := String(data.get("id", ""))
	if data.get("flying", false) and String(data.get("archetype", "")) == "shade":
		return "mist"
	if id.contains("slime") or id.contains("kappa"):
		return "splash"
	if id.contains("oni") or id.contains("flame"):
		return "embers"
	return "ash"


## Estilo de entrada (campo "spawn" ou pelo arquétipo).
static func spawn_style(data: Dictionary) -> String:
	var style := String(data.get("spawn", ""))
	if style in SPAWN_STYLES:
		return style
	if bool(data.get("flying", false)):
		return "wisp"
	if float(data.get("radius", 5)) >= 7.0 or String(data.get("archetype", "")) == "tank":
		return "portal"
	return "smoke"


## Morte de inimigo: partículas do estilo, na cor do bicho, e (se der) um som do estilo.
func death(at: Vector2, style: String, tint: Color, size: float = 1.0, elite: bool = false,
		with_sound: bool = true) -> void:
	var n := roundi(DEATH_COUNT[detail] * clampf(size, 0.6, 2.5) * (2.0 if elite else 1.0))
	var body := at + Vector2(0, -5.0 * size)
	match style:
		"embers":
			for _k: int in range(n):
				var v := _rand_dir(PI) * _look.randf_range(30.0, 90.0) * size
				var hot := Color(1.0, _look.randf_range(0.35, 0.75), 0.15)
				add(Kind.GLOW, body, v, _look.randf_range(0.35, 0.8), _look.randf_range(1.5, 3.0), hot, -40.0)
			add(Kind.SMOKE, body, Vector2(0, -10), 0.6, 9.0 * size, Color(0.25, 0.18, 0.18, 0.55))
			if detail >= 1:
				add(Kind.RING, at, Vector2.ZERO, 0.3, 14.0 * size, Color(1.0, 0.55, 0.2, 0.9))
		"mist":
			for _k: int in range(maxi(2, floori(n / 3.0))):
				var v := Vector2(_look.randf_range(-12.0, 12.0), _look.randf_range(-22.0, -8.0))
				add(Kind.SMOKE, body + _rand_dir() * 3.0, v, _look.randf_range(0.7, 1.2), 6.0 * size,
						Color(tint.lerp(Color(0.85, 0.9, 1.0), 0.6), 0.55))
			for _k: int in range(floori(n / 2.0)):
				add(Kind.GLOW, body, _rand_dir(PI) * _look.randf_range(8.0, 25.0), 0.9, 1.5,
						Color(0.7, 0.85, 1.0), -18.0)
		"splash":
			for _k: int in range(n):
				var v := _rand_dir(1.2) * _look.randf_range(35.0, 80.0) * size
				add(Kind.PIXEL, body, v, _look.randf_range(0.35, 0.6), _look.randf_range(1.0, 2.0),
						tint.lerp(Color.WHITE, 0.15), 220.0)
			add(Kind.RING, at, Vector2.ZERO, 0.35, 10.0 * size, Color(tint, 0.7))
		"bones", "stone":
			var bone := Color(0.93, 0.9, 0.82) if style == "bones" else Color(0.55, 0.53, 0.5)
			for _k: int in range(n):
				var v := _rand_dir(1.3) * _look.randf_range(30.0, 75.0) * size
				add(Kind.SHARD, body, v, _look.randf_range(0.45, 0.7), _look.randf_range(1.5, 3.0), bone, 240.0,
						_look.randf_range(-12.0, 12.0))
			add(Kind.SMOKE, at, Vector2(0, -6), 0.45, 7.0 * size, Color(0.6, 0.55, 0.5, 0.45))
		"leaves", "feathers":
			var leaf := Color(0.45, 0.75, 0.3) if style == "leaves" else Color(0.18, 0.15, 0.25)
			for _k: int in range(n):
				var v := _rand_dir(PI) * _look.randf_range(20.0, 50.0)
				add(Kind.SHARD, body, v, _look.randf_range(0.7, 1.2), _look.randf_range(1.5, 2.5),
						leaf.lerp(tint, 0.25), 25.0, _look.randf_range(-6.0, 6.0))
		_:
			for _k: int in range(n):
				var v := Vector2(_look.randf_range(-18.0, 18.0), _look.randf_range(-35.0, -10.0))
				var ash := Color(0.2, 0.18, 0.22).lerp(tint, 0.3)
				add(Kind.PIXEL, body + _rand_dir() * 3.0, v, _look.randf_range(0.5, 0.9), 1.0, ash, -10.0)
	# Alma que sobe (hitodama): todos menos respingo/pedra; só a partir do nível médio.
	if detail >= 1 and style != "splash" and style != "stone":
		add(Kind.SOUL, body, Vector2(_look.randf_range(-6.0, 6.0), -28.0), 0.9 + 0.3 * detail, 2.5,
				Color(0.65, 0.85, 1.0) if style != "embers" else Color(1.0, 0.6, 0.35))
	if elite:
		add(Kind.RING, at, Vector2.ZERO, 0.45, 26.0, Color(1.0, 0.85, 0.4, 1.0))
		for _k: int in range(6 + 6 * detail):
			add(Kind.GLOW, body, _rand_dir(PI) * _look.randf_range(40.0, 110.0), 0.6, 2.0,
					Color(1.0, 0.85, 0.4), 60.0)
	if with_sound:
		_death_sound(style)


func _death_sound(style: String) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_sound_ms < SOUND_GAP_MS:
		return
	_last_sound_ms = now
	var audio := get_node_or_null(^"/root/AudioManager")
	if audio:
		var id := "%s_%d" % [DEATH_SOUND.get(style, "e_die_ash"), _look.randi_range(0, 2)]
		audio.call("play", id, 1.0, 0.08, SOUND_DB)


## Entrada: fumaça escura, fogo-fátuo que se junta ou portal de névoa no chão.
func spawn_in(at: Vector2, style: String, size: float = 1.0) -> void:
	match style:
		"wisp":
			for _k: int in range(3 + 3 * detail):
				var from := at + _rand_dir(PI) * 12.0 * size
				add(Kind.GLOW, from, (at - from) * 2.2, 0.45, 2.0, Color(0.6, 0.9, 1.0))
			add(Kind.RING, at, Vector2.ZERO, 0.35, 8.0 * size, Color(0.6, 0.9, 1.0, 0.8))
		"portal":
			add(Kind.RING, at, Vector2.ZERO, 0.6, 16.0 * size, Color(0.55, 0.3, 0.85, 0.9))
			for _k: int in range(2 + 2 * detail):
				add(Kind.SMOKE, at + _rand_dir(PI) * 6.0 * size, Vector2(0, -12), 0.8, 8.0 * size,
						Color(0.2, 0.12, 0.3, 0.6))
			for _k: int in range(2 * detail):
				add(Kind.GLOW, at + Vector2(_look.randf_range(-8.0, 8.0), 0) * size, Vector2(0, -45), 0.5, 1.5,
						Color(0.75, 0.5, 1.0))
		_:
			for _k: int in range(2 + detail):
				add(Kind.SMOKE, at + _rand_dir(PI) * 4.0, Vector2(_look.randf_range(-8.0, 8.0), -10), 0.55,
						6.0 * size, Color(0.15, 0.12, 0.18, 0.6))


## Poeira do recuo: atrás do inimigo, no chão.
func dust(at: Vector2, dir: Vector2, amount: int = 2) -> void:
	if detail == 0:
		return
	for _k: int in range(amount * detail):
		var v := (-dir.normalized()).rotated(_look.randf_range(-0.8, 0.8)) * _look.randf_range(10.0, 30.0)
		add(Kind.SMOKE, at, v, 0.35, 3.0, Color(0.72, 0.66, 0.55, 0.45))


## Pisada pesada (onis, tanques): anel de poeira no pé.
func stomp(at: Vector2, size: float = 1.0) -> void:
	add(Kind.RING, at, Vector2.ZERO, 0.3, 9.0 * size, Color(0.75, 0.68, 0.55, 0.6))
	if detail >= 2:
		for side: float in [-1.0, 1.0]:
			add(Kind.SMOKE, at, Vector2(side * 18.0, -4.0), 0.4, 3.5 * size, Color(0.7, 0.64, 0.52, 0.45))


## Vapor que sai do corpo dos onis.
func steam(at: Vector2, color: Color = Color(0.9, 0.85, 0.85, 0.35)) -> void:
	add(Kind.SMOKE, at, Vector2(_look.randf_range(-5.0, 5.0), -16.0), 0.9, 2.5, color)


## Faísca das elites e da aura dos chefes.
func spark(at: Vector2, color: Color, up: float = 30.0) -> void:
	add(Kind.GLOW, at, Vector2(_look.randf_range(-8.0, 8.0), -up), 0.7, 1.5, color, -5.0)


## Chuva de almas: sobem do corpo do chefe, abrem em leque e descem devagar como neve.
func soul_rain(at: Vector2, count: int) -> void:
	for _k: int in range(count):
		var v := _rand_dir(1.2) * _look.randf_range(60.0, 140.0)
		add(Kind.SOUL, at, v, _look.randf_range(1.6, 2.6), _look.randf_range(2.0, 3.5),
				Color(0.65, 0.85, 1.0).lerp(Color(1.0, 0.9, 0.6), _look.randf()), 55.0)


## Explosão em camadas (chefes): clarão, brasas, fumaça e anel.
func explosion(at: Vector2, size: float, color: Color) -> void:
	add(Kind.RING, at, Vector2.ZERO, 0.4, 20.0 * size, Color(color, 1.0))
	add(Kind.GLOW, at, Vector2.ZERO, 0.25, 10.0 * size, Color(1.0, 0.95, 0.8))
	for _k: int in range(4 + 6 * detail):
		add(Kind.GLOW, at, _rand_dir(PI) * _look.randf_range(40.0, 140.0) * size, _look.randf_range(0.4, 0.9),
				_look.randf_range(1.5, 3.0), color.lerp(Color(1, 0.9, 0.5), _look.randf()), 80.0)
	for _k: int in range(1 + detail):
		add(Kind.SMOKE, at + _rand_dir(PI) * 6.0, Vector2(0, -14), 0.9, 10.0 * size, Color(0.18, 0.14, 0.16, 0.6))


# --- Passo e desenho --------------------------------------------------------------------

func _process(delta: float) -> void:
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			time_scale = 1.0
	if GameClock.paused:
		queue_redraw()
		_add_layer.queue_redraw()
		return
	advance(minf(delta, 0.1) * GameClock.speed * time_scale)
	queue_redraw()
	_add_layer.queue_redraw()


## Avança as partículas `dt` segundos (os testes chamam direto).
func advance(dt: float) -> void:
	if _alive <= 0:
		return
	var alive := 0
	for i: int in range(cap):
		if _life[i] <= 0.0:
			continue
		_life[i] -= dt
		if _life[i] <= 0.0:
			continue
		alive += 1
		var v: Vector2 = _vel[i]
		match _kind[i]:
			Kind.SMOKE:
				v *= 1.0 - minf(1.0, 2.5 * dt)
			Kind.SOUL:
				# Balança como chama e, sem impulso, sobe devagar.
				v = v * (1.0 - minf(1.0, 1.6 * dt)) + Vector2(sin(_life[i] * 9.0 + i) * 30.0 * dt, -20.0 * dt)
			_:
				v *= 1.0 - minf(1.0, 1.2 * dt)
		v.y += _grav[i] * dt
		_vel[i] = v
		_pos[i] += v * dt
	_alive = alive


func _draw() -> void:
	for i: int in range(cap):
		if _life[i] <= 0.0:
			continue
		var t := _life[i] / _max_life[i]
		var c: Color = _color[i]
		var p: Vector2 = _pos[i]
		match _kind[i]:
			Kind.PIXEL:
				c.a *= minf(1.0, t * 2.0)
				var s := maxf(1.0, roundf(_size[i]))
				draw_rect(Rect2(p.round(), Vector2(s, s)), c)
			Kind.SHARD:
				c.a *= minf(1.0, t * 3.0)
				var angle := _rot[i] * (1.0 - t)
				var half := Vector2(_size[i], _size[i] * 0.45)
				draw_set_transform(p.round(), angle, Vector2.ONE)
				draw_rect(Rect2(-half, half * 2.0), c)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			Kind.SMOKE:
				var r := _size[i] * (1.6 - 0.6 * t)
				c.a *= t
				draw_texture_rect(_soft, Rect2(p - Vector2(r, r * 0.8), Vector2(r * 2.0, r * 1.6)), false, c)
			Kind.RING:
				var r := _size[i] * (1.0 - t * t)
				c.a *= t
				Stroke.arc(self, p, r, 0.0, TAU, 20, c, 1.0 + t)
			_:
				if not glow:
					c.a *= t
					draw_rect(Rect2(p.round(), Vector2.ONE * 2.0), c)


## Brilhos e almas em modo aditivo (no nível baixo viram pixels na camada normal).
func _draw_additive() -> void:
	if not glow:
		return
	for i: int in range(cap):
		if _life[i] <= 0.0:
			continue
		var kind := _kind[i]
		if kind != Kind.GLOW and kind != Kind.SOUL:
			continue
		var t := _life[i] / _max_life[i]
		var c: Color = _color[i]
		var p: Vector2 = _pos[i]
		var r := _size[i] * (1.5 if kind == Kind.SOUL else 1.0)
		c.a = minf(1.0, t * 1.6)
		_add_layer.draw_texture_rect(_soft, Rect2(p - Vector2(r, r) * 2.0, Vector2(r, r) * 4.0), false,
				Color(c.r, c.g, c.b, c.a * 0.55))
		if kind == Kind.SOUL:
			# Chama: cauda para baixo e miolo claro.
			_add_layer.draw_texture_rect(_soft, Rect2(p + Vector2(-r * 0.6, -r * 0.4), Vector2(r * 1.2, r * 2.6)),
					false, Color(c.r, c.g, c.b, c.a * 0.6))
			_add_layer.draw_rect(Rect2(p.round() - Vector2.ONE, Vector2(2, 2)), Color(1, 1, 1, c.a))
		else:
			_add_layer.draw_rect(Rect2(p.round(), Vector2.ONE), Color(1, 1, 1, c.a * 0.8))
