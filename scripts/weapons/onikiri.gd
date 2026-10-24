class_name Onikiri
extends Weapon
## Onikiri (鬼切) / Dōjigiri (童子切), a espada da Yuki: combo de três cortes curtos em
## meia-lua na direção do inimigo mais próximo (sem alvo, para onde ela olha). Os cortes 0 e
## 1 alternam o sentido do golpe (de cima para baixo e de baixo para cima); o 2 é o golpe
## final, mais largo, mais forte e com mais recuo. Perfura tudo; cada inimigo leva no máximo
## um acerto por golpe. Com Quantidade 2, corta também para o lado oposto.
## A evolução (flag "combo_wave") solta no golpe final uma onda em meia-lua que avança
## WAVE_RANGE px e fere cada inimigo uma vez.
## Determinística: mira, combo, acertos e ondas só dependem do estado da simulação. Os rastros
## são só desenho (avançam no step(), mas não mudam o resultado).

const COMBO_STEPS := 3
const FINISHER := 2
## Meia-abertura do corte normal (75°) e do golpe final (100°), em radianos.
const HALF_ANGLE := 1.309
const FINISHER_HALF_ANGLE := 1.745
const FINISHER_RADIUS := 1.3
const FINISHER_DAMAGE := 1.6
const FINISHER_KNOCKBACK := 1.7
## Inimigo colado na guardiã leva o golpe seja qual for o ângulo.
const CLOSE_RANGE := 8.0
## Procura de alvo: até REACH x o raio do corte.
const REACH := 1.6
## Rastro: varre em SWEEP_TIME s e some em FADE_TIME s, em degraus de alfa (pixel art).
const SWEEP_TIME := 0.12
const FADE_TIME := 0.15
const MAX_TRAILS := 6
const ARC_POINTS := 14
const ALPHA_STEPS := 3
## Onda do Dōjigiri: avança WAVE_RANGE px em WAVE_TIME s.
const WAVE_RANGE := 130.0
const WAVE_TIME := 0.4
const WAVE_RADIUS := 26.0
const WAVE_ARC := 0.7
const WAVE_THICKNESS := 12.0
const WAVE_DAMAGE := 1.2
const WAVE_KNOCKBACK := 0.6
const MAX_WAVES := 4
## Cor de poder da Yuki (cast_color "a8dcff" em data/heroes.json): borda de gelo e núcleo branco.
const ICE := Color(0.659, 0.863, 1.0)
const CORE := Color(1.0, 1.0, 1.0)
## Brilho rubro do sangue oni, só no Dōjigiri.
const ONI := Color(1.0, 0.36, 0.4)

## Próximo passo do combo (0, 1 ou 2).
var combo: int = 0
## Rastros vivos (só desenho): offset da guardiã, ângulo, raio, meia-abertura, sentido, final, tempo.
var trails: Array[Dictionary] = []
## Ondas vivas (simulação): origem, direção, distância percorrida, inimigos já atingidos.
var waves: Array[Dictionary] = []

var _hits: Array[int] = []
var _struck: Dictionary = {}


## Golpe em volta do corpo: sai de sim_pos, não da mão.
func from_hand() -> bool:
	return false


func step(dt: float) -> void:
	_advance_trails(dt)
	_advance_waves(dt)
	super.step(dt)


## Um golpe por disparo: a guardiã (e o clone do Kenta, sem repetir a pose) cortam no mesmo
## passo do combo, que avança uma vez.
func fire_all() -> void:
	var player := game.player
	var dir := aim(player.sim_pos)
	_swing(player.sim_pos, dir, combo)
	if player.clone_time > 0.0:
		var clone := player.clone_position()
		_swing(clone, aim(clone), combo)
	var dir_x := signf(dir.x) if absf(dir.x) > 0.15 else player.facing_x
	player.on_slash(dir_x if dir_x != 0.0 else 1.0, combo)
	_slash_sound(combo)
	combo = (combo + 1) % COMBO_STEPS


## Corte avulso no passo atual do combo, sem avançar o combo nem mexer na pose.
func fire(origin: Vector2) -> void:
	_swing(origin, aim(origin), combo)


## Direção do corte: o inimigo mais próximo ao alcance; sem alvo, para onde a guardiã olha.
func aim(origin: Vector2) -> Vector2:
	var target := game.enemies.nearest(origin, radius(FINISHER) * REACH)
	if target >= 0:
		var to := game.enemies.pos[target] - origin
		if to.length_squared() > 0.0001:
			return to.normalized()
	return Vector2(game.player.facing_x if game.player.facing_x != 0.0 else 1.0, 0.0)


func radius(combo_step: int) -> float:
	var r := raw("radius") * area()
	return r * FINISHER_RADIUS if combo_step == FINISHER else r


func half_angle(combo_step: int) -> float:
	return FINISHER_HALF_ANGLE if combo_step == FINISHER else HALF_ANGLE


func swing_damage(combo_step: int) -> float:
	return damage() * (FINISHER_DAMAGE if combo_step == FINISHER else 1.0)


