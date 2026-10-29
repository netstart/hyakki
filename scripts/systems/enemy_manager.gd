class_name EnemyManager
extends Node2D
## Todos os inimigos num laço só, guardados em arrays (plano 10.6).
## Arquétipos (plano 6.1): perseguidor, enxame, investida, atirador, tanque, sombra,
## divisor e "prop" (lanterna destrutível). Chefes usam o mesmo array (para as armas
## acertarem neles), mas quem os move é o BossDirector.

enum AI { CHASER, SWARM, CHARGER, SHOOTER, TANK, SHADE, SPLITTER, PROP, BOSS }
enum State { MOVE, WINDUP, DASH, RECOVER }

const CAPACITY := 640
const CONTACT_INTERVAL := 0.5
const SEPARATION_FORCE := 70.0
const STEER := 0.2
const HURT_RADIUS_FACTOR := 0.7
const MAX_NEIGHBORS_CHECKED := 8
## A separação de cada inimigo é recalculada a cada SEPARATION_EVERY passos (escalonada).
const SEPARATION_EVERY := 3
const ELITE_SCALE := 1.6
const ELITE_HP := 10.0
const STUCK_SECONDS := 3.0
const SHADE_DARK_SPEED := 1.2
const SHADE_DARK_ALPHA := 0.4
const FROZEN_TINT := Color(0.6, 0.85, 1.0)
## Chave da ordem de desenho (order_key): bits do índice e limite do Y (em 1/16 px).
const ORDER_INDEX_BITS := 12
const ORDER_INDEX_MASK := (1 << ORDER_INDEX_BITS) - 1
const ORDER_Y_LIMIT := 1 << 40
const AI_CODES := {"chaser": AI.CHASER, "swarm": AI.SWARM, "charger": AI.CHARGER,
		"shooter": AI.SHOOTER, "tank": AI.TANK, "shade": AI.SHADE, "splitter": AI.SPLITTER,
		"prop": AI.PROP}

var game: HyakkiGame
var count_alive: int = 0
## Inimigos comuns vivos (sem props e chefes): é o que o spawner compara com o alvo.
var count_common: int = 0
var spatial := SpatialHash.new(24.0)
## Congelamento global (ampulheta) e multiplicador de velocidade (tempestade de cinza etc.).
var freeze_time: float = 0.0
var speed_mult: float = 1.0

# Dados por tipo (índice do tipo = ordem em DB.enemies, mais os chefes no fim).
var type_ids: Array[StringName] = []
var type_index: Dictionary = {}
var type_sheets: Array[SpriteSheet] = []
var type_tint: Array[Color] = []
var type_scale: PackedFloat32Array = []
var type_ai: PackedInt32Array = []
var type_data: Array[Dictionary] = []
var type_flying: PackedByteArray = []

# Dados por inimigo.
var pos := PackedVector2Array()
var prev := PackedVector2Array()
var vel := PackedVector2Array()
var push := PackedVector2Array()
var ai_dir := PackedVector2Array()
var hp := PackedFloat32Array()
var max_hp := PackedFloat32Array()
var dmg := PackedFloat32Array()
var speed := PackedFloat32Array()
var radius := PackedFloat32Array()
var flash := PackedFloat32Array()
var phase := PackedFloat32Array()
var contact_cd := PackedFloat32Array()
var ai_timer := PackedFloat32Array()
var stun := PackedFloat32Array()
var slow := PackedFloat32Array()
var stuck := PackedFloat32Array()
var resist := PackedFloat32Array()
var kind := PackedInt32Array()
var xp_value := PackedInt32Array()
var state := PackedInt32Array()
var facing := PackedInt32Array()
var alive := PackedByteArray()
var elite := PackedByteArray()
var controlled := PackedByteArray()
var decoy := PackedByteArray()
## Chefe mergulhado (Kappa, Tengu): não aparece e não causa dano por contato.
var submerged := PackedByteArray()
## Marchando em linha reta (procissão e enxames), seja qual for o arquétipo.
var marching := PackedByteArray()
## Só de desenho (fora do hash): quando nasceu e quando levou o último golpe (tempo de jogo),
## e a pose do chefe que o BossDirector informa (0 = andar/parado, 1 = preparando o golpe).
var born := PackedFloat32Array()
var hit_at := PackedFloat32Array()
var pose := PackedByteArray()
## Efeitos (entrada, morte, poeira, vapor) e desenho em lote (scripts/systems/enemy_look.gd).
var fx: EnemyFx
var look: EnemyLook
## Retângulo visível no mundo (com folga), atualizado a cada quadro; só para efeitos.
var view_rect := Rect2(-1e6, -1e6, 2e6, 2e6)

