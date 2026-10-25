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
## Raios do céu (Raijin): 8 variantes de 32x256, branco sobre preto, desenhadas em modo aditivo.
const BOLT_TEXTURE := "res://assets/art/fx/lightning/lightning.png"
const BOLT_VARIANTS := 8
const BOLT_SIZE := Vector2(32, 256)
const BOLT_LIFE := 0.2
## Altura de onde o raio cai, acima do alvo.
const BOLT_FALL := 180.0
const BOLT_WIDTH := 20.0
const CHAIN_WIDTH := 12.0
## Teto de raios desenhados ao mesmo tempo (o mais velho sai primeiro).
const MAX_BOLTS := 24
const BOLT_COLOR := Color(0.6, 0.85, 1.0)

var game: HyakkiGame
var effects: Array[Dictionary] = []
## Raios só de desenho: {"from", "to", "variant", "width", "life"}.
var bolts: Array[Dictionary] = []

var _near: Array[int] = []
var _smoke: SpriteSheet
var _thunder: SpriteSheet
var _bolt_texture: Texture2D
## Camada aditiva acima dos inimigos: o preto do PNG não aparece.
var _bolt_layer: Node2D
## Variante do raio: fora da simulação, não mexe no determinismo.
var _look := RandomNumberGenerator.new()


func _ready() -> void:
	_smoke = SpriteSheet.load_sheet("res://assets/art/fx/smoke/SpriteSheet.png", "strip", Vector2(32, 32))
	_thunder = SpriteSheet.load_sheet("res://assets/art/fx/thunder/SpriteSheet.png", "strip", Vector2(16, 28))
	_bolt_texture = load(BOLT_TEXTURE) as Texture2D
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_bolt_layer = Node2D.new()
	_bolt_layer.material = additive
	_bolt_layer.z_index = 13
	_bolt_layer.draw.connect(_draw_bolts)
	add_child(_bolt_layer)


func reset() -> void:
	effects.clear()
	bolts.clear()


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
## Com `source` (a mão do herói), um raio também sai dela até o primeiro alvo. Só desenho.
func lightning(weapon: StringName, enemy: int, damage: float, r: float, chain: int = 0,
		chain_range: float = 70.0, source: Vector2 = Vector2.INF, tint: Color = BOLT_COLOR) -> void:
	var already: Array[int] = []
	var current := enemy
	var previous := Vector2.INF
	for _link: int in range(chain + 1):
		if current < 0 or game.enemies.alive[current] == 0:
			break
		already.append(current)
		var at := game.enemies.pos[current]
		# Raio do céu no alvo e, na corrente, o mesmo raio esticado desde o elo anterior.
		add_bolt(at - Vector2(0, BOLT_FALL), at, BOLT_WIDTH, tint)
		if previous != Vector2.INF:
			add_bolt(previous, at, CHAIN_WIDTH, tint)
			WeaponSfx.play("chain_link", 1.0 + 0.06 * already.size())
		elif source != Vector2.INF:
			add_bolt(source, at, CHAIN_WIDTH, tint)
		previous = at
		_strike_fx(at, r, tint)
		blast(weapon, at, r, damage, 30.0)
		current = game.enemies.nearest(at, chain_range, already)


## Impacto do raio no chão: animação, clarão, faíscas e queimado (só desenho).
func _strike_fx(at: Vector2, r: float, tint: Color) -> void:
	var fx := game.fx
	fx.play_anim("thunder", at - Vector2(0, 10), 1.0 + r / 30.0, 0.0, tint.lerp(Color.WHITE, 0.5), 16.0, false, true)
	fx.flash(at, 12.0 + r, Color(tint, 0.85), 0.12)
	fx.sparks(at, Vector2(0, -1), tint.lerp(Color.WHITE, 0.6), [1, 4, 7][FxLayer.wfx], 120.0, 1.4, 0.18)
	if FxLayer.wfx > 0:
		fx.add_ring(at, r + 6.0, Color(tint, 0.7), 0.22, 1.0)


## Raio só de desenho de `from` até `to`, com uma das 8 variantes ao acaso.
func add_bolt(from: Vector2, to: Vector2, width: float = BOLT_WIDTH, tint: Color = BOLT_COLOR) -> void:
	if bolts.size() >= MAX_BOLTS:
		bolts.pop_front()
	bolts.append({"from": from, "to": to, "variant": _look.randi_range(0, BOLT_VARIANTS - 1),
			"width": width, "life": BOLT_LIFE, "tint": tint})


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
	for i: int in range(bolts.size() - 1, -1, -1):
		bolts[i]["life"] = float(bolts[i]["life"]) - dt
		if float(bolts[i]["life"]) <= 0.0:
			bolts.remove_at(i)


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
				lightning(e["weapon"], j, float(e["damage"]) * 1.5, 14.0, 0, 70.0, Vector2.INF, Color(0.66, 0.78, 1.0))
				WeaponSfx.play("raijin", 0.9)


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
	_bolt_layer.queue_redraw()