## O inimigo está dentro da meia-lua? Tolerância angular pelo tamanho dele e aceite direto
## de quem está colado.
static func in_arc(origin: Vector2, dir: Vector2, r: float, half: float, at: Vector2, size: float) -> bool:
	var to := at - origin
	var dist := to.length()
	if dist > r + size:
		return false
	if dist <= CLOSE_RANGE + size:
		return true
	var slack := asin(minf(1.0, size / dist))
	return absf(dir.angle_to(to)) <= half + slack


func _swing(origin: Vector2, dir: Vector2, combo_step: int) -> void:
	var r := radius(combo_step)
	var half := half_angle(combo_step)
	var dmg := swing_damage(combo_step)
	var force := knockback() * (FINISHER_KNOCKBACK if combo_step == FINISHER else 1.0)
	var dirs: Array[Vector2] = [dir]
	if amount() >= 2:
		dirs.append(-dir)
	_struck.clear()
	game.enemies.query_circle(origin, r, _hits)
	for d: Vector2 in dirs:
		for i: int in _hits:
			if _struck.has(i) or game.enemies.alive[i] == 0:
				continue
			var at := game.enemies.pos[i]
			if not in_arc(origin, d, r, half, at, game.enemies.radius[i]):
				continue
			_struck[i] = true
			var push := (at - origin).normalized() if at.distance_squared_to(origin) > 0.01 else d
			game.deal_damage(id, i, dmg, push, force)
		_add_trail(origin, d, r, half, combo_step)
		if combo_step == FINISHER and bool(flags.get("combo_wave", false)):
			_add_wave(origin, d)


func _add_trail(origin: Vector2, dir: Vector2, r: float, half: float, combo_step: int) -> void:
	if trails.size() >= MAX_TRAILS:
		trails.pop_front()
	trails.append({"offset": origin - game.player.sim_pos, "angle": dir.angle(), "radius": r,
			"half": half, "down": combo_step != 1, "final": combo_step == FINISHER, "t": 0.0})


func _advance_trails(dt: float) -> void:
	for k: int in range(trails.size() - 1, -1, -1):
		var trail := trails[k]
		trail["t"] = float(trail["t"]) + dt
		if float(trail["t"]) >= SWEEP_TIME + FADE_TIME:
			trails.remove_at(k)


func _add_wave(origin: Vector2, dir: Vector2) -> void:
	if waves.size() >= MAX_WAVES:
		waves.pop_front()
	waves.append({"origin": origin, "dir": dir, "dist": 0.0, "t": 0.0, "hit": {},
			"size": WAVE_RADIUS * area()})


## Cada passo a onda varre de onde estava até onde chegou (sem atravessar inimigos entre
## passos) e fere uma vez cada inimigo na faixa.
func _advance_waves(dt: float) -> void:
	if waves.is_empty():
		return
	var dmg := damage() * WAVE_DAMAGE
	var force := knockback() * WAVE_KNOCKBACK
	for k: int in range(waves.size() - 1, -1, -1):
		var wave := waves[k]
		var t := minf(float(wave["t"]) + dt, WAVE_TIME)
		var before := float(wave["dist"])
		var dist := WAVE_RANGE * t / WAVE_TIME
		wave["t"] = t
		wave["dist"] = dist
		var origin: Vector2 = wave["origin"]
		var dir: Vector2 = wave["dir"]
		var size := float(wave["size"])
		var width := size * sin(WAVE_ARC)
		var hit: Dictionary = wave["hit"]
		var mid := origin + dir * (before + dist) * 0.5
		game.enemies.query_circle(mid, (dist - before) * 0.5 + WAVE_THICKNESS + width, _hits)
		for i: int in _hits:
			if hit.has(i):
				continue
			var rel := game.enemies.pos[i] - origin
			var along := rel.dot(dir)
			var side := absf(rel.dot(dir.orthogonal()))
			var pad := game.enemies.radius[i] + WAVE_THICKNESS * 0.5
			if along >= before - pad and along <= dist + pad and side <= width + game.enemies.radius[i]:
				hit[i] = true
				game.deal_damage(id, i, dmg, dir, force)
		if t >= WAVE_TIME:
			waves.remove_at(k)


func on_removed() -> void:
	trails.clear()
	waves.clear()


# --- Desenho -------------------------------------------------------------------

func draw(canvas: CanvasItem) -> void:
	var center := game.player.position
	var evolved := is_evolved()
	for trail: Dictionary in trails:
		_draw_trail(canvas, center + (trail["offset"] as Vector2), trail, evolved)
	for wave: Dictionary in waves:
		_draw_wave(canvas, wave)


## Alfa em degraus: inteiro na varredura, depois ALPHA_STEPS degraus secos até sumir.
static func stepped_alpha(fade: float) -> float:
	if fade <= 0.0:
		return 1.0
	var level := ceili((1.0 - clampf(fade, 0.0, 1.0)) * ALPHA_STEPS)
	return float(level) / ALPHA_STEPS


