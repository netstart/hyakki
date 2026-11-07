class_name KageBunshin
extends Weapon
## Kage Bunshin 影分身 / Mil Sombras 千影 e as uniões de clone, Casamento da Raposa 狐の嫁入り e
## Espelho de Gelo 氷鏡 (.ai/06-fogo-gelo-clones.md): clones de sombra (a silhueta da guardiã
## atual, escura e roxa com borda clara para ler na horda; Player.draw_silhouette, o mesmo
## desenho do clone da Sombra Dupla do Kenta) aparecem em volta dela com fumaça, correm até o
## inimigo mais próximo e cortam em meia-lua de raio "radius" a cada SLASH_EVERY s; somem com
## fumaça no fim de "duration". Teto de MAX_CLONES vivos somando todas as fontes (alive_total).
## Flags: "permanent" (o grupo se refaz a cada recarga: reaparece ~1 s depois se for desfeito),
## "clone_on_kill" (chance de um clone extra de EXTRA_CLONE_TIME s quando um clone mata),
## "fire_clone"/"ice_clone" (raposa de fogo-fátuo / gelo translúcido: a cada "burst_every" s cada
## clone se lança e explode em chamas ou estilhaça num leque de pingentes e renasce RESPAWN_TIME s
## depois) e "shatter" (inimigo morto congelado estilhaça).
## Clones não recebem dano, não disparam as outras armas e não vão para o save da partida suspensa
## (renascem no próximo disparo). Tudo no passo fixo; o desenho só lê.

## Estado de cada clone: correndo/cortando, lançando-se para explodir, ou fora (esperando renascer).
enum State { RUN, DASH, GONE }

const MAX_CLONES := 10
const SLASH_EVERY := 0.6
## Meia-lua: abertura total de 180° à frente do clone.
const SLASH_HALF_ANGLE := PI * 0.5
const CHASE_RANGE := 220.0
const RETARGET := 0.3
## Longe demais da guardiã (troca de mundo, teleporte): o clone reaparece ao lado dela.
const LEASH := 320.0
const SPAWN_RING := 18.0
const FOLLOW_GAP := 22.0
const RESPAWN_TIME := 1.0
const EXTRA_CLONE_TIME := 4.0
const DASH_TIME := 0.25
const DASH_SPEED := 3.0
const SHARD_SPEED := 200.0
const SHARD_LIFE := 0.9
## Defasagem (fração áurea) entre os relógios de corte e de estouro de cada clone.
const STAGGER := 0.618
## Cores do desenho: sombra (roxa), raposa de fogo (laranja) e gelo (azul translúcido).
const SHADOW_TINT := Color(0.24, 0.18, 0.42, 0.9)
const SHADOW_RIM := Color(0.78, 0.68, 1.0, 0.85)
const FIRE_TINT := Color(1.0, 0.5, 0.18, 0.85)
const FIRE_RIM := Color(1.0, 0.86, 0.5, 0.9)
const ICE_TINT := Color(0.55, 0.85, 1.0, 0.6)
const ICE_RIM := Color(0.9, 0.98, 1.0, 0.9)

## Fonte do dano (registro por arma, Choque Térmico): o próprio id, ou o item (Caco do Espelho).
var source_id: StringName
## Falso nos clones do Caco do Espelho: só summon() cria clones (sem recarga).
var auto_fire: bool = true
## Multiplicador do dano dos cortes (Caco do Espelho: cresce com o nível da guardiã).
var damage_scale: float = 1.0

var c_pos := PackedVector2Array()
var c_prev := PackedVector2Array()
var c_life := PackedFloat32Array()
var c_slash := PackedFloat32Array()
var c_burst := PackedFloat32Array()
var c_timer := PackedFloat32Array()
var c_retarget := PackedFloat32Array()
var c_target := PackedInt32Array()
var c_state := PackedInt32Array()
var c_perm := PackedByteArray()
var c_face := PackedFloat32Array()
## Só de desenho: quando nasceu e o último corte (tempo de jogo).
var c_born := PackedFloat32Array()
var c_cut := PackedFloat32Array()

var _near: Array[int] = []


func _init(p_game: HyakkiGame, p_id: StringName) -> void:
	super(p_game, p_id)
	source_id = p_id


func from_hand() -> bool:
	return false


func is_permanent() -> bool:
	return bool(flags.get("permanent", false))


## Clones vivos de todas as fontes (armas da guardiã e o Caco do Espelho): o teto MAX_CLONES.
static func alive_total(game: HyakkiGame) -> int:
	var total := 0
	for weapon: Weapon in game.weapons:
		if weapon is KageBunshin:
			total += (weapon as KageBunshin).c_pos.size()
	if game.elements != null and game.elements.item_clones != null:
		total += game.elements.item_clones.c_pos.size()
	return total


