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
## Habilidades dos guardiões: velocidade de quem foge com medo (× a própria), lentidão padrão
## (slow sem fator) e a fração do atordoamento em área que um chefe sofre (stun_circle). Chefes
## são movidos pelo BossDirector e ignoram lentidão, raiz, medo, isca e puxão.
const FEAR_SPEED := 1.15
const DEFAULT_SLOW := 0.5
const BOSS_STUN := 0.4
## Puxão (pull_to): duração do arraste; a velocidade é calculada para chegar no ponto pedido
## com o mesmo amortecimento do atordoado (vel × 0,8 por passo).
const PULL_TIME := 0.35
const PULL_DAMPING := 0.8
## Fogo e gelo (.ai/06-fogo-gelo-clones.md), números lidos pelo Guia:
## Queimadura (炎上): dano contínuo a cada BURN_TICK s, creditado à arma que queimou; reaplicar
## fica com o maior dps e o maior tempo (não soma). Chefes queimam.
const BURN_TICK := 0.5
## Frio (凍結): cada acerto de gelo soma pilhas e deixa lento (CHILL_SLOW por CHILL_SLOW_TIME s,
## × atributo "chill", até CHILL_SLOW_MAX); com CHILL_STACKS_TO_FREEZE pilhas o inimigo congela
## por FREEZE_TIME s (× "chill"). As pilhas só duram enquanto a lentidão do frio dura. Chefes
## ficam lentos (× BOSS_STUN) e as pilhas param uma antes de congelar.
const CHILL_STACKS_TO_FREEZE := 5
const FREEZE_TIME := 1.2
const CHILL_SLOW := 0.35
const CHILL_SLOW_TIME := 1.5
const CHILL_SLOW_MAX := 0.7
## Estilhaçar: inimigo morto congelado (arma com "shatter") explode em estilhaços.
const SHATTER_DAMAGE := 25.0
const SHATTER_RADIUS := 30.0
const SHATTER_CHILL := 1
## Reações em cadeia (Estilhaçar, chamas do Kagutsuchi) por passo: na horda congelada ou em brasa,
## uma morte puxa a outra e um passo só fazia centenas de explosões (pico de 140 ms no estresse).
const CASCADES_PER_STEP := 12
const SIGHT_TRIES := 6
## Choque Térmico (温度衝撃): fogo em congelado ou gelo em quem queima consome o estado e soma
## THERMAL_SHOCK_MULT × o dano do acerto; recarga por inimigo.
const THERMAL_SHOCK_MULT := 1.0
const THERMAL_SHOCK_COOLDOWN := 0.5
## Folga do último tique da Queimadura (erro de ponto flutuante dos passos).
const BURN_EPSILON := 0.0001
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
## Lentidão: tempo restante e o fator de velocidade enquanto dura (slow_circle).
var slow := PackedFloat32Array()
var slow_mult := PackedFloat32Array()
## Controle das habilidades (tempo restante): preso no lugar, fugindo de `goal` (medo) e
## perseguindo `goal` (isca). Medo e isca dividem o ponto: vale o último aplicado.
var root := PackedFloat32Array()
var fear := PackedFloat32Array()
var lure := PackedFloat32Array()
var goal := PackedVector2Array()
## Queimadura: tempo restante, dano por segundo, próximo tique e a fonte (índice em burn_sources).
var burn_time := PackedFloat32Array()
var burn_dps := PackedFloat32Array()
var burn_tick := PackedFloat32Array()
var burn_src := PackedInt32Array()
## Frio: pilhas, congelado (tempo restante; parado pelo stun) e recarga do Choque Térmico.
var chill := PackedInt32Array()
var frozen := PackedFloat32Array()
var shock_cd := PackedFloat32Array()
## Ids das armas que queimam (burn_src aponta para cá; poucos, cresce sob demanda).
var burn_sources: Array[StringName] = []
## Reações em cadeia que ainda cabem neste passo (CASCADES_PER_STEP; take_cascade).
var cascades_left: int = CASCADES_PER_STEP
## Último golpe (HyakkiGame.deal_damage escreve antes do dano): quem matou, para o on_kill.
var hit_by: StringName = &""
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
## Identidade de cada nascimento (sobe a cada spawn, na ordem da simulação): quem guarda um
## índice por mais de um passo (EliteAffixes, AltarSystem) confere que a vaga não foi reusada.
var uid := PackedInt32Array()
## Selado pelo altar (surgimento do Elite): não leva dano nem fere por contato.
var sealed := PackedByteArray()
## Escudo que absorve dano antes da vida (afixo 剛 Diamante); ao zerar avisa o AltarSystem.
var shield := PackedFloat32Array()
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
var _next_uid: int = 1
var _order: Array[int] = []
var _order_keys := PackedInt64Array()
var _order_dirty: bool = true
var _near: Array[int] = []
## Resultado reaproveitado das primitivas das habilidades (sem alocar por chamada).
var _hits: Array[int] = []
var _under: Node2D
var _over: Node2D
## Estado de quem está morrendo (pilha: mortes dentro de mortes, como o Estilhaçar em cadeia),
## lido pelos on_kill das armas durante o Events.enemy_killed.
var _dying_index := PackedInt32Array()
var _dying_burn := PackedFloat32Array()
var _dying_frozen := PackedByteArray()
var _dying_killer: Array[StringName] = []


