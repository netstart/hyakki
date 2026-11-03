class_name AkiAbilities
extends HeroAbilities
## Aki, a última guardiã da Ordem (energia: Chama da Ordem, 灯火). Referência para os outros
## heróis (HeroAbilities explica o contrato):
##   1. 暁閃 Passo da Aurora: avanço na direção do movimento, invencível, cortando todos no
##      caminho uma vez cada; deixa um rastro de luz (só desenho).
##   2. 灯籠結界 Muralha da Lanterna: anel de luz em volta dela, que nasce varrendo para fora;
##      apaga os tiros que tocam o anel, queima quem está na borda e empurra para fora quem entra.
##   3. 百年の焔 Chama de Cem Anos: a chama voa até o maior grupo; depois de `delay` s, coluna de
##      fogo e chão em brasa que queima a cada `ground_tick` s.
## Efeitos persistentes (anel, chamas no ar, chão em brasa) vão no save da partida suspensa e no
## hash. O avanço dura um instante e não é salvo (a partida suspensa volta parada).

const COLOR := Color(1.0, 0.70, 0.28)
const HOT := Color(1.0, 0.95, 0.78)
const FLAME := Color(1.0, 0.42, 0.12)
const EMBER := Color(1.0, 0.62, 0.2)
## Rastro de luz do avanço (só desenho) e quantos ficam ao mesmo tempo.
const MAX_TRAILS := 6
## Lanternas de papel girando no anel: quantas e a volta por segundo (rad).
const WALL_LANTERNS := 8
const WALL_SPIN := 1.6
## Altura do arco da chama até o alvo (px) e a cota de brasas soltas por passo no voo.
const FLAME_ARC := 46.0
## Brasas por tique do chão em brasa em cada nível gráfico (FxLayer.wfx).
const GROUND_EMBERS: Array[int] = [1, 3, 5]

# Passo da Aurora (avanço em curso).
var _dash_active: bool = false
var _dash_last := Vector2.ZERO
var _dash_damage: float = 0.0
var _dash_width: float = 0.0
var _dash_force: float = 0.0
var _dash_ability: Dictionary = {}
var _dash_hit: Dictionary = {}
## Rastros (só desenho): {"a", "b", "life", "max"}.
var _trails: Array[Dictionary] = []
# Muralha da Lanterna.
var _wall_time: float = 0.0
var _wall_max: float = 0.0
var _wall_radius: float = 0.0
var _wall_grow: float = 0.2
var _wall_burn: float = 0.0
var _wall_tick: float = 0.25
var _wall_tick_left: float = 0.0
var _wall_band: float = 10.0
var _wall_push: float = 140.0
var _wall_r_now: float = 0.0
## Chamas no ar: {"from", "to", "left", "max", "r", "damage", "force", "g_time", "g_damage", "g_tick"}.
var _flames: Array[Dictionary] = []
## Chão em brasa: {"pos", "r", "life", "max", "tick", "tick_left", "damage"}.
var _grounds: Array[Dictionary] = []


func reset() -> void:
	_dash_active = false
	_dash_hit.clear()
	_trails.clear()
	_wall_time = 0.0
	_wall_r_now = 0.0
	_flames.clear()
	_grounds.clear()


func cast(slot: int, ability: Dictionary, power: float) -> bool:
	match StringName(ability["id"]):
		&"dawn_step":
			return _cast_dawn_step(ability, power)
		&"lantern_wall":
			return _cast_wall(ability, power)
		&"century_flame":
			return _cast_flame(ability, power)
	return super.cast(slot, ability, power)


func step(dt: float) -> void:
	if _dash_active:
		_step_dash()
	for k: int in range(_trails.size() - 1, -1, -1):
		_trails[k]["life"] = float(_trails[k]["life"]) - dt
		if float(_trails[k]["life"]) <= 0.0:
			_trails.remove_at(k)
	if _wall_time > 0.0:
		_step_wall(dt)
	if not _flames.is_empty():
		_step_flames(dt)
	if not _grounds.is_empty():
		_step_grounds(dt)


# --- 暁閃 Passo da Aurora -------------------------------------------------------------------

