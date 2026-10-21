class_name AreaEffects
extends Node2D
## Efeitos de área, aliados e hostis (plano 4.5, 6.3 e 5.3):
## - aliados: poças (Bomba de Fumaça, Névoa Venenosa), onda de choque (Taiko), furacão
##   (Furacão de Fūjin), tufão (Fūjin-Raijin), explosões e raios instantâneos;
## - hostis: aviso no chão seguido de dano (todo ataque de chefe é avisado ≥ 0,7 s,
##   plano 15.2), poças lentas, feixe giratório e lava.
## São poucos ao mesmo tempo (dezenas), então cada um é um Dictionary.

enum Kind { POOL, RING, HURRICANE, TYPHOON, TELEGRAPH, BEAM, HAZARD_POOL, LAVA }

const SMOKE_FRAMES := 6
const RING_THICKNESS := 10.0

var game: HyakkiGame
var effects: Array[Dictionary] = []

var _near: Array[int] = []
var _smoke: SpriteSheet
var _thunder: SpriteSheet


func _ready() -> void:
	_smoke = SpriteSheet.load_sheet("res://assets/art/fx/smoke/SpriteSheet.png", "strip", Vector2(32, 32))
	_thunder = SpriteSheet.load_sheet("res://assets/art/fx/thunder/SpriteSheet.png", "strip", Vector2(16, 28))


func reset() -> void:
	effects.clear()


func count() -> int:
	return effects.size()


# --- Criação ------------------------------------------------------------------

func pool(weapon: StringName, at: Vector2, r: float, damage: float, tick: float, life: float,
		grow: float = 1.0, follow: float = 0.0, tint: Color = Color(0.75, 0.85, 0.7, 0.8)) -> void:
	effects.append({"kind": Kind.POOL, "weapon": weapon, "pos": at, "radius": r, "base_radius": r,
			"damage": damage, "tick": tick, "tick_left": 0.0, "life": life, "max_life": life,
			"grow": grow, "follow": follow, "tint": tint})


func ring(weapon: StringName, at: Vector2, max_radius: float, damage: float, duration: float,
		knockback: float, stun: float = 0.0, delay: float = 0.0) -> void:
	effects.append({"kind": Kind.RING, "weapon": weapon, "pos": at, "radius": 0.0,
			"max_radius": max_radius, "damage": damage, "life": duration + delay,
			"max_life": duration, "delay": delay, "knockback": knockback, "stun": stun, "hit": {}})


func hurricane(weapon: StringName, at: Vector2, r: float, damage: float, tick: float, life: float,
		wander_speed: float, pull: float, lightning: bool = false) -> void:
	var dir := Vector2.from_angle(game.rng.randf() * TAU)
	effects.append({"kind": Kind.TYPHOON if lightning else Kind.HURRICANE, "weapon": weapon,
			"pos": at, "vel": dir * wander_speed, "radius": r, "damage": damage, "tick": tick,
			"tick_left": 0.0, "life": life, "max_life": life, "pull": pull, "spin": 0.0})


## Aviso no chão; ao terminar, causa dano à guardiã se ela estiver dentro.
func telegraph(at: Vector2, r: float, windup: float, damage: float, on_hit: Callable = Callable(),
		tint: Color = Color(1.0, 0.25, 0.25), source: StringName = DamageControl.UNKNOWN) -> void:
	effects.append({"kind": Kind.TELEGRAPH, "pos": at, "radius": r, "life": windup,
			"max_life": windup, "damage": damage, "on_hit": on_hit, "tint": tint, "source": source})


func hazard_pool(at: Vector2, r: float, damage: float, life: float, slow_factor: float,
		windup: float = 0.8, source: StringName = DamageControl.UNKNOWN) -> void:
	effects.append({"kind": Kind.HAZARD_POOL, "pos": at, "radius": r, "damage": damage,
			"life": life + windup, "max_life": life, "windup": windup, "slow": slow_factor,
			"tick_left": 0.0, "source": source})


