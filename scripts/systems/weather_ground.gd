class_name WeatherGround
extends Node2D
## Chão do clima e das superfícies lentas, no mundo (z -17: acima do piso e da lava, abaixo da
## decoração e dos atores):
##   - superfícies (lama, barro, pântano, óleo, piche, areia movediça) desenhadas por SurfaceLook;
##   - poças que crescem com a chuva, com reflexo do céu, da lanterna e ondinhas (Alta);
##   - quem atravessa: pegadas da cor do solo que somem, respingos/ondas e som de passo por tipo;
##     ao sair, os últimos respingos e pegadas sujas; no piche, gotas escuras pingando enquanto
##     a velocidade se recupera;
##   - respingos das gotas de chuva no chão.
## A FORMA e o TAMANHO vêm do SurfaceField/WeatherModel (semente + tempo: é o mesmo solo que deixa
## os personagens lentos). O resto (pegadas, respingos, brilho, som) é só desenho, com RNG próprio.

const Z := -17
const SPLASH_TEX := "res://assets/art/fx/particle/RainOnFloor.png"
const PRINT_LIFE := 9.0
const SPLASH_LIFE := 0.2
const RIPPLE_LIFE := 0.7
const DROPLET_LIFE := 0.45
const HERO_STEP_PX := 7.0
const HERO_SOUND_GAP := 0.26
const ENEMY_SOUND_GAP := 0.45
## Sons por "sound" de data/surfaces.json: [arquivos, pitch, volume dB].
const STEP_SOUNDS := {
	"mud": [["k_step_soft_0", "k_step_soft_1", "k_step_soft_2"], 0.72, -4.0],
	"water": [["surf_water_0", "surf_water_1", "surf_water_2"], 1.0, -8.0],
	"oil": [["surf_water_0", "surf_water_2"], 1.35, -11.0],
	"tar": [["surf_bubble_0", "surf_bubble_1"], 0.6, -7.0],
	"sand": [["k_step_soft_0", "k_step_soft_1", "k_step_soft_2"], 1.05, -6.0],
}

var weather: WeatherSystem

var _splash_tex: Texture2D
var _polys: Dictionary = {}
var _time: float = 0.0
var _sim_t: float = 0.0
var _puddle_level: float = 0.0
var _wet: float = 0.0
var _quality: int = GfxQuality.HIGH
var _rng := RandomNumberGenerator.new()
# Pegadas: posição, idade e tipo de solo (índice do SurfaceField).
var _prints := PackedVector2Array()
var _print_age := PackedFloat32Array()
var _print_type := PackedByteArray()
var _print_next: int = 0
var _last_hero_print := Vector2.INF
var _hero_side: float = 1.0
var _hero_was_inside: bool = false
var _hero_sound_cd: float = 0.0
var _enemy_sound_cd: float = 0.0
var _drip_cd: float = 0.0
# Respingos das gotas, ondinhas e gotículas (cor do solo).
var _splash := PackedVector2Array()
var _splash_age := PackedFloat32Array()
var _splash_next: int = 0
var _ripple := PackedVector2Array()
var _ripple_age := PackedFloat32Array()
var _ripple_next: int = 0
var _drop_pos := PackedVector2Array()
var _drop_vel := PackedVector2Array()
var _drop_age := PackedFloat32Array()
var _drop_color := PackedColorArray()
var _drop_next: int = 0
var _enemy_cursor: int = 0
var _enemy_samples: int = 24


func _ready() -> void:
	z_index = Z
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_rng.randomize()
	_splash_tex = load(SPLASH_TEX) as Texture2D
	apply_quality()


## Orçamentos: pegadas, respingos e quantos inimigos olhar por quadro.
func apply_quality() -> void:
	_quality = GfxQuality.level()
	_resize_ring(int(GfxQuality.pick(48, 96, 160)), _prints, _print_age)
	_print_type.resize(_prints.size())
	_resize_ring(int(GfxQuality.pick(0, 40, 72)) if bool(GfxQuality.budget("splashes")) else 0, _splash, _splash_age)
	_resize_ring(int(GfxQuality.pick(8, 24, 48)), _ripple, _ripple_age)
	_resize_ring(int(GfxQuality.pick(16, 40, 80)), _drop_pos, _drop_age)
	_drop_vel.resize(_drop_pos.size())
	_drop_color.resize(_drop_pos.size())
	_enemy_samples = int(GfxQuality.pick(8, 16, 28))
	_print_next = 0
	_splash_next = 0
	_ripple_next = 0
	_drop_next = 0


func _resize_ring(size: int, pos: PackedVector2Array, age: PackedFloat32Array) -> void:
	pos.resize(size)
	age.resize(size)
	age.fill(99.0)