func _ready() -> void:
	for packed: StringName in [&"pos", &"prev", &"vel", &"push", &"ai_dir", &"hp", &"max_hp",
			&"dmg", &"speed", &"radius", &"flash", &"phase", &"contact_cd", &"ai_timer", &"stun",
			&"slow", &"slow_mult", &"root", &"fear", &"lure", &"goal", &"burn_time", &"burn_dps",
			&"burn_tick", &"burn_src", &"chill", &"frozen", &"shock_cd", &"stuck", &"resist", &"kind",
			&"xp_value", &"state", &"facing", &"alive",
			&"elite", &"controlled", &"decoy", &"submerged", &"marching", &"born", &"hit_at", &"pose",
			&"uid", &"sealed", &"shield"]:
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
	_next_uid = 1
	count_alive = 0
	count_common = 0
	freeze_time = 0.0
	speed_mult = 1.0
	hit_by = &""
	_dying_index.clear()
	_dying_burn.clear()
	_dying_frozen.clear()
	_dying_killer.clear()
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
	slow_mult[i] = DEFAULT_SLOW
	root[i] = 0.0
	fear[i] = 0.0
	lure[i] = 0.0
	goal[i] = at
	burn_time[i] = 0.0
	burn_dps[i] = 0.0
	burn_tick[i] = 0.0
	burn_src[i] = 0
	chill[i] = 0
	frozen[i] = 0.0
	shock_cd[i] = 0.0
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
	uid[i] = _next_uid
	_next_uid += 1
	sealed[i] = 0
	shield[i] = 0.0
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
	cascades_left = CASCADES_PER_STEP
	# Mesmo resultado de clear() + insert(i, pos[i]) para cada vivo em ordem crescente.
	spatial.rebuild(pos, alive, CAPACITY)
	if freeze_time > 0.0:
		freeze_time -= dt
	var time_stopped := freeze_time > 0.0
	var player := game.player
	var target := player.sim_pos
	var parity := game.step_index % SEPARATION_EVERY
	var far := game.view_half_diagonal() * 2.2
	var time := GameClock.game_time
	# Lua Vermelha III+: as Sombras agem também na luz (como no escuro em toda parte).
	var light_r := -1.0 if RedMoon.shades_in_light(game.moon) else game.lantern.radius
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
		if burn_time[i] > 0.0 or frozen[i] > 0.0 or shock_cd[i] > 0.0:
			_step_status(i, dt)
			if alive[i] == 0:
				continue
		var p: Vector2 = pos[i]
		var to_player := target - p
		var dist := to_player.length()
		if controlled[i] == 1:
			# Chefe: o BossDirector o move e lê a lentidão do frio (move_factor).
			if slow[i] > 0.0:
				slow[i] -= dt
			_contact(i, dist, player)
			continue
		if time_stopped or stun[i] > 0.0:
			stun[i] = maxf(0.0, stun[i] - dt)
			vel[i] = vel[i] * 0.8
			pos[i] = p + vel[i] * dt
			continue
		var r: float = radius[i]
		if root[i] > 0.0:
			# Preso (armadilha, habilidade): não anda, mas ainda fere quem encosta.
			root[i] -= dt
			vel[i] = Vector2.ZERO
			if dist < r * HURT_RADIUS_FACTOR + contact_reach:
				_contact(i, dist, player)
			continue
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
			spd *= slow_mult[i]
		var desired := dir * spd
		# Medo (foge de goal) e isca (persegue goal) mandam no lugar do arquétipo.
		var steered := fear[i] > 0.0 or lure[i] > 0.0
		if steered:
			desired = _steer(i, p, spd, dt)
			ai = -1
		elif marching[i] == 1:
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
		if ai != AI.SWARM and not steered and (next - p).length() < spd * dt * 0.15 and dist > 40.0:
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
	if decoy[i] == 1 or submerged[i] == 1 or sealed[i] == 1 or dmg[i] <= 0.0:
		return
	if dist < radius[i] * HURT_RADIUS_FACTOR + Player.RADIUS and contact_cd[i] <= 0.0 and player.is_alive:
		contact_cd[i] = CONTACT_INTERVAL
		var taken := player.take_damage(dmg[i], type_ids[kind[i]])
		# Espinhos (Corpo de Diamante): devolve parte do dano de contato a quem encostou.
		var back := player.thorns_damage(dmg[i]) if taken > 0.0 else 0.0
		if back > 0.0:
			game.deal_damage(player.thorns_source, i, back, (pos[i] - player.sim_pos).normalized(), 60.0)


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
	# Referências locais (só leitura): evita buscar o membro a cada vizinho.
	var alive_l := alive
	var pos_l := pos
	var radius_l := radius
	for j: int in _near:
		if j == i or alive_l[j] == 0:
			continue
		checked += 1
		if checked > MAX_NEIGHBORS_CHECKED:
			break
		var d: Vector2 = p - pos_l[j]
		var min_dist: float = r + radius_l[j]
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
	var alive_l := alive
	var pos_l := pos
	var radius_l := radius
	for j: int in _near:
		if alive_l[j] == 1 and center.distance_to(pos_l[j]) <= r + radius_l[j]:
			out.append(j)


