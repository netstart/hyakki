class_name ToraAbilities
extends HeroAbilities
## Tora, o ferreiro de 70 anos que pega em armas pela primeira vez (energia: Calor da Forja, 熱).
## Ferro, brasa laranja, fagulhas e vapor (HeroAbilities explica o contrato):
##   1. 鉄槌 Martelo na Bigorna: um martelo em brasa aparece `offset` px à frente (rumo ao inimigo
##      mais próximo) e cai em FALL_TIME s: fere e atordoa em volta, chuva de fagulhas e chão
##      chamuscado.
##   2. 鎖引き Corrente Puxadora: a corrente do kusarigama gira 360° em volta do Tora, fere e puxa
##      todos do raio para perto (com rastro); `delay` s depois, estouro de brasa no ponto do puxão.
##   3. 焼き入れ Têmpera: explosão de vapor que fere e empurra para longe; por `time` s o Tora
##      ganha `armor` de armadura (Player.add_armor), brilha em laranja e solta vapor; cura
##      `heal_pct` da vida máxima.
## Martelos no ar, estouros pendentes e a Têmpera vão no save e no hash (a armadura é reaplicada
## ao Player ao retomar). A corrente girando, os rastros e o chão chamuscado são só desenho.

const COLOR := Color(1.0, 0.48, 0.23)
const HOT := Color(1.0, 0.9, 0.62)
const WHITE_HOT := Color(1.0, 0.98, 0.9)
const EMBER := Color(1.0, 0.58, 0.16)
const IRON := Color(0.2, 0.18, 0.2)
const IRON_LIGHT := Color(0.45, 0.42, 0.44)
const STEAM := Color(0.93, 0.95, 1.0)
const HANDLE := Color(0.42, 0.26, 0.12)
## Queda do martelo (s) e de que altura começa (px).
const FALL_TIME := 0.2
const FALL_HEIGHT := 56.0
## Martelo cravado e chão chamuscado depois da batida (só desenho, s).
const MARK_TIME := 1.2
const HEAD_STAY := 0.3
## Corrente girando (só desenho): a volta inteira e o recolher (s), elos desenhados.
const SPIN_TIME := 0.34
const REEL_TIME := 0.22
const CHAIN_LINKS := 14
## Rastros dos puxados (só desenho): no máximo quantos e por quanto tempo.
const MAX_TRAILS := 40
const TRAIL_TIME := 0.45
## Vapor que sobe do Tora durante a Têmpera: a cada quantos passos, em cada nível gráfico.
const STEAM_EVERY: Array[int] = [12, 6, 3]
## Rajada da Têmpera: por quanto tempo o vapor segue empurrando (s) e a fração do empurrão por
## passo (o golpe sozinho perde a velocidade em poucos passos; a rajada leva o grupo para longe).
const GUST_TIME := 0.3
const GUST_SHARE := 0.18

# Martelos caindo (no save): {"pos", "left", "r", "damage", "stun", "force", "sfx"}.
var _hammers: Array[Dictionary] = []
## Martelos cravados e chão chamuscado (só desenho): {"pos", "r", "life"}.
var _marks: Array[Dictionary] = []
# Estouros da corrente pendentes (no save): {"pos", "left", "r", "damage", "sfx"}.
var _blasts: Array[Dictionary] = []
## Corrente girando (só desenho): onde, quanto falta, alcance e ângulo inicial.
var _spin_time: float = 0.0
var _spin_pos := Vector2.ZERO
var _spin_r: float = 0.0
var _spin_start: float = 0.0
## Rastros dos puxados (só desenho): {"j", "from", "life"}.
var _trails: Array[Dictionary] = []
# Têmpera (no save).
var _quench_time: float = 0.0
var _quench_max: float = 0.0
var _quench_armor: float = 0.0
## Rajada de vapor (no save): tempo restante, centro, raio e empurrão por passo.
var _gust_time: float = 0.0
var _gust_pos := Vector2.ZERO
var _gust_r: float = 0.0
var _gust_force: float = 0.0
## Anel de vapor no chão depois da explosão (só desenho).
var _steam_ground: float = 0.0
var _steam_pos := Vector2.ZERO
var _steam_r: float = 0.0


func reset() -> void:
	_hammers.clear()
	_marks.clear()
	_blasts.clear()
	_spin_time = 0.0
	_trails.clear()
	_quench_time = 0.0
	_quench_max = 0.0
	_quench_armor = 0.0
	_gust_time = 0.0
	_steam_ground = 0.0
	if game != null and game.player != null:
		game.player.ability_rim.a = 0.0


