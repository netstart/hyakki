class_name KentaAbilities
extends HeroAbilities
## Kenta, o ninja que traiu o próprio contrato (energia: Sombra, 影). Fumaça roxa, sombra e aço
## (HeroAbilities explica o contrato; aki_abilities.gd é a referência):
##   1. 瞬身 Passo Sombrio: teleporte na direção do movimento, cortando quem ficou no caminho
##      (uma vez cada); na origem fica uma nuvem de fumaça que deixa lentos e a silhueta
##      residual dele (só desenho) esticada até o destino.
##   2. 変わり身 Troca de Corpo: Kenta salta e deixa um tronco no lugar; os yōkai até
##      `lure_radius` perseguem o tronco (isca) por `lure_time` s, e então ele explode em
##      estilhaços de madeira e fumaça. Kenta fica invencível `invuln` s.
##   3. 撒菱 Chuva de Makibishi: espalha `count` estrepes de ferro no chão em volta (sorteio do
##      game.rng); quem pisa leva dano e fica lento (cada estrepe pisa a cada CALTROP_TICK s); e
##      solta `kunai` kunai em círculo que atravessam todos (uma vez cada).
## Efeitos persistentes (fumaça, tronco, estrepes, kunai no ar) vão no save da partida suspensa e
## no hash. A silhueta residual, as farpas e as faíscas são só desenho.

const COLOR := Color(0.56, 0.49, 0.94)
const DEEP := Color(0.2, 0.13, 0.36)
const HOT := Color(0.9, 0.86, 1.0)
const SMOKE := Color(0.42, 0.33, 0.62)
const STEEL := Color(0.7, 0.72, 0.8)
const STEEL_DARK := Color(0.2, 0.2, 0.26)
const WOOD := Color(0.58, 0.38, 0.2)
const WOOD_DARK := Color(0.33, 0.2, 0.1)
const WOOD_END := Color(0.85, 0.66, 0.42)
## Silhueta residual do Passo Sombrio (s) e quantos vultos ficam no caminho.
const GHOST_TIME := 0.7
const GHOST_COPIES := 3
const MAX_GHOSTS := 4
## A fumaça reaplica a lentidão a cada SMOKE_TICK s (por SMOKE_HOLD s a quem ainda está nela).
const SMOKE_TICK := 0.25
const SMOKE_HOLD := 0.5
## Tronco: reaplica a isca a cada LURE_TICK s; treme e pisca nos últimos FUSE_TIME s.
const LURE_TICK := 0.5
const FUSE_TIME := 0.6
## Estrepes: voo até o chão (s), intervalo entre pisadas, raio de cada um (× "area").
const CALTROP_LAND := 0.18
const CALTROP_TICK := 0.4
const CALTROP_RADIUS := 6.0
## Kunai: velocidade (px/s), meia-largura do golpe e o alcance × raio da chuva.
const KUNAI_SPEED := 420.0
const KUNAI_WIDTH := 5.0
const KUNAI_REACH := 1.35

# Passo Sombrio: nuvens de fumaça {"pos", "r", "life", "max", "slow", "tick_left"}.
var _smokes: Array[Dictionary] = []
## Silhuetas residuais (só desenho): {"from", "to", "dir", "life"}.
var _ghosts: Array[Dictionary] = []
# Troca de Corpo (um tronco por vez).
var _log_time: float = 0.0
var _log_max: float = 0.0
var _log_pos := Vector2.ZERO
var _log_lure: float = 0.0
var _log_r: float = 0.0
var _log_damage: float = 0.0
var _log_force: float = 0.0
var _log_tick_left: float = 0.0
var _log_sfx: String = ""
## Estrepes: {"pos", "from", "age", "life", "max", "tick_left", "r", "damage", "slow", "slow_time"}.
var _caltrops: Array[Dictionary] = []
## Kunai no ar: {"pos", "dir", "dist", "max", "damage", "hit"}.
var _kunai: Array[Dictionary] = []


func reset() -> void:
	_smokes.clear()
	_ghosts.clear()
	_log_time = 0.0
	_caltrops.clear()
	_kunai.clear()


