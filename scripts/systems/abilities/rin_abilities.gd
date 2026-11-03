class_name RinAbilities
extends HeroAbilities
## Rin, a caçadora que corre contra o amanhecer para salvar o irmão (energia: Foco, 集中).
## Penas brancas, fita vermelha e o dourado da alvorada:
##   1. 破魔矢 Hamaya: flecha sagrada para o inimigo mais próximo (ou para a frente); voa rápida
##      numa linha de `length` px atravessando todos (um golpe por inimigo, faísca em cada um)
##      e deixa um rastro de luz que se apaga.
##   2. 罠 Armadilha de Caça: mandíbula de ferro aos pés (no máx. `max_traps`; a mais antiga sai);
##      os `max_catch` primeiros inimigos comuns que entram no raio ficam presos e levam dano. As
##      cargas que restam aparecem em pontos dourados sobre a armadilha; vazia, ela se fecha.
##   3. 燕返し Salto da Andorinha: salto para trás (longe do inimigo mais próximo), invencível,
##      com rastro de andorinhas e penas; ao cair, leque de `arrows` flechas para onde ela estava
##      (cada uma atravessa `pierce` inimigos).
## Efeitos persistentes (flechas no ar, armadilhas, salto em curso) vão no save da partida
## suspensa e no hash. Penas e rastros são só desenho (fora do hash).

const COLOR := Color(1.0, 0.88, 0.54)
const HOT := Color(1.0, 0.98, 0.86)
const DAWN := Color(1.0, 0.72, 0.3)
const RIBBON := Color(0.88, 0.14, 0.2)
const FEATHER := Color(0.97, 0.98, 1.0)
const QUILL := Color(0.55, 0.58, 0.66)
const IRON := Color(0.36, 0.37, 0.42)
const IRON_HI := Color(0.8, 0.82, 0.86)
const IRON_DARK := Color(0.12, 0.12, 0.15)
const SWALLOW := Color(0.14, 0.17, 0.3)
## Flecha: comprimento do corpo (px) e quanto tempo o rastro de luz leva para sumir (s).
const ARROW_LEN := 11.0
const HAMAYA_FADE := 0.45
const VOLLEY_FADE := 0.18
## Rastro de cada flecha do leque (px atrás da ponta).
const VOLLEY_TRAIL := 16.0
## Armadilha: raio da mandíbula (px), tempo do estalo ao prender, quanto dura fechando quando
## as cargas acabam e o limite de pontos de carga desenhados.
const JAW_R := 7.0
const SNAP_TIME := 0.22
const SPENT_TIME := 0.6
const MAX_PIPS := 8
## Penas soltas (só desenho) e as andorinhas do rastro do salto.
const MAX_FEATHERS := 28
const LEAP_GHOSTS := 4

## Flechas no ar: {"kind" (0 hamaya, 1 leque), "id", "origin", "pos", "prev", "dir", "speed",
## "left" (px que faltam), "pierce" (0 = todos), "count", "damage", "width", "force", "hit"
## (índices já atingidos), "fade" (> 0: já parou, só o rastro some)}.
var _arrows: Array[Dictionary] = []
## Armadilhas: {"pos", "life", "max", "left" (cargas), "total", "r", "root", "damage",
## "caught" (índices presos), "snap" (estalo, só desenho), "spent"}.
var _traps: Array[Dictionary] = []
# Salto da Andorinha em curso (o leque sai quando ela cai).
var _leap_active: bool = false
var _leap_origin := Vector2.ZERO
var _leap_start := Vector2.ZERO
var _leap_aim := Vector2.RIGHT
var _leap_ability: Dictionary = {}
var _leap_power: float = 1.0
## Penas (só desenho): {"pos", "vel", "rot", "spin", "life", "max"}.
var _feathers: Array[Dictionary] = []
## Rastro do salto (só desenho): {"a", "b", "life", "max"}.
var _leap_trail: Dictionary = {}
var _sfx_hit_step: int = -1
var _order: Array = []


func reset() -> void:
	_arrows.clear()
	_traps.clear()
	_leap_active = false
	_leap_ability = {}
	_feathers.clear()
	_leap_trail = {}


func cast(slot: int, ability: Dictionary, power: float) -> bool:
	match StringName(ability["id"]):
		&"hamaya":
			return _cast_hamaya(ability, power)
		&"hunting_trap":
			return _cast_trap(ability, power)
		&"swallow_leap":
			return _cast_leap(ability, power)
	return super.cast(slot, ability, power)


func step(dt: float) -> void:
	if _leap_active:
		_step_leap()
	if not _arrows.is_empty():
		_step_arrows(dt)
	if not _traps.is_empty():
		_step_traps(dt)
	_step_visuals(dt)


# --- 破魔矢 Hamaya --------------------------------------------------------------------------