func _draw_trail(canvas: CanvasItem, at: Vector2, trail: Dictionary, evolved: bool) -> void:
	var t := float(trail["t"])
	var sweep := clampf(t / SWEEP_TIME, 0.0, 1.0)
	sweep = 1.0 - (1.0 - sweep) * (1.0 - sweep)
	if sweep < 0.08:
		return
	var is_final := bool(trail["final"])
	var alpha := stepped_alpha((t - SWEEP_TIME) / FADE_TIME)
	if alpha <= 0.0:
		return
	var r := float(trail["radius"])
	var half := float(trail["half"])
	var base := float(trail["angle"])
	var from := base - half if bool(trail["down"]) else base + half
	var to := base + half if bool(trail["down"]) else base - half
	var thick := r * (0.42 if is_final else 0.32)
	var shrink := 0.75 + 0.25 * alpha
	if is_final:
		_crescent(canvas, at, from, to, sweep, r + 2.0, thick * 1.25 * shrink, Color(ICE, 0.35 * alpha))
	_crescent(canvas, at, from, to, sweep, r, thick * shrink, Color(ICE, 0.9 * alpha))
	if evolved:
		_crescent(canvas, at, from, to, sweep, r - thick * 0.55 * shrink, thick * 0.2 * shrink,
				Color(ONI, 0.8 * alpha))
	_crescent(canvas, at, from, to, sweep, r - 1.0, thick * (0.55 if is_final else 0.42) * shrink,
			Color(CORE, alpha))
	if is_final and t >= SWEEP_TIME * 0.6:
		_sparks(canvas, at + Vector2.from_angle(to) * r, to, alpha, (from - to) < 0.0)


## Meia-lua: borda de fora no raio r, de dentro r - espessura, mais grossa no meio do arco.
## Só a parte já varrida (0..sweep) aparece.
func _crescent(canvas: CanvasItem, at: Vector2, from: float, to: float, sweep: float, r: float,
		thick: float, color: Color) -> void:
	if thick < 0.5 or r <= 1.0:
		return
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for k: int in range(ARC_POINTS + 1):
		var u := sweep * k / float(ARC_POINTS)
		var angle := lerpf(from, to, u)
		var w := maxf(0.4, thick * sin(PI * u))
		outer.append((at + Vector2.from_angle(angle) * r).round())
		inner.append(at + Vector2.from_angle(angle) * maxf(0.0, r - w))
	inner.reverse()
	outer.append_array(inner)
	canvas.draw_colored_polygon(outer, color)


## Faíscas curtas na ponta do golpe final, em leque fixo (sem sorteio).
func _sparks(canvas: CanvasItem, tip: Vector2, angle: float, alpha: float, clockwise: bool) -> void:
	var turn := 1.0 if clockwise else -1.0
	var length := 3.0 + 4.0 * alpha
	for k: int in range(4):
		var a := angle + turn * (PI * 0.5) + (k - 1.5) * 0.45
		var start := tip + Vector2.from_angle(a) * 1.5
		canvas.draw_line(start.round(), (start + Vector2.from_angle(a) * length).round(),
				Color(CORE if k % 2 == 0 else ICE, alpha), 1.0)


func _draw_wave(canvas: CanvasItem, wave: Dictionary) -> void:
	var u := float(wave["t"]) / WAVE_TIME
	var alpha := stepped_alpha((u - 0.5) * 2.0)
	if alpha <= 0.0:
		return
	var dir: Vector2 = wave["dir"]
	var size := float(wave["size"])
	var pivot: Vector2 = (wave["origin"] as Vector2) + dir * (float(wave["dist"]) - size)
	var base := dir.angle()
	var thick := WAVE_THICKNESS * (1.0 - 0.4 * u)
	_crescent(canvas, pivot, base - WAVE_ARC, base + WAVE_ARC, 1.0, size + 2.0, thick + 2.0,
			Color(ICE, 0.35 * alpha))
	_crescent(canvas, pivot, base - WAVE_ARC, base + WAVE_ARC, 1.0, size, thick, Color(ICE, 0.85 * alpha))
	_crescent(canvas, pivot, base - WAVE_ARC, base + WAVE_ARC, 1.0, size - 1.0, thick * 0.4, Color(ONI, alpha))


## Cada corte: o "shing" (Kenney knifeSlice) e o swish de ar (hy_slash), mais baixos que a
## Katana porque saem quase duas vezes mais. O golpe final soma um swish grave e encorpado;
## cortando dos dois lados, um swish extra discreto.
func _slash_sound(combo_step: int) -> void:
	if combo_step == FINISHER:
		AudioManager.play("katana", 0.9, 0.04, -3.0)
		AudioManager.play("slash", 0.92, 0.06, -4.0)
		AudioManager.play("whoosh", 0.7, 0.04, -7.0)
	else:
		AudioManager.play("katana", 1.12 if combo_step == 0 else 1.04, 0.05, -5.0)
		AudioManager.play("slash", 1.1, 0.08, -6.0)
	if amount() >= 2:
		AudioManager.play("whoosh", 0.9, 0.05, -12.0)
