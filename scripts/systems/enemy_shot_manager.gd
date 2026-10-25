class_name EnemyShotManager
extends Node2D
## Projéteis dos inimigos e chefes (plano 6.1 "atirador" e 6.3).
## Sempre em vermelho/magenta ou com contorno forte, para serem legíveis (plano 8.1 e 15.2).
## Desenho em camadas: disco escuro por baixo (lê em chão claro e escuro), rastro de vultos
## (Média: 1, Alta: 3), o sprite, miolo claro pulsando e halo aditivo na cor do tiro (Média/Alta).

const CAPACITY := 400
const HIT_RADIUS := 3.0
## Tipos de projétil: textura (tira horizontal), tamanho do quadro, cor e se gira com a direção.
const FX_DIR := "res://assets/art/fx/projectile/"
const KINDS := {
	"fireball": {"path": "res://assets/art/fx/projectile/Fireball.png", "frame": 16, "tint": "#ffffff", "rotate": true},
	"energy_ball": {"path": FX_DIR + "EnergyBall.png", "frame": 16, "tint": "#ff6b9d", "rotate": false},
	"water": {"path": "res://assets/art/fx/projectile/EnergyBall.png", "frame": 16, "tint": "#6fd3ff", "rotate": false},
	"leaf": {"path": "res://assets/art/fx/projectile/SpriteSheetRock.png", "frame": 16, "tint": "#9be36b", "rotate": true},
	"fox_fire": {"path": "res://assets/art/fx/projectile/Fireball.png", "frame": 16, "tint": "#ff8fd1", "rotate": true},
	"feather": {"path": "res://assets/art/fx/projectile/Kunai.png", "frame": 14, "tint": "#3b2f4a", "rotate": true},
	"spirit_orb": {"path": FX_DIR + "EnergyBall.png", "frame": 16, "tint": "#c58cff", "rotate": false},
	"dark_slash": {"path": FX_DIR + "BigEnergyBall.png", "frame": 24, "tint": "#5b4b8a", "rotate": true},
	"statue_shot": {"path": FX_DIR + "EnergyBall.png", "frame": 16, "tint": "#ffd166", "rotate": false},
}

var game: HyakkiGame
var count_alive: int = 0

var pos := PackedVector2Array()
var prev := PackedVector2Array()
var vel := PackedVector2Array()
var dmg := PackedFloat32Array()
var life := PackedFloat32Array()
var turn := PackedFloat32Array()
var kind := PackedInt32Array()
## Quem disparou (inimigo, chefe ou perigo), para o controle de dano (plano 4.15).
var source: Array[StringName] = []
var alive := PackedByteArray()

var _free: Array[int] = []
var _kind_names: Array[String] = []
var _kind_sheets: Array[SpriteSheet] = []
var _kind_tint: Array[Color] = []
var _kind_rotate: PackedByteArray = []
var _soft: Texture2D
var _halo: Node2D
var _trail: int = 3
var _glow: bool = true


func _ready() -> void:
	for name: String in KINDS:
		var data: Dictionary = KINDS[name]
		_kind_names.append(name)
		var frame := float(data["frame"])
		var sheet := SpriteSheet.load_sheet(data["path"], "strip", Vector2(frame, 0.0))
		_kind_sheets.append(sheet)
		_kind_tint.append(Color(String(data["tint"])))
		_kind_rotate.append(1 if bool(data["rotate"]) else 0)
	pos.resize(CAPACITY)
	prev.resize(CAPACITY)
	vel.resize(CAPACITY)
	dmg.resize(CAPACITY)
	life.resize(CAPACITY)
	turn.resize(CAPACITY)
	kind.resize(CAPACITY)
	alive.resize(CAPACITY)
	source.resize(CAPACITY)
	_soft = EnemyFx.soft_texture()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_halo = Node2D.new()
	_halo.material = additive
	_halo.draw.connect(_draw_halo)
	add_child(_halo)
	_apply_quality()
	var settings := get_node_or_null(^"/root/Settings")
	if settings:
		settings.connect("changed", func(k: String) -> void:
			if k == GfxQuality.changed_signal_key():
				_apply_quality())
	reset()


func _apply_quality() -> void:
	_trail = int(GfxQuality.pick(0, 1, 3))
	_glow = int(GfxQuality.budget("enemy_fx")) >= 1
	if _halo:
		_halo.visible = _glow