func cast(slot: int, ability: Dictionary, power: float) -> bool:
	match StringName(ability["id"]):
		&"shadow_step":
			return _cast_shadow_step(ability, power)
		&"kawarimi":
			return _cast_kawarimi(ability, power)
		&"makibishi":
			return _cast_makibishi(ability, power)
	return super.cast(slot, ability, power)


func step(dt: float) -> void:
	for k: int in range(_ghosts.size() - 1, -1, -1):
		_ghosts[k]["life"] = float(_ghosts[k]["life"]) - dt
		if float(_ghosts[k]["life"]) <= 0.0:
			_ghosts.remove_at(k)
	if not _smokes.is_empty():
		_step_smokes(dt)
	if _log_time > 0.0:
		_step_log(dt)
	if not _kunai.is_empty():
		_step_kunai(dt)
	if not _caltrops.is_empty():
		_step_caltrops(dt)


# --- 瞬身 Passo Sombrio ----------------------------------------------------------------------

func _cast_shadow_step(ability: Dictionary, power: float) -> bool:
	var player := game.player
	var dir := player.aim_direction(Player.Aim.MOVE)
	var from := player.sim_pos
	var to := player.blink(dir, param(ability, "distance", 110.0), param(ability, "invuln", 0.25))
	var cut := hit_segment(&"shadow_step", from, to, area_of(ability, "width"), dmg(ability, "damage", power),
			param(ability, "knockback", 60.0), {})
	var r := area_of(ability, "smoke_radius")
	var hold := dur(ability, "slow_time")
	var slow := param(ability, "slow", 0.5)
	game.enemies.slow_circle(from, r, slow, hold)
	_smokes.append({"pos": from, "r": r, "life": hold, "max": hold, "slow": slow, "tick_left": SMOKE_TICK})
	if _ghosts.size() >= MAX_GHOSTS:
		_ghosts.pop_front()
	_ghosts.append({"from": from, "to": to, "dir": dir, "life": GHOST_TIME})
	var fx := game.fx
	# Origem: estouro de fumaça roxa; destino: corte em X de aço e faíscas para trás.
	fx.play_anim("smoke_circular", from, r / 15.0, 0.0, Color(0.6, 0.5, 0.95, 0.6), 18.0)
	fx.play_anim("smoke", from + Vector2(0, -4), r / 20.0, 0.0, Color(0.5, 0.4, 0.85, 0.55), 16.0)
	fx.dust(from, r * 0.4, Color(SMOKE, 0.8), [4, 8, 14][FxLayer.wfx], 50.0)
	fx.flash(to, 22.0, Color(COLOR, 0.85), 0.12)
	fx.sparks(to, -dir, HOT, [3, 7, 12][FxLayer.wfx], 160.0, 0.45, 0.2)
	fx.play_anim("cut_x", to + dir * 4.0, 0.9, dir.angle(), Color(0.85, 0.8, 1.0), 26.0, false, true)
	fx.motes((from + to) * 0.5, COLOR, [0, 4, 8][FxLayer.wfx], from.distance_to(to) * 0.4, 20.0)
	if cut > 0:
		impact_sfx(ability)
		punch(1.6, 25)
	else:
		punch(0.8, 15)
	return true


## A fumaça segura a lentidão de quem ainda está nela e solta fiapos roxos.
func _step_smokes(dt: float) -> void:
	for smoke: Dictionary in _smokes:
		smoke["life"] = float(smoke["life"]) - dt
		smoke["tick_left"] = float(smoke["tick_left"]) - dt
		if float(smoke["tick_left"]) <= 0.0:
			smoke["tick_left"] = float(smoke["tick_left"]) + SMOKE_TICK
			game.enemies.slow_circle(smoke["pos"], float(smoke["r"]), float(smoke["slow"]), SMOKE_HOLD)
			if FxLayer.wfx > 0:
				var at: Vector2 = smoke["pos"]
				game.fx.embers(at, SMOKE, FxLayer.wfx, float(smoke["r"]) * 0.6)
	for k: int in range(_smokes.size() - 1, -1, -1):
		if float(_smokes[k]["life"]) <= 0.0:
			_smokes.remove_at(k)


# --- 変わり身 Troca de Corpo -------------------------------------------------------------------

