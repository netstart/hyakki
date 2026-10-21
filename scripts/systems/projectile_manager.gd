class_name ProjectileManager
extends Node2D
## Projéteis da guardiã em arrays, num laço só (plano 10.7).
## Comportamentos: reto, teleguiado (Hitodama), bumerangue (Kusarigama), explosão no fim
## (Flecha de Hachiman). A colisão testa o segmento do passo (sem tunneling, plano 8.7.2).

enum Move { STRAIGHT, HOMING, BOOMERANG, SPIRAL }

const CAPACITY := 360
const KINDS := {
	"shuriken": {"path": "res://assets/art/items/projectile/shuriken.png", "frame": 15, "spin": 14.0, "tint": "#ffffff"},
	"kunai": {"path": "res://assets/art/fx/projectile/Kunai.png", "frame": 14, "spin": 0.0, "tint": "#ffffff"},
	"arrow": {"path": "res://assets/art/fx/projectile/Arrow.png", "frame": 13, "spin": 0.0, "tint": "#ffffff"},
	"golden_arrow": {"path": "res://assets/art/fx/projectile/Arrow.png", "frame": 13, "spin": 0.0, "tint": "#ffd166"},
	"hook": {"path": "res://assets/art/fx/projectile/Shuriken.png", "frame": 16, "spin": 18.0, "tint": "#d9d9d9"},
	"flame": {"path": "res://assets/art/fx/projectile/Fireball.png", "frame": 16, "spin": 0.0, "tint": "#9fd7ff"},
	"ally_flame": {"path": "res://assets/art/fx/projectile/Fireball.png", "frame": 16, "spin": 0.0, "tint": "#c9ffb5"},
	"needle": {"path": "res://assets/art/fx/projectile/Kunai.png", "frame": 14, "spin": 0.0, "tint": "#ffe9a8"},
	"rain_arrow": {"path": "res://assets/art/fx/projectile/Arrow.png", "frame": 13, "spin": 0.0, "tint": "#ffe08a"},
}

var game: HyakkiGame
var count_alive: int = 0

var pos := PackedVector2Array()
var prev := PackedVector2Array()
var vel := PackedVector2Array()
var origin := PackedVector2Array()
var dmg := PackedFloat32Array()
var radius := PackedFloat32Array()
var life := PackedFloat32Array()
var max_life := PackedFloat32Array()
var rot := PackedFloat32Array()
var turn := PackedFloat32Array()
var knock := PackedFloat32Array()
var explode := PackedFloat32Array()
var pierce := PackedInt32Array()
var move := PackedInt32Array()
var kind := PackedInt32Array()
var target := PackedInt32Array()
var crit := PackedByteArray()
var alive := PackedByteArray()
var weapon_id: Array[StringName] = []
## Inimigos já atingidos por cada projétil, para não acertar o mesmo duas vezes.
var hits: Array[Array] = []

var _free: Array[int] = []
var _near: Array[int] = []
var _kind_names: Array[String] = []
var _kind_sheets: Array[SpriteSheet] = []
var _kind_spin: PackedFloat32Array = []
var _kind_tint: Array[Color] = []


func _ready() -> void:
	for name: String in KINDS:
		var data: Dictionary = KINDS[name]
		_kind_names.append(name)
		_kind_sheets.append(SpriteSheet.load_sheet(data["path"], "strip", Vector2(float(data["frame"]), 0.0)))
		_kind_spin.append(float(data["spin"]))
		_kind_tint.append(Color(String(data["tint"])))
	for packed: StringName in [&"pos", &"prev", &"vel", &"origin", &"dmg", &"radius", &"life",
			&"max_life", &"rot", &"turn", &"knock", &"explode", &"pierce", &"move", &"kind",
			&"target", &"crit", &"alive"]:
		var array: Variant = get(packed)
		array.resize(CAPACITY)
		set(packed, array)
	weapon_id.resize(CAPACITY)
	for i: int in range(CAPACITY):
		hits.append([])
	reset()


func reset() -> void:
	_free.clear()
	for i: int in range(CAPACITY - 1, -1, -1):
		_free.append(i)
	alive.fill(0)
	count_alive = 0