func _cast_dawn_step(ability: Dictionary, power: float) -> bool:
	var player := game.player
	var dir := player.aim_direction(Player.Aim.MOVE)
	var from := player.sim_pos
	player.dash(dir, param(ability, "distance", 90.0), param(ability, "dash_time", 0.16), param(ability, "invuln", 0.12))
	_dash_active = true
	_dash_last = from
	_dash_damage = dmg(ability, "damage", power)
	_dash_width = area_of(ability, "width")
	_dash_force = param(ability, "knockback", 90.0)
	_dash_ability = ability
	_dash_hit.clear()
	_add_trail(from, from, param(ability, "trail_time", 0.8))
	var fx := game.fx
	fx.flash(from, 26.0, Color(HOT, 0.9), 0.14)
	fx.sparks(from, -dir, COLOR, [4, 8, 14][FxLayer.wfx], 150.0, 0.5, 0.25)
	fx.play_anim("boost", from, 0.7, dir.angle() - PI * 0.5, Color(1.0, 0.85, 0.5), 30.0, false, true)
	punch(1.2, 25)
	return true


## Corta todos no trecho andado neste passo (uma vez cada) e estica o rastro.
func _step_dash() -> void:
	var player := game.player
	var now := player.sim_pos
	if now != _dash_last:
		hit_segment(&"dawn_step", _dash_last, now, _dash_width, _dash_damage, _dash_force, _dash_hit)
		if not _trails.is_empty():
			_trails[-1]["b"] = now
		game.fx.motes((_dash_last + now) * 0.5, COLOR, [0, 2, 3][FxLayer.wfx], 4.0, 30.0)
		_dash_last = now
	if player.is_dashing():
		return
	_dash_active = false
	var dir := player.facing
	game.fx.play_anim("slash_double", now + dir * 6.0, 1.1, dir.angle(), Color(1.0, 0.9, 0.6), 24.0, false, true)
	game.fx.add_ring(now, 26.0, COLOR, 0.3)
	if not _dash_hit.is_empty():
		game.fx.flash(now, 30.0, Color(COLOR, 0.8), 0.12)
		impact_sfx(_dash_ability)
		punch(1.5, 20)


func _add_trail(a: Vector2, b: Vector2, life: float) -> void:
	if _trails.size() >= MAX_TRAILS:
		_trails.pop_front()
	_trails.append({"a": a, "b": b, "life": life, "max": life})


# --- 灯籠結界 Muralha da Lanterna --------------------------------------------------------------

func _cast_wall(ability: Dictionary, power: float) -> bool:
	_wall_max = dur(ability, "time")
	_wall_time = _wall_max
	_wall_radius = area_of(ability, "radius")
	_wall_grow = maxf(param(ability, "grow_time", 0.2), GameClock.STEP)
	_wall_burn = dmg(ability, "burn", power)
	_wall_tick = maxf(param(ability, "tick", 0.25), GameClock.STEP)
	_wall_tick_left = 0.0
	_wall_band = area_of(ability, "band")
	_wall_push = param(ability, "push", 140.0)
	_wall_r_now = 0.0
	var at := game.player.sim_pos
	var fx := game.fx
	fx.shockwave(at, _wall_radius, COLOR, 1.2, 0.4)
	fx.flash(at, _wall_radius * 0.6, Color(COLOR, 0.7), 0.25)
	fx.play_anim("circle_orange", at, _wall_radius / 14.0, 0.0, Color(1.0, 0.9, 0.7, 0.85), 18.0)
	if FxLayer.glow:
		fx.play_anim("circle_spark", at, _wall_radius / 12.0, 0.0, COLOR.lerp(Color.WHITE, 0.3), 16.0, false, true)
	fx.dust(at, _wall_radius * 0.5, Color(COLOR, 0.8), [6, 12, 20][FxLayer.wfx], 90.0)
	punch(1.8, 35)
	return true


## O anel nasce varrendo para fora em `grow_time` s e segue a Aki: apaga os tiros na faixa
## (enquanto cresce, tudo o que ele varre), empurra para fora quem entra e queima a borda.
func _step_wall(dt: float) -> void:
	_wall_time -= dt
	var age := _wall_max - _wall_time
	var prev_r := _wall_r_now
	_wall_r_now = _wall_radius * _ease_out(clampf(age / _wall_grow, 0.0, 1.0))
	var r := _wall_r_now
	var center := game.player.sim_pos
	var half := _wall_band * 0.5
	var shots := game.enemy_shots
	if shots.clear_circle(center, r + half, maxf(0.0, minf(prev_r, r) - half)) > 0:
		for at: Vector2 in shots.cleared:
			game.fx.sparks(at, at - center, HOT, [1, 3, 5][FxLayer.wfx], 80.0, 0.8, 0.2)
			game.fx.flash(at, 8.0, Color(COLOR, 0.8), 0.1)
	game.enemies.push_out_of(center, maxf(0.0, r - half), _wall_push)
	_wall_tick_left -= dt
	if _wall_tick_left <= 0.0:
		_wall_tick_left += _wall_tick
		_burn_band(center, r, half)
	if _wall_time <= 0.0:
		_wall_time = 0.0
		game.fx.add_ring(center, r * 1.15, COLOR, 0.35)
		game.fx.dust(center, r, Color(COLOR, 0.7), [4, 8, 14][FxLayer.wfx], 30.0)