func _cast_hamaya(ability: Dictionary, power: float) -> bool:
	var player := game.player
	var length := param(ability, "length", 320.0)
	var dir := player.aim_direction(Player.Aim.NEAREST, length)
	var from := player.sim_pos
	_add_arrow(0, &"hamaya", from, dir, param(ability, "speed", 1400.0), length, 0,
			dmg(ability, "damage", power), area_of(ability, "width"), param(ability, "knockback", 40.0))
	var fx := game.fx
	var hand := from + dir * 6.0 + Vector2(0.0, -6.0)
	fx.flash(hand, 22.0, Color(HOT, 0.95), 0.14)
	fx.sparks(hand, dir, COLOR, [4, 8, 12][FxLayer.wfx], 190.0, 0.35, 0.22)
	fx.motes(hand, DAWN, [0, 3, 6][FxLayer.wfx], 6.0, 30.0)
	fx.add_ring(hand, 14.0, COLOR, 0.25)
	punch(0.8, 15)
	return true


# --- 罠 Armadilha de Caça -------------------------------------------------------------------

func _cast_trap(ability: Dictionary, power: float) -> bool:
	var at := game.player.sim_pos
	var limit := maxi(1, int(param(ability, "max_traps", 2.0)))
	while _traps.size() >= limit:
		var old: Dictionary = _traps.pop_front()
		game.fx.dust(old["pos"], 6.0, Color(IRON_HI, 0.8), [3, 5, 8][FxLayer.wfx], 30.0)
	var charges := maxi(1, int(param(ability, "max_catch", 6.0)))
	var life := dur(ability, "life")
	_traps.append({"pos": at, "life": life, "max": life, "left": charges, "total": charges,
			"r": area_of(ability, "radius"), "root": dur(ability, "root_time"),
			"damage": dmg(ability, "damage", power), "caught": [], "snap": 0.0, "spent": false,
			"sfx": String(ability.get("sfx", ""))})
	var fx := game.fx
	fx.dust(at, 8.0, Color(0.55, 0.45, 0.32, 0.9), [4, 8, 12][FxLayer.wfx], 35.0)
	fx.sparks(at, Vector2.UP, IRON_HI, [2, 5, 8][FxLayer.wfx], 90.0, 1.2, 0.2)
	fx.add_ring(at, area_of(ability, "radius"), Color(COLOR, 0.7), 0.35, 1.0)
	punch(0.6, 15)
	return true


## Cada armadilha prende os primeiros que entram (na ordem da grade) até acabarem as cargas.
func _step_traps(dt: float) -> void:
	var enemies := game.enemies
	for trap: Dictionary in _traps:
		trap["life"] = float(trap["life"]) - dt
		trap["snap"] = maxf(0.0, float(trap["snap"]) - dt)
		if bool(trap["spent"]):
			continue
		var at: Vector2 = trap["pos"]
		var caught: Array = trap["caught"]
		enemies.query_circle(at, float(trap["r"]), _hits)
		var snapped := 0
		for j: int in _hits.duplicate():
			if int(trap["left"]) <= 0:
				break
			if caught.has(j) or not enemies.is_controllable(j):
				continue
			enemies.root_one(j, float(trap["root"]))
			caught.append(j)
			trap["left"] = int(trap["left"]) - 1
			hit(&"hunting_trap", j, float(trap["damage"]), (enemies.pos[j] - at).normalized(), 0.0)
			_snap_fx(enemies.pos[j] + Vector2(0.0, enemies.radius[j] * 0.6))
			snapped += 1
		if snapped > 0:
			trap["snap"] = SNAP_TIME
			play_sfx(String(trap["sfx"]) + "_hit")
			punch(0.5, 12)
		if int(trap["left"]) <= 0:
			trap["spent"] = true
			trap["life"] = minf(float(trap["life"]), SPENT_TIME)
			trap["snap"] = SNAP_TIME
			game.fx.dust(at, 5.0, Color(IRON_HI, 0.8), [3, 6, 9][FxLayer.wfx], 25.0)
	for k: int in range(_traps.size() - 1, -1, -1):
		if float(_traps[k]["life"]) <= 0.0:
			_traps.remove_at(k)


## Estalo da mandíbula nos pés de quem ficou preso.
func _snap_fx(foot: Vector2) -> void:
	var fx := game.fx
	fx.flash(foot, 12.0, Color(HOT, 0.85), 0.1)
	fx.sparks(foot, Vector2.UP, IRON_HI, [2, 4, 6][FxLayer.wfx], 110.0, 1.3, 0.18)
	if FxLayer.wfx > 0:
		fx.dust(foot, 3.0, Color(0.55, 0.45, 0.32, 0.8), FxLayer.wfx * 2, 25.0)


# --- 燕返し Salto da Andorinha ----------------------------------------------------------------