func _cast_kawarimi(ability: Dictionary, power: float) -> bool:
	var player := game.player
	var at := player.sim_pos
	var dir := player.aim_direction(Player.Aim.MOVE)
	player.blink(dir, param(ability, "hop", 36.0), param(ability, "invuln", 1.0))
	player.invuln = maxf(player.invuln, param(ability, "invuln", 1.0))
	_log_max = dur(ability, "lure_time")
	_log_time = _log_max
	_log_pos = at
	_log_lure = area_of(ability, "lure_radius")
	_log_r = area_of(ability, "radius")
	_log_damage = dmg(ability, "damage", power)
	_log_force = param(ability, "knockback", 160.0)
	_log_tick_left = LURE_TICK
	_log_sfx = String(ability.get("sfx", ""))
	game.enemies.lure_circle(at, _log_lure, at, _log_time)
	var fx := game.fx
	# Puf: Kenta some na fumaça e o tronco aparece no lugar; onda roxa marca a área da isca.
	fx.play_anim("smoke_circular", at, 1.6, 0.0, Color(0.75, 0.65, 1.0, 0.9), 20.0)
	fx.play_anim("smoke", player.sim_pos, 0.9, 0.0, Color(0.6, 0.5, 0.9, 0.8), 18.0)
	fx.add_ring(at, _log_lure, Color(COLOR, 0.55), 0.6, 1.0)
	fx.shockwave(at, 40.0, COLOR, 0.8, 0.35)
	fx.dust(at, 10.0, Color(WOOD_END, 0.9), [3, 6, 10][FxLayer.wfx], 40.0)
	punch(1.0, 20)
	return true


## A isca puxa quem chega ao alcance; no fim, o tronco explode.
func _step_log(dt: float) -> void:
	_log_time -= dt
	_log_tick_left -= dt
	if _log_tick_left <= 0.0 and _log_time > 0.0:
		_log_tick_left += LURE_TICK
		game.enemies.lure_circle(_log_pos, _log_lure, _log_pos, _log_time)
	if _log_time < FUSE_TIME and FxLayer.wfx > 0 and game.step_index % 4 == 0:
		game.fx.sparks(_log_pos + Vector2(6, -3), Vector2.UP, HOT, FxLayer.wfx, 60.0, 0.8, 0.15)
	if _log_time <= 0.0:
		_log_time = 0.0
		_explode_log()


func _explode_log() -> void:
	var at := _log_pos
	var r := _log_r
	hit_circle(&"kawarimi", at, r, _log_damage, _log_force)
	var fx := game.fx
	fx.play_anim("explosion", at, r / 20.0, 0.0, Color(0.85, 0.75, 1.0))
	fx.play_anim("smoke_circular", at, r / 13.0, 0.0, Color(0.6, 0.5, 0.9, 0.85), 16.0)
	for k: int in range([2, 4, 6][FxLayer.wfx]):
		var off := Vector2.from_angle(TAU * k / float([2, 4, 6][FxLayer.wfx]) + 0.4) * r * 0.5
		fx.play_anim("smoke", at + off, r / 34.0, 0.0, Color(0.55, 0.45, 0.85, 0.75), 14.0)
	# Estilhaços de madeira (farpas claras e escuras) e lascas de aço roxas.
	fx.sparks(at, Vector2.UP, WOOD_END, [8, 16, 26][FxLayer.wfx], 230.0, PI, 0.35)
	fx.sparks(at, Vector2.DOWN, WOOD, [4, 10, 16][FxLayer.wfx], 180.0, PI, 0.3)
	fx.dust(at, r * 0.3, Color(WOOD_DARK, 0.95), [6, 12, 20][FxLayer.wfx], 140.0)
	fx.dust(at, r * 0.15, Color(WOOD_END, 0.95), [4, 10, 16][FxLayer.wfx], 110.0)
	fx.motes(at, COLOR, [0, 6, 12][FxLayer.wfx], r * 0.5, 40.0)
	fx.shockwave(at, r * 1.3, COLOR, 1.4, 0.45)
	fx.flash(at, r, Color(HOT, 0.9), 0.22)
	play_sfx(_log_sfx + "_hit")
	punch(2.6, 50)


# --- 撒菱 Chuva de Makibishi ----------------------------------------------------------------