func reset() -> void:
	_print_age.fill(99.0)
	_splash_age.fill(99.0)
	_ripple_age.fill(99.0)
	_drop_age.fill(99.0)
	_last_hero_print = Vector2.INF
	_hero_was_inside = false
	_polys.clear()


func _field() -> SurfaceField:
	return weather.surfaces.field if weather.surfaces != null else null


func _type_name(type: int) -> String:
	var f := _field()
	return f.type_names[type] if f != null and type >= 0 and type < f.type_names.size() else "mud"


# --- Passo visual --------------------------------------------------------------------

func tick(dt: float, sim_t: float) -> void:
	_time += dt
	_sim_t = sim_t
	var model := weather.model
	_puddle_level = model.puddle_level_at(sim_t)
	_wet = model.wetness_at(sim_t)
	_age(_print_age, dt)
	_age(_splash_age, dt)
	_age(_ripple_age, dt)
	_age(_drop_age, dt)
	for i: int in range(_drop_pos.size()):
		if _drop_age[i] < DROPLET_LIFE:
			_drop_vel[i] += Vector2(0.0, 260.0) * dt
			_drop_pos[i] += _drop_vel[i] * dt
	_hero_sound_cd -= dt
	_enemy_sound_cd -= dt
	_drip_cd -= dt
	if dt > 0.0:
		_track_hero()
		_track_enemies()
	queue_redraw()


func _age(ages: PackedFloat32Array, dt: float) -> void:
	for i: int in range(ages.size()):
		ages[i] += dt


## Herói: ao entrar, respingo e som; dentro, pegadas, gotículas e passos do tipo; ao sair, as
## últimas pegadas sujas e (piche) gotas escuras pingando durante a recuperação.
func _track_hero() -> void:
	var player := weather.game.player
	var surfaces := weather.surfaces
	if player == null or not player.is_alive or surfaces == null or _field() == null:
		return
	var p := player.position
	var inside := surfaces.player_inside
	var type := surfaces.player_type
	var recovering := not inside and type >= 0 and surfaces.player_mult < 1.0
	if inside and not _hero_was_inside:
		for _k: int in range(5 if _quality > GfxQuality.LOW else 3):
			_add_droplet(p + Vector2(0, 1), SurfaceLook.droplet_color(_type_name(type)))
		_play_step(type, true, 0.0)
		_add_ripple(p)
	_hero_was_inside = inside
	if recovering and _type_name(type) == "tar" and _drip_cd <= 0.0:
		_drip_cd = 0.12
		_add_droplet(p + Vector2(_rng.randf_range(-3, 3), -6), Color(0.03, 0.02, 0.04), Vector2(0, 10))
	if not inside and not recovering:
		var wet := _puddle_level > 0.0 and in_puddle(p)
		if wet and (_last_hero_print == Vector2.INF or p.distance_to(_last_hero_print) >= HERO_STEP_PX):
			_last_hero_print = p
			_add_ripple(p + Vector2(0, 1))
			_add_droplet(p, Color(0.75, 0.85, 1.0))
		elif not wet:
			_last_hero_print = Vector2.INF
		return
	if _last_hero_print != Vector2.INF and p.distance_to(_last_hero_print) < HERO_STEP_PX:
		return
	var dir := (p - _last_hero_print).normalized() if _last_hero_print != Vector2.INF else Vector2.RIGHT
	_last_hero_print = p
	_hero_side = -_hero_side
	add_print(p + dir.orthogonal() * 1.5 * _hero_side, type)
	var kind := _type_name(type)
	if inside:
		if kind in ["swamp", "oil", "tar"]:
			_add_ripple(p + Vector2(0, 1))
		for _k: int in range(1 if _quality == GfxQuality.LOW else 2):
			_add_droplet(p + Vector2(0, 1), SurfaceLook.droplet_color(kind))
		_play_step(type, false, 0.0)
	elif _rng.randf() < 0.6:
		_add_droplet(p + Vector2(0, 1), SurfaceLook.droplet_color(kind))


## Alguns inimigos por quadro (rodízio): quem está no solo (ou saindo dele) deixa pegada e espirra.
func _track_enemies() -> void:
	var enemies := weather.game.enemies
	var surfaces := weather.surfaces
	if enemies == null or surfaces == null:
		return
	var cap := enemies.alive.size()
	if cap == 0:
		return
	for _k: int in range(_enemy_samples):
		_enemy_cursor = (_enemy_cursor + 1) % cap
		var i := _enemy_cursor
		var type := surfaces.enemy_type(i)
		if enemies.alive[i] != 1 or type < 0 or enemies.vel[i].length() < 3.0:
			continue
		var p: Vector2 = enemies.pos[i]
		add_print(p + Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-1, 1)), type)
		if surfaces.enemy_inside(i):
			if _rng.randf() < 0.5:
				_add_droplet(p, SurfaceLook.droplet_color(_type_name(type)))
			if _rng.randf() < 0.3:
				_add_ripple(p)
			_play_step(type, false, -10.0, p)