func cast(slot: int, ability: Dictionary, power: float) -> bool:
	match StringName(ability["id"]):
		&"anvil_hammer":
			return _cast_hammer(ability, power)
		&"chain_pull":
			return _cast_chain(ability, power)
		&"quench":
			return _cast_quench(ability, power)
	return super.cast(slot, ability, power)


func step(dt: float) -> void:
	if not _hammers.is_empty():
		_step_hammers(dt)
	for k: int in range(_marks.size() - 1, -1, -1):
		_marks[k]["life"] = float(_marks[k]["life"]) - dt
		if float(_marks[k]["life"]) <= 0.0:
			_marks.remove_at(k)
	if not _blasts.is_empty():
		_step_blasts(dt)
	if _spin_time > 0.0:
		_spin_time = maxf(0.0, _spin_time - dt)
	for k: int in range(_trails.size() - 1, -1, -1):
		_trails[k]["life"] = float(_trails[k]["life"]) - dt
		if float(_trails[k]["life"]) <= 0.0:
			_trails.remove_at(k)
	if _gust_time > 0.0:
		_gust_time -= dt
		game.enemies.push_from(_gust_pos, _gust_r, _gust_force)
	if _quench_time > 0.0:
		_step_quench(dt)
	if _steam_ground > 0.0:
		_steam_ground = maxf(0.0, _steam_ground - dt)


# --- 鉄槌 Martelo na Bigorna ----------------------------------------------------------------

func _cast_hammer(ability: Dictionary, power: float) -> bool:
	var player := game.player
	var offset := param(ability, "offset", 40.0)
	var r := area_of(ability, "radius")
	var dir := player.aim_direction(Player.Aim.NEAREST, offset + r)
	var at := player.sim_pos + dir * offset
	_hammers.append({"pos": at, "left": FALL_TIME, "r": r, "damage": dmg(ability, "damage", power),
			"stun": dur(ability, "stun"), "force": param(ability, "knockback", 120.0),
			"sfx": String(ability.get("sfx", ""))})
	var top := at + Vector2(0.0, -FALL_HEIGHT)
	game.fx.flash(top, 16.0, Color(COLOR, 0.9), 0.15)
	game.fx.embers(top, EMBER, [2, 4, 7][FxLayer.wfx], 6.0)
	game.fx.sparks(player.hand_position(), dir, HOT, [2, 4, 6][FxLayer.wfx], 90.0, 0.6, 0.18)
	return true


func _step_hammers(dt: float) -> void:
	var landed: Array[Dictionary] = []
	for h: Dictionary in _hammers:
		h["left"] = float(h["left"]) - dt
		if float(h["left"]) <= 0.0:
			landed.append(h)
		elif FxLayer.wfx > 0:
			game.fx.embers(_hammer_point(h, 0.0), EMBER, 1, 4.0)
	for h: Dictionary in landed:
		_hammers.erase(h)
		_smash(h)


## A martelada: fere e atordoa no raio, clarão, chuva de fagulhas, brasas e o chão chamuscado.
func _smash(h: Dictionary) -> void:
	var at: Vector2 = h["pos"]
	var r := float(h["r"])
	hit_circle(&"anvil_hammer", at, r, float(h["damage"]), float(h["force"]), false, float(h["stun"]))
	if _marks.size() >= 4:
		_marks.pop_front()
	_marks.append({"pos": at, "r": r, "life": MARK_TIME})
	var fx := game.fx
	fx.play_anim("explosion", at + Vector2(0.0, -4.0), r / 28.0, 0.0, Color(1.0, 0.72, 0.45))
	fx.shockwave(at, r * 1.25, COLOR, 1.5, 0.4)
	fx.flash(at, r, Color(COLOR, 0.95), 0.2)
	fx.flash(at, r * 0.4, Color(WHITE_HOT, 0.9), 0.08)
	# Chuva de fagulhas: um leque alto que se abre e brasas que sobem.
	fx.sparks(at, Vector2.UP, HOT, [10, 22, 36][FxLayer.wfx], 230.0, 1.2, 0.45)
	fx.sparks(at, Vector2.ZERO, EMBER, [4, 10, 16][FxLayer.wfx], 140.0, PI, 0.3)
	fx.embers(at, EMBER, [4, 10, 18][FxLayer.wfx], r * 0.5)
	fx.dust(at, r * 0.4, Color(0.5, 0.45, 0.42, 0.9), [4, 8, 14][FxLayer.wfx], 80.0)
	play_sfx(String(h.get("sfx", "")) + "_hit")
	punch(2.6, 50)