var _free: Array[int] = []
var _order: Array[int] = []
var _order_keys := PackedInt64Array()
var _order_dirty: bool = true
var _near: Array[int] = []
var _under: Node2D
var _over: Node2D


func _ready() -> void:
	for packed: StringName in [&"pos", &"prev", &"vel", &"push", &"ai_dir", &"hp", &"max_hp",
			&"dmg", &"speed", &"radius", &"flash", &"phase", &"contact_cd", &"ai_timer", &"stun",
			&"slow", &"stuck", &"resist", &"kind", &"xp_value", &"state", &"facing", &"alive",
			&"elite", &"controlled", &"decoy", &"submerged", &"marching", &"born", &"hit_at", &"pose"]:
		var array: Variant = get(packed)
		array.resize(CAPACITY)
		set(packed, array)
	_build_types()
	_build_visuals()
	reset()


## Camadas de desenho: aditiva por baixo (auras), aditiva por cima (brasas, avisos) e efeitos.
func _build_visuals() -> void:
	look = EnemyLook.new(self)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_under = Node2D.new()
	_under.show_behind_parent = true
	_under.material = additive
	_under.draw.connect(func() -> void: look.draw_under(_under))
	add_child(_under)
	_over = Node2D.new()
	_over.material = additive
	_over.draw.connect(func() -> void: look.draw_over(_over))
	add_child(_over)
	fx = EnemyFx.new()
	fx.game = game
	fx.z_as_relative = false
	fx.z_index = 9
	add_child(fx)
	var settings := get_node_or_null(^"/root/Settings")
	if settings:
		settings.connect("changed", func(k: String) -> void:
			if k == GfxQuality.changed_signal_key():
				look.apply_quality())


func _build_types() -> void:
	for id: StringName in DB.ids("enemies"):
		_add_type(id, DB.enemies[id], false)
	for id: StringName in DB.ids("bosses"):
		_add_type(id, DB.bosses[id], true)


func _add_type(id: StringName, data: Dictionary, is_boss: bool) -> void:
	type_index[id] = type_ids.size()
	type_ids.append(id)
	type_data.append(data)
	var sheet: SpriteSheet
	if is_boss:
		var sprite: Dictionary = data["sprite"]
		var frame: Array = sprite.get("frame", [0, 0])
		sheet = SpriteSheet.load_sheet(sprite["path"], sprite.get("layout", "strip"),
				Vector2(frame[0], frame[1]), 0, bool(sprite.get("faces_left", false)))
	else:
		var layout := String(data.get("layout", "dir4"))
		if layout == "region":
			var r: Array = data["region"]
			sheet = SpriteSheet.load_sheet(data["sprite"], "strip", Vector2(r[2], r[3]), 1)
			sheet.layout = "region"
			sheet.set_meta("region", Rect2(r[0], r[1], r[2], r[3]))
		else:
			var frame: Array = data.get("frame", [16, 16])
			sheet = SpriteSheet.load_sheet(data["sprite"], layout, Vector2(frame[0], frame[1]), 0,
					bool(data.get("faces_left", false)))
	type_sheets.append(sheet)
	type_tint.append(Color(String(data.get("tint", "#ffffff"))))
	type_scale.append(float(data.get("scale", 1.0)))
	type_ai.append(AI.BOSS if is_boss else int(AI_CODES.get(String(data.get("archetype", "chaser")), AI.CHASER)))
	type_flying.append(1 if bool(data.get("flying", false)) else 0)


func reset() -> void:
	_free.clear()
	for i: int in range(CAPACITY - 1, -1, -1):
		_free.append(i)
	alive.fill(0)
	count_alive = 0
	count_common = 0
	freeze_time = 0.0
	speed_mult = 1.0
	_order.clear()
	_order_dirty = true
	if fx:
		fx.reset()
	queue_redraw()


func type_of(id: StringName) -> int:
	return int(type_index.get(id, -1))