## Mais próximo dentro do alcance; ignora props (lanternas) para as armas mirarem em inimigos.
func nearest(center: Vector2, max_dist: float, skip: Array[int] = []) -> int:
	var best := -1
	var best_d2 := max_dist * max_dist
	# Mesmo resultado da varredura antiga (o primeiro índice com a menor distância), com referências
	# locais e a distância antes do tipo e da lista: os clones procuram alvo várias vezes por passo.
	var alive_l := alive
	var pos_l := pos
	var kind_l := kind
	var ai_l := type_ai
	var skipping := not skip.is_empty()
	for i: int in range(CAPACITY):
		if alive_l[i] == 0:
			continue
		var d2 := center.distance_squared_to(pos_l[i])
		if d2 >= best_d2 or ai_l[kind_l[i]] == AI.PROP or (skipping and skip.has(i)):
			continue
		best_d2 = d2
		best = i
	return best


## Mais próximo com a linha livre de sólidos (até SIGHT_TRIES candidatos); sem nenhum à vista, o mais próximo.
func nearest_in_sight(center: Vector2, max_dist: float) -> int:
	var first := nearest(center, max_dist)
	var skip: Array[int] = []
	var i := first
	while i >= 0 and skip.size() < SIGHT_TRIES and game != null and game.world != null:
		if game.world.solid_hit(center, pos[i], 0.0) < 0.0:
			return i
		skip.append(i)
		i = nearest(center, max_dist, skip)
	return first