func clone_count() -> int:
	return c_pos.size()


func clone_radius() -> float:
	return raw("radius") * area()


func step(dt: float) -> void:
	if auto_fire:
		super(dt)
	_step_clones(dt)


## A cada recarga: clones novos (Kage Bunshin) ou o grupo completado (permanentes).
func fire(origin: Vector2) -> void:
	var made := 0
	if is_permanent():
		var have := 0
		for k: int in range(c_pos.size()):
			if c_perm[k] == 1:
				have += 1
		made = _spawn_many(origin, amount() - have, INF, true)
	else:
		made = _spawn_many(origin, amount(), duration(), false)
	if made > 0:
		WeaponSfx.launch(self)


## Caco do Espelho: `count` clones por `seconds` em volta da guardiã. Devolve quantos nasceram.
func summon(count: int, seconds: float) -> int:
	var made := _spawn_many(game.player.sim_pos, count, seconds, false)
	if made > 0:
		WeaponSfx.play(WeaponSfx.launch_cue(data))
	return made


func _spawn_many(origin: Vector2, count: int, life: float, perm: bool) -> int:
	var made := 0
	for k: int in range(maxi(0, count)):
		if alive_total(game) >= MAX_CLONES:
			break
		var a := TAU * k / float(maxi(1, count)) + game.rng.randf() * 0.6
		_add(origin + Vector2.from_angle(a) * SPAWN_RING, life, perm)
		made += 1
	return made


func _add(at: Vector2, life: float, perm: bool) -> void:
	c_pos.append(at)
	c_prev.append(at)
	c_life.append(life)
	# Cortes e estouros defasados por clone (STAGGER): o grupo inteiro estourando no mesmo passo
	# custava dezenas de ms na horda do estresse.
	var phase := fmod(c_pos.size() * STAGGER, 1.0)
	c_slash.append(SLASH_EVERY * (0.25 + 0.75 * phase))
	c_burst.append(float(flags.get("burst_every", 0.0)) * (1.0 + phase))
	c_timer.append(0.0)
	c_retarget.append(0.0)
	c_target.append(-1)
	c_state.append(State.RUN)
	c_perm.append(1 if perm else 0)
	c_face.append(game.player.facing_x if game.player.facing_x != 0.0 else 1.0)
	c_born.append(GameClock.game_time)
	c_cut.append(-10.0)
	_puff(at)


func _remove(k: int) -> void:
	for arr: StringName in [&"c_pos", &"c_prev", &"c_life", &"c_slash", &"c_burst", &"c_timer", &"c_retarget",
			&"c_target", &"c_state", &"c_perm", &"c_face", &"c_born", &"c_cut"]:
		var list: Variant = get(arr)
		list.remove_at(k)
		set(arr, list)


func _step_clones(dt: float) -> void:
	if c_pos.is_empty():
		return
	c_prev = c_pos.duplicate()
	var enemies := game.enemies
	var me := game.player.sim_pos
	var r := clone_radius()
	var spd := raw("speed")
	var burst_every := float(flags.get("burst_every", 0.0))
	for k: int in range(c_pos.size() - 1, -1, -1):
		if c_state[k] == State.GONE:
			c_timer[k] -= dt
			if c_timer[k] <= 0.0:
				c_state[k] = State.RUN
				c_burst[k] = burst_every
				c_pos[k] = me + Vector2.from_angle(TAU * k / 6.0) * SPAWN_RING
				c_prev[k] = c_pos[k]
				c_born[k] = GameClock.game_time
				_puff(c_pos[k])
			continue
		if c_state[k] == State.DASH:
			_step_dash(k, dt, spd)
			continue
		if c_perm[k] == 0:
			c_life[k] -= dt
			if c_life[k] <= 0.0:
				_puff(c_pos[k])
				_remove(k)
				continue
		var p: Vector2 = c_pos[k]
		if p.distance_to(me) > LEASH:
			p = me + Vector2.from_angle(TAU * k / 6.0) * SPAWN_RING
			c_prev[k] = p
			_puff(p)
		c_retarget[k] -= dt
		var t := c_target[k]
		if t < 0 or enemies.alive[t] == 0 or c_retarget[k] <= 0.0:
			c_retarget[k] = RETARGET
			t = enemies.nearest(p, CHASE_RANGE)
			c_target[k] = t
		c_slash[k] = maxf(0.0, c_slash[k] - dt)
		if t >= 0:
			var to := enemies.pos[t] - p
			var dist := to.length()
			var reach := r * 0.6 + enemies.radius[t]
			if dist > reach:
				p += to / dist * minf(spd * dt, dist - reach)
			if absf(to.x) > 0.5:
				c_face[k] = signf(to.x)
			if c_slash[k] <= 0.0 and dist <= r + enemies.radius[t]:
				c_slash[k] = SLASH_EVERY
				c_pos[k] = p
				_slash(k, to / maxf(dist, 0.001))
		else:
			var slot := me + Vector2.from_angle(k * 2.39996 + GameClock.game_time * 0.5) * FOLLOW_GAP
			var go := slot - p
			if go.length() > 1.0:
				p += go.normalized() * minf(spd * dt, go.length())
				if absf(go.x) > 0.5:
					c_face[k] = signf(go.x)
		c_pos[k] = p
		if burst_every > 0.0:
			c_burst[k] -= dt
			if c_burst[k] <= 0.0:
				c_state[k] = State.DASH
				c_timer[k] = DASH_TIME