## Cria um inimigo. Devolve o índice ou -1 se não houver espaço.
func spawn(id: StringName, at: Vector2, hp_mult: float, damage_mult: float,
		is_elite: bool = false) -> int:
	var t := type_of(id)
	if t < 0 or _free.is_empty():
		return -1
	var i: int = _free.pop_back()
	var data := type_data[t]
	var ai := type_ai[t]
	pos[i] = at
	prev[i] = at
	vel[i] = Vector2.ZERO
	push[i] = Vector2.ZERO
	ai_dir[i] = (game.player.sim_pos - at).normalized()
	var life := float(data.get("hp", 10)) * hp_mult * (ELITE_HP if is_elite else 1.0)
	hp[i] = life
	max_hp[i] = life
	dmg[i] = float(data.get("damage", 1)) * damage_mult
	speed[i] = float(data.get("speed", 30)) * game.rng.randf_range(0.92, 1.08)
	radius[i] = float(data.get("radius", 5)) * (ELITE_SCALE if is_elite else 1.0)
	flash[i] = 0.0
	phase[i] = game.rng.randf() * TAU
	contact_cd[i] = 0.0
	ai_timer[i] = game.rng.randf_range(0.5, 2.0)
	stun[i] = 0.0
	slow[i] = 0.0
	stuck[i] = 0.0
	resist[i] = float(data.get("knock_resist", 0.0))
	kind[i] = t
	xp_value[i] = int(data.get("xp", 0))
	state[i] = State.MOVE
	facing[i] = SpriteSheet.Dir.DOWN
	alive[i] = 1
	elite[i] = 1 if is_elite else 0
	controlled[i] = 1 if ai == AI.BOSS else 0
	decoy[i] = 0
	submerged[i] = 0
	marching[i] = 0
	born[i] = GameClock.game_time
	hit_at[i] = -100.0
	pose[i] = 0
	if look and view_rect.has_point(at) and ai != AI.PROP:
		fx.spawn_in(at, look.spawn_styles[t], type_scale[t] * (ELITE_SCALE if is_elite else 1.0))
	count_alive += 1
	if ai != AI.PROP and ai != AI.BOSS:
		count_common += 1
	_order_dirty = true
	return i


func is_boss(i: int) -> bool:
	return type_ai[kind[i]] == AI.BOSS


func is_prop(i: int) -> bool:
	return type_ai[kind[i]] == AI.PROP