## Inimigo com mais vida no alcance (Hitodama mira nele, plano 4.5); com sight, o mais forte à vista, se houver.
func strongest(center: Vector2, max_dist: float, sight: bool = false) -> int:
	var best := -1
	var best_hp := -1.0
	var seen := -1
	var max_d2 := max_dist * max_dist
	for i: int in range(CAPACITY):
		if alive[i] == 0 or is_prop(i):
			continue
		if center.distance_squared_to(pos[i]) > max_d2:
			continue
		if hp[i] > best_hp:
			best_hp = hp[i]
			best = i
		if sight and (seen < 0 or hp[i] > hp[seen]) and game.world.solid_hit(center, pos[i], 0.0) < 0.0:
			seen = i
	return seen if seen >= 0 else best


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
	if sealed[i] == 1:
		return false
	if shield[i] > 0.0:
		var absorbed := minf(shield[i], amount)
		shield[i] -= absorbed
		amount -= absorbed
		flash[i] = 0.05
		if game != null and game.altars != null:
			game.altars.on_shield_hit(i, absorbed, shield[i] <= 0.0)
		if amount <= 0.0:
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
	var dying_burn := burn_dps[i] if burn_time[i] > 0.0 else 0.0
	var dying_frozen := frozen[i] > 0.0
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
	# Elite de altar ou campeão da emboscada: o AltarSystem cuida do saque (o baú comum não sai).
	if was_elite and game != null and game.altars != null:
		game.altars.on_enemy_killed(i, at)
	if type_ai[t] == AI.SPLITTER:
		var params: Dictionary = data.get("ai", {})
		for k: int in range(int(params.get("count", 2))):
			var offset := Vector2.from_angle(TAU * k / float(params.get("count", 2))) * 6.0
			spawn(StringName(params.get("split_into", "")), at + offset,
					game.enemy_hp_mult(), game.enemy_damage_mult())
	_dying_index.append(i)
	_dying_burn.append(dying_burn)
	_dying_frozen.append(1 if dying_frozen else 0)
	_dying_killer.append(hit_by)
	Events.enemy_killed.emit(at, xp_value[i], type_tint[t], type_ids[t], was_elite, type_ai[t])
	_dying_index.resize(_dying_index.size() - 1)
	_dying_burn.resize(_dying_burn.size() - 1)
	_dying_frozen.resize(_dying_frozen.size() - 1)
	_dying_killer.pop_back()


## Quem está morrendo agora (dentro do Events.enemy_killed): queimava (dps da Queimadura, 0 sem),
## estava congelado e a arma do golpe final. Fora de uma morte: 0, false e &"".
func dying_index() -> int:
	return _dying_index[_dying_index.size() - 1] if not _dying_index.is_empty() else -1


func dying_burn() -> float:
	return _dying_burn[_dying_burn.size() - 1] if not _dying_burn.is_empty() else 0.0


func dying_frozen() -> bool:
	return not _dying_frozen.is_empty() and _dying_frozen[_dying_frozen.size() - 1] == 1


func dying_killer() -> StringName:
	return _dying_killer.back() if not _dying_killer.is_empty() else &""


func _remove(i: int) -> void:
	if alive[i] == 0:
		return
	alive[i] = 0
	_free.append(i)
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


# --- Primitivas das habilidades dos guardiões -------------------------------------------
# Todas no passo fixo e sem sorteio: só leem posições e escrevem nos arrays. As de área
# consultam a grade (SpatialHash, refeita no começo do passo dos inimigos) e reaproveitam
# `_hits`, sem alocar por inimigo. Devolvem quantos inimigos foram afetados. Props (lanternas)
# nunca são afetados; chefes ignoram lentidão, raiz, medo, isca e puxão (o BossDirector os
# move) e sofrem só BOSS_STUN do atordoamento em área.