## Raios em modo aditivo: o eixo vertical da textura vai de `from` a `to` e o alfa some no fim.
## Com "reduzir clarões", o raio fica mais fraco e sem o brilho no chão.
func _draw_bolts() -> void:
	if bolts.is_empty() or _bolt_texture == null:
		return
	var calm := bool(Settings.get_value("reduce_flashes"))
	for b: Dictionary in bolts:
		var from: Vector2 = (b["from"] as Vector2).round()
		var to: Vector2 = (b["to"] as Vector2).round()
		var span := to - from
		if span.length() < 1.0:
			continue
		var a := clampf(float(b["life"]) / BOLT_LIFE, 0.0, 1.0) * (0.55 if calm else 1.0)
		var tint: Color = b.get("tint", BOLT_COLOR)
		var src := Rect2(Vector2(int(b["variant"]) * BOLT_SIZE.x, 0.0), BOLT_SIZE)
		var s := Vector2(float(b["width"]) / BOLT_SIZE.x, span.length() / BOLT_SIZE.y)
		_bolt_layer.draw_set_transform(from, span.angle() - PI * 0.5, s)
		_bolt_layer.draw_texture_rect_region(_bolt_texture, Rect2(Vector2(-BOLT_SIZE.x * 0.5, 0.0), BOLT_SIZE),
				src, Color(tint.r, tint.g, tint.b, a))
		_bolt_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not calm:
			if FxLayer.glow:
				FxLayer.draw_soft(_bolt_layer, to, 18.0, Color(tint, 0.6 * a))
			else:
				_bolt_layer.draw_circle(to, 8.0, Color(tint.r, tint.g, tint.b, 0.35 * a))


func _draw() -> void:
	var time := GameClock.game_time
	for e: Dictionary in effects:
		var at: Vector2 = (e["pos"] as Vector2).round()
		match int(e["kind"]):
			Kind.POOL:
				_draw_pool(e, at, time)
			Kind.RING:
				if float(e["delay"]) <= 0.0:
					_draw_ring(e, at)
			Kind.HURRICANE, Kind.TYPHOON:
				_draw_storm(e, at, time)
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