func reset() -> void:
	_free.clear()
	for i: int in range(CAPACITY - 1, -1, -1):
		_free.append(i)
	alive.fill(0)
	count_alive = 0


func spawn(at: Vector2, velocity: Vector2, damage: float, kind_name: String,
		lifetime: float = 5.0, homing: float = 0.0, from: StringName = DamageControl.UNKNOWN) -> void:
	if _free.is_empty():
		return
	var i: int = _free.pop_back()
	pos[i] = at
	prev[i] = at
	vel[i] = velocity
	dmg[i] = damage
	life[i] = lifetime
	turn[i] = homing
	source[i] = from
	kind[i] = maxi(0, _kind_names.find(kind_name))
	alive[i] = 1
	count_alive += 1


func step(dt: float) -> void:
	prev = pos.duplicate()
	var player := game.player
	var target := player.sim_pos
	var reach := HIT_RADIUS + Player.RADIUS
	var frozen := game.enemies.freeze_time > 0.0
	for i: int in range(CAPACITY):
		if alive[i] == 0:
			continue
		life[i] -= dt
		if life[i] <= 0.0:
			_kill(i)
			continue
		if frozen:
			continue
		var v: Vector2 = vel[i]
		if turn[i] > 0.0:
			var wanted := (target - pos[i]).normalized() * v.length()
			v = v.lerp(wanted, clampf(turn[i] * dt, 0.0, 1.0)).normalized() * v.length()
			vel[i] = v
		var from: Vector2 = pos[i]
		var to := from + v * dt
		pos[i] = to
		if player.is_alive and Geometry.segment_hits_circle(from, to, target, reach):
			player.take_damage(dmg[i], source[i])
			_kill(i)


func clear_all() -> void:
	for i: int in range(CAPACITY):
		if alive[i] == 1:
			_kill(i)


func _kill(i: int) -> void:
	alive[i] = 0
	_free.append(i)
	count_alive -= 1


func _process(_delta: float) -> void:
	queue_redraw()
	if _glow:
		_halo.queue_redraw()


func _draw() -> void:
	var a := GameClock.alpha
	var time := GameClock.game_time
	var frame := int(time * 12.0)
	for i: int in range(CAPACITY):
		if alive[i] == 0:
			continue
		var at := prev[i].lerp(pos[i], a).round()
		var size := 4.0 if _kind_sheets[kind[i]].frame_size.x <= 16.0 else 6.0
		draw_texture_rect(_soft, Rect2(at - Vector2(size, size) * 1.4, Vector2(size, size) * 2.8), false,
				Color(0.08, 0.0, 0.06, 0.55))
	for i: int in range(CAPACITY):
		if alive[i] == 0:
			continue
		var k := kind[i]
		var sheet := _kind_sheets[k]
		var src := sheet.region(frame, 0)
		var angle := vel[i].angle() if _kind_rotate[k] == 1 else 0.0
		var at := prev[i].lerp(pos[i], a).round()
		var tint := _kind_tint[k]
		var back := -vel[i].normalized()
		for t: int in range(_trail, 0, -1):
			draw_set_transform(at + back * 3.5 * t, angle, Vector2.ONE * (1.0 - 0.12 * t))
			draw_texture_rect_region(sheet.texture, Rect2(-src.size * 0.5, src.size), src,
					Color(tint.r, tint.g, tint.b, 0.4 / (t + 0.5)))
		draw_set_transform(at, angle, Vector2.ONE)
		draw_texture_rect_region(sheet.texture, Rect2(-src.size * 0.5, src.size), src, tint)
		var pulse := 0.6 + 0.4 * sin(time * 18.0 + i)
		draw_rect(Rect2(Vector2(-1, -1), Vector2(2, 2)), Color(1.0, 0.97, 0.9, 0.8 * pulse))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_halo() -> void:
	var a := GameClock.alpha
	var time := GameClock.game_time
	for i: int in range(CAPACITY):
		if alive[i] == 0:
			continue
		var at := prev[i].lerp(pos[i], a)
		var tint := _kind_tint[kind[i]]
		var r := 7.0 + 1.5 * sin(time * 12.0 + i)
		_halo.draw_texture_rect(_soft, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false,
				Color(tint.r, tint.g, tint.b, 0.55))