## Pode receber controle (lentidão, raiz, medo, isca, puxão): vivo, nem prop nem chefe.
func is_controllable(i: int) -> bool:
	return alive[i] == 1 and type_ai[kind[i]] != AI.PROP and type_ai[kind[i]] != AI.BOSS


## Inimigos comuns e elites vivos no círculo (sem props e chefes), em `_hits`.
func _controllable_in(center: Vector2, r: float) -> Array[int]:
	query_circle(center, r, _hits)
	var k := 0
	for j: int in _hits:
		if is_controllable(j):
			_hits[k] = j
			k += 1
	_hits.resize(k)
	return _hits


## Velocidade × (1 - `amount`) por `seconds` para quem está no círculo (vale a mais forte).
func slow_circle(center: Vector2, r: float, amount: float, seconds: float) -> int:
	var factor := clampf(1.0 - amount, 0.0, 1.0)
	var list := _controllable_in(center, r)
	for j: int in list:
		apply_slow(j, factor, seconds)
	return list.size()


## Lentidão num inimigo: fator de velocidade `factor` (0,6 = −40%) por `seconds`.
func apply_slow(i: int, factor: float, seconds: float) -> void:
	if not is_controllable(i):
		return
	slow_mult[i] = minf(slow_mult[i], factor) if slow[i] > 0.0 else factor
	slow[i] = maxf(slow[i], seconds)


## Prende no lugar por `seconds` os do círculo (até `max_count`, 0 = todos), na ordem da grade.
func root_circle(center: Vector2, r: float, seconds: float, max_count: int = 0) -> int:
	var count := 0
	for j: int in _controllable_in(center, r):
		if max_count > 0 and count >= max_count:
			break
		if root_one(j, seconds):
			count += 1
	return count


func root_one(i: int, seconds: float) -> bool:
	if not is_controllable(i):
		return false
	root[i] = maxf(root[i], seconds)
	vel[i] = Vector2.ZERO
	return true


## Medo: os do círculo fogem de `from` por `seconds` (FEAR_SPEED × a velocidade).
func fear_circle(center: Vector2, r: float, seconds: float, from: Vector2 = Vector2.INF) -> int:
	var source := center if from == Vector2.INF else from
	var list := _controllable_in(center, r)
	for j: int in list:
		fear[j] = maxf(fear[j], seconds)
		lure[j] = 0.0
		goal[j] = source
		state[j] = State.MOVE
	return list.size()


## Isca: os do círculo perseguem `at` (e não o herói) por `seconds`.
func lure_circle(center: Vector2, r: float, at: Vector2, seconds: float) -> int:
	var list := _controllable_in(center, r)
	for j: int in list:
		lure[j] = maxf(lure[j], seconds)
		fear[j] = 0.0
		goal[j] = at
		state[j] = State.MOVE
	return list.size()


## Puxa os do círculo até ficarem a `keep` px de `center`, arrastados em PULL_TIME s (como um
## atordoamento curto, com o amortecimento do atordoado). Elites e tanques resistem pela metade
## do knock_resist.
func pull_to(center: Vector2, r: float, keep: float = 12.0) -> int:
	var list := _controllable_in(center, r)
	# O atordoado faz vel × PULL_DAMPING e depois anda: o total é v × STEP × D / (1 − D).
	var gain := (1.0 - PULL_DAMPING) / (PULL_DAMPING * GameClock.STEP)
	for j: int in list:
		var d := center - pos[j]
		var dist := d.length()
		if dist <= keep + 0.5:
			continue
		var travel := (dist - keep) * (1.0 - resist[j] * 0.5)
		vel[j] = d / dist * travel * gain
		stun[j] = maxf(stun[j], PULL_TIME)
		state[j] = State.MOVE
	return list.size()