func _cast_makibishi(ability: Dictionary, power: float) -> bool:
	var player := game.player
	var from := player.sim_pos
	var count := maxi(1, int(param(ability, "count", 12.0)))
	var r := area_of(ability, "radius")
	var life := dur(ability, "time")
	var damage := dmg(ability, "damage", power)
	var slow := param(ability, "slow", 0.4)
	var slow_time := dur(ability, "slow_time")
	var hit_r := CALTROP_RADIUS * game.player.stats.get_stat("area")
	var rng := game.rng
	for k: int in range(count):
		var a := TAU * k / float(count) + rng.randf_range(-0.25, 0.25)
		var d := r * sqrt(rng.randf_range(0.12, 1.0))
		var at := game.world.clamp_to_bounds(from + Vector2.from_angle(a) * d)
		# Pisadas defasadas (k % 4) para os estrepes não picarem todos no mesmo passo.
		_caltrops.append({"pos": at, "from": from, "age": 0.0, "life": life, "max": life,
				"tick_left": CALTROP_LAND + CALTROP_TICK * 0.25 * (k % 4), "r": hit_r, "damage": damage,
				"slow": slow, "slow_time": slow_time})
	var kunai := int(param(ability, "kunai", 8.0))
	var base := player.facing.angle()
	for k: int in range(kunai):
		var dir := Vector2.from_angle(base + TAU * k / float(maxi(kunai, 1)))
		_kunai.append({"pos": from, "dir": dir, "dist": 0.0, "max": r * KUNAI_REACH,
				"damage": dmg(ability, "kunai_damage", power), "hit": {}})
	var fx := game.fx
	fx.play_anim("smoke_circular", from, 1.2, 0.0, Color(0.55, 0.45, 0.9, 0.6), 20.0)
	fx.shockwave(from, r * 0.6, COLOR, 0.9, 0.35)
	fx.sparks(from, Vector2.UP, STEEL, [4, 10, 16][FxLayer.wfx], 200.0, PI, 0.2)
	fx.flash(from, 20.0, Color(COLOR, 0.8), 0.12)
	punch(1.2, 20)
	return true


## Kunai voando para fora: cortam todos no trecho (uma vez cada) até o alcance.
func _step_kunai(dt: float) -> void:
	for k: int in range(_kunai.size() - 1, -1, -1):
		var kn := _kunai[k]
		var a: Vector2 = kn["pos"]
		var dir: Vector2 = kn["dir"]
		var move := minf(KUNAI_SPEED * dt, float(kn["max"]) - float(kn["dist"]))
		var b := a + dir * move
		if hit_segment(&"makibishi", a, b, KUNAI_WIDTH, float(kn["damage"]), 50.0, kn["hit"]) > 0 and FxLayer.wfx > 0:
			game.fx.sparks(b, dir, HOT, FxLayer.wfx, 90.0, 0.6, 0.12)
		kn["pos"] = b
		kn["dist"] = float(kn["dist"]) + move
		if float(kn["dist"]) >= float(kn["max"]) - 0.01:
			game.fx.sparks(b, -dir, STEEL, [1, 2, 3][FxLayer.wfx], 60.0, 0.8, 0.15)
			_kunai.remove_at(k)


## Cada estrepe pica quem está em cima a cada CALTROP_TICK s: dano, lentidão e uma faísca.
func _step_caltrops(dt: float) -> void:
	var fx := game.fx
	for c: Dictionary in _caltrops:
		c["age"] = float(c["age"]) + dt
		c["life"] = float(c["life"]) - dt
		c["tick_left"] = float(c["tick_left"]) - dt
		if float(c["tick_left"]) > 0.0:
			continue
		c["tick_left"] = float(c["tick_left"]) + CALTROP_TICK
		var at: Vector2 = c["pos"]
		var r := float(c["r"])
		if hit_circle(&"makibishi", at, r, float(c["damage"]), 0.0) > 0:
			game.enemies.slow_circle(at, r, float(c["slow"]), float(c["slow_time"]))
			fx.sparks(at, Vector2.UP, HOT, [1, 3, 5][FxLayer.wfx], 110.0, 0.9, 0.16)
			fx.flash(at, 7.0, Color(COLOR, 0.8), 0.08)
	for k: int in range(_caltrops.size() - 1, -1, -1):
		if float(_caltrops[k]["life"]) <= 0.0:
			_caltrops.remove_at(k)