## Feixe que gira a partir de `at`, começando em `angle` e varrendo `sweep` radianos.
func beam(at: Vector2, angle: float, sweep: float, length: float, width: float, windup: float,
		duration: float, damage: float, source: StringName = DamageControl.UNKNOWN) -> void:
	effects.append({"kind": Kind.BEAM, "pos": at, "angle": angle, "sweep": sweep, "length": length,
			"width": width, "windup": windup, "life": windup + duration, "max_life": duration,
			"damage": damage, "tick_left": 0.0, "source": source})


func lava(at: Vector2, r: float, damage: float) -> void:
	effects.append({"kind": Kind.LAVA, "pos": at, "radius": r, "damage": damage, "life": INF,
			"tick_left": 0.0, "phase": game.rng.randf() * TAU, "source": &"lava"})


## Dano instantâneo em círculo (explosões, sino, golpe da lanterna).
func blast(weapon: StringName, at: Vector2, r: float, damage: float, knockback: float,
		stun: float = 0.0) -> int:
	game.enemies.query_circle(at, r, _near)
	var hits := 0
	for j: int in _near.duplicate():
		var away := (game.enemies.pos[j] - at).normalized()
		game.deal_damage(weapon, j, damage, away, knockback)
		if stun > 0.0 and game.enemies.alive[j] == 1:
			game.enemies.stun[j] = maxf(game.enemies.stun[j], stun)
		hits += 1
	return hits


## Raio instantâneo num inimigo (Raio de Raijin). Pode encadear para vizinhos.
func lightning(weapon: StringName, enemy: int, damage: float, r: float, chain: int = 0,
		chain_range: float = 70.0) -> void:
	var already: Array[int] = []
	var current := enemy
	for _link: int in range(chain + 1):
		if current < 0 or game.enemies.alive[current] == 0:
			break
		already.append(current)
		var at := game.enemies.pos[current]
		game.fx.play_anim("thunder", at - Vector2(0, 10), 1.0 + r / 30.0)
		blast(weapon, at, r, damage, 30.0)
		current = game.enemies.nearest(at, chain_range, already)
	AudioManager.play("magic2", 1.3, 0.1, -4.0)


# --- Passo --------------------------------------------------------------------

func step(dt: float) -> void:
	var player := game.player
	for i: int in range(effects.size() - 1, -1, -1):
		var e := effects[i]
		e["life"] = float(e["life"]) - dt
		match int(e["kind"]):
			Kind.POOL:
				_step_pool(e, dt)
			Kind.RING:
				_step_ring(e, dt)
			Kind.HURRICANE, Kind.TYPHOON:
				_step_hurricane(e, dt)
			Kind.TELEGRAPH:
				if float(e["life"]) <= 0.0:
					if player.sim_pos.distance_to(e["pos"]) <= float(e["radius"]) + Player.RADIUS:
						player.take_damage(float(e["damage"]), e["source"])
					var cb: Callable = e["on_hit"]
					if cb.is_valid():
						cb.call(e["pos"])
					game.fx.play_anim("rock_spike" if float(e["radius"]) < 30.0 else "explosion",
							e["pos"], float(e["radius"]) / 22.0)
					game.shake(2.0)
			Kind.HAZARD_POOL:
				if float(e["life"]) < float(e["max_life"]):
					e["tick_left"] = float(e["tick_left"]) - dt
					if player.sim_pos.distance_to(e["pos"]) <= float(e["radius"]):
						player.slow_time = maxf(player.slow_time, 0.2)
						player.slow_factor = float(e["slow"])
						if float(e["tick_left"]) <= 0.0:
							e["tick_left"] = 0.5
							player.take_damage(float(e["damage"]), e["source"])
			Kind.BEAM:
				_step_beam(e, dt)
			Kind.LAVA:
				e["tick_left"] = float(e["tick_left"]) - dt
				if float(e["tick_left"]) <= 0.0 and player.sim_pos.distance_to(e["pos"]) <= float(e["radius"]):
					e["tick_left"] = 0.6
					player.take_damage(float(e["damage"]), e["source"])
		if float(e["life"]) <= 0.0:
			effects.remove_at(i)