## Quem está dentro do círculo vai para a borda (a `r` + o próprio raio) e ganha velocidade
## para fora (`force`): barreiras que empurram (Muralha da Lanterna). Chefes não.
func push_out_of(center: Vector2, r: float, force: float) -> int:
	var count := 0
	for j: int in _controllable_in(center, r):
		var d := pos[j] - center
		var dist := d.length()
		var out := d / dist if dist > 0.001 else Vector2.from_angle(float(j))
		var edge := r + radius[j]
		if dist >= edge:
			continue
		pos[j] = center + out * edge
		vel[j] = out * force * (1.0 - resist[j] * 0.5)
		count += 1
	return count


## Atordoa os do círculo por `seconds` (chefes por `seconds` × `boss_factor`).
func stun_circle(center: Vector2, r: float, seconds: float, boss_factor: float = BOSS_STUN) -> int:
	query_circle(center, r, _hits)
	var count := 0
	for j: int in _hits:
		if is_prop(j):
			continue
		stun_one(j, seconds * (boss_factor if is_boss(j) else 1.0))
		count += 1
	return count


## Atordoa um inimigo (ou chefe, pelo tempo cheio) por `seconds`.
func stun_one(i: int, seconds: float) -> void:
	if alive[i] == 1 and not is_prop(i) and seconds > 0.0:
		stun[i] = maxf(stun[i], seconds)


# --- Fogo e gelo (.ai/06-fogo-gelo-clones.md) --------------------------------------------
# Tudo no passo fixo e sem sorteio. Os acertos das armas de fogo/gelo chegam por
# HyakkiGame.deal_damage (Weapon.element_hit / apply_status); os tiques da Queimadura saem daqui.


## Índice da fonte `id` em burn_sources (registra na 1ª vez).
func burn_source(id: StringName) -> int:
	var k := burn_sources.find(id)
	if k < 0:
		burn_sources.append(id)
		k = burn_sources.size() - 1
	return k


## Atributos da guardiã que mexem nos estados (1 = sem bônus): dano da Queimadura ("burn") e
## força do frio e duração do congelamento ("chill").
func burn_mult() -> float:
	return game.player.stats.get_stat("burn") if game and game.player else 1.0


func chill_mult() -> float:
	return game.player.stats.get_stat("chill") if game and game.player else 1.0


## Queima o inimigo `i`: `dps` (× atributo "burn") por `seconds`, creditado a `src`. Reaplicar fica
## com o maior dps (e a fonte dele) e o maior tempo restante, sem somar. Props e selados (anel da
## emboscada e Elite surgindo no Altar do Selo, intocáveis até soltar) não queimam.
func burn_one(i: int, dps: float, seconds: float, src: StringName) -> bool:
	if alive[i] == 0 or is_prop(i) or sealed[i] == 1 or dps <= 0.0 or seconds <= 0.0:
		return false
	var value := dps * burn_mult()
	if burn_time[i] <= 0.0:
		burn_tick[i] = BURN_TICK
		burn_dps[i] = value
		burn_src[i] = burn_source(src)
	elif value > burn_dps[i]:
		burn_dps[i] = value
		burn_src[i] = burn_source(src)
	burn_time[i] = maxf(burn_time[i], seconds)
	return true


## Queima quem toca o círculo (chefes também). Devolve quantos.
func burn_circle(center: Vector2, r: float, dps: float, seconds: float, src: StringName) -> int:
	query_circle(center, r, _hits)
	var count := 0
	for j: int in _hits:
		if burn_one(j, dps, seconds, src):
			count += 1
	return count