## Lançamento antes de explodir (uniões): corre até o alvo e estoura; some por RESPAWN_TIME s.
func _step_dash(k: int, dt: float, spd: float) -> void:
	var t := c_target[k]
	var enemies := game.enemies
	if t >= 0 and enemies.alive[t] == 1:
		var to := enemies.pos[t] - c_pos[k]
		if to.length() > 2.0:
			c_pos[k] += to.normalized() * minf(spd * DASH_SPEED * dt, to.length())
	c_timer[k] -= dt
	if c_timer[k] > 0.0:
		return
	_burst(k)
	if c_perm[k] == 1:
		c_state[k] = State.GONE
		c_timer[k] = RESPAWN_TIME
	else:
		_remove(k)


## Corte em meia-lua à frente do clone (`dir`), raio clone_radius().
func _slash(k: int, dir: Vector2) -> void:
	var p := c_pos[k]
	var r := clone_radius()
	game.enemies.query_cone(p, dir, SLASH_HALF_ANGLE, r, _near)
	var dmg := damage() * damage_scale
	for j: int in _near.duplicate():
		game.deal_damage(source_id, j, dmg, dir, knockback())
	c_cut[k] = GameClock.game_time
	var fx := game.fx
	if fx != null:
		fx.play_anim("slash", p + dir * r * 0.4, clampf(r / 18.0, 0.8, 1.8), dir.angle(), Color(_rim_color(), 0.95),
				26.0, false, FxLayer.glow)


## Explosão (raposa de fogo) ou leque de pingentes (gelo) do clone `k`.
func _burst(k: int) -> void:
	var p := c_pos[k]
	var might := stats().get_stat("might") * game.damage_bonus()
	var fx := game.fx
	if bool(flags.get("fire_clone", false)):
		var r := float(flags.get("burst_radius", 40.0)) * area()
		game.areas.blast(source_id, p, r, float(flags.get("burst_damage", 60.0)) * might, knockback())
		fx.play_anim("explosion", p, minf(2.2, r / 20.0), 0.0, Color(1.0, 0.75, 0.45))
		fx.flash(p, r, Color(1.0, 0.55, 0.2, 0.8), 0.14)
		fx.embers(p, Color(1.0, 0.6, 0.25), [2, 6, 10][FxLayer.wfx], r * 0.3)
		WeaponSfx.play("hachiman_blast", 1.15)
	elif bool(flags.get("ice_clone", false)):
		var shards := int(flags.get("burst_shards", 8))
		var dmg := float(flags.get("shard_damage", 20.0)) * might
		for s: int in range(shards):
			var dir := Vector2.from_angle(TAU * s / float(shards) + k * 0.4)
			game.projectiles.spawn(source_id, "icicle", p, dir * SHARD_SPEED, dmg, 3.0, 0, SHARD_LIFE, 20.0)
		fx.play_anim("ice", p, 1.2, 0.0, Color(0.85, 0.97, 1.0), 24.0, false, true)
		fx.flash(p, 20.0, Color(0.7, 0.9, 1.0, 0.7), 0.1)
		WeaponSfx.play("shatter")
	else:
		_puff(p)


## Abate: clone extra (Mil Sombras, só abate de clone) e Estilhaçar (uniões de gelo).
func on_kill(at: Vector2, _j: int) -> void:
	var chance := float(flags.get("clone_on_kill", 0.0))
	if chance > 0.0 and game.enemies.dying_killer() == source_id and game.rng.randf() < chance:
		_spawn_many(at, 1, EXTRA_CLONE_TIME, false)
	if bool(flags.get("shatter", false)) and game.enemies.dying_frozen():
		game.elements.shatter(at, source_id, EnemyManager.SHATTER_DAMAGE * stats().get_stat("might"))