func _play_step(type: int, enter: bool, extra_db: float, at: Vector2 = Vector2.INF) -> void:
	var f := _field()
	if f == null or type < 0:
		return
	if at != Vector2.INF:
		if _enemy_sound_cd > 0.0 or at.distance_to(weather.game.player.position) > 200.0:
			return
		_enemy_sound_cd = ENEMY_SOUND_GAP
	elif not enter:
		if _hero_sound_cd > 0.0:
			return
		_hero_sound_cd = HERO_SOUND_GAP
	var spec: Array = STEP_SOUNDS.get(String(f.types[type].get("sound", "mud")), STEP_SOUNDS["mud"])
	var files: Array = spec[0]
	var db := float(spec[2]) + extra_db + (3.0 if enter else 0.0)
	AudioManager.play(String(files.pick_random()), float(spec[1]), 0.08, db)


func add_print(p: Vector2, type: int) -> void:
	if _prints.is_empty():
		return
	_prints[_print_next] = p.round()
	_print_age[_print_next] = 0.0
	_print_type[_print_next] = maxi(type, 0)
	_print_next = (_print_next + 1) % _prints.size()


## Pegadas vivas (testes).
func live_prints() -> int:
	var n := 0
	for a: float in _print_age:
		if a < PRINT_LIFE:
			n += 1
	return n


## Uma gota tocou o chão em `p` (mundo): ondinha se cair numa poça, respingo no resto.
func add_drop_splash(p: Vector2, near: bool) -> void:
	if _splash.is_empty() or _rng.randf() > (0.5 if near else 0.25):
		return
	if _puddle_level > 0.0 and _ripple.size() > 0 and in_puddle(p):
		_add_ripple(p)
		return
	_splash[_splash_next] = p.round()
	_splash_age[_splash_next] = 0.0
	_splash_next = (_splash_next + 1) % _splash.size()


func _add_ripple(p: Vector2) -> void:
	if _ripple.is_empty():
		return
	_ripple[_ripple_next] = p.round()
	_ripple_age[_ripple_next] = 0.0
	_ripple_next = (_ripple_next + 1) % _ripple.size()


func _add_droplet(p: Vector2, color: Color, vel: Vector2 = Vector2.INF) -> void:
	if _drop_pos.is_empty():
		return
	_drop_pos[_drop_next] = p
	_drop_vel[_drop_next] = vel if vel != Vector2.INF else Vector2(_rng.randf_range(-30.0, 30.0),
			_rng.randf_range(-70.0, -35.0))
	_drop_age[_drop_next] = 0.0
	_drop_color[_drop_next] = color
	_drop_next = (_drop_next + 1) % _drop_pos.size()


func in_puddle(p: Vector2) -> bool:
	var c := Vector2i(floori(p.x / WeatherModel.CHUNK), floori(p.y / WeatherModel.CHUNK))
	for pud: Dictionary in weather.model.puddles(c):
		if WeatherModel.patch_contains(pud, p, WeatherModel.patch_scale(pud, _puddle_level) * 0.9):
			return true
	return false


# --- Desenho -------------------------------------------------------------------------

func _polys_of(patch: Dictionary) -> Array:
	var key := int(patch["seed"])
	if not _polys.has(key):
		_polys[key] = SurfaceLook.polys(patch)
	return _polys[key]


func _draw() -> void:
	if weather == null or weather.model == null or weather.game == null:
		return
	var model := weather.model
	var game := weather.game
	var cam := game.camera.get_screen_center_position() if game.camera != null else Vector2.ZERO
	var half := game.view_size() * 0.5 + Vector2(48, 48)
	var lo := Vector2i(floori((cam.x - half.x) / WeatherModel.CHUNK), floori((cam.y - half.y) / WeatherModel.CHUNK))
	var hi := Vector2i(floori((cam.x + half.x) / WeatherModel.CHUNK), floori((cam.y + half.y) / WeatherModel.CHUNK))
	if _puddle_level > 0.0:
		for cy: int in range(lo.y, hi.y + 1):
			for cx: int in range(lo.x, hi.x + 1):
				for pud: Dictionary in model.puddles(Vector2i(cx, cy)):
					_draw_puddle(pud)
	var field := _field()
	if field != null:
		var patches: Array = []
		var scales: Array[float] = []
		for cy: int in range(lo.y, hi.y + 1):
			for cx: int in range(lo.x, hi.x + 1):
				for patch: Dictionary in field.patches(Vector2i(cx, cy)):
					var s := field.scale_of(patch, _sim_t)
					if s > 0.0:
						patches.append(patch)
						scales.append(s)
		for pass_id: int in range(4):
			for k: int in range(patches.size()):
				var patch: Dictionary = patches[k]
				draw_set_transform(patch["center"], 0.0, Vector2(scales[k], scales[k]))
				SurfaceLook.draw_pass(self, field.type_names[int(patch["type"])], patch, _polys_of(patch), pass_id,
						_time, _quality, _wet)
	draw_set_transform(Vector2.ZERO)
	_draw_prints()
	_draw_splashes()