# --- Bot, save e hash ------------------------------------------------------------------------

## Passo Sombrio só correndo (atravessa para onde já ia); Troca de Corpo sem tronco no chão;
## os outros, pela regra do JSON.
func bot_should_cast(slot: int, ability: Dictionary) -> bool:
	var id := StringName(ability["id"])
	if id == &"shadow_step" and game.player.move_input.length_squared() < 0.01:
		return false
	if id == &"kawarimi" and _log_time > 0.0:
		return false
	return super.bot_should_cast(slot, ability)


func state() -> Dictionary:
	var smokes: Array = []
	for s: Dictionary in _smokes:
		var row := s.duplicate()
		row["pos"] = vec(s["pos"])
		smokes.append(row)
	var caltrops: Array = []
	for c: Dictionary in _caltrops:
		var row := c.duplicate()
		row["pos"] = vec(c["pos"])
		row["from"] = vec(c["from"])
		caltrops.append(row)
	var kunai: Array = []
	for kn: Dictionary in _kunai:
		var row := kn.duplicate()
		row["pos"] = vec(kn["pos"])
		row["dir"] = vec(kn["dir"])
		row["hit"] = (kn["hit"] as Dictionary).keys()
		kunai.append(row)
	return {"smokes": smokes, "log": [_log_time, _log_max, _log_pos.x, _log_pos.y, _log_lure, _log_r, _log_damage,
			_log_force, _log_tick_left], "log_sfx": _log_sfx, "caltrops": caltrops, "kunai": kunai}


func load_state(s: Dictionary) -> void:
	reset()
	for row: Variant in s.get("smokes", []):
		var smoke: Dictionary = (row as Dictionary).duplicate()
		smoke["pos"] = to_vec(smoke.get("pos"))
		_smokes.append(smoke)
	var wood: Array = s.get("log", [])
	if wood.size() >= 9:
		_log_time = float(wood[0])
		_log_max = float(wood[1])
		_log_pos = Vector2(float(wood[2]), float(wood[3]))
		_log_lure = float(wood[4])
		_log_r = float(wood[5])
		_log_damage = float(wood[6])
		_log_force = float(wood[7])
		_log_tick_left = float(wood[8])
	_log_sfx = String(s.get("log_sfx", ""))
	for row: Variant in s.get("caltrops", []):
		var c: Dictionary = (row as Dictionary).duplicate()
		c["pos"] = to_vec(c.get("pos"))
		c["from"] = to_vec(c.get("from"))
		_caltrops.append(c)
	for row: Variant in s.get("kunai", []):
		var kn: Dictionary = (row as Dictionary).duplicate()
		kn["pos"] = to_vec(kn.get("pos"))
		kn["dir"] = to_vec(kn.get("dir"))
		var hit: Dictionary = {}
		for j: Variant in kn.get("hit", []):
			hit[int(j)] = true
		kn["hit"] = hit
		_kunai.append(kn)


func hash_tag() -> String:
	var tag := " kenta=%d,%.3f,%d,%d" % [_smokes.size(), _log_time, _caltrops.size(), _kunai.size()]
	for c: Dictionary in _caltrops:
		tag += ",%.1f:%.1f" % [(c["pos"] as Vector2).x, (c["pos"] as Vector2).y]
	return tag


# --- Desenho (só leitura) ---------------------------------------------------------------------

func has_visuals() -> bool:
	return not _ghosts.is_empty() or not _smokes.is_empty() or _log_time > 0.0 or not _caltrops.is_empty() \
			or not _kunai.is_empty()