## Queima quem está na faixa da borda (de r − meia faixa até r + faixa inteira).
func _burn_band(center: Vector2, r: float, half: float) -> void:
	var enemies := game.enemies
	enemies.query_circle(center, r + _wall_band, _hits)
	for j: int in _hits.duplicate():
		if enemies.alive[j] == 0 or enemies.is_prop(j):
			continue
		var d := enemies.pos[j] - center
		if d.length() + enemies.radius[j] < r - half:
			continue
		hit(&"lantern_wall", j, _wall_burn, d.normalized(), 30.0, true)
		if FxLayer.wfx > 0:
			game.fx.embers(enemies.pos[j], EMBER, 1)


# --- 百年の焔 Chama de Cem Anos ----------------------------------------------------------------

func _cast_flame(ability: Dictionary, power: float) -> bool:
	var player := game.player
	var from := player.hand_position()
	var r := area_of(ability, "radius")
	var reach := param(ability, "reach", 160.0)
	var target := game.enemies.densest_point(player.sim_pos, reach, r)
	if target == Vector2.INF:
		target = player.sim_pos + player.aim_direction() * reach * 0.5
	var delay := maxf(param(ability, "delay", 0.5), GameClock.STEP)
	_flames.append({"from": from, "to": target, "left": delay, "max": delay, "r": r,
			"damage": dmg(ability, "damage", power), "force": param(ability, "knockback", 70.0),
			"g_time": dur(ability, "ground_time"), "g_damage": dmg(ability, "ground_damage", power),
			"g_tick": maxf(param(ability, "ground_tick", 0.5), GameClock.STEP), "sfx": String(ability.get("sfx", ""))})
	var dir := (target - from).normalized()
	game.fx.flash(from, 18.0, Color(FLAME, 0.9), 0.15)
	game.fx.sparks(from, dir, EMBER, [3, 6, 10][FxLayer.wfx], 120.0, 0.6, 0.2)
	game.fx.play_anim("flame", from, 0.9, 0.0, Color(1.0, 0.8, 0.5))
	punch(0.8, 15)
	return true


func _step_flames(dt: float) -> void:
	var landed: Array[Dictionary] = []
	for flame: Dictionary in _flames:
		flame["left"] = float(flame["left"]) - dt
		if float(flame["left"]) <= 0.0:
			landed.append(flame)
		elif FxLayer.wfx > 0:
			game.fx.embers(_flame_point(flame, 0.0), EMBER, FxLayer.wfx, 2.0)
	for flame: Dictionary in landed:
		_flames.erase(flame)
		_explode(flame)


## Coluna de fogo no alvo e o chão em brasa.
func _explode(flame: Dictionary) -> void:
	var at: Vector2 = flame["to"]
	var r := float(flame["r"])
	hit_circle(&"century_flame", at, r, float(flame["damage"]), float(flame["force"]))
	_grounds.append({"pos": at, "r": r, "life": float(flame["g_time"]), "max": float(flame["g_time"]),
			"tick": float(flame["g_tick"]), "tick_left": float(flame["g_tick"]), "damage": float(flame["g_damage"])})
	var fx := game.fx
	fx.play_anim("explosion", at, r / 18.0, 0.0, Color(1.0, 0.75, 0.45))
	fx.play_anim("flame", at + Vector2(0, -r * 0.35), r / 11.0, 0.0, Color(1.0, 0.85, 0.6), 14.0, false, FxLayer.glow)
	for k: int in range([2, 4, 6][FxLayer.wfx]):
		var off := Vector2.from_angle(TAU * k / float([2, 4, 6][FxLayer.wfx])) * r * 0.55
		fx.play_anim("flame", at + off, r / 30.0, 0.0, Color(1.0, 0.7, 0.4), 18.0)
	fx.shockwave(at, r * 1.4, FLAME, 1.5, 0.5)
	fx.flash(at, r * 1.2, Color(FLAME, 0.95), 0.3)
	fx.sparks(at, Vector2.UP, HOT, [8, 18, 30][FxLayer.wfx], 200.0, PI, 0.4)
	fx.embers(at, EMBER, [6, 14, 24][FxLayer.wfx], r * 0.5)
	play_sfx(String(flame.get("sfx", "")) + "_hit")
	punch(3.0, 60)