## Frio: soma `stacks` pilhas e deixa lento; com CHILL_STACKS_TO_FREEZE pilhas congela (devolve
## true). Pilhas novas só contam enquanto a lentidão do frio dura (senão recomeçam do zero).
## Congelado não soma pilhas. Chefes (as Sombras 影 do Kakuriyo também): lentidão × BOSS_STUN e no
## máximo uma pilha antes de congelar. Selados não sentem o frio.
func chill_one(i: int, stacks: int) -> bool:
	if alive[i] == 0 or is_prop(i) or sealed[i] == 1 or stacks <= 0:
		return false
	var power := chill_mult()
	var boss := is_boss(i)
	var amount := minf(CHILL_SLOW_MAX, CHILL_SLOW * power) * (BOSS_STUN if boss else 1.0)
	if slow[i] <= 0.0:
		chill[i] = 0
	var factor := 1.0 - amount
	slow_mult[i] = minf(slow_mult[i], factor) if slow[i] > 0.0 else factor
	slow[i] = maxf(slow[i], CHILL_SLOW_TIME)
	if frozen[i] > 0.0:
		return false
	chill[i] += stacks
	if boss:
		chill[i] = mini(chill[i], CHILL_STACKS_TO_FREEZE - 1)
		return false
	if chill[i] < CHILL_STACKS_TO_FREEZE:
		return false
	chill[i] = 0
	freeze_one(i, FREEZE_TIME * power)
	return true


## Congela (parado pelo stun, bloco de gelo no desenho) por `seconds`. Chefes, props e selados não.
func freeze_one(i: int, seconds: float) -> void:
	if alive[i] == 0 or is_prop(i) or is_boss(i) or sealed[i] == 1 or seconds <= 0.0:
		return
	frozen[i] = maxf(frozen[i], seconds)
	stun[i] = maxf(stun[i], seconds)
	vel[i] = Vector2.ZERO
	if game and game.fx and view_rect.has_point(pos[i]):
		game.fx.play_anim("ice", pos[i] - Vector2(0, radius[i]), clampf(radius[i] / 8.0, 0.6, 1.4), 0.0,
				Color(0.85, 0.95, 1.0, 0.9), 22.0)


## Choque Térmico: acerto de fogo (`fire`) num congelado ou de gelo num inimigo queimando consome
## o estado oposto e devolve o dano extra (THERMAL_SHOCK_MULT × `amount`); 0 na recarga ou sem o
## estado oposto.
func thermal_shock(i: int, amount: float, fire: bool) -> float:
	if alive[i] == 0 or shock_cd[i] > 0.0:
		return 0.0
	if fire:
		if frozen[i] <= 0.0:
			return 0.0
		stun[i] = maxf(0.0, stun[i] - frozen[i])
		frozen[i] = 0.0
		chill[i] = 0
	else:
		if burn_time[i] <= 0.0:
			return 0.0
		burn_time[i] = 0.0
		burn_dps[i] = 0.0
	shock_cd[i] = THERMAL_SHOCK_COOLDOWN
	if game:
		game.elements.steam(pos[i])
	return amount * THERMAL_SHOCK_MULT


## Tira Queimadura, frio e congelamento (pulso do Taikyoku). Devolve se tinha algum.
func consume_elements(i: int) -> bool:
	var had := burn_time[i] > 0.0 or frozen[i] > 0.0 or chill[i] > 0
	if frozen[i] > 0.0:
		stun[i] = maxf(0.0, stun[i] - frozen[i])
	burn_time[i] = 0.0
	burn_dps[i] = 0.0
	frozen[i] = 0.0
	chill[i] = 0
	return had


## Tem algum estado de fogo ou gelo (Queimadura, pilhas de frio ou congelado).
func has_element(i: int) -> bool:
	return burn_time[i] > 0.0 or frozen[i] > 0.0 or chill[i] > 0


## Gasta uma reação em cadeia do passo (false quando o teto do passo acabou).
func take_cascade() -> bool:
	if cascades_left <= 0:
		return false
	cascades_left -= 1
	return true


## Fator de velocidade da lentidão agora (1 sem): o BossDirector lê para o frio dos chefes.
func move_factor(i: int) -> float:
	return slow_mult[i] if slow[i] > 0.0 else 1.0