## Chão: fumaça baixa, a área da isca com ondas que fecham no tronco, o tronco e os estrepes.
func draw_ground(canvas: CanvasItem) -> void:
	var t := GameClock.game_time
	for smoke: Dictionary in _smokes:
		var at: Vector2 = smoke["pos"]
		var r := float(smoke["r"])
		var fade := clampf(float(smoke["life"]) / 0.5, 0.0, 1.0)
		canvas.draw_circle(at, r, Color(DEEP, 0.22 * fade))
		for k: int in range(5):
			var p := at + Vector2.from_angle(TAU * k / 5.0 + t * 0.7) * r * 0.45
			canvas.draw_circle(p, r * 0.42, Color(SMOKE, 0.14 * fade))
		Stroke.arc(canvas, at, r, 0.0, TAU, 28, Color(COLOR, 0.35 * fade), 1.0)
	if _log_time > 0.0:
		_draw_lure(canvas, t)
	# Brilho roxo fraco no chão sob cada estrepe (o ferro vai por cima, para não sumir na horda).
	for c: Dictionary in _caltrops:
		if float(c["age"]) >= CALTROP_LAND:
			var at: Vector2 = c["pos"]
			var glow := 0.5 + 0.5 * sin(t * 4.0 + at.x * 0.3)
			canvas.draw_circle(at, 5.0, Color(COLOR, (0.14 + 0.1 * glow) * clampf(float(c["life"]) / 0.4, 0.0, 1.0)))


## Área da isca: borda tracejada que gira, três ondas fechando no tronco e pontos de sombra
## sugados pelos raios até ele.
func _draw_lure(canvas: CanvasItem, t: float) -> void:
	var at := _log_pos
	var r := _log_lure
	var fade := clampf((_log_max - _log_time) / 0.2, 0.0, 1.0)
	for k: int in range(3):
		var f := 1.0 - fmod(t * 0.9 + k / 3.0, 1.0)
		Stroke.arc(canvas, at, maxf(r * f, 8.0), 0.0, TAU, clampi(int(r * f * 0.4), 16, 48),
				Color(COLOR, (0.15 + 0.5 * (1.0 - f)) * fade), 1.0 if f > 0.5 else 2.0)
	for k: int in range(12):
		var a := TAU * k / 12.0 + 0.2
		for n: int in range(3):
			var f := 1.0 - fmod(t * 0.7 + n / 3.0 + k * 0.137, 1.0)
			var p := (at + Vector2.from_angle(a) * (14.0 + (r - 14.0) * f)).round()
			var c := Color(COLOR.lerp(HOT, 1.0 - f), 0.7 * fade * (1.0 - f * 0.5))
			canvas.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), c)
	canvas.draw_circle(at, 22.0, Color(COLOR, 0.16 * fade))
	canvas.draw_circle(at, 12.0, Color(COLOR, 0.14 * fade))


## Por cima da horda: a borda tracejada da área da isca (traços curtos com sombra, sem cobrir os
## inimigos), um anel forte que pulsa em volta do tronco e a seta roxa acima dele.
func _draw_lure_rim(canvas: CanvasItem, t: float) -> void:
	var at := _log_pos
	var fade := clampf((_log_max - _log_time) / 0.2, 0.0, 1.0)
	for k: int in range(16):
		var a := TAU * k / 16.0 + t * 0.4
		Stroke.arc(canvas, at, _log_lure, a, a + TAU / 32.0, 4, Color(RING_SHADOW, 0.5 * fade), 4.0)
		Stroke.arc(canvas, at, _log_lure, a, a + TAU / 32.0, 4, Color(COLOR, 0.85 * fade), 2.0)
	var beat := fmod(t * 2.0, 1.0)
	bold_ring(canvas, at, 14.0 + 4.0 * beat, Color(COLOR, 1.0 - beat), HOT, fade, 2.0)
	var tip := (at + Vector2(0.0, -16.0 + roundf(sin(t * 6.0) * 2.0))).round()
	Stroke.convex(canvas, PackedVector2Array([tip + Vector2(-5, -6), tip + Vector2(5, -6), tip + Vector2(0, 1)]),
			Color(RING_SHADOW, 0.9 * fade))
	Stroke.convex(canvas, PackedVector2Array([tip + Vector2(-3, -5), tip + Vector2(3, -5), tip + Vector2(0, -1)]),
			Color(COLOR.lerp(HOT, 0.3), fade))