func _step_grounds(dt: float) -> void:
	for ground: Dictionary in _grounds:
		ground["life"] = float(ground["life"]) - dt
		ground["tick_left"] = float(ground["tick_left"]) - dt
		if float(ground["tick_left"]) <= 0.0:
			ground["tick_left"] = float(ground["tick_left"]) + float(ground["tick"])
			var at: Vector2 = ground["pos"]
			var r := float(ground["r"])
			hit_circle(&"century_flame", at, r, float(ground["damage"]), 0.0, true)
			for _k: int in range(GROUND_EMBERS[FxLayer.wfx]):
				game.fx.embers(at + Vector2.from_angle(randf() * TAU) * randf() * r * 0.8, EMBER, 1, 2.0)
	for k: int in range(_grounds.size() - 1, -1, -1):
		if float(_grounds[k]["life"]) <= 0.0:
			_grounds.remove_at(k)


## Ponto da chama no voo (arco), `ahead` = fração do passo seguinte (desenho interpolado).
func _flame_point(flame: Dictionary, ahead: float) -> Vector2:
	var total := float(flame["max"])
	var k := clampf((total - float(flame["left"]) + ahead * GameClock.STEP) / total, 0.0, 1.0)
	var from: Vector2 = flame["from"]
	var to: Vector2 = flame["to"]
	return from.lerp(to, k) + Vector2(0.0, -FLAME_ARC * 4.0 * k * (1.0 - k))


static func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


# --- Bot, save e hash --------------------------------------------------------------------------

## Passo da Aurora só correndo (avança para onde já ia); os outros, pela regra do JSON.
func bot_should_cast(slot: int, ability: Dictionary) -> bool:
	if StringName(ability["id"]) == &"dawn_step" and game.player.move_input.length_squared() < 0.01:
		return false
	if StringName(ability["id"]) == &"lantern_wall" and _wall_time > 0.0:
		return false
	return super.bot_should_cast(slot, ability)


func state() -> Dictionary:
	var flames: Array = []
	for f: Dictionary in _flames:
		var row := f.duplicate()
		row["from"] = vec(f["from"])
		row["to"] = vec(f["to"])
		flames.append(row)
	var grounds: Array = []
	for g: Dictionary in _grounds:
		var row := g.duplicate()
		row["pos"] = vec(g["pos"])
		grounds.append(row)
	return {"wall": [_wall_time, _wall_max, _wall_radius, _wall_grow, _wall_burn, _wall_tick, _wall_tick_left,
			_wall_band, _wall_push], "flames": flames, "grounds": grounds}


func load_state(s: Dictionary) -> void:
	reset()
	var wall: Array = s.get("wall", [])
	if wall.size() >= 9:
		_wall_time = float(wall[0])
		_wall_max = float(wall[1])
		_wall_radius = float(wall[2])
		_wall_grow = maxf(float(wall[3]), GameClock.STEP)
		_wall_burn = float(wall[4])
		_wall_tick = maxf(float(wall[5]), GameClock.STEP)
		_wall_tick_left = float(wall[6])
		_wall_band = float(wall[7])
		_wall_push = float(wall[8])
		_wall_r_now = _wall_radius if _wall_max - _wall_time >= _wall_grow else 0.0
	for row: Variant in s.get("flames", []):
		var f: Dictionary = (row as Dictionary).duplicate()
		f["from"] = to_vec(f.get("from"))
		f["to"] = to_vec(f.get("to"))
		_flames.append(f)
	for row: Variant in s.get("grounds", []):
		var g: Dictionary = (row as Dictionary).duplicate()
		g["pos"] = to_vec(g.get("pos"))
		_grounds.append(g)


func hash_tag() -> String:
	var tag := " aki=%.3f,%d,%d" % [_wall_time, _flames.size(), _grounds.size()]
	for g: Dictionary in _grounds:
		tag += ",%.1f:%.1f" % [(g["pos"] as Vector2).x, (g["pos"] as Vector2).y]
	return tag


# --- Desenho (só leitura) -------------------------------------------------------------------

func has_visuals() -> bool:
	return _dash_active or not _trails.is_empty() or _wall_time > 0.0 or not _flames.is_empty() \
			or not _grounds.is_empty()