## Cria um projétil. `pierce` = inimigos extras que atravessa (-1 = infinito).
func spawn(id: StringName, kind_name: String, at: Vector2, velocity: Vector2, damage: float,
		r: float, pierce_count: int, lifetime: float, knockback: float = 40.0,
		move_mode: int = Move.STRAIGHT, homing: float = 0.0, explode_radius: float = 0.0,
		always_crit: bool = false) -> int:
	if _free.is_empty():
		return -1
	var i: int = _free.pop_back()
	pos[i] = at
	prev[i] = at
	origin[i] = at
	vel[i] = velocity
	dmg[i] = damage
	radius[i] = r
	life[i] = lifetime
	max_life[i] = lifetime
	rot[i] = velocity.angle()
	turn[i] = homing
	knock[i] = knockback
	explode[i] = explode_radius
	pierce[i] = pierce_count
	move[i] = move_mode
	kind[i] = maxi(0, _kind_names.find(kind_name))
	target[i] = -1
	crit[i] = 1 if always_crit else 0
	weapon_id[i] = id
	hits[i].clear()
	alive[i] = 1
	count_alive += 1
	return i


func step(dt: float) -> void:
	prev = pos.duplicate()
	var enemies := game.enemies
	var me := game.player.sim_pos
	for i: int in range(CAPACITY):
		if alive[i] == 0:
			continue
		life[i] -= dt
		var v: Vector2 = vel[i]
		match move[i]:
			Move.HOMING:
				var t := target[i]
				if t < 0 or enemies.alive[t] == 0:
					t = enemies.strongest(pos[i], 260.0)
					target[i] = t
				if t >= 0:
					var wanted := (enemies.pos[t] - pos[i]).normalized() * v.length()
					v = v.lerp(wanted, clampf(turn[i] * dt, 0.0, 1.0)).normalized() * v.length()
			Move.BOOMERANG:
				# Primeira metade da vida vai; a segunda volta para a guardiã.
				if life[i] < max_life[i] * 0.5:
					var back := (me - pos[i])
					if back.length() < 8.0:
						_kill(i)
						continue
					v = back.normalized() * v.length()
					# Na virada, pode acertar de novo quem já atingiu na ida.
					if turn[i] >= 0.0:
						hits[i].clear()
						turn[i] = -1.0
			Move.SPIRAL:
				v = v.rotated(turn[i] * dt)
		vel[i] = v
		var from: Vector2 = pos[i]
		var to: Vector2 = from + v * dt
		var mid := (from + to) * 0.5
		enemies.query_circle(mid, from.distance_to(to) * 0.5 + radius[i], _near)
		var dead := false
		for j: int in _near:
			if hits[i].has(j):
				continue
			if not Geometry.segment_hits_circle(from, to, enemies.pos[j], radius[i] + enemies.radius[j]):
				continue
			hits[i].append(j)
			game.deal_damage(weapon_id[i], j, dmg[i], v.normalized(), knock[i], crit[i] == 1)
			if pierce[i] >= 0:
				pierce[i] -= 1
				if pierce[i] < 0:
					dead = true
					break
		if dead:
			_finish(i)
			continue
		pos[i] = to
		rot[i] = rot[i] + _kind_spin[kind[i]] * dt if _kind_spin[kind[i]] > 0.0 else v.angle()
		if life[i] <= 0.0:
			_finish(i)


## Fim da vida: explode se for o caso (Flecha de Hachiman).
func _finish(i: int) -> void:
	if explode[i] > 0.0:
		game.areas.blast(weapon_id[i], pos[i], explode[i], dmg[i] * 0.6, 60.0)
		game.fx.play_anim("explosion", pos[i], explode[i] / 20.0)
	_kill(i)


func _kill(i: int) -> void:
	if alive[i] == 0:
		return
	alive[i] = 0
	_free.append(i)
	count_alive -= 1


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var a := GameClock.alpha
	var frame := int(GameClock.game_time * 12.0)
	for i: int in range(CAPACITY):
		if alive[i] == 0:
			continue
		var k := kind[i]
		var sheet := _kind_sheets[k]
		var src := sheet.region(frame, 0)
		draw_set_transform(prev[i].lerp(pos[i], a).round(), rot[i], Vector2.ONE)
		draw_texture_rect_region(sheet.texture, Rect2(-src.size * 0.5, src.size), src, _kind_tint[k])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