func on_removed() -> void:
	for k: int in range(c_pos.size()):
		if c_state[k] != State.GONE:
			_puff(c_pos[k])
	for arr: StringName in [&"c_pos", &"c_prev", &"c_life", &"c_slash", &"c_burst", &"c_timer", &"c_retarget",
			&"c_target", &"c_state", &"c_perm", &"c_face", &"c_born", &"c_cut"]:
		var list: Variant = get(arr)
		list.clear()
		set(arr, list)
	super()


## Fumaça de entrada/saída do clone (só desenho).
func _puff(at: Vector2) -> void:
	var fx := game.fx
	if fx == null:
		return
	fx.play_anim("smoke", at - Vector2(0, 6), 0.7, 0.0, Color(_rim_color().lerp(Color.WHITE, 0.5), 0.85), 20.0)
	if FxLayer.wfx > 0:
		fx.dust(at, 4.0, Color(_body_color(), 0.7), 2 * FxLayer.wfx, 30.0)


func _body_color() -> Color:
	if bool(flags.get("fire_clone", false)):
		return FIRE_TINT
	if bool(flags.get("ice_clone", false)):
		return ICE_TINT
	return SHADOW_TINT


func _rim_color() -> Color:
	if bool(flags.get("fire_clone", false)):
		return FIRE_RIM
	if bool(flags.get("ice_clone", false)):
		return ICE_RIM
	return SHADOW_RIM


## Clones: sombra no chão, silhueta da guardiã com borda clara, rabos de raposa (fogo) ou brilho
## que corre (gelo). Entram e saem esmaecendo; o corte puxa o corpo 1 px para a frente.
func draw(canvas: CanvasItem) -> void:
	if c_pos.is_empty():
		return
	var a := GameClock.alpha
	var time := GameClock.game_time
	var player := game.player
	var fire := bool(flags.get("fire_clone", false))
	var ice := bool(flags.get("ice_clone", false))
	for k: int in range(c_pos.size()):
		if c_state[k] == State.GONE:
			continue
		var at := c_prev[k].lerp(c_pos[k], a).round()
		var fade := clampf((time - c_born[k]) / 0.15, 0.0, 1.0)
		if c_perm[k] == 0:
			fade *= clampf(c_life[k] / 0.3, 0.0, 1.0)
		var moving := c_prev[k].distance_squared_to(c_pos[k]) > 0.01
		if time - c_cut[k] < 0.12:
			at.x += c_face[k]
		canvas.draw_rect(Rect2(at + Vector2(-4, 2), Vector2(8, 2)), Color(0.0, 0.0, 0.0, 0.3 * fade))
		if fire:
			_draw_tails(canvas, at, k, time, fade)
		var body := _body_color()
		var rim := _rim_color()
		player.draw_silhouette(canvas, at, Color(body, body.a * fade), Color(rim, rim.a * fade), c_face[k] < 0.0,
				int(time * 8.0 + k) if moving else -1)
		if ice:
			var glint := fmod(time * 1.3 + k * 0.29, 1.0)
			canvas.draw_rect(Rect2(at + Vector2(-3.0 + roundf(glint * 6.0), -11.0 + roundf(glint * 8.0)), Vector2(1, 1)),
					Color(1, 1, 1, 0.9 * fade))


## Três rabos de raposa de luz atrás do clone de fogo, ondulando (Stroke, sem polígono do motor).
func _draw_tails(canvas: CanvasItem, at: Vector2, k: int, time: float, fade: float) -> void:
	var back := -c_face[k]
	for tail: int in range(3):
		var points := PackedVector2Array()
		for s: int in range(5):
			var u := s / 4.0
			var sway := sin(time * 6.0 + tail * 1.7 + k + u * 3.0) * 2.0 * u
			points.append(at + Vector2(back * (2.0 + u * 7.0), -4.0 - tail * 2.0 + sway - u * 3.0 * (tail - 1)))
		Stroke.line(canvas, points, Color(FIRE_RIM, 0.75 * fade), 1.0)


func draw_glow(canvas: CanvasItem) -> void:
	if c_pos.is_empty() or not (bool(flags.get("fire_clone", false)) or bool(flags.get("ice_clone", false))):
		return
	var a := GameClock.alpha
	for k: int in range(c_pos.size()):
		if c_state[k] != State.GONE:
			FxLayer.draw_soft(canvas, c_prev[k].lerp(c_pos[k], a) - Vector2(0, 6), 11.0, Color(_rim_color(), 0.4))