func _cast_leap(ability: Dictionary, power: float) -> bool:
	var player := game.player
	var aim := player.aim_direction(Player.Aim.NEAREST, param(ability, "reach", 200.0))
	var from := player.sim_pos
	player.dash(-aim, param(ability, "distance", 80.0), param(ability, "leap_time", 0.22),
			param(ability, "invuln", 0.15))
	_leap_active = true
	_leap_origin = from
	_leap_start = from
	_leap_aim = aim
	_leap_ability = ability
	_leap_power = power
	_leap_trail = {"a": from, "b": from, "life": 0.6, "max": 0.6}
	var fx := game.fx
	fx.dust(from + Vector2(0, 3), 5.0, Color(0.75, 0.7, 0.6, 0.8), [4, 8, 12][FxLayer.wfx], 50.0)
	fx.play_anim("boost", from, 0.6, (-aim).angle() - PI * 0.5, Color(1.0, 0.95, 0.8), 30.0, false, true)
	_add_feathers(from, -aim, [3, 6, 10][FxLayer.wfx])
	punch(0.8, 20)
	return true


## Durante o salto: penas e o rastro; ao cair, o leque para onde ela estava.
func _step_leap() -> void:
	var player := game.player
	var now := player.sim_pos
	if not _leap_trail.is_empty():
		_leap_trail["b"] = now
	if FxLayer.wfx > 0 and game.step_index % 2 == 0:
		_add_feathers(now + Vector2(0, -6), -_leap_aim, FxLayer.wfx)
	if player.is_dashing():
		return
	_leap_active = false
	var ability := _leap_ability
	var aim := _leap_origin - now
	aim = aim.normalized() if aim.length_squared() > 1.0 else _leap_aim
	var count := maxi(1, int(param(ability, "arrows", 9.0)))
	var spread := deg_to_rad(param(ability, "spread", 60.0))
	var damage := dmg(ability, "damage", _leap_power)
	var reach := param(ability, "range", 220.0)
	var speed := param(ability, "speed", 520.0)
	var width := area_of(ability, "width")
	var pierce := maxi(1, int(param(ability, "pierce", 3.0)))
	for k: int in range(count):
		var t := 0.5 if count == 1 else float(k) / float(count - 1)
		var dir := aim.rotated(lerpf(-spread * 0.5, spread * 0.5, t))
		_add_arrow(1, &"swallow_leap", now, dir, speed, reach, pierce, damage, width, param(ability, "knockback", 50.0))
	var fx := game.fx
	var bow := now + aim * 6.0 + Vector2(0, -6)
	fx.flash(bow, 26.0, Color(HOT, 0.95), 0.16)
	fx.sparks(bow, aim, COLOR, [6, 12, 18][FxLayer.wfx], 200.0, spread * 0.5, 0.25)
	fx.shockwave(bow, 22.0, COLOR, 0.6, 0.3)
	fx.dust(now + Vector2(0, 3), 6.0, Color(0.75, 0.7, 0.6, 0.8), [3, 6, 10][FxLayer.wfx], 40.0)
	_add_feathers(now + Vector2(0, -6), aim, [4, 8, 14][FxLayer.wfx])
	punch(1.6, 30)


# --- Flechas (Hamaya e o leque) -----------------------------------------------------------

func _add_arrow(kind: int, id: StringName, from: Vector2, dir: Vector2, speed: float, reach: float, pierce: int,
		damage: float, width: float, force: float) -> void:
	var d := dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	_arrows.append({"kind": kind, "id": String(id), "origin": from, "pos": from, "prev": from, "dir": d,
			"speed": speed, "left": reach, "pierce": pierce, "count": 0, "damage": damage, "width": width,
			"force": force, "hit": [], "fade": 0.0})


## Cada flecha anda no passo e acerta, na ordem do caminho, quem cruzou (uma vez cada); com
## `pierce`, para no último que atravessa. Parada, só o rastro some.
func _step_arrows(dt: float) -> void:
	for arrow: Dictionary in _arrows:
		arrow["prev"] = arrow["pos"]
		if float(arrow["fade"]) > 0.0:
			arrow["fade"] = float(arrow["fade"]) - dt
			continue
		var from: Vector2 = arrow["pos"]
		var dir: Vector2 = arrow["dir"]
		var travel := minf(float(arrow["speed"]) * dt, float(arrow["left"]))
		var to := from + dir * travel
		var stop := _arrow_hits(arrow, from, to)
		if stop != Vector2.INF:
			to = stop
			arrow["left"] = 0.0
		else:
			arrow["left"] = float(arrow["left"]) - travel
		arrow["pos"] = to
		if float(arrow["left"]) <= 0.0:
			arrow["fade"] = HAMAYA_FADE if int(arrow["kind"]) == 0 else VOLLEY_FADE
			if int(arrow["kind"]) == 0:
				game.fx.sparks(to, dir, COLOR, [2, 4, 6][FxLayer.wfx], 90.0, 0.6, 0.18)
				game.fx.motes(to, DAWN, [0, 2, 4][FxLayer.wfx], 4.0, 20.0)
	for k: int in range(_arrows.size() - 1, -1, -1):
		if float(_arrows[k]["left"]) <= 0.0 and float(_arrows[k]["fade"]) <= 0.0:
			_arrows.remove_at(k)