## Tronco deitado com casca, anéis na ponta e o ofuda do contrato; treme no fim.
func _draw_log(canvas: CanvasItem, t: float) -> void:
	var fuse := clampf(1.0 - _log_time / FUSE_TIME, 0.0, 1.0)
	var shake := Vector2(sin(t * 70.0), cos(t * 53.0)) * 1.2 * fuse
	var at := (_log_pos + shake).round()
	canvas.draw_set_transform(at + Vector2(0, 6), 0.0, Vector2(1.5, 0.5))
	canvas.draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.35))
	canvas.draw_set_transform(at, -0.18, Vector2(1.5, 1.5))
	canvas.draw_rect(Rect2(-9, -4, 18, 7), WOOD_DARK)
	canvas.draw_rect(Rect2(-8, -3, 16, 5), WOOD)
	for x: int in [-6, -2, 3]:
		canvas.draw_rect(Rect2(x, -3, 1, 5), WOOD_DARK)
	canvas.draw_rect(Rect2(-8, -3, 16, 1), WOOD_END.darkened(0.2))
	canvas.draw_circle(Vector2(8.5, -0.5), 3.5, WOOD_DARK)
	canvas.draw_circle(Vector2(8.5, -0.5), 2.7, WOOD_END)
	canvas.draw_circle(Vector2(8.5, -0.5), 1.3, WOOD)
	canvas.draw_rect(Rect2(-3, -6, 2, 3), WOOD_DARK)
	# Ofuda roxo pregado no tronco (o selo do clã que ele traiu).
	canvas.draw_rect(Rect2(-1, -3, 3, 5), Color(0.92, 0.9, 0.98))
	canvas.draw_rect(Rect2(0, -2, 1, 3), COLOR.darkened(0.2))
	if fuse > 0.0 and int(t * 16.0) % 2 == 0:
		canvas.draw_rect(Rect2(-9, -4, 18, 7), Color(HOT, 0.45 * fuse))
	canvas.draw_set_transform(Vector2.ZERO)


## Estrepe de ferro: quatro pontas em cruz com brilho roxo fraco; no ar, voa em arco até o chão.
func _draw_caltrop(canvas: CanvasItem, c: Dictionary, t: float) -> void:
	var at: Vector2 = c["pos"]
	var age := float(c["age"]) + GameClock.alpha * GameClock.STEP
	var fade := clampf(float(c["life"]) / 0.4, 0.0, 1.0)
	if age < CALTROP_LAND:
		var k := age / CALTROP_LAND
		var from: Vector2 = c["from"]
		at = from.lerp(at, k) + Vector2(0, -18.0 * 4.0 * k * (1.0 - k))
	else:
		var glint := maxf(0.0, sin(t * 3.0 + at.x * 0.7))
		fade *= 0.85 + 0.15 * glint
	at = at.round()
	var spin := fmod(at.x * 0.37 + at.y * 0.21, PI)
	var a := Vector2.from_angle(spin) * 3.5
	var b := Vector2.from_angle(spin + PI * 0.5) * 3.5
	# Halo escuro e brilho roxo atrás do ferro: o estrepe lê sobre a horda e sobre a grama.
	canvas.draw_circle(at, 4.5, Color(RING_SHADOW, 0.45 * fade))
	canvas.draw_circle(at, 3.0, Color(COLOR, 0.35 * fade))
	canvas.draw_line(at - a, at + a, Color(STEEL_DARK, fade), 2.0)
	canvas.draw_line(at - b, at + b, Color(STEEL_DARK, fade), 2.0)
	canvas.draw_line(at - a, at + a, Color(STEEL, fade), 1.0)
	canvas.draw_line(at - b, at + b, Color(STEEL, fade), 1.0)
	canvas.draw_rect(Rect2(at - Vector2(0.5, 1.5), Vector2(1, 1)), Color(HOT, fade))