## Ponto do martelo na queda (acelerando), `ahead` = fração do passo seguinte (desenho).
func _hammer_point(h: Dictionary, ahead: float) -> Vector2:
	var k := clampf((FALL_TIME - float(h["left"]) + ahead * GameClock.STEP) / FALL_TIME, 0.0, 1.0)
	return (h["pos"] as Vector2) + Vector2(0.0, -FALL_HEIGHT * (1.0 - k * k))


# --- 鎖引き Corrente Puxadora ---------------------------------------------------------------

func _cast_chain(ability: Dictionary, power: float) -> bool:
	var player := game.player
	var at := player.sim_pos
	var r := area_of(ability, "radius")
	var enemies := game.enemies
	# Rastros (só desenho): de onde cada puxado saiu.
	enemies.query_circle(at, r, _hits)
	for j: int in _hits:
		if _trails.size() >= MAX_TRAILS:
			break
		if enemies.is_controllable(j):
			_trails.append({"j": j, "from": enemies.pos[j], "life": TRAIL_TIME})
	hit_circle(&"chain_pull", at, r, dmg(ability, "damage", power), 0.0)
	enemies.pull_to(at, r, param(ability, "keep", 14.0))
	_blasts.append({"pos": at, "left": maxf(param(ability, "delay", 0.4), GameClock.STEP),
			"r": area_of(ability, "blast_radius"), "damage": dmg(ability, "blast_damage", power),
			"force": param(ability, "blast_knockback", 160.0), "sfx": String(ability.get("sfx", ""))})
	_spin_time = SPIN_TIME + REEL_TIME
	_spin_pos = at
	_spin_r = r
	_spin_start = player.aim_direction().angle()
	var fx := game.fx
	fx.add_ring(at, r, Color(IRON_LIGHT, 0.8), SPIN_TIME + 0.1, 1.0)
	fx.dust(at, r * 0.9, Color(0.6, 0.55, 0.5, 0.7), [4, 10, 18][FxLayer.wfx], -60.0)
	punch(1.4, 30)
	return true


func _step_blasts(dt: float) -> void:
	var due: Array[Dictionary] = []
	for b: Dictionary in _blasts:
		b["left"] = float(b["left"]) - dt
		if float(b["left"]) <= 0.0:
			due.append(b)
	for b: Dictionary in due:
		_blasts.erase(b)
		_blast(b)


## Estouro de brasa no ponto do puxão.
func _blast(b: Dictionary) -> void:
	var at: Vector2 = b["pos"]
	var r := float(b["r"])
	hit_circle(&"chain_pull", at, r, float(b["damage"]), float(b.get("force", 160.0)))
	var fx := game.fx
	fx.play_anim("explosion", at, r / 24.0, 0.0, Color(1.0, 0.7, 0.4))
	fx.shockwave(at, r * 1.6, COLOR, 1.6, 0.45)
	fx.flash(at, r, Color(COLOR, 0.85), 0.2)
	fx.sparks(at, Vector2.ZERO, HOT, [8, 18, 30][FxLayer.wfx], 200.0, PI, 0.35)
	fx.embers(at, EMBER, [6, 12, 22][FxLayer.wfx], r * 0.6)
	play_sfx(String(b.get("sfx", "")) + "_hit")
	punch(2.8, 55)


# --- 焼き入れ Têmpera -----------------------------------------------------------------------