func _step_pool(e: Dictionary, dt: float) -> void:
	var t := 1.0 - float(e["life"]) / maxf(float(e["max_life"]), 0.001)
	e["radius"] = float(e["base_radius"]) * lerpf(1.0, float(e["grow"]), t)
	if float(e["follow"]) > 0.0:
		var to := game.player.sim_pos - (e["pos"] as Vector2)
		if to.length() > 4.0:
			e["pos"] = (e["pos"] as Vector2) + to.normalized() * float(e["follow"]) * dt
	e["tick_left"] = float(e["tick_left"]) - dt
	if float(e["tick_left"]) > 0.0:
		return
	e["tick_left"] = float(e["tick"])
	blast(e["weapon"], e["pos"], float(e["radius"]), float(e["damage"]), 5.0)


func _step_ring(e: Dictionary, dt: float) -> void:
	if float(e["delay"]) > 0.0:
		e["delay"] = float(e["delay"]) - dt
		return
	var duration := maxf(float(e["max_life"]), 0.001)
	var t := clampf(1.0 - float(e["life"]) / duration, 0.0, 1.0)
	var r := float(e["max_radius"]) * t
	e["radius"] = r
	var at: Vector2 = e["pos"]
	var hit: Dictionary = e["hit"]
	game.enemies.query_circle(at, r, _near)
	for j: int in _near.duplicate():
		if hit.has(j):
			continue
		var d := at.distance_to(game.enemies.pos[j])
		if d < r - RING_THICKNESS - game.enemies.radius[j]:
			continue
		hit[j] = true
		var away := (game.enemies.pos[j] - at).normalized()
		game.deal_damage(e["weapon"], j, float(e["damage"]), away, float(e["knockback"]))
		if float(e["stun"]) > 0.0 and game.enemies.alive[j] == 1:
			game.enemies.stun[j] = maxf(game.enemies.stun[j], float(e["stun"]))


func _step_hurricane(e: Dictionary, dt: float) -> void:
	var at: Vector2 = e["pos"]
	var v: Vector2 = e["vel"]
	# Passeia, mas sem se afastar demais da guardiã.
	var to_player := game.player.sim_pos - at
	if to_player.length() > 140.0:
		v = v.lerp(to_player.normalized() * v.length(), 0.05)
	elif game.rng.randf() < 0.02:
		v = v.rotated(game.rng.randf_range(-1.2, 1.2))
	e["vel"] = v
	at += v * dt
	e["pos"] = at
	e["spin"] = float(e["spin"]) + dt * 8.0
	var r := float(e["radius"])
	var pull := float(e["pull"])
	# Suga inimigos e brasas para o centro.
	game.enemies.query_circle(at, r * 1.6, _near)
	for j: int in _near:
		if game.enemies.is_boss(j) or game.enemies.is_prop(j):
			continue
		var d := at - game.enemies.pos[j]
		if d.length() > 2.0:
			game.enemies.vel[j] = game.enemies.vel[j].lerp(d.normalized() * pull, 0.15)
	game.pickups.pull_gems(at, r * 1.8, pull * 1.5, dt)
	e["tick_left"] = float(e["tick_left"]) - dt
	if float(e["tick_left"]) <= 0.0:
		e["tick_left"] = float(e["tick"])
		blast(e["weapon"], at, r, float(e["damage"]), 0.0)
		if int(e["kind"]) == Kind.TYPHOON:
			var j := game.enemies.random_alive(at, r * 1.5)
			if j >= 0:
				lightning(e["weapon"], j, float(e["damage"]) * 1.5, 14.0)


func _step_beam(e: Dictionary, dt: float) -> void:
	if float(e["life"]) > float(e["max_life"]):
		return
	var progress := 1.0 - float(e["life"]) / maxf(float(e["max_life"]), 0.001)
	var angle := float(e["angle"]) + float(e["sweep"]) * progress
	e["current"] = angle
	e["tick_left"] = float(e["tick_left"]) - dt
	var start: Vector2 = e["pos"]
	var finish := start + Vector2.from_angle(angle) * float(e["length"])
	var player := game.player
	if float(e["tick_left"]) <= 0.0 and Geometry.segment_hits_circle(start, finish, player.sim_pos,
			float(e["width"]) * 0.5 + Player.RADIUS):
		e["tick_left"] = 0.4
		player.take_damage(float(e["damage"]), e["source"])