## Por cima: o tronco e os estrepes (visíveis mesmo sob a horda), a silhueta residual do Passo
## Sombrio e as kunai no ar.
func draw_over(canvas: CanvasItem) -> void:
	var t := GameClock.game_time
	if _log_time > 0.0:
		_draw_lure_rim(canvas, t)
		_draw_log(canvas, t)
	for c: Dictionary in _caltrops:
		_draw_caltrop(canvas, c, t)
	for g: Dictionary in _ghosts:
		_draw_ghost(canvas, g)
	for kn: Dictionary in _kunai:
		var dir: Vector2 = kn["dir"]
		var p: Vector2 = kn["pos"] + dir * KUNAI_SPEED * GameClock.STEP * GameClock.alpha
		canvas.draw_line(p - dir * 14.0, p - dir * 4.0, Color(COLOR, 0.45), 2.0)
		canvas.draw_line(p - dir * 4.0, p + dir * 3.0, STEEL, 2.0)
		canvas.draw_line(p - dir * 1.0, p + dir * 3.0, Color(1, 1, 1, 0.9), 1.0)
		canvas.draw_rect(Rect2((p - dir * 6.0).round() - Vector2(1, 1), Vector2(2, 2)), DEEP)


## Vulto roxo do Kenta na origem e cópias mais fracas pelo caminho até o destino.
func _draw_ghost(canvas: CanvasItem, g: Dictionary) -> void:
	var k := clampf(float(g["life"]) / GHOST_TIME, 0.0, 1.0)
	var from: Vector2 = g["from"]
	var to: Vector2 = g["to"]
	# Rastro de sombra: cunha larga na origem que afina até o destino, com o fio de aço no meio.
	var side := (to - from).normalized().orthogonal()
	if from.distance_squared_to(to) > 4.0:
		var w := 6.0 * k + 1.0
		Stroke.convex(canvas, PackedVector2Array([from + side * w, to + side, to - side, from - side * w]),
				Color(DEEP, 0.45 * k))
		Stroke.convex(canvas, PackedVector2Array([from + side * w * 0.5, to, from - side * w * 0.5]), Color(COLOR, 0.5 * k))
	canvas.draw_line(from.round(), to.round(), Color(HOT, 0.8 * k), 1.0)
	var sheet := _hero_sheet()
	if sheet == null:
		return
	var frame := sheet.region(0, SpriteSheet.dir_from_vector(g["dir"], 0))
	var tex := sheet.flash_texture
	for c: int in range(GHOST_COPIES, -1, -1):
		var f := c / float(GHOST_COPIES + 1)
		var p := from.lerp(to, f).round() + Vector2(-8.0, -13.0)
		var alpha := (1.0 if c == 0 else 0.45 * (1.0 - f)) * k
		if c == 0:
			# Vulto principal: contorno roxo claro e o corpo de sombra.
			for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				canvas.draw_texture_rect_region(tex, Rect2(p + d, Vector2(16, 16)), frame, Color(COLOR.lerp(HOT, 0.4), alpha))
		canvas.draw_texture_rect_region(tex, Rect2(p, Vector2(16, 16)), frame,
				Color(DEEP.lerp(COLOR, 0.25 + 0.5 * f), alpha * (0.9 if c == 0 else 1.0)))


## Folha do herói (a mesma do Player, do cache do SpriteSheet) para a silhueta residual.
func _hero_sheet() -> SpriteSheet:
	var hero: Dictionary = game.player.hero
	if not hero.has("sprite") or String(hero.get("layout", "dir4")) != "dir4":
		return null
	return SpriteSheet.load_sheet(String(hero["sprite"]), "dir4", Vector2(16, 16), 4)


## Brilho (Alta): fumaça, isca pulsando, estrepes e kunai.
func draw_glow(canvas: CanvasItem) -> void:
	var t := GameClock.game_time
	if _log_time > 0.0:
		var fuse := clampf(1.0 - _log_time / FUSE_TIME, 0.0, 1.0)
		FxLayer.draw_soft(canvas, _log_pos, 22.0 + 10.0 * fuse, Color(COLOR, 0.3 + 0.4 * fuse * (0.5 + 0.5 * sin(t * 30.0))))
	for c: Dictionary in _caltrops:
		if float(c["age"]) >= CALTROP_LAND:
			FxLayer.draw_soft(canvas, c["pos"], 5.0, Color(COLOR, 0.25 * clampf(float(c["life"]) / 0.4, 0.0, 1.0)))
	for kn: Dictionary in _kunai:
		FxLayer.draw_soft(canvas, kn["pos"], 6.0, Color(COLOR, 0.5))
	for g: Dictionary in _ghosts:
		FxLayer.draw_soft(canvas, g["from"], 12.0, Color(COLOR, 0.4 * float(g["life"]) / GHOST_TIME))