func _cast_quench(ability: Dictionary, power: float) -> bool:
	var player := game.player
	var at := player.sim_pos
	var r := area_of(ability, "radius")
	var push := param(ability, "knockback", 380.0)
	hit_circle(&"quench", at, r, dmg(ability, "damage", power), push)
	_gust_time = GUST_TIME
	_gust_pos = at
	_gust_r = r + 20.0
	_gust_force = push * GUST_SHARE
	_quench_max = dur(ability, "time")
	_quench_time = _quench_max
	_quench_armor = param(ability, "armor", 5.0)
	player.add_armor(_quench_armor, _quench_time)
	player.heal(player.max_hp() * param(ability, "heal_pct", 0.1), true)
	_steam_ground = 1.4
	_steam_pos = at
	_steam_r = r
	var fx := game.fx
	fx.add_ring(at, r * 0.6, Color(STEAM, 0.7), 0.5, 3.0)
	fx.add_ring(at, r * 1.1, Color(STEAM, 0.45), 0.7, 1.0)
	# Nuvem de vapor: anéis de partículas brancas que correm para fora (sem cobrir os inimigos).
	for ring: float in [0.15, 0.45, 0.8]:
		fx.dust(at, r * ring, Color(STEAM, 0.85), [6, 12, 18][FxLayer.wfx], 120.0 + 120.0 * ring)
	fx.motes(at, STEAM, [3, 8, 14][FxLayer.wfx], r * 0.6, 50.0)
	fx.shockwave(at, r, STEAM, 1.9, 0.55)
	fx.flash(at, r * 0.8, Color(STEAM, 0.85), 0.25)
	fx.flash(at, 24.0, Color(COLOR, 0.9), 0.15)
	fx.sparks(at, Vector2.ZERO, EMBER, [6, 12, 20][FxLayer.wfx], 160.0, PI, 0.3)
	punch(3.2, 70)
	return true


## Armadura correndo: contorno laranja pulsando no Tora e vapor que sobe dele.
func _step_quench(dt: float) -> void:
	var player := game.player
	_quench_time -= dt
	if _quench_time <= 0.0:
		_quench_time = 0.0
		player.ability_rim.a = 0.0
		game.fx.dust(player.sim_pos + Vector2(0.0, -6.0), 8.0, Color(STEAM, 0.8), [3, 6, 10][FxLayer.wfx], 40.0)
		return
	var fade := clampf(_quench_time / 0.5, 0.0, 1.0)
	player.ability_rim = Color(COLOR.lerp(HOT, 0.25 + 0.25 * sin(GameClock.game_time * 7.0)), 0.75 * fade)
	if game.step_index % STEAM_EVERY[FxLayer.wfx] == 0:
		game.fx.motes(player.sim_pos + Vector2(0.0, -10.0), Color(STEAM, 0.8), 1, 6.0, 14.0)
		if FxLayer.wfx > 0:
			game.fx.embers(player.sim_pos + Vector2(0.0, -4.0), EMBER, 1, 5.0)


# --- Bot, save e hash --------------------------------------------------------------------------

## Têmpera também para curar (vida abaixo de 50% com gente perto) e nunca com ela correndo; a
## Corrente só sem estouro pendente; o resto pela regra do JSON.
func bot_should_cast(slot: int, ability: Dictionary) -> bool:
	var id := StringName(ability["id"])
	if id == &"quench":
		if _quench_time > 0.0:
			return false
		var player := game.player
		if player.hp < player.max_hp() * 0.5 and game.enemies.count_in_circle(player.sim_pos, 110.0, 4) >= 4:
			return true
	if id == &"chain_pull" and not _blasts.is_empty():
		return false
	return super.bot_should_cast(slot, ability)


func state() -> Dictionary:
	var hammers: Array = []
	for h: Dictionary in _hammers:
		var row := h.duplicate()
		row["pos"] = vec(h["pos"])
		hammers.append(row)
	var blasts: Array = []
	for b: Dictionary in _blasts:
		var row := b.duplicate()
		row["pos"] = vec(b["pos"])
		blasts.append(row)
	return {"hammers": hammers, "blasts": blasts, "quench": [_quench_time, _quench_max, _quench_armor],
			"gust": [_gust_time, _gust_pos.x, _gust_pos.y, _gust_r, _gust_force]}


func load_state(s: Dictionary) -> void:
	reset()
	for row: Variant in s.get("hammers", []):
		var h: Dictionary = (row as Dictionary).duplicate()
		h["pos"] = to_vec(h.get("pos"))
		_hammers.append(h)
	for row: Variant in s.get("blasts", []):
		var b: Dictionary = (row as Dictionary).duplicate()
		b["pos"] = to_vec(b.get("pos"))
		_blasts.append(b)
	var q: Array = s.get("quench", [])
	if q.size() >= 3:
		_quench_time = float(q[0])
		_quench_max = float(q[1])
		_quench_armor = float(q[2])
		if _quench_time > 0.0:
			game.player.add_armor(_quench_armor, _quench_time)
	var g: Array = s.get("gust", [])
	if g.size() >= 5:
		_gust_time = float(g[0])
		_gust_pos = Vector2(float(g[1]), float(g[2]))
		_gust_r = float(g[3])
		_gust_force = float(g[4])


