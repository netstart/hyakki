class_name ProjectileManager
extends Node2D
## Projéteis da guardiã em arrays, num laço só (plano 10.7).
## Comportamentos: reto, teleguiado (Hitodama), bumerangue (Kusarigama), explosão no fim
## (Flecha de Hachiman). A colisão testa o segmento do passo (sem tunneling, plano 8.7.2).
## Visual (só desenho, nunca muda a simulação): rastro por projétil com "trail_points" pontos
## (Média/Alta), brilho aditivo por tipo na Alta (draw_glow, chamado pela camada de brilho do
## FxLayer), a corrente da Kusarigama ligando a mão ao gancho e brasas atrás das chamas.

enum Move { STRAIGHT, HOMING, BOOMERANG, SPIRAL }

const CAPACITY := 360
## Pontos de rastro guardados por projétil (a cota "trail_points" da Alta).
const TRAIL_MAX := 14
## Corrente da Kusarigama: inteira até CHAIN_REACH px da mão; além disso, só CHAIN_TAIL px.
const CHAIN_REACH := 130.0
const CHAIN_TAIL := 26.0
## "trail": cor do rastro; "width": largura; "glow": cor do brilho aditivo e "glow_r" o raio;
## "scale": tamanho do sprite; "ember": solta brasas da cor do rastro.
const KINDS := {
	"shuriken": {"path": "res://assets/art/items/projectile/shuriken.png", "frame": 15, "spin": 14.0,
			"tint": "#ffffff", "trail": "#c8d4e6", "width": 2.0, "glow": "#9fb8d8", "glow_r": 7.0},
	"steel_shuriken": {"path": "res://assets/art/items/projectile/shuriken.png", "frame": 15, "spin": 20.0,
			"tint": "#d8f4ff", "trail": "#8fd8ff", "width": 3.0, "glow": "#5fc8ff", "glow_r": 10.0, "scale": 1.25},
	"kunai": {"path": "res://assets/art/fx/projectile/Kunai.png", "frame": 14, "spin": 0.0, "tint": "#ffffff",
			"trail": "#d8dde6", "width": 1.0, "glow": "#c0c8d8", "glow_r": 5.0},
	"arrow": {"path": "res://assets/art/fx/projectile/Arrow.png", "frame": 13, "spin": 0.0, "tint": "#ffffff",
			"trail": "#f0e6d2", "width": 1.0, "glow": "#e0d8c8", "glow_r": 5.0},
	"golden_arrow": {"path": "res://assets/art/fx/projectile/Arrow.png", "frame": 13, "spin": 0.0,
			"tint": "#ffd166", "trail": "#ffcf4a", "width": 2.0, "glow": "#ffb020", "glow_r": 11.0, "ember": true},
	"hook": {"path": "res://assets/art/fx/projectile/Shuriken.png", "frame": 16, "spin": 18.0, "tint": "#d9d9d9",
			"trail": "#b9c3cf", "width": 2.0, "glow": "#8090a8", "glow_r": 7.0},
	"reaper_hook": {"path": "res://assets/art/fx/projectile/Shuriken.png", "frame": 16, "spin": 22.0,
			"tint": "#ffb0b8", "trail": "#ff5a6a", "width": 3.0, "glow": "#ff3048", "glow_r": 11.0},
	"flame": {"path": "res://assets/art/fx/projectile/Fireball.png", "frame": 16, "spin": 0.0, "tint": "#9fd7ff",
			"trail": "#7fc8ff", "width": 3.0, "glow": "#3fa0ff", "glow_r": 12.0, "ember": true},
	"ally_flame": {"path": "res://assets/art/fx/projectile/Fireball.png", "frame": 16, "spin": 0.0,
			"tint": "#c9ffb5", "trail": "#9bff9b", "width": 3.0, "glow": "#50ff70", "glow_r": 12.0, "ember": true},
	"needle": {"path": "res://assets/art/fx/projectile/Kunai.png", "frame": 14, "spin": 0.0, "tint": "#ffe9a8",
			"trail": "#ffd166", "width": 1.0, "glow": "#ffc040", "glow_r": 7.0},
	"rain_arrow": {"path": "res://assets/art/fx/projectile/Arrow.png", "frame": 13, "spin": 0.0,
			"tint": "#ffe08a", "trail": "#ffe08a", "width": 1.0, "glow": "#ffc040", "glow_r": 6.0},
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
var _kind_trail: Array[Color] = []
var _kind_width: PackedFloat32Array = []
var _kind_glow: Array[Color] = []
var _kind_glow_r: PackedFloat32Array = []
var _kind_scale: PackedFloat32Array = []
var _kind_ember: Array[bool] = []
var _hook_kinds: Array[int] = []
var _reaper_kind: int = -1
## Rastro (só desenho): TRAIL_MAX posições por projétil num anel; _trail_n = quantas valem.
var _trail := PackedVector2Array()
var _trail_head := PackedInt32Array()
var _trail_n := PackedInt32Array()
var _ember_tick: int = 0


func _ready() -> void:
	for name: String in KINDS:
		var data: Dictionary = KINDS[name]
		_kind_names.append(name)
		_kind_sheets.append(SpriteSheet.load_sheet(data["path"], "strip", Vector2(float(data["frame"]), 0.0)))
		_kind_spin.append(float(data["spin"]))
		_kind_tint.append(Color(String(data["tint"])))
		_kind_trail.append(Color(String(data.get("trail", "#ffffff"))))
		_kind_width.append(float(data.get("width", 1.0)))
		_kind_glow.append(Color(String(data.get("glow", "#ffffff"))))
		_kind_glow_r.append(float(data.get("glow_r", 0.0)))
		_kind_scale.append(float(data.get("scale", 1.0)))
		_kind_ember.append(bool(data.get("ember", false)))
		if name.ends_with("hook"):
			_hook_kinds.append(_kind_names.size() - 1)
	_reaper_kind = _kind_names.find("reaper_hook")
	_trail.resize(CAPACITY * TRAIL_MAX)
	_trail_head.resize(CAPACITY)
	_trail_n.resize(CAPACITY)
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
	_trail_n[i] = 0
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
		_note_trail(i, to)
		rot[i] = rot[i] + _kind_spin[kind[i]] * dt if _kind_spin[kind[i]] > 0.0 else v.angle()
		if life[i] <= 0.0:
			_finish(i)


## Ponto novo do rastro (só desenho; nada aqui é lido pela simulação).
func _note_trail(i: int, at: Vector2) -> void:
	if FxLayer.trail_points <= 0:
		_trail_n[i] = 0
		return
	var head := (_trail_head[i] + 1) % TRAIL_MAX
	_trail_head[i] = head
	_trail[i * TRAIL_MAX + head] = at
	_trail_n[i] = mini(_trail_n[i] + 1, TRAIL_MAX)


## Fim da vida: explode se for o caso (Flecha de Hachiman).
func _finish(i: int) -> void:
	if explode[i] > 0.0:
		game.areas.blast(weapon_id[i], pos[i], explode[i], dmg[i] * 0.6, 60.0)
		_explosion_fx(pos[i], explode[i])
	_kill(i)


## Explosão dourada da Flecha de Hachiman: animação, onda, clarão e brasas (só desenho).
func _explosion_fx(at: Vector2, r: float) -> void:
	var fx := game.fx
	fx.play_anim("explosion", at, minf(2.6, r / 20.0), 0.0, Color(1.0, 0.92, 0.7))
	fx.play_anim("circle_spark", at, minf(2.6, r / 16.0), 0.0, Color(1.0, 0.85, 0.4), 18.0, false, true)
	fx.shockwave(at, r * 1.2, Color(1.0, 0.82, 0.35), 1.0, 0.35)
	fx.flash(at, r * 1.3, Color(1.0, 0.75, 0.3, 0.9), 0.18)
	fx.embers(at, Color(1.0, 0.8, 0.3), [2, 6, 12][FxLayer.wfx], r * 0.3)
	WeaponSfx.play("hachiman_blast")
	game.shake(1.2 * FxLayer.shake_mult)


func _kill(i: int) -> void:
	if alive[i] == 0:
		return
	alive[i] = 0
	_free.append(i)
	count_alive -= 1


func _process(_delta: float) -> void:
	queue_redraw()
	_emit_embers()


## Brasas atrás das chamas e da flecha dourada (Média: poucas; Alta: mais; Baixa: nada).
func _emit_embers() -> void:
	if FxLayer.wfx == 0 or count_alive == 0 or game == null or game.fx == null:
		return
	_ember_tick += 1
	if _ember_tick % (4 if FxLayer.wfx == 1 else 2) != 0:
		return
	for i: int in range(CAPACITY):
		if alive[i] == 1 and _kind_ember[kind[i]]:
			game.fx.embers(pos[i], _kind_trail[kind[i]], 1, 2.0)


func _draw() -> void:
	var a := GameClock.alpha
	var frame := int(GameClock.game_time * 12.0)
	var points := FxLayer.trail_points
	if count_alive > 0 and game and game.player:
		_draw_chains(a)
	for i: int in range(CAPACITY):
		if alive[i] == 0:
			continue
		var k := kind[i]
		var at := prev[i].lerp(pos[i], a).round()
		if points > 0 and _trail_n[i] > 1:
			_draw_trail(i, at, mini(points, _trail_n[i]), _kind_trail[k], _kind_width[k])
		var sheet := _kind_sheets[k]
		var src := sheet.region(frame, 0)
		draw_set_transform(at, rot[i], Vector2.ONE * _kind_scale[k])
		draw_texture_rect_region(sheet.texture, Rect2(-src.size * 0.5, src.size), src, _kind_tint[k])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Rastro afinando e sumindo do projétil para trás (uma polilinha por projétil).
func _draw_trail(i: int, head_at: Vector2, n: int, color: Color, width: float) -> void:
	var line := PackedVector2Array([head_at])
	var head := _trail_head[i]
	for k: int in range(1, n):
		line.append(_trail[i * TRAIL_MAX + (head - k + TRAIL_MAX) % TRAIL_MAX].round())
	var colors := PackedColorArray()
	for k: int in range(line.size()):
		colors.append(Color(color, 0.8 * (1.0 - k / float(line.size()))))
	draw_polyline_colors(line, colors, width)


## Corrente da Kusarigama: elos da mão da guardiã até o gancho (em todos os níveis).
func _draw_chains(a: float) -> void:
	var player := game.player
	var hand := player.hand_position(player.position) if player.has_hand() else player.position
	for i: int in range(CAPACITY):
		if alive[i] == 0 or not _hook_kinds.has(kind[i]):
			continue
		var tip := prev[i].lerp(pos[i], a)
		var red := kind[i] == _reaper_kind
		var from := hand
		# Longe da mão (ou a corrente em espiral, solta) só um rabo de elos atrás do gancho.
		if red or tip.distance_to(hand) > CHAIN_REACH:
			var back := -vel[i].normalized() if vel[i] != Vector2.ZERO else (hand - tip).normalized()
			from = tip + back * CHAIN_TAIL
		var span := tip - from
		var links := int(span.length() / 4.0)
		for k: int in range(1, links):
			var p := (from + span * (k / float(links))).round()
			draw_rect(Rect2(p - Vector2.ONE, Vector2(2, 2)),
					Color(0.18, 0.16, 0.2) if k % 2 else Color(0.32, 0.3, 0.34))
			draw_rect(Rect2(p - Vector2.ONE, Vector2.ONE), Color(1.0, 0.55, 0.6) if red else Color(0.82, 0.86, 0.92))


## Brilho aditivo de cada projétil (Alta), desenhado na camada de brilho do FxLayer.
func draw_glow(canvas: CanvasItem) -> void:
	if count_alive == 0:
		return
	var a := GameClock.alpha
	var pulse := 0.85 + 0.15 * sin(GameClock.game_time * 18.0)
	for i: int in range(CAPACITY):
		if alive[i] == 0:
			continue
		var k := kind[i]
		if _kind_glow_r[k] <= 0.0:
			continue
		FxLayer.draw_soft(canvas, prev[i].lerp(pos[i], a), _kind_glow_r[k] * pulse, Color(_kind_glow[k], 0.55))
