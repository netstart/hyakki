class_name FxLayer
extends Node2D
## Efeitos de "juice" (plano 8.5): animações do pacote (cortes, raios, explosões,
## faíscas), partículas de morte, anéis e números de dano. Animações e partículas seguem
## o tempo de jogo; números de dano duram o mesmo tempo real em qualquer velocidade (4.14).

const MAX_PARTICLES := 600
const MAX_NUMBERS := 120
const MAX_ANIMS := 160
const NUMBER_LIFETIME := 0.6
const RING_LIFETIME := 0.4
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
	"circle": ["res://assets/art/fx/circle/SpriteSheetWhite.png", 32],
	"circle_spark": ["res://assets/art/fx/circle/SpriteSheetSpark.png", 32],
	"aura": ["res://assets/art/fx/aura/SpriteSheet.png", 25],
	"shield": ["res://assets/art/fx/shield/SpriteSheetYellow.png", 24],
	"boost": ["res://assets/art/fx/boost/SpriteSheet.png", 53],
	"smoke": ["res://assets/art/fx/smoke/SpriteSheet.png", 32],
	"smoke_circular": ["res://assets/art/fx/smoke_circular/SpriteSheet.png", 30],
	"rock_spike": ["res://assets/art/fx/rock_spike/SpriteSheet.png", 45],
	"flame": ["res://assets/art/fx/flame/SpriteSheet.png", 25],
	"water_pillar": ["res://assets/art/fx/water_pillar/SpriteSheet.png", 30],
}

var _sheets: Dictionary = {}

var _p_pos := PackedVector2Array()
var _p_vel := PackedVector2Array()
var _p_life := PackedFloat32Array()
var _p_color := PackedColorArray()
var _p_next: int = 0

var _n_pos := PackedVector2Array()
var _n_life := PackedFloat32Array()
var _n_text := PackedStringArray()
var _n_color := PackedColorArray()
var _n_next: int = 0

var _anims: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _font: Font


func _ready() -> void:
	_font = Locale.font if Locale.font else ThemeDB.fallback_font
	for name: String in ANIMS:
		var spec: Array = ANIMS[name]
		_sheets[name] = SpriteSheet.load_sheet(spec[0], "strip", Vector2(float(spec[1]), 0.0))
	_p_pos.resize(MAX_PARTICLES)
	_p_vel.resize(MAX_PARTICLES)
	_p_life.resize(MAX_PARTICLES)
	_p_color.resize(MAX_PARTICLES)
	_n_pos.resize(MAX_NUMBERS)
	_n_life.resize(MAX_NUMBERS)
	_n_text.resize(MAX_NUMBERS)
	_n_color.resize(MAX_NUMBERS)
	reset()


func reset() -> void:
	_p_life.fill(0.0)
	_n_life.fill(0.0)
	_anims.clear()
	_rings.clear()


## Partículas de morte: 5 pixels da cor do inimigo (decorativo; usa randf, fora da simulação).
func burst(at: Vector2, color: Color, count: int = 5) -> void:
	for k: int in range(count):
		var angle := TAU * (k / float(count)) + randf() * 0.6
		_p_pos[_p_next] = at
		_p_vel[_p_next] = Vector2.from_angle(angle) * randf_range(25.0, 55.0)
		_p_life[_p_next] = randf_range(0.25, 0.4)
		_p_color[_p_next] = color
		_p_next = (_p_next + 1) % MAX_PARTICLES


func add_number(at: Vector2, amount: float, crit: bool = false, color: Color = Color.WHITE) -> void:
	if not bool(Settings.get_value("damage_numbers")):
		return
	_n_pos[_n_next] = at + Vector2(randf_range(-3.0, 3.0), -8.0)
	_n_life[_n_next] = NUMBER_LIFETIME
	_n_text[_n_next] = str(roundi(amount))
	_n_color[_n_next] = Color("ffd166") if crit else color
	_n_next = (_n_next + 1) % MAX_NUMBERS


func play_anim(name: String, at: Vector2, scale_factor: float = 1.0, angle: float = 0.0,
		tint: Color = Color.WHITE, fps: float = 16.0, flip: bool = false) -> void:
	if not _sheets.has(name) or _anims.size() >= MAX_ANIMS:
		return
	var sheet: SpriteSheet = _sheets[name]
	_anims.append({"sheet": sheet, "pos": at, "scale": scale_factor, "angle": angle, "tint": tint,
			"time": 0.0, "duration": sheet.frames / fps, "fps": fps, "flip": flip})


func add_ring(at: Vector2, max_radius: float, color: Color = Color(1.0, 0.9, 0.6)) -> void:
	_rings.append({"pos": at, "r": max_radius, "life": RING_LIFETIME, "color": color})


func step(dt: float) -> void:
	for i: int in range(MAX_PARTICLES):
		if _p_life[i] <= 0.0:
			continue
		_p_life[i] -= dt
		_p_pos[i] += _p_vel[i] * dt
		_p_vel[i] *= 0.9
	for k: int in range(_anims.size() - 1, -1, -1):
		var anim := _anims[k]
		anim["time"] = float(anim["time"]) + dt
		if float(anim["time"]) >= float(anim["duration"]):
			_anims.remove_at(k)
	for k: int in range(_rings.size() - 1, -1, -1):
		_rings[k]["life"] = float(_rings[k]["life"]) - dt
		if float(_rings[k]["life"]) <= 0.0:
			_rings.remove_at(k)


func _process(delta: float) -> void:
	for i: int in range(MAX_NUMBERS):
		if _n_life[i] > 0.0:
			_n_life[i] -= delta
			_n_pos[i] += Vector2(0.0, -14.0 * delta)
	queue_redraw()


func _draw() -> void:
	for i: int in range(MAX_PARTICLES):
		if _p_life[i] > 0.0:
			draw_rect(Rect2(_p_pos[i].round(), Vector2.ONE), _p_color[i])
	for anim: Dictionary in _anims:
		var sheet: SpriteSheet = anim["sheet"]
		var frame := mini(int(float(anim["time"]) * float(anim["fps"])), sheet.frames - 1)
		var src := sheet.region(frame, 0)
		var s := float(anim["scale"])
		draw_set_transform((anim["pos"] as Vector2).round(), float(anim["angle"]),
				Vector2(-s if bool(anim["flip"]) else s, s))
		draw_texture_rect_region(sheet.texture, Rect2(-src.size * 0.5, src.size), src, anim["tint"])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for ring: Dictionary in _rings:
		var t: float = 1.0 - float(ring["life"]) / RING_LIFETIME
		var color: Color = ring["color"]
		color.a = 1.0 - t
		draw_arc(ring["pos"], float(ring["r"]) * t, 0.0, TAU, 32, color, 2.0)
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