# --- Desenho ------------------------------------------------------------------

func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var time := GameClock.game_time
	for e: Dictionary in effects:
		var at: Vector2 = (e["pos"] as Vector2).round()
		match int(e["kind"]):
			Kind.POOL:
				var r := float(e["radius"])
				var tint: Color = e["tint"]
				draw_circle(at, r, Color(tint.r, tint.g, tint.b, 0.22))
				var frame := int(time * 8.0) % SMOKE_FRAMES
				var src := _smoke.region(frame, 0)
				var s := r / 14.0
				draw_set_transform(at, 0.0, Vector2(s, s * 0.7))
				draw_texture_rect_region(_smoke.texture, Rect2(-src.size * 0.5, src.size), src, tint)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			Kind.RING:
				if float(e["delay"]) <= 0.0:
					var t := clampf(1.0 - float(e["life"]) / maxf(float(e["max_life"]), 0.001), 0.0, 1.0)
					draw_arc(at, float(e["radius"]), 0.0, TAU, 48, Color(1.0, 0.85, 0.5, 1.0 - t), 3.0)
					draw_arc(at, maxf(0.0, float(e["radius"]) - 5.0), 0.0, TAU, 48, Color(1.0, 1.0, 0.8, (1.0 - t) * 0.5), 1.0)
			Kind.HURRICANE, Kind.TYPHOON:
				var r := float(e["radius"])
				var spin := float(e["spin"])
				var color := Color(0.8, 0.95, 1.0, 0.55) if int(e["kind"]) == Kind.HURRICANE else Color(0.7, 0.85, 1.0, 0.7)
				for k: int in range(3):
					var start := spin + k * TAU / 3.0
					draw_arc(at, r * (0.4 + 0.25 * k), start, start + 2.2, 16, color, 2.0)
				if int(e["kind"]) == Kind.TYPHOON:
					draw_arc(at, r, spin * 1.5, spin * 1.5 + 1.0, 8, Color(1.0, 1.0, 0.5, 0.8), 1.0)
			Kind.TELEGRAPH:
				var t := 1.0 - clampf(float(e["life"]) / maxf(float(e["max_life"]), 0.001), 0.0, 1.0)
				var tint: Color = e["tint"]
				draw_circle(at, float(e["radius"]), Color(tint.r, tint.g, tint.b, 0.12 + 0.25 * t))
				draw_arc(at, float(e["radius"]), 0.0, TAU, 32, Color(tint.r, tint.g, tint.b, 0.8), 1.0)
				draw_circle(at, float(e["radius"]) * t, Color(tint.r, tint.g, tint.b, 0.18))
			Kind.HAZARD_POOL:
				var windup := float(e["life"]) > float(e["max_life"])
				draw_circle(at, float(e["radius"]), Color(0.35, 0.6, 1.0, 0.18 if windup else 0.38))
				draw_arc(at, float(e["radius"]), 0.0, TAU, 32, Color(0.5, 0.75, 1.0, 0.7), 1.0)
			Kind.BEAM:
				var active := float(e["life"]) <= float(e["max_life"])
				var angle := float(e.get("current", e["angle"]))
				var finish := at + Vector2.from_angle(angle) * float(e["length"])
				if active:
					draw_line(at, finish, Color(1.0, 0.4, 0.3, 0.9), float(e["width"]))
					draw_line(at, finish, Color(1.0, 0.95, 0.8, 1.0), float(e["width"]) * 0.35)
				else:
					var sweep_end := at + Vector2.from_angle(float(e["angle"]) + float(e["sweep"])) * float(e["length"])
					draw_line(at, finish, Color(1.0, 0.25, 0.25, 0.5), 1.0)
					draw_line(at, sweep_end, Color(1.0, 0.25, 0.25, 0.3), 1.0)
			Kind.LAVA:
				var pulse := 0.5 + 0.5 * sin(time * 2.0 + float(e["phase"]))
				draw_circle(at, float(e["radius"]), Color(1.0, 0.35, 0.1, 0.35 + 0.15 * pulse))
				draw_circle(at, float(e["radius"]) * 0.6, Color(1.0, 0.7, 0.2, 0.35 + 0.2 * pulse))