## Chão em brasa (disco queimado, borda tremulando e brasas acesas) e o alvo da chama.
func draw_ground(canvas: CanvasItem) -> void:
	var t := GameClock.game_time
	for g: Dictionary in _grounds:
		var at: Vector2 = g["pos"]
		var r := float(g["r"])
		var fade := clampf(float(g["life"]) / 0.6, 0.0, 1.0) * clampf((float(g["max"]) - float(g["life"])) / 0.15, 0.0, 1.0)
		canvas.draw_circle(at, r, Color(0.16, 0.05, 0.02, 0.45 * fade))
		canvas.draw_circle(at, r * 0.7, Color(0.45, 0.12, 0.03, 0.3 * fade))
		var flicker := 0.75 + 0.25 * sin(t * 13.0 + at.x)
		bold_ring(canvas, at, r, Color(FLAME, 0.85 * flicker), Color(EMBER, 0.9), fade, 2.0)
		for k: int in range(10):
			var a := TAU * k / 10.0 + float(k * 37 % 11)
			var p := at + Vector2.from_angle(a) * r * (0.25 + 0.6 * fmod(k * 0.618, 1.0))
			var glow := 0.5 + 0.5 * sin(t * 7.0 + k * 1.7)
			canvas.draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(EMBER, (0.35 + 0.55 * glow) * fade))
	for f: Dictionary in _flames:
		var to: Vector2 = f["to"]
		var k := 1.0 - float(f["left"]) / float(f["max"])
		var r := float(f["r"])
		# Aviso no chão: anel que fecha até o raio da coluna.
		bold_ring(canvas, to, lerpf(r * 1.6, r, k), FLAME, HOT, 0.45 + 0.55 * k, 2.0)
		canvas.draw_circle(to, r * k, Color(FLAME, 0.12 * k))


## Anel da muralha (segue a Aki), lanternas girando, a chama no ar e o rastro do avanço.
func draw_over(canvas: CanvasItem) -> void:
	var t := GameClock.game_time
	for trail: Dictionary in _trails:
		var k := float(trail["life"]) / float(trail["max"])
		var a: Vector2 = trail["a"]
		var b: Vector2 = trail["b"]
		canvas.draw_line(a.round(), b.round(), Color(RING_SHADOW, 0.45 * k), 4.0 * k + 3.0)
		canvas.draw_line(a.round(), b.round(), Color(COLOR, 0.75 * k), 4.0 * k + 1.0)
		canvas.draw_line(a.round(), b.round(), Color(HOT, 0.95 * k), 1.0)
	if _wall_time > 0.0:
		var center := game.player.position
		var r := _wall_r_now
		var fade := clampf(_wall_time / 0.3, 0.0, 1.0)
		var pulse := 0.8 + 0.2 * sin(t * 10.0)
		var segments := clampi(int(r * 0.7), 24, 64)
		bold_ring(canvas, center, r, Color(COLOR, 0.95 * pulse), HOT, fade)
		Stroke.arc(canvas, center, r - 4.0, 0.0, TAU, segments, Color(HOT, 0.35 * fade), 1.0)
		if FxLayer.wfx > 0:
			Stroke.arc(canvas, center, r + 3.0, 0.0, TAU, segments, Color(FLAME, 0.3 * fade), 1.0)
		for k: int in range(WALL_LANTERNS):
			var p := center + Vector2.from_angle(TAU * k / WALL_LANTERNS + t * WALL_SPIN) * r
			canvas.draw_rect(Rect2((p - Vector2(1.5, 2.0)).round(), Vector2(3, 4)), Color(1.0, 0.86, 0.5, fade))
			canvas.draw_rect(Rect2((p - Vector2(0.5, 1.0)).round(), Vector2(1, 2)), Color(1.0, 1.0, 0.9, fade))
	for f: Dictionary in _flames:
		var p := _flame_point(f, GameClock.alpha)
		canvas.draw_circle(p, 4.0, Color(FLAME, 0.75))
		canvas.draw_circle(p, 2.0, Color(HOT, 0.95))


## Brilho (Alta): halos nas lanternas do anel, na chama no ar e sobre o chão em brasa.
func draw_glow(canvas: CanvasItem) -> void:
	var t := GameClock.game_time
	if _wall_time > 0.0:
		var center := game.player.position
		var fade := clampf(_wall_time / 0.3, 0.0, 1.0)
		for k: int in range(WALL_LANTERNS):
			var p := center + Vector2.from_angle(TAU * k / WALL_LANTERNS + t * WALL_SPIN) * _wall_r_now
			FxLayer.draw_soft(canvas, p, 7.0, Color(COLOR, 0.5 * fade))
	for f: Dictionary in _flames:
		FxLayer.draw_soft(canvas, _flame_point(f, GameClock.alpha), 12.0, Color(FLAME, 0.8))
	for g: Dictionary in _grounds:
		var fade := clampf(float(g["life"]) / 0.6, 0.0, 1.0)
		FxLayer.draw_soft(canvas, g["pos"], float(g["r"]) * 1.1, Color(FLAME, 0.22 * fade * (0.85 + 0.15 * sin(t * 9.0))))