## Poça de fumaça (Bomba de Fumaça) ou névoa venenosa: base translúcida, borda pontilhada que
## gira e vários tufos do pacote espalhados pela área (sempre em tamanho próximo do original,
## sem ampliar um tufo só), mais tufos na Alta. A névoa venenosa solta bolhas (Média/Alta).
## O chão eletrificado do Takemikazuchi não é fumaça: faíscas e arcos curtos piscando.
func _draw_pool(e: Dictionary, at: Vector2, time: float) -> void:
	var r := float(e["radius"])
	var tint: Color = e["tint"]
	var fade := clampf(float(e["life"]) / 0.4, 0.0, 1.0)
	draw_circle(at, r, Color(tint.r, tint.g, tint.b, 0.14 * fade))
	draw_circle(at, r * 0.55, Color(tint.r, tint.g, tint.b, 0.08 * fade))
	var dots := clampi(int(r * 0.5), 8, 28)
	for k: int in range(dots):
		var a := TAU * k / float(dots) + time * 0.6
		draw_rect(Rect2((at + Vector2.from_angle(a) * r).round(), Vector2.ONE), Color(tint, 0.55 * fade))
	if game.fx and String(game.fx.style(e["weapon"])["impact"]) == "hit_thunder":
		_draw_field(at, r, tint, fade)
		return
	var puffs := clampi(int(r * r / 260.0), 2, 12) * (2 + FxLayer.wfx) / 4
	var size := clampf(r / 24.0, 0.7, 1.3)
	for k: int in range(maxi(puffs, 2)):
		var u := fmod(k * 0.618, 1.0)
		var a := k * 2.39996 + time * (0.25 + 0.1 * (k % 3))
		var off := Vector2(cos(a), sin(a) * 0.7) * r * sqrt(u) * 0.75
		var frame := int(time * 7.0 + k * 1.7) % SMOKE_FRAMES
		var src := _smoke.region(frame, 0)
		draw_set_transform((at + off).round(), 0.0, Vector2(size, size * 0.8))
		draw_texture_rect_region(_smoke.texture, Rect2(-src.size * 0.5, src.size), src,
				Color(tint, tint.a * fade * (0.9 - 0.3 * u)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var poison := tint.g > tint.r + 0.2
	if poison and FxLayer.wfx > 0 and _look.randf() < 0.15 * FxLayer.wfx:
		var p := at + Vector2.from_angle(_look.randf() * TAU) * r * _look.randf()
		game.fx.embers(p, Color(0.7, 1.0, 0.45), 1, 1.0)


## Chão eletrificado: arcos quebrados curtos que piscam em pontos sorteados (só desenho).
func _draw_field(at: Vector2, r: float, tint: Color, fade: float) -> void:
	for _k: int in range(1 + FxLayer.wfx):
		var from := at + Vector2.from_angle(_look.randf() * TAU) * r * _look.randf() * 0.9
		var line := PackedVector2Array([from.round()])
		var p := from
		for _s: int in range(3):
			p += Vector2.from_angle(_look.randf() * TAU) * _look.randf_range(3.0, 7.0)
			line.append(p.round())
		draw_polyline(line, Color(tint.lerp(Color.WHITE, 0.5), 0.9 * fade), 1.0)


## Onda do Taiko: frente grossa na cor da arma, borda clara por dentro e rastro de pó.
func _draw_ring(e: Dictionary, at: Vector2) -> void:
	var t := clampf(1.0 - float(e["life"]) / maxf(float(e["max_life"]), 0.001), 0.0, 1.0)
	var r := float(e["radius"])
	var color: Color = game.fx.style(e["weapon"])["color"] if game.fx else Color(1.0, 0.85, 0.5)
	var a := 1.0 - t
	draw_arc(at, r, 0.0, TAU, 48, Color(color, a), 3.0)
	draw_arc(at, maxf(0.0, r - 3.0), 0.0, TAU, 48, Color(1.0, 1.0, 0.9, a * 0.7), 1.0)
	if FxLayer.wfx > 0:
		draw_arc(at, maxf(0.0, r - 8.0), 0.0, TAU, 48, Color(color, a * 0.25), 5.0)
		if float(e["stun"]) > 0.0:
			# Trovão Ritual: arcos elétricos correndo na frente da onda.
			for k: int in range(4):
				var s := t * 9.0 + k * TAU / 4.0
				draw_arc(at, r + 1.0, s, s + 0.35, 6, Color(1.0, 1.0, 0.75, a), 1.0)


## Furacão (Fūjin) e tufão (Fūjin-Raijin): espiral de faixas de vento em várias alturas,
## detritos girando (posições derivadas do tempo, sem estado) e, no tufão, núcleo escuro com
## lampejos de raio. A Alta desenha mais faixas e detritos.
func _draw_storm(e: Dictionary, at: Vector2, time: float) -> void:
	var r := float(e["radius"])
	var spin := float(e["spin"])
	var typhoon := int(e["kind"]) == Kind.TYPHOON
	var color: Color = game.fx.style(e["weapon"])["color"] if game.fx else Color(0.8, 0.95, 1.0)
	var age := float(e["max_life"]) - float(e["life"])
	var fade := clampf(float(e["life"]) / 0.5, 0.0, 1.0) * clampf(age / 0.3, 0.0, 1.0)
	if typhoon:
		draw_circle(at, r * 0.5, Color(0.12, 0.14, 0.26, 0.35 * fade))
	draw_circle(at, r, Color(color, 0.06 * fade))
	var bands: int = [3, 5, 7][FxLayer.wfx]
	for k: int in range(bands):
		var u := k / float(bands)
		var start := spin * (1.0 + 0.3 * u) + k * 2.4
		var rr := r * (0.3 + 0.75 * u)
		draw_arc(at + Vector2(0, -3.0 * u), rr, start, start + 1.6 + u, 14,
				Color(color.lerp(Color.WHITE, 0.4 * (1.0 - u)), (0.75 - 0.4 * u) * fade), 2.0 if k % 2 == 0 else 1.0)
	var debris: int = [4, 8, 14][FxLayer.wfx]
	for k: int in range(debris):
		var a := spin * (1.4 + 0.1 * (k % 3)) + k * 1.7
		var rr := r * (0.35 + 0.6 * fmod(k * 0.37, 1.0))
		var p := at + Vector2(cos(a), sin(a) * 0.6) * rr
		var c := Color(0.55, 0.75, 0.4, fade) if k % 3 == 0 else Color(0.9, 0.95, 1.0, 0.8 * fade)
		draw_rect(Rect2(p.round(), Vector2(2, 1) if k % 2 else Vector2.ONE), c)
	if typhoon and fmod(time * 3.7 + spin, 1.0) < 0.15:
		var a := spin * 2.0
		draw_polyline(PackedVector2Array([at + Vector2.from_angle(a) * r * 0.2,
				at + Vector2.from_angle(a + 0.4) * r * 0.55, at + Vector2.from_angle(a + 0.2) * r * 0.9]),
				Color(1.0, 1.0, 0.7, 0.9 * fade), 1.0)