## Acerta quem a flecha cruza de `from` a `to`; devolve onde ela para (Vector2.INF = segue).
func _arrow_hits(arrow: Dictionary, from: Vector2, to: Vector2) -> Vector2:
	var enemies := game.enemies
	enemies.query_segment(from, to, float(arrow["width"]), _hits)
	if _hits.is_empty():
		return Vector2.INF
	var hit_list: Array = arrow["hit"]
	var dir: Vector2 = arrow["dir"]
	# Na ordem do caminho (projeção na direção da flecha; empate pelo índice).
	_order.clear()
	for j: int in _hits:
		if not hit_list.has(j):
			_order.append([(enemies.pos[j] - from).dot(dir), j])
	_order.sort_custom(func(x: Array, y: Array) -> bool:
		return float(x[0]) < float(y[0]) or (float(x[0]) == float(y[0]) and int(x[1]) < int(y[1])))
	var pierce := int(arrow["pierce"])
	var id := StringName(String(arrow["id"]))
	var hamaya := int(arrow["kind"]) == 0
	for row: Array in _order:
		var j: int = row[1]
		if enemies.alive[j] == 0:
			continue
		hit_list.append(j)
		var at := enemies.pos[j]
		hit(id, j, float(arrow["damage"]), dir, float(arrow["force"]))
		arrow["count"] = int(arrow["count"]) + 1
		var fx := game.fx
		fx.sparks(at, dir, HOT if hamaya else COLOR, [2, 4, 6][FxLayer.wfx] if hamaya else [1, 2, 3][FxLayer.wfx],
				150.0, 0.45, 0.18)
		if hamaya:
			fx.flash(at, 12.0, Color(COLOR, 0.85), 0.1)
			fx.motes(at, DAWN, [0, 1, 2][FxLayer.wfx], 3.0, 25.0)
		if _sfx_hit_step != game.step_index:
			_sfx_hit_step = game.step_index
			play_sfx("ab_%s_hit" % id)
		if pierce > 0 and int(arrow["count"]) >= pierce:
			return from + dir * maxf(0.0, float(row[0]))
	return Vector2.INF


# --- Penas e rastro (só desenho, no passo para seguir a pausa e a velocidade do jogo) ------

func _add_feathers(at: Vector2, dir: Vector2, count: int) -> void:
	for _k: int in range(count):
		if _feathers.size() >= MAX_FEATHERS:
			_feathers.pop_front()
		var a := dir.angle() + randf_range(-1.1, 1.1)
		var life := randf_range(0.5, 0.9)
		_feathers.append({"pos": at + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)),
				"vel": Vector2.from_angle(a) * randf_range(20.0, 60.0), "rot": randf() * TAU,
				"spin": randf_range(-6.0, 6.0), "life": life, "max": life})


func _step_visuals(dt: float) -> void:
	for k: int in range(_feathers.size() - 1, -1, -1):
		var f := _feathers[k]
		f["life"] = float(f["life"]) - dt
		if float(f["life"]) <= 0.0:
			_feathers.remove_at(k)
			continue
		var vel: Vector2 = f["vel"]
		# Cai balançando, freada pelo ar.
		vel = vel * (1.0 - 3.0 * dt) + Vector2(sin(float(f["rot"]) * 2.0) * 30.0, 14.0) * dt
		f["vel"] = vel
		f["pos"] = (f["pos"] as Vector2) + vel * dt
		f["rot"] = float(f["rot"]) + float(f["spin"]) * dt
	if not _leap_trail.is_empty():
		_leap_trail["life"] = float(_leap_trail["life"]) - dt
		if float(_leap_trail["life"]) <= 0.0 and not _leap_active:
			_leap_trail = {}


# --- Bot, save e hash --------------------------------------------------------------------------

## Armadilha: não arma outra em cima de uma ainda cheia; o resto pela regra do JSON.
func bot_should_cast(slot: int, ability: Dictionary) -> bool:
	if StringName(ability["id"]) == &"hunting_trap":
		var at := game.player.sim_pos
		for trap: Dictionary in _traps:
			if not bool(trap["spent"]) and at.distance_to(trap["pos"]) < float(trap["r"]):
				return false
	if StringName(ability["id"]) == &"swallow_leap" and _leap_active:
		return false
	return super.bot_should_cast(slot, ability)


func state() -> Dictionary:
	var arrows: Array = []
	for a: Dictionary in _arrows:
		var row := a.duplicate(true)
		row["origin"] = vec(a["origin"])
		row["pos"] = vec(a["pos"])
		row["prev"] = vec(a["prev"])
		row["dir"] = vec(a["dir"])
		arrows.append(row)
	var traps: Array = []
	for t: Dictionary in _traps:
		var row := t.duplicate(true)
		row["pos"] = vec(t["pos"])
		traps.append(row)
	var out := {"arrows": arrows, "traps": traps}
	if _leap_active:
		out["leap"] = {"origin": vec(_leap_origin), "aim": vec(_leap_aim), "power": _leap_power,
				"id": String(_leap_ability.get("id", ""))}
	return out