func _draw_puddle(pud: Dictionary) -> void:
	var s := WeatherModel.patch_scale(pud, _puddle_level)
	if s <= 0.0:
		return
	var center: Vector2 = pud["center"]
	draw_set_transform(center, 0.0, Vector2(s, s))
	var water := Color(String(weather.profile().get("puddle_color", "#34445e")))
	var polys := _polys_of(pud)
	for entry: Array in polys:
		draw_colored_polygon(SurfaceLook.scaled(entry[0], entry[1], 1.22), Color(0.08, 0.07, 0.06, 0.22))
	for entry: Array in polys:
		draw_colored_polygon(entry[0], Color(water, 0.66))
	var lead: Vector2 = (polys[0] as Array)[1]
	if _quality == GfxQuality.LOW:
		draw_line(lead + Vector2(-4, -2), lead + Vector2(2, -2), Color(0.7, 0.8, 1.0, 0.35), 1.0)
		return
	for entry: Array in polys:
		# Reflexo do céu: faixa clara deslocada para cima/esquerda, mais forte em Alta.
		var refl := SurfaceLook.scaled(entry[0], entry[1], 0.62)
		for i: int in range(refl.size()):
			refl[i] += Vector2(-1.5, -1.5)
		draw_colored_polygon(refl, Color(water.lightened(0.5), 0.42 if _quality == GfxQuality.HIGH else 0.28))
	if _quality == GfxQuality.HIGH:
		var tw := 0.5 + 0.5 * sin(_time * 1.7 + center.x * 0.1)
		draw_line(lead + Vector2(-5, -3), lead + Vector2(1, -3), Color(0.9, 0.95, 1.0, 0.45 * tw), 1.0)
		draw_rect(Rect2((lead + Vector2(3, -2)).round(), Vector2(1, 1)), Color(1, 1, 1, 0.6 * tw))
		# Lanterna do herói refletida na poça (só quando ele está perto).
		var hero := weather.game.player.position
		var d := hero.distance_to(center)
		if d < 90.0:
			draw_circle(lead + (hero - center).normalized() * -2.0, 2.5, Color(1.0, 0.85, 0.5, (1.0 - d / 90.0) * 0.35))


func _draw_prints() -> void:
	var f := _field()
	for i: int in range(_prints.size()):
		var age := _print_age[i]
		if age >= PRINT_LIFE:
			continue
		var a := 0.6 * (1.0 - age / PRINT_LIFE)
		var known := f != null and _print_type[i] < f.type_names.size()
		var col := SurfaceLook.print_color(f.type_names[_print_type[i]] if known else "mud")
		draw_rect(Rect2(_prints[i] + Vector2(-1, -1), Vector2(2, 3)), Color(col, a))


func _draw_splashes() -> void:
	for i: int in range(_splash.size()):
		var age := _splash_age[i]
		if age >= SPLASH_LIFE:
			continue
		var frame := mini(2, int(age / SPLASH_LIFE * 3.0))
		draw_texture_rect_region(_splash_tex, Rect2(_splash[i] - Vector2(4, 6), Vector2(8, 8)),
				Rect2(frame * 8, 0, 8, 8), Color(0.85, 0.92, 1.0, 0.75))
	for i: int in range(_ripple.size()):
		var age := _ripple_age[i]
		if age >= RIPPLE_LIFE:
			continue
		var k := age / RIPPLE_LIFE
		draw_set_transform(_ripple[i], 0.0, Vector2(1.0, 0.55))
		Stroke.arc(self, Vector2.ZERO, 1.0 + 6.0 * k, 0.0, TAU, 12, Color(0.8, 0.88, 1.0, 0.5 * (1.0 - k)), 1.0)
	draw_set_transform(Vector2.ZERO)
	for i: int in range(_drop_pos.size()):
		var age := _drop_age[i]
		if age >= DROPLET_LIFE:
			continue
		draw_rect(Rect2(_drop_pos[i].round(), Vector2(1, 1)), Color(_drop_color[i], 0.9 * (1.0 - age / DROPLET_LIFE)))