## Tiques da Queimadura, fim do congelamento e recarga do Choque Térmico de `i` (no passo).
func _step_status(i: int, dt: float) -> void:
	if shock_cd[i] > 0.0:
		shock_cd[i] -= dt
	if frozen[i] > 0.0:
		frozen[i] = maxf(0.0, frozen[i] - dt)
	if burn_time[i] <= 0.0:
		return
	burn_time[i] -= dt
	burn_tick[i] -= dt
	# Folga contra o erro de ponto flutuante: o último tique cai no mesmo passo em que acaba.
	if burn_tick[i] <= BURN_EPSILON:
		burn_tick[i] += BURN_TICK
		game.deal_damage(burn_sources[burn_src[i]], i, burn_dps[i] * BURN_TICK, Vector2.ZERO, 0.0, false,
				true, true)
	if alive[i] == 1 and burn_time[i] <= BURN_EPSILON:
		burn_time[i] = 0.0
		burn_dps[i] = 0.0


## Vivos (inclui chefes, sem props) que tocam o segmento a→b de meia-largura `width`.
func query_segment(a: Vector2, b: Vector2, width: float, out: Array[int]) -> void:
	var mid := (a + b) * 0.5
	spatial.query(mid, a.distance_to(b) * 0.5 + width + 30.0, _near)
	out.clear()
	for j: int in _near:
		if alive[j] == 1 and not is_prop(j) and Geometry.segment_hits_circle(a, b, pos[j], radius[j] + width):
			out.append(j)


## Vivos (inclui chefes, sem props) no leque de `center` para `dir`, abertura total
## 2 × `half_angle` rad e alcance `reach`. Quem encosta no herói (dentro do próprio raio) conta.
func query_cone(center: Vector2, dir: Vector2, half_angle: float, reach: float, out: Array[int]) -> void:
	spatial.query(center, reach + 30.0, _near)
	out.clear()
	var facing_dir := dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	var min_dot := cos(half_angle)
	for j: int in _near:
		if alive[j] == 0 or is_prop(j):
			continue
		var d := pos[j] - center
		var dist := d.length()
		if dist > reach + radius[j]:
			continue
		if dist <= radius[j] or facing_dir.dot(d / dist) >= min_dot:
			out.append(j)


## Inimigos vivos (sem props, com chefes) que tocam o círculo: decide o bot e mira as
## habilidades. Com `enough` > 0, para de contar ao chegar nele (a horda inteira não é percorrida).
func count_in_circle(center: Vector2, r: float, enough: int = 0) -> int:
	spatial.query(center, r + 30.0, _near)
	var count := 0
	var alive_l := alive
	var pos_l := pos
	var radius_l := radius
	for j: int in _near:
		if alive_l[j] == 1 and center.distance_to(pos_l[j]) <= r + radius_l[j] and not is_prop(j):
			count += 1
			if count == enough:
				break
	return count


## Centro do maior grupo: entre os inimigos até `reach` de `center` (no máximo `candidates`,
## os mais próximos da ordem da grade), o que tem mais vizinhos num raio `r`. Vector2.INF sem
## ninguém. Empate: o mais perto de `center`.
func densest_point(center: Vector2, reach: float, r: float, candidates: int = 48) -> Vector2:
	query_circle(center, reach, _hits)
	var pool: Array[int] = []
	for j: int in _hits:
		if not is_prop(j):
			pool.append(j)
			if pool.size() >= candidates:
				break
	var best := Vector2.INF
	var best_count := 0
	var best_d2 := INF
	var r2 := r * r
	for j: int in pool:
		var at := pos[j]
		var n := 0
		for k: int in pool:
			if at.distance_squared_to(pos[k]) <= r2:
				n += 1
		var d2 := center.distance_squared_to(at)
		if n > best_count or (n == best_count and d2 < best_d2):
			best = at
			best_count = n
			best_d2 = d2
	return best


func _steer(i: int, p: Vector2, spd: float, dt: float) -> Vector2:
	if fear[i] > 0.0:
		fear[i] -= dt
		var away := p - goal[i]
		return (away.normalized() if away.length_squared() > 0.01 else Vector2.from_angle(float(i))) \
				* spd * FEAR_SPEED
	lure[i] -= dt
	var to_goal := goal[i] - p
	return to_goal.normalized() * spd if to_goal.length_squared() > 4.0 else Vector2.ZERO


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