func load_state(s: Dictionary) -> void:
	reset()
	for row: Variant in s.get("arrows", []):
		var a: Dictionary = (row as Dictionary).duplicate(true)
		for key: String in ["origin", "pos", "prev", "dir"]:
			a[key] = to_vec(a.get(key))
		a["kind"] = int(a.get("kind", 0))
		a["pierce"] = int(a.get("pierce", 0))
		a["count"] = int(a.get("count", 0))
		a["hit"] = _int_list(a.get("hit", []))
		_arrows.append(a)
	for row: Variant in s.get("traps", []):
		var t: Dictionary = (row as Dictionary).duplicate(true)
		t["pos"] = to_vec(t.get("pos"))
		t["left"] = int(t.get("left", 0))
		t["total"] = int(t.get("total", 1))
		t["caught"] = _int_list(t.get("caught", []))
		t["spent"] = bool(t.get("spent", false))
		_traps.append(t)
	var leap: Dictionary = s.get("leap", {})
	if not leap.is_empty():
		for ability: Dictionary in system.abilities:
			if String(ability.get("id", "")) == String(leap.get("id", "")):
				_leap_ability = ability
		if not _leap_ability.is_empty():
			_leap_active = true
			_leap_origin = to_vec(leap.get("origin"))
			_leap_start = _leap_origin
			_leap_aim = to_vec(leap.get("aim"))
			_leap_power = float(leap.get("power", 1.0))


static func _int_list(list: Variant) -> Array:
	var out: Array = []
	for v: Variant in (list if list is Array else []):
		out.append(int(v))
	return out


func hash_tag() -> String:
	var tag := " rin=%d,%d,%d" % [_arrows.size(), _traps.size(), 1 if _leap_active else 0]
	for a: Dictionary in _arrows:
		tag += ",%.1f:%.1f:%d" % [(a["pos"] as Vector2).x, (a["pos"] as Vector2).y, int(a["count"])]
	for t: Dictionary in _traps:
		tag += ",%.1f:%.1f:%d:%.2f" % [(t["pos"] as Vector2).x, (t["pos"] as Vector2).y, int(t["left"]), float(t["life"])]
	return tag


# --- Desenho (só leitura) -------------------------------------------------------------------

func has_visuals() -> bool:
	return not _arrows.is_empty() or not _traps.is_empty() or _leap_active or not _feathers.is_empty() \
			or not _leap_trail.is_empty()


## Armadilhas no chão: o raio de captura pontilhado, a mandíbula de ferro (aberta, com um brilho
## que corre pelos dentes; fecha no estalo) e as cargas que restam.
func draw_ground(canvas: CanvasItem) -> void:
	var t := GameClock.game_time
	for trap: Dictionary in _traps:
		_draw_trap(canvas, trap, t)


func _draw_trap(canvas: CanvasItem, trap: Dictionary, t: float) -> void:
	var at: Vector2 = (trap["pos"] as Vector2).round()
	var life := float(trap["life"])
	var age := float(trap["max"]) - life
	var fade := clampf(life / 0.4, 0.0, 1.0) * clampf(age / 0.12, 0.0, 1.0)
	var spent := bool(trap["spent"])
	var snap := float(trap["snap"]) / SNAP_TIME
	# Fechada: no estalo e depois de gastar as cargas; abre de novo devagar depois do estalo.
	var closed := 1.0 if spent else clampf(snap * 1.6, 0.0, 1.0)
	# Raio de captura: pontos que giram devagar (some na Baixa quando gasta).
	if not spent:
		var r := float(trap["r"])
		var dots := clampi(int(r * 0.45), 12, 28)
		for k: int in range(dots):
			var a := TAU * k / dots + t * 0.4
			var p := at + Vector2(cos(a) * r, sin(a) * r * 0.5)
			canvas.draw_rect(Rect2(p.round(), Vector2(1, 1)), Color(COLOR, 0.35 * fade))
	# Sombra e a placa do gatilho.
	canvas.draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
	canvas.draw_circle(Vector2.ZERO, JAW_R + 3.0, Color(0.0, 0.0, 0.0, 0.35 * fade))
	canvas.draw_circle(Vector2.ZERO, 3.0, Color(IRON_DARK, fade))
	canvas.draw_circle(Vector2.ZERO, 2.0, Color(IRON, fade))
	# As duas mandíbulas: semicírculos de ferro com dentes para dentro; fechando, encolhem no eixo.
	var open := 1.0 - closed
	for side: float in [-1.0, 1.0]:
		var squash := 0.25 + 0.75 * open
		canvas.draw_set_transform(at, 0.0, Vector2(1.0, 0.5 * squash))
		var start := PI if side < 0.0 else 0.0
		Stroke.arc(canvas, Vector2(0.0, side * (1.0 - open) * 1.5), JAW_R, start, start + PI, 9,
				Color(IRON_DARK, fade), 3.0)
		Stroke.arc(canvas, Vector2(0.0, side * (1.0 - open) * 1.5), JAW_R, start, start + PI, 9,
				Color(IRON, fade), 1.5)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for k: int in range(5):
			var a := start + PI * (k + 0.5) / 5.0
			var rim := at + Vector2(cos(a) * JAW_R, sin(a) * JAW_R * 0.5 * squash)
			var tip := rim.lerp(at, 0.35 + 0.4 * closed)
			canvas.draw_rect(Rect2(tip.round(), Vector2(1, 1)), Color(IRON_HI, fade))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Brilho sutil de armada: um ponto de luz que corre pelos dentes.
	if not spent:
		var g := fmod(t * 0.9 + at.x * 0.01, 1.6)
		if g < 1.0:
			var a := PI + TAU * g
			var p := at + Vector2(cos(a) * JAW_R, sin(a) * JAW_R * 0.5)
			canvas.draw_rect(Rect2(p.round() - Vector2(1, 0), Vector2(3, 1)), Color(HOT, 0.8 * fade))
			canvas.draw_rect(Rect2(p.round() - Vector2(0, 1), Vector2(1, 3)), Color(HOT, 0.5 * fade))
	# Fita vermelha presa na corrente (a marca da Rin).
	var sway := sin(t * 3.0 + at.y) * 1.0
	canvas.draw_rect(Rect2(at + Vector2(JAW_R + 1.0, -1.0), Vector2(2, 1)), Color(IRON, fade))
	canvas.draw_rect(Rect2((at + Vector2(JAW_R + 3.0, -2.0 + sway)).round(), Vector2(1, 3)), Color(RIBBON, fade))
	canvas.draw_rect(Rect2((at + Vector2(JAW_R + 4.0, -1.0 + sway * 1.5)).round(), Vector2(1, 3)),
			Color(RIBBON, 0.8 * fade))