func step(dt: float) -> void:
	prev = pos.duplicate()
	spatial.clear()
	for i: int in range(CAPACITY):
		if alive[i] == 1:
			spatial.insert(i, pos[i])
	if freeze_time > 0.0:
		freeze_time -= dt
	var frozen := freeze_time > 0.0
	var player := game.player
	var target := player.sim_pos
	var parity := game.step_index % SEPARATION_EVERY
	var far := game.view_half_diagonal() * 2.2
	var time := GameClock.game_time
	var light_r := game.lantern.radius
	var world := game.world
	var bounds := world.bounds
	var contact_reach := Player.RADIUS
	# Superfícies lentas (lama, piche...): só sobre o solo, recuperação suave. Voadores passam por cima.
	var surf := SurfaceSystem.of(game)
	for i: int in range(CAPACITY):
		if alive[i] == 0:
			continue
		var t := kind[i]
		var ai := type_ai[t]
		if ai == AI.PROP:
			continue
		if flash[i] > 0.0:
			flash[i] -= dt
		contact_cd[i] -= dt
		var p: Vector2 = pos[i]
		var to_player := target - p
		var dist := to_player.length()
		if controlled[i] == 1:
			_contact(i, dist, player)
			continue
		if frozen or stun[i] > 0.0:
			stun[i] = maxf(0.0, stun[i] - dt)
			vel[i] = vel[i] * 0.8
			pos[i] = p + vel[i] * dt
			continue
		var r: float = radius[i]
		if i % SEPARATION_EVERY == parity:
			push[i] = _separation(i, p, r)
		if dist > far and ai != AI.SWARM:
			p = game.spawner.edge_point()
			pos[i] = p
			prev[i] = p
			continue
		var dir := to_player / maxf(dist, 0.001)
		var spd: float = speed[i] * speed_mult * (1.0 if surf == null or type_flying[t] == 1 else surf.enemy_factor(i, p, r))
		if slow[i] > 0.0:
			slow[i] -= dt
			spd *= 0.5
		var desired := dir * spd
		if marching[i] == 1:
			ai = AI.SWARM
		match ai:
			AI.SWARM:
				desired = ai_dir[i] * spd
				if dist > far * 1.3:
					_remove(i)
					continue
			AI.CHARGER:
				desired = _charger(i, dir, dist, spd, dt)
			AI.SHOOTER:
				desired = _shooter(i, dir, dist, spd, dt)
			AI.SHADE:
				if dist > light_r:
					desired *= SHADE_DARK_SPEED
		var steer_amount := 1.0 if state[i] == State.DASH else STEER * (1.0 if surf == null else surf.enemy_accel(i))
		var v: Vector2 = vel[i].lerp(desired + push[i] * SEPARATION_FORCE, steer_amount)
		vel[i] = v
		var next := p + v * dt
		if type_flying[t] == 0:
			next = world.resolve(next, r * 0.8)
		# clamp_to_bounds em linha: roda para cada inimigo a cada passo.
		if bounds.x > 0.0:
			next.x = clampf(next.x, -bounds.x, bounds.x)
		if bounds.y > 0.0:
			next.y = clampf(next.y, -bounds.y, bounds.y)
		# Preso atrás de obstáculo por muito tempo: reaparece perto (plano 8.7.2).
		if ai != AI.SWARM and (next - p).length() < spd * dt * 0.15 and dist > 40.0:
			stuck[i] += dt
			if stuck[i] > STUCK_SECONDS:
				stuck[i] = 0.0
				next = game.spawner.edge_point()
				prev[i] = next
		else:
			stuck[i] = maxf(0.0, stuck[i] - dt)
		pos[i] = next
		facing[i] = SpriteSheet.dir_from_vector(v, facing[i])
		if dist < r * HURT_RADIUS_FACTOR + contact_reach:
			_contact(i, dist, player)


func _contact(i: int, dist: float, player: Player) -> void:
	if decoy[i] == 1 or submerged[i] == 1 or dmg[i] <= 0.0:
		return
	if dist < radius[i] * HURT_RADIUS_FACTOR + Player.RADIUS and contact_cd[i] <= 0.0 and player.is_alive:
		contact_cd[i] = CONTACT_INTERVAL
		player.take_damage(dmg[i], type_ids[kind[i]])


func _charger(i: int, dir: Vector2, dist: float, spd: float, dt: float) -> Vector2:
	var params: Dictionary = type_data[kind[i]].get("ai", {})
	ai_timer[i] -= dt
	match state[i]:
		State.MOVE:
			if dist < float(params.get("range", 110)) and ai_timer[i] <= 0.0:
				state[i] = State.WINDUP
				ai_timer[i] = float(params.get("windup", 0.6))
				ai_dir[i] = dir
			return dir * spd
		State.WINDUP:
			flash[i] = 0.05 if int(ai_timer[i] * 10.0) % 2 == 0 else 0.0
			if ai_timer[i] <= 0.0:
				state[i] = State.DASH
				ai_timer[i] = float(params.get("dash_time", 0.45))
			return Vector2.ZERO
		State.DASH:
			if ai_timer[i] <= 0.0:
				state[i] = State.MOVE
				ai_timer[i] = float(params.get("cooldown", 2.5))
			return ai_dir[i] * float(params.get("dash_speed", 180)) * speed_mult
	return dir * spd


func _shooter(i: int, dir: Vector2, dist: float, spd: float, dt: float) -> Vector2:
	var params: Dictionary = type_data[kind[i]].get("ai", {})
	var keep := float(params.get("range", 160))
	ai_timer[i] -= dt
	if ai_timer[i] <= 0.0 and dist < keep * 1.4:
		ai_timer[i] = float(params.get("cooldown", 2.4))
		game.enemy_shots.spawn(pos[i], dir * float(params.get("proj_speed", 70)),
				float(params.get("proj_damage", 5)) * game.enemy_damage_mult(),
				String(params.get("projectile", "energy_ball")), 5.0, 0.0, type_ids[kind[i]])
	if dist < keep * 0.75:
		return -dir * spd * 0.7
	if dist > keep:
		return dir * spd
	return dir.orthogonal() * spd * 0.4