func hash_tag() -> String:
	var tag := " tora=%.3f,%.3f,%d,%d" % [_quench_time, _gust_time, _hammers.size(), _blasts.size()]
	for h: Dictionary in _hammers:
		tag += ",%.1f:%.1f" % [(h["pos"] as Vector2).x, (h["pos"] as Vector2).y]
	return tag


# --- Desenho (só leitura) -------------------------------------------------------------------

func has_visuals() -> bool:
	return not _hammers.is_empty() or not _marks.is_empty() or not _blasts.is_empty() or _spin_time > 0.0 \
			or not _trails.is_empty() or _quench_time > 0.0 or _steam_ground > 0.0


## Chão: sombra e alvo do martelo que cai, chão chamuscado com brasas, aviso do estouro e o anel
## molhado de vapor da Têmpera.
func draw_ground(canvas: CanvasItem) -> void:
	var t := GameClock.game_time
	for h: Dictionary in _hammers:
		var at: Vector2 = h["pos"]
		var r := float(h["r"])
		var k := clampf(1.0 - float(h["left"]) / FALL_TIME, 0.0, 1.0)
		canvas.draw_circle(at, 4.0 + 6.0 * k, Color(0.0, 0.0, 0.0, 0.25 + 0.25 * k))
		Stroke.arc(canvas, at, lerpf(r * 1.4, r, k), 0.0, TAU, 32, Color(COLOR, 0.4 + 0.5 * k), 1.0)
	for m: Dictionary in _marks:
		var at: Vector2 = m["pos"]
		var r := float(m["r"])
		var fade := clampf(float(m["life"]) / 0.5, 0.0, 1.0)
		canvas.draw_circle(at, r * 0.55, Color(0.12, 0.06, 0.03, 0.4 * fade))
		canvas.draw_circle(at, r * 0.3, Color(0.5, 0.16, 0.04, 0.35 * fade))
		for k: int in range(8):
			var a := TAU * k / 8.0 + float(k * 29 % 7)
			var p := at + Vector2.from_angle(a) * r * (0.15 + 0.4 * fmod(k * 0.618, 1.0))
			var glow := 0.5 + 0.5 * sin(t * 8.0 + k * 1.9)
			canvas.draw_rect(Rect2(p.round(), Vector2(2, 1)), Color(EMBER, (0.3 + 0.6 * glow) * fade))
	for b: Dictionary in _blasts:
		var r := float(b["r"])
		var pulse := 0.6 + 0.4 * sin(t * 30.0)
		canvas.draw_circle(b["pos"], r, Color(COLOR, 0.14 * pulse))
		Stroke.arc(canvas, b["pos"], r, 0.0, TAU, 28, Color(EMBER, 0.6 * pulse), 1.0)
	if _steam_ground > 0.0:
		var k := _steam_ground / 1.4
		Stroke.arc(canvas, _steam_pos, _steam_r * (1.05 - 0.15 * k), 0.0, TAU, 48, Color(STEAM, 0.35 * k), 2.0)
		canvas.draw_circle(_steam_pos, _steam_r * 0.5, Color(0.3, 0.32, 0.36, 0.18 * k))


## Por cima: o martelo em brasa caindo (e cravado logo depois), a corrente girando e os rastros.
func draw_over(canvas: CanvasItem) -> void:
	for h: Dictionary in _hammers:
		_draw_hammer(canvas, _hammer_point(h, GameClock.alpha), 1.0)
	for m: Dictionary in _marks:
		var stay := float(m["life"]) - (MARK_TIME - HEAD_STAY)
		if stay > 0.0:
			_draw_hammer(canvas, m["pos"], stay / HEAD_STAY)
	for trail: Dictionary in _trails:
		var j := int(trail["j"])
		if game.enemies.alive[j] == 0:
			continue
		var k := float(trail["life"]) / TRAIL_TIME
		var from: Vector2 = trail["from"]
		var to := game.enemies.pos[j]
		Stroke.line(canvas, PackedVector2Array([from.round(), to.round()]), Color(COLOR, 0.55 * k), 2.0)
		Stroke.line(canvas, PackedVector2Array([from.round(), to.round()]), Color(HOT, 0.8 * k), 1.0)
	if _spin_time > 0.0:
		_draw_chain(canvas)