## Cargas que restam: pontos dourados acesos (restam) e apagados (usadas) logo abaixo da
## armadilha, por cima de tudo (a Rin e os presos ficam em cima dela).
## Por cima da horda (a mandíbula fica no chão, embaixo dos inimigos): o raio de captura com
## borda escura e fio claro, e uma seta dourada balançando acima da armadilha armada.
func _draw_trap_marker(canvas: CanvasItem, trap: Dictionary, t: float) -> void:
	var at: Vector2 = (trap["pos"] as Vector2).round()
	var life := float(trap["life"])
	var r := float(trap["r"])
	var snap := float(trap["snap"]) / SNAP_TIME
	if bool(trap["spent"]):
		# Fechou com tudo: anel de ferro que estoura para fora e correntes até quem ficou preso.
		var k := clampf(life / SPENT_TIME, 0.0, 1.0)
		bold_ring(canvas, at, r * (1.0 + 0.5 * (1.0 - k)), IRON_HI.lerp(HOT, snap), HOT, sqrt(k), 3.0)
		_draw_trap_chains(canvas, trap, at, k)
		return
	var fade := clampf(life / 0.4, 0.0, 1.0) * clampf((float(trap["max"]) - life) / 0.12, 0.0, 1.0)
	_draw_trap_chains(canvas, trap, at, fade)
	var segments := clampi(int(r * 0.8), 20, 40)
	canvas.draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
	Stroke.arc(canvas, Vector2.ZERO, r, 0.0, TAU, segments, Color(IRON_DARK, 0.55 * fade), 3.0)
	Stroke.arc(canvas, Vector2.ZERO, r, 0.0, TAU, segments, Color(COLOR.lerp(HOT, snap), (0.6 + 0.4 * snap) * fade), 1.0)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Seta: contorno escuro e miolo dourado, balança 2 px; no estalo pisca em branco.
	var bob := roundf(sin(t * 5.0 + at.x * 0.05) * 2.0)
	var tip := at + Vector2(0.0, -11.0 + bob)
	var dark := Color(IRON_DARK, 0.9 * fade)
	Stroke.convex(canvas, PackedVector2Array([tip + Vector2(-5, -6), tip + Vector2(5, -6), tip + Vector2(0, 1)]), dark)
	Stroke.convex(canvas, PackedVector2Array([tip + Vector2(-3, -5), tip + Vector2(3, -5), tip + Vector2(0, -1)]),
			Color(COLOR.lerp(HOT, snap), fade))
	canvas.draw_rect(Rect2(tip + Vector2(-1, -9), Vector2(2, 3)), dark)
	canvas.draw_rect(Rect2(tip + Vector2(0, -9), Vector2(1, 2)), Color(RIBBON, fade))