func _separation(i: int, p: Vector2, r: float) -> Vector2:
	spatial.query(p, r * 2.0, _near, MAX_NEIGHBORS_CHECKED + 2)
	var acc := Vector2.ZERO
	var touching := 0
	var checked := 0
	for j: int in _near:
		if j == i or alive[j] == 0:
			continue
		checked += 1
		if checked > MAX_NEIGHBORS_CHECKED:
			break
		var d: Vector2 = p - pos[j]
		var min_dist: float = r + radius[j]
		var d2 := d.length_squared()
		if d2 >= min_dist * min_dist:
			continue
		if d2 < 0.0001:
			acc += Vector2.from_angle(float(i)) * 0.5
		else:
			var length := sqrt(d2)
			acc += d / length * (1.0 - length / min_dist)
		touching += 1
		if touching >= 4:
			break
	return acc


## Inimigos vivos que tocam o círculo (inclui props e chefes).
func query_circle(center: Vector2, r: float, out: Array[int]) -> void:
	spatial.query(center, r + 30.0, _near)
	out.clear()
	for j: int in _near:
		if alive[j] == 1 and center.distance_to(pos[j]) <= r + radius[j]:
			out.append(j)


## Mais próximo dentro do alcance; ignora props (lanternas) para as armas mirarem em inimigos.
func nearest(center: Vector2, max_dist: float, skip: Array[int] = []) -> int:
	var best := -1
	var best_d2 := max_dist * max_dist
	for i: int in range(CAPACITY):
		if alive[i] == 0 or is_prop(i):
			continue
		if not skip.is_empty() and skip.has(i):
			continue
		var d2 := center.distance_squared_to(pos[i])
		if d2 < best_d2:
			best_d2 = d2
			best = i
	return best


## Inimigo com mais vida no alcance (Hitodama mira nele, plano 4.5).
func strongest(center: Vector2, max_dist: float) -> int:
	var best := -1
	var best_hp := -1.0
	var max_d2 := max_dist * max_dist
	for i: int in range(CAPACITY):
		if alive[i] == 0 or is_prop(i):
			continue
		if center.distance_squared_to(pos[i]) > max_d2:
			continue
		if hp[i] > best_hp:
			best_hp = hp[i]
			best = i
	return best


func random_alive(center: Vector2, max_dist: float) -> int:
	var candidates: Array[int] = []
	var max_d2 := max_dist * max_dist
	for i: int in range(CAPACITY):
		if alive[i] == 1 and not is_prop(i) and center.distance_squared_to(pos[i]) <= max_d2:
			candidates.append(i)
	if candidates.is_empty():
		return -1
	return candidates[game.rng.randi_range(0, candidates.size() - 1)]


## Aplica dano e recuo. Devolve true se o inimigo morreu.
func damage(i: int, amount: float, dir: Vector2, force: float) -> bool:
	if alive[i] == 0:
		return false
	if is_boss(i) and bool(type_data[kind[i]].get("invincible", false)):
		flash[i] = 0.05
		return false
	hp[i] -= amount
	flash[i] = 0.08
	hit_at[i] = GameClock.game_time
	if fx and force >= 40.0 and not is_boss(i) and view_rect.has_point(pos[i]):
		fx.dust(pos[i] + Vector2(0, radius[i] * 0.6), dir, 1)
	if not is_prop(i):
		vel[i] = vel[i] + dir * force * (1.0 - resist[i]) * (0.15 if is_boss(i) else 1.0)
	if hp[i] > 0.0:
		return false
	_kill(i)
	return true


func _kill(i: int) -> void:
	var t := kind[i]
	var data := type_data[t]
	var at: Vector2 = pos[i]
	var was_elite := elite[i] == 1
	var was_decoy := decoy[i] == 1
	_remove(i)
	if type_ai[t] == AI.PROP:
		game.on_prop_destroyed(i, at)
		return
	if was_decoy:
		game.fx.burst(at, Color.WHITE)
		if fx:
			fx.death(at, "mist", Color.WHITE, 2.0, false, false)
		return
	if fx and type_ai[t] != AI.BOSS and view_rect.has_point(at):
		fx.death(at, look.death_styles[t], type_tint[t], type_scale[t], was_elite)
	if type_ai[t] == AI.SPLITTER:
		var params: Dictionary = data.get("ai", {})
		for k: int in range(int(params.get("count", 2))):
			var offset := Vector2.from_angle(TAU * k / float(params.get("count", 2))) * 6.0
			spawn(StringName(params.get("split_into", "")), at + offset,
					game.enemy_hp_mult(), game.enemy_damage_mult())
	Events.enemy_killed.emit(at, xp_value[i], type_tint[t], type_ids[t], was_elite, type_ai[t])