## Martelo de forja: cabeça de ferro em brasa (borda escura, miolo laranja, fio branco) e o cabo.
func _draw_hammer(canvas: CanvasItem, at: Vector2, alpha: float) -> void:
	var head := Rect2((at + Vector2(-11.0, -12.0)).round(), Vector2(22, 12))
	Stroke.line(canvas, PackedVector2Array([(at + Vector2(3.0, -12.0)).round(), (at + Vector2(11.0, -32.0)).round()]),
			Color(IRON, alpha), 4.0)
	Stroke.line(canvas, PackedVector2Array([(at + Vector2(3.0, -12.0)).round(), (at + Vector2(11.0, -32.0)).round()]),
			Color(HANDLE, alpha), 2.0)
	canvas.draw_rect(head, Color(IRON, alpha))
	canvas.draw_rect(head.grow(-1.0), Color(0.55, 0.2, 0.08, alpha))
	canvas.draw_rect(Rect2(head.position + Vector2(2, 2), Vector2(18, 7)), Color(COLOR, alpha))
	canvas.draw_rect(Rect2(head.position + Vector2(3, 2), Vector2(16, 2)), Color(HOT, alpha))
	canvas.draw_rect(Rect2(head.position + Vector2(1, 10), Vector2(20, 1)), Color(WHITE_HOT, alpha))


## Corrente do kusarigama: varre 360° a partir da mira e depois recolhe; elos alternados e a
## foice na ponta, com um rastro de luz atrás da ponta.
func _draw_chain(canvas: CanvasItem) -> void:
	var center := game.player.position + Vector2(0.0, -6.0)
	var since := SPIN_TIME + REEL_TIME - _spin_time
	var angle := _spin_start + TAU * clampf(since / SPIN_TIME, 0.0, 1.0)
	var reach := _spin_r
	if since > SPIN_TIME:
		var k := clampf((since - SPIN_TIME) / REEL_TIME, 0.0, 1.0)
		reach = _spin_r * (1.0 - k * k)
	else:
		reach = _spin_r * minf(1.0, since / (SPIN_TIME * 0.25))
	var dir := Vector2.from_angle(angle)
	var tip := center + dir * reach
	# Rastro da ponta: arco atrás da foice durante a volta.
	if since <= SPIN_TIME:
		var tail := minf(1.6, angle - _spin_start)
		Stroke.arc(canvas, center, reach, angle - tail, angle, 18, Color(COLOR, 0.35), 3.0)
		Stroke.arc(canvas, center, reach, angle - tail * 0.5, angle, 10, Color(HOT, 0.6), 1.0)
	Stroke.line(canvas, PackedVector2Array([center.round(), tip.round()]), Color(0.08, 0.06, 0.06, 0.85), 3.0)
	for k: int in range(CHAIN_LINKS):
		var p := center.lerp(tip, (k + 0.5) / CHAIN_LINKS)
		var c := Color(0.78, 0.74, 0.72) if k % 2 == 0 else HOT
		canvas.draw_rect(Rect2((p - Vector2(1, 1)).round(), Vector2(2, 2)), c)
	var side := dir.orthogonal()
	Stroke.convex(canvas, PackedVector2Array([tip - dir * 3.0, tip + side * 10.0 + dir * 3.0, tip + dir * 4.0]),
			Color(0.9, 0.9, 0.95))
	Stroke.line(canvas, PackedVector2Array([(tip - dir * 2.0).round(), (tip + side * 10.0 + dir * 3.0).round()]),
			Color(HOT, 0.9), 1.0)


## Brilho (Alta): martelo e chão em brasa, estouro pendente, ponta da corrente e o Tora temperado.
func draw_glow(canvas: CanvasItem) -> void:
	var t := GameClock.game_time
	for h: Dictionary in _hammers:
		FxLayer.draw_soft(canvas, _hammer_point(h, GameClock.alpha) + Vector2(0.0, -5.0), 14.0, Color(COLOR, 0.7))
	for m: Dictionary in _marks:
		var fade := clampf(float(m["life"]) / 0.5, 0.0, 1.0)
		FxLayer.draw_soft(canvas, m["pos"], float(m["r"]) * 0.7, Color(COLOR, 0.25 * fade))
	for b: Dictionary in _blasts:
		FxLayer.draw_soft(canvas, b["pos"], float(b["r"]) * 1.1, Color(COLOR, 0.3 + 0.1 * sin(t * 30.0)))
	if _quench_time > 0.0:
		var fade := clampf(_quench_time / 0.5, 0.0, 1.0)
		FxLayer.draw_soft(canvas, game.player.position + Vector2(0.0, -6.0), 20.0,
				Color(COLOR, (0.3 + 0.08 * sin(t * 7.0)) * fade))