## Corrente pontilhada (elos claros e escuros) da armadilha até cada presa ainda presa.
func _draw_trap_chains(canvas: CanvasItem, trap: Dictionary, at: Vector2, alpha: float) -> void:
	var enemies := game.enemies
	for j: int in trap["caught"]:
		if enemies.alive[j] == 0 or enemies.root[j] <= 0.0:
			continue
		var to := enemies.prev[j].lerp(enemies.pos[j], GameClock.alpha)
		var span := to - at
		var links := clampi(int(span.length() / 3.0), 1, 16)
		for n: int in range(1, links):
			var p := (at + span * (n / float(links))).round()
			canvas.draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color(IRON_DARK, 0.8 * alpha))
			canvas.draw_rect(Rect2(p - Vector2(0, 0), Vector2(1, 1)), Color(IRON_HI if n % 2 == 0 else COLOR, alpha))


func _draw_trap_pips(canvas: CanvasItem, trap: Dictionary) -> void:
	if bool(trap["spent"]):
		return
	var at: Vector2 = (trap["pos"] as Vector2).round()
	var life := float(trap["life"])
	var fade := clampf(life / 0.4, 0.0, 1.0) * clampf((float(trap["max"]) - life) / 0.12, 0.0, 1.0)
	var total := mini(int(trap["total"]), MAX_PIPS)
	var left := int(trap["left"])
	var w := total * 3 - 1
	for k: int in range(total):
		var p := at + Vector2(-w * 0.5 + k * 3.0, JAW_R * 0.5 + 3.0).round()
		canvas.draw_rect(Rect2(p - Vector2(1, 1), Vector2(4, 4)), Color(0.1, 0.06, 0.0, 0.75 * fade))
		var c := COLOR if k < left else IRON
		canvas.draw_rect(Rect2(p, Vector2(2, 2)), Color(c, fade))


## Flechas (rastro de luz, corpo branco com fita vermelha e a ponta dourada), andorinhas do
## salto e penas caindo.
func draw_over(canvas: CanvasItem) -> void:
	var alpha := GameClock.alpha
	if not _leap_trail.is_empty():
		_draw_leap_trail(canvas)
	var t := GameClock.game_time
	for trap: Dictionary in _traps:
		_draw_trap_marker(canvas, trap, t)
		_draw_trap_pips(canvas, trap)
	for arrow: Dictionary in _arrows:
		var tip := (arrow["prev"] as Vector2).lerp(arrow["pos"], alpha)
		var dir: Vector2 = arrow["dir"]
		var flying := float(arrow["fade"]) <= 0.0
		if int(arrow["kind"]) == 0:
			var k := 1.0 if flying else clampf(float(arrow["fade"]) / HAMAYA_FADE, 0.0, 1.0)
			var origin: Vector2 = arrow["origin"]
			# Traço de comprimento zero com largura vira polígono degenerado no motor.
			if origin.round() != tip.round():
				canvas.draw_line(origin.round(), tip.round(), Color(DAWN, 0.35 * k), 5.0 * k + 1.0)
				canvas.draw_line(origin.round(), tip.round(), Color(COLOR, 0.7 * k), 2.0)
				canvas.draw_line(origin.round(), tip.round(), Color(HOT, 0.95 * k), 1.0)
			if flying:
				_draw_arrow(canvas, tip, dir, 1.0, 1.0)
		else:
			var back := tip - dir * minf(VOLLEY_TRAIL, (tip - (arrow["origin"] as Vector2)).length())
			var k := 1.0 if flying else clampf(float(arrow["fade"]) / VOLLEY_FADE, 0.0, 1.0)
			if back.round() != tip.round():
				canvas.draw_line(back.round(), tip.round(), Color(COLOR, 0.5 * k), 2.0)
				canvas.draw_line(back.round(), tip.round(), Color(HOT, 0.8 * k), 1.0)
			if flying:
				_draw_arrow(canvas, tip, dir, 0.8, 1.0)
	for f: Dictionary in _feathers:
		var k := float(f["life"]) / float(f["max"])
		var p: Vector2 = f["pos"]
		var d := Vector2.from_angle(float(f["rot"]))
		canvas.draw_line(p - d * 2.0, p + d * 2.0, Color(FEATHER, 0.9 * k), 2.0)
		canvas.draw_line(p - d * 2.0, p + d * 1.0, Color(QUILL, 0.8 * k), 1.0)


## Flecha com a ponta em `tip`: corpo claro, penas brancas atrás e fita vermelha.
func _draw_arrow(canvas: CanvasItem, tip: Vector2, dir: Vector2, size: float, a: float) -> void:
	var side := dir.orthogonal()
	var tail := tip - dir * ARROW_LEN * size
	canvas.draw_line(tail, tip - dir * 2.0, Color(0.95, 0.9, 0.78, a), 1.0)
	Stroke.convex(canvas, PackedVector2Array([tip + dir * 1.5, tip - dir * 3.0 * size + side * 2.0 * size,
			tip - dir * 3.0 * size - side * 2.0 * size]), Color(HOT, a))
	Stroke.convex(canvas, PackedVector2Array([tail, tail + dir * 4.0 * size + side * 2.5 * size, tail + dir * 1.5 * size]),
			Color(FEATHER, a))
	Stroke.convex(canvas, PackedVector2Array([tail, tail + dir * 1.5 * size, tail + dir * 4.0 * size - side * 2.5 * size]),
			Color(FEATHER, a))
	var knot := tail + dir * 5.0 * size
	canvas.draw_rect(Rect2(knot.round(), Vector2(1, 1)), Color(RIBBON, a))
	canvas.draw_rect(Rect2((knot - dir * 1.5 + side * 1.5).round(), Vector2(1, 1)), Color(RIBBON, a * 0.8))