func _remove(i: int) -> void:
	if alive[i] == 0:
		return
	alive[i] = 0
	_free.append(i)
	if look:
		look.forget(i)
	count_alive -= 1
	var ai := type_ai[kind[i]]
	if ai != AI.PROP and ai != AI.BOSS:
		count_common -= 1
	_order_dirty = true


## Remove sem recompensa (amanhecer, sino purificador não, esse dá recompensa).
func despawn(i: int) -> void:
	_remove(i)


func push_from(center: Vector2, r: float, force: float) -> void:
	for i: int in range(CAPACITY):
		if alive[i] == 0 or is_prop(i) or is_boss(i):
			continue
		var d := pos[i] - center
		var dist := d.length()
		if dist < r and dist > 0.001:
			vel[i] = vel[i] + d / dist * force * (1.0 - resist[i])


func stun_all(seconds: float, center: Vector2 = Vector2.ZERO, r: float = INF) -> void:
	for i: int in range(CAPACITY):
		if alive[i] == 1 and not is_prop(i) and not is_boss(i) and center.distance_to(pos[i]) <= r:
			stun[i] = maxf(stun[i], seconds)


func _process(delta: float) -> void:
	if _order_dirty or Engine.get_process_frames() % 6 == 0:
		_rebuild_order()
	view_rect = _visible_world_rect(28.0)
	look.collect(view_rect)
	look.process(delta)
	queue_redraw()
	_under.queue_redraw()
	_over.queue_redraw()


## Parte do mundo na tela, com `margin` px de folga (inimigos fora dela não são desenhados).
func _visible_world_rect(margin: float) -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return view_rect
	var inverse := get_canvas_transform().affine_inverse()
	var rect := inverse * viewport.get_visible_rect()
	return rect.grow(margin)


## Ordem de desenho por Y. Uma chave inteira por inimigo (Y em 1/16 px nos bits altos, o índice
## nos baixos) ordenada pelo sort nativo: ~20x mais rápido que sort_custom com um Callable de
## GDScript (1,4 ms → 0,07 ms com 500 inimigos no PC), e roda quase todo quadro na horda (cada
## nascimento ou morte suja a ordem). Só desenho: a simulação não lê _order. Empate em Y sai em
## ordem de índice (estável), o que o sort_custom não garantia.
func _rebuild_order() -> void:
	_order_dirty = false
	_order_keys.clear()
	for i: int in range(CAPACITY):
		if alive[i] == 1:
			_order_keys.append(order_key(pos[i].y, i))
	_order_keys.sort()
	_order.resize(_order_keys.size())
	for k: int in range(_order_keys.size()):
		_order[k] = _order_keys[k] & ORDER_INDEX_MASK


## Chave de ordenação por Y (resolução de 1/16 px) com o índice nos bits baixos.
static func order_key(y: float, index: int) -> int:
	return ((clampi(roundi(y * 16.0), -ORDER_Y_LIMIT, ORDER_Y_LIMIT) + ORDER_Y_LIMIT) << ORDER_INDEX_BITS) | index


## Congelado: tom azulado no próprio sprite. Não usa desenho extra por inimigo, que dobrava
## os draw calls com centenas de inimigos e derrubava o FPS (o jogador parecia travado).
static func frozen_tint(base: Color, frozen: bool) -> Color:
	if not frozen:
		return base
	var tint := base.lerp(FROZEN_TINT, 0.5)
	tint.a = base.a
	return tint


func _draw() -> void:
	look.draw(self)
	if game.show_hitboxes:
		var a := GameClock.alpha
		for i: int in _order:
			if alive[i] == 1:
				draw_arc(prev[i].lerp(pos[i], a), radius[i], 0.0, TAU, 12, Color.RED, 1.0)