## Rastro do salto: andorinhas escuras de barriga branca ao longo do caminho, sumindo.
func _draw_leap_trail(canvas: CanvasItem) -> void:
	var a: Vector2 = _leap_trail["a"]
	var b: Vector2 = _leap_trail["b"]
	var k := clampf(float(_leap_trail["life"]) / float(_leap_trail["max"]), 0.0, 1.0)
	if _leap_active:
		k = 1.0
	if a.distance_squared_to(b) < 4.0:
		return
	var dir := (b - a).normalized()
	canvas.draw_line(a.round() + Vector2(0, -6), b.round() + Vector2(0, -6), Color(FEATHER, 0.25 * k), 3.0)
	for g: int in range(LEAP_GHOSTS):
		var t := (g + 1.0) / (LEAP_GHOSTS + 1.0)
		var p := a.lerp(b, t) + Vector2(0, -7.0 - sin(t * PI) * 5.0)
		_draw_swallow(canvas, p, dir, 0.7 + 0.3 * t, (0.25 + 0.6 * t) * k)


## Andorinha vista de cima (corpo, asas em foice e a cauda bifurcada), voando para `dir`.
static func _draw_swallow(canvas: CanvasItem, at: Vector2, dir: Vector2, size: float, a: float) -> void:
	var s := dir.orthogonal() * size
	var f := dir * size
	var body := Color(SWALLOW, a)
	Stroke.convex(canvas, PackedVector2Array([at + f * 4.0, at - f * 2.0 + s * 1.5, at - f * 2.0 - s * 1.5]), body)
	Stroke.convex(canvas, PackedVector2Array([at + f * 1.0, at - f * 4.0 + s * 7.0, at - f * 1.0]), body)
	Stroke.convex(canvas, PackedVector2Array([at + f * 1.0, at - f * 1.0, at - f * 4.0 - s * 7.0]), body)
	Stroke.convex(canvas, PackedVector2Array([at - f * 2.0, at - f * 7.0 + s * 2.5, at - f * 4.0]), body)
	Stroke.convex(canvas, PackedVector2Array([at - f * 2.0, at - f * 4.0, at - f * 7.0 - s * 2.5]), body)
	canvas.draw_rect(Rect2((at + f * 1.0).round(), Vector2(1, 1)), Color(FEATHER, a))
	canvas.draw_rect(Rect2((at + f * 3.0).round(), Vector2(1, 1)), Color(RIBBON, a))


## Brilho (Alta): halo na ponta das flechas e ao longo do rastro da Hamaya, e nas armadilhas.
func draw_glow(canvas: CanvasItem) -> void:
	var alpha := GameClock.alpha
	var t := GameClock.game_time
	for arrow: Dictionary in _arrows:
		var tip := (arrow["prev"] as Vector2).lerp(arrow["pos"], alpha)
		var flying := float(arrow["fade"]) <= 0.0
		if int(arrow["kind"]) == 0:
			var k := 1.0 if flying else clampf(float(arrow["fade"]) / HAMAYA_FADE, 0.0, 1.0)
			if flying:
				FxLayer.draw_soft(canvas, tip, 14.0, Color(COLOR, 0.85))
				FxLayer.draw_soft(canvas, tip, 6.0, Color(HOT, 0.9))
			var origin: Vector2 = arrow["origin"]
			var length := origin.distance_to(tip)
			var blobs := clampi(int(length / 36.0), 1, 10)
			for b: int in range(blobs):
				FxLayer.draw_soft(canvas, origin.lerp(tip, (b + 0.5) / blobs), 9.0, Color(DAWN, 0.22 * k))
		elif flying:
			FxLayer.draw_soft(canvas, tip, 7.0, Color(COLOR, 0.6))
	for trap: Dictionary in _traps:
		if bool(trap["spent"]):
			continue
		var fade := clampf(float(trap["life"]) / 0.4, 0.0, 1.0)
		var pulse := 0.75 + 0.25 * sin(t * 4.0 + (trap["pos"] as Vector2).x)
		FxLayer.draw_soft(canvas, trap["pos"], 12.0, Color(COLOR, 0.12 * fade * pulse))
		if float(trap["snap"]) > 0.0:
			FxLayer.draw_soft(canvas, trap["pos"], 16.0, Color(HOT, 0.6 * float(trap["snap"]) / SNAP_TIME))
