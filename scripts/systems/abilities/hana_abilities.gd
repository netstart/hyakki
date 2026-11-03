class_name HanaAbilities
extends HeroAbilities
## Hana, a miko herdeira do selo (energia: Prece, 霊力). Papel ofuda, shide, sinos suzu e a luz
## verde-menta do santuário (HeroAbilities explica o contrato; aki_abilities.gd é a referência):
##   1. 祓 Purificação: o gohei varre um leque para o inimigo mais próximo (ou a frente): dano e
##      empurrão em quem está no leque, e os tiros inimigos no leque viram pétalas e papel.
##   2. 結界 Kekkai: barreira sagrada fixa no chão por `time` s: quem está dentro fica lento e
##      leva dano a cada `tick` s, os tiros inimigos que entram se desfazem e a Hana, dentro, cura
##      `heal_pct` da vida por segundo. Ofuda giram nos quatro pontos cardeais.
##   3. 祖母の封印 Selo da Avó: 5 ofuda voam em espiral até o inimigo mais forte em `reach` px
##      (chefe primeiro). Comum/elite: preso no selo 封 por `seal_time` s e então se desfaz em luz
##      (morte normal: abate, XP e missões); chefe: atordoado `boss_stun` s com os ofuda presos e
##      leva `boss_damage`. Sem ninguém no alcance, não sai (devolve o custo).
## Efeitos persistentes (barreira, ofuda no ar, selos) vão no save da partida suspensa e no hash
## (os inimigos não entram no save: um selo retomado sem o alvo se desfaz). Varredura, pétalas e
## tiras de papel são só desenho.

const COLOR := Color(0.62, 1.0, 0.77)
const HOT := Color(0.92, 1.0, 0.95)
const DEEP := Color(0.18, 0.55, 0.42)
const PAPER := Color(0.98, 0.96, 0.88)
const INK := Color(0.82, 0.12, 0.16)
const PETAL := Color(1.0, 0.78, 0.86)
const BELL := Color(1.0, 0.84, 0.36)
const ROPE := Color(0.93, 0.85, 0.6)
const KEK_SHADOW := Color(0.03, 0.12, 0.09)
const KANJI_FONT := "res://assets/fonts/fusion_pixel_12_ja.woff2"
const SEAL_GLYPH := "封"
## Varredura do gohei (s) e as tiras de papel / pétalas soltas (só desenho).
const SWEEP_TIME := 0.22
const MAX_BITS := 64
const BIT_LIFE := 0.9
## Kekkai: a lentidão é renovada todo passo por KEKKAI_HOLD s; ofuda que giram no anel (rad/s).
const KEKKAI_HOLD := 0.3
const KEKKAI_SPIN := 0.5
const KEKKAI_GROW := 0.25
## Selo: voo dos ofuda (s), raio da espiral (px) e voltas no voo.
const SEAL_FLY := 0.45
const SEAL_SPIRAL := 30.0
const SEAL_TURNS := 1.5

## Fonte japonesa do 封 (carregada uma vez).
static var _glyph_font: Font

## Varreduras em curso (só desenho): {"pos", "dir", "half", "reach", "life"}.
var _sweeps: Array[Dictionary] = []
## Pétalas e tiras de papel (só desenho): {"pos", "vel", "life", "rot", "spin", "color", "size"}.
var _bits: Array[Dictionary] = []
# Kekkai (uma barreira por vez).
var _kek_time: float = 0.0
var _kek_max: float = 0.0
var _kek_pos := Vector2.ZERO
var _kek_r: float = 0.0
var _kek_slow: float = 0.0
var _kek_damage: float = 0.0
var _kek_tick: float = 0.5
var _kek_tick_left: float = 0.0
var _kek_heal: float = 0.0
## Selos: {"target", "born", "boss", "from", "last", "fly", "bind", "bind_max", "seal_time",
## "boss_stun", "boss_damage", "phase", "sfx"}; "fly" > 0 voando, depois "bind" > 0 preso.
var _seals: Array[Dictionary] = []


func reset() -> void:
	_sweeps.clear()
	_bits.clear()
	_kek_time = 0.0
	_seals.clear()


func cast(slot: int, ability: Dictionary, power: float) -> bool:
	match StringName(ability["id"]):
		&"harae":
			return _cast_harae(ability, power)
		&"kekkai":
			return _cast_kekkai(ability, power)
		&"grandmother_seal":
			return _cast_seal(ability, power)
	return super.cast(slot, ability, power)


func step(dt: float) -> void:
	for k: int in range(_sweeps.size() - 1, -1, -1):
		_sweeps[k]["life"] = float(_sweeps[k]["life"]) - dt
		if float(_sweeps[k]["life"]) <= 0.0:
			_sweeps.remove_at(k)
	if not _bits.is_empty():
		_step_bits(dt)
	if _kek_time > 0.0:
		_step_kekkai(dt)
	if not _seals.is_empty():
		_step_seals(dt)


# --- 祓 Purificação ----------------------------------------------------------------------------

func _cast_harae(ability: Dictionary, power: float) -> bool:
	var player := game.player
	var reach := area_of(ability, "reach")
	var dir := player.aim_direction(Player.Aim.NEAREST, reach * 1.5)
	var half := deg_to_rad(param(ability, "angle", 100.0)) * 0.5
	var at := player.sim_pos
	var hits := hit_cone(&"harae", at, dir, half, reach, dmg(ability, "damage", power), param(ability, "knockback", 180.0))
	var shots := game.enemy_shots
	var purified := shots.clear_cone(at, dir, half, reach)
	for p: Vector2 in shots.cleared:
		_purify_shot(p)
	_sweeps.append({"pos": at, "dir": dir, "half": half, "reach": reach, "life": SWEEP_TIME})
	var fx := game.fx
	fx.play_anim("slash", at + dir * reach * 0.45, reach / 22.0, dir.angle(), Color(0.85, 1.0, 0.92), 26.0, false, true)
	fx.flash(at + dir * 12.0, 20.0, Color(COLOR, 0.8), 0.12)
	# Tiras de papel (shide) voando da ponta do gohei ao longo do arco.
	for k: int in range([4, 8, 12][FxLayer.wfx]):
		var a := dir.angle() + lerpf(-half, half, k / float([4, 8, 12][FxLayer.wfx] - 1))
		var edge := at + Vector2.from_angle(a) * reach * randf_range(0.55, 0.95)
		_add_bit(edge, Vector2.from_angle(a + 0.6) * randf_range(40.0, 80.0), PAPER, 2.0)
	fx.sparks(at + dir * reach * 0.6, dir, HOT, [3, 6, 10][FxLayer.wfx], 140.0, half, 0.22)
	if hits > 0 or purified > 0:
		impact_sfx(ability)
		punch(1.4, 20)
	else:
		punch(0.7, 12)
	return true


## Tiro purificado: um floco de luz e pétalas e papel que caem balançando.
func _purify_shot(at: Vector2) -> void:
	game.fx.flash(at, 8.0, Color(COLOR, 0.8), 0.1)
	game.fx.motes(at, HOT, [0, 2, 3][FxLayer.wfx], 3.0, 20.0)
	for k: int in range([1, 3, 4][FxLayer.wfx]):
		_add_bit(at, Vector2.from_angle(randf() * TAU) * randf_range(15.0, 35.0), PETAL if k % 2 == 0 else PAPER, 1.0)


func _add_bit(at: Vector2, vel: Vector2, color: Color, size: float) -> void:
	if _bits.size() >= MAX_BITS:
		_bits.pop_front()
	_bits.append({"pos": at, "vel": vel, "life": BIT_LIFE * randf_range(0.7, 1.0), "rot": randf() * TAU,
			"spin": randf_range(-8.0, 8.0), "color": color, "size": size})


## Só desenho (randf próprio, fora do hash): caem devagar, balançando e girando.
func _step_bits(dt: float) -> void:
	for k: int in range(_bits.size() - 1, -1, -1):
		var b := _bits[k]
		var vel: Vector2 = b["vel"]
		vel = vel * (1.0 - 2.5 * dt) + Vector2(sin(float(b["rot"]) * 2.0) * 20.0 * dt, 22.0 * dt)
		b["vel"] = vel
		b["pos"] = (b["pos"] as Vector2) + vel * dt
		b["rot"] = float(b["rot"]) + float(b["spin"]) * dt
		b["life"] = float(b["life"]) - dt
		if float(b["life"]) <= 0.0:
			_bits.remove_at(k)


# --- 結界 Kekkai -------------------------------------------------------------------------------

func _cast_kekkai(ability: Dictionary, power: float) -> bool:
	var at := game.player.sim_pos
	_kek_max = dur(ability, "time")
	_kek_time = _kek_max
	_kek_pos = at
	_kek_r = area_of(ability, "radius")
	_kek_slow = param(ability, "slow", 0.6)
	_kek_damage = dmg(ability, "damage", power)
	_kek_tick = maxf(param(ability, "tick", 0.5), GameClock.STEP)
	_kek_tick_left = 0.0
	_kek_heal = param(ability, "heal_pct", 0.02)
	var fx := game.fx
	fx.shockwave(at, _kek_r, COLOR, 1.3, 0.45)
	fx.flash(at, _kek_r * 0.7, Color(COLOR, 0.7), 0.25)
	fx.play_anim("circle", at, _kek_r / 14.0, 0.0, Color(0.75, 1.0, 0.88, 0.85), 18.0)
	if FxLayer.glow:
		fx.play_anim("circle_spark2", at, _kek_r / 12.0, 0.0, Color(0.8, 1.0, 0.9), 16.0, false, true)
	fx.dust(at, _kek_r * 0.9, Color(PAPER, 0.85), [6, 12, 20][FxLayer.wfx], 30.0)
	punch(1.6, 30)
	return true


## Lentidão em quem está dentro (renovada todo passo), tiros que entram se desfazem, dano a
## cada `tick` s e a cura da Hana enquanto ela estiver dentro.
func _step_kekkai(dt: float) -> void:
	_kek_time -= dt
	var at := _kek_pos
	var r := _kek_r
	game.enemies.slow_circle(at, r, _kek_slow, KEKKAI_HOLD)
	var shots := game.enemy_shots
	if shots.clear_circle(at, r) > 0:
		for p: Vector2 in shots.cleared:
			_purify_shot(p)
			game.fx.sparks(p, p - at, HOT, [1, 2, 4][FxLayer.wfx], 70.0, 0.7, 0.16)
	_kek_tick_left -= dt
	if _kek_tick_left <= 0.0:
		_kek_tick_left += _kek_tick
		if hit_circle(&"kekkai", at, r, _kek_damage, 0.0, true) > 0 and FxLayer.wfx > 0:
			game.fx.dust(at, r * 0.8, Color(COLOR, 0.7), FxLayer.wfx * 2, -20.0)
	var player := game.player
	if player.sim_pos.distance_to(at) <= r:
		player.heal(_kek_heal * player.max_hp() * dt)
		if FxLayer.wfx > 0 and game.step_index % 10 == 0:
			game.fx.motes(player.sim_pos + Vector2(0, -6), COLOR, FxLayer.wfx, 6.0, 14.0)
	if _kek_time <= 0.0:
		_kek_time = 0.0
		game.fx.add_ring(at, r * 1.1, COLOR, 0.4)
		game.fx.dust(at, r, Color(PAPER, 0.8), [4, 8, 14][FxLayer.wfx], 25.0)


# --- 祖母の封印 Selo da Avó --------------------------------------------------------------------

## Alvo do selo: o chefe mais perto no alcance; sem chefe, o de mais vida (empate: o primeiro
## na ordem da grade). -1 sem ninguém.
func seal_target(center: Vector2, reach: float) -> int:
	var enemies := game.enemies
	enemies.query_circle(center, reach, _hits)
	var best := -1
	var best_boss := false
	var best_score := -INF
	for j: int in _hits:
		if enemies.is_prop(j) or _is_sealed(j):
			continue
		var boss := enemies.is_boss(j)
		var score := -center.distance_squared_to(enemies.pos[j]) if boss else enemies.hp[j]
		if (boss and not best_boss) or (boss == best_boss and score > best_score):
			best = j
			best_boss = boss
			best_score = score
	return best


func _is_sealed(j: int) -> bool:
	for s: Dictionary in _seals:
		if int(s["target"]) == j:
			return true
	return false


func _cast_seal(ability: Dictionary, power: float) -> bool:
	var player := game.player
	var target := seal_target(player.sim_pos, param(ability, "reach", 200.0))
	if target < 0:
		return false
	var enemies := game.enemies
	var from := player.hand_position()
	_seals.append({"target": target, "born": enemies.born[target], "boss": enemies.is_boss(target),
			"from": from, "last": enemies.pos[target], "fly": SEAL_FLY, "bind": 0.0, "bind_max": 0.0,
			"count": int(param(ability, "ofuda", 5.0)), "seal_time": dur(ability, "seal_time"),
			"boss_stun": dur(ability, "boss_stun"), "boss_damage": dmg(ability, "boss_damage", power),
			"phase": float(game.step_index % 360) * 0.1, "sfx": String(ability.get("sfx", ""))})
	var fx := game.fx
	fx.flash(from, 20.0, Color(COLOR, 0.9), 0.15)
	fx.add_ring(from, 26.0, COLOR, 0.3)
	fx.dust(from, 6.0, Color(PAPER, 0.9), [3, 6, 10][FxLayer.wfx], 60.0)
	punch(1.0, 15)
	return true


func _target_alive(s: Dictionary) -> bool:
	var j := int(s["target"])
	var enemies := game.enemies
	return j >= 0 and j < EnemyManager.CAPACITY and enemies.alive[j] == 1 and enemies.born[j] == float(s["born"])


func _step_seals(dt: float) -> void:
	var done: Array[Dictionary] = []
	for s: Dictionary in _seals:
		var alive := _target_alive(s)
		var j := int(s["target"])
		if alive:
			s["last"] = game.enemies.pos[j]
		if float(s["fly"]) > 0.0:
			s["fly"] = float(s["fly"]) - dt
			if not alive:
				_fizzle(s)
				done.append(s)
			elif float(s["fly"]) <= 0.0:
				_bind(s, j)
			continue
		s["bind"] = float(s["bind"]) - dt
		if not alive:
			if not bool(s["boss"]):
				_dissolve_fx(s["last"])
			done.append(s)
			continue
		game.enemies.stun_one(j, maxf(float(s["bind"]), GameClock.STEP))
		if float(s["bind"]) <= 0.0:
			if not bool(s["boss"]):
				_dissolve(s, j)
			else:
				game.fx.dust(s["last"], 10.0, Color(PAPER, 0.9), [3, 6, 10][FxLayer.wfx], 50.0)
			done.append(s)
	for s: Dictionary in done:
		_seals.erase(s)


## Os ofuda chegam: o comum fica preso no selo; o chefe, atordoado com os ofuda presos.
func _bind(s: Dictionary, j: int) -> void:
	var enemies := game.enemies
	var at := enemies.pos[j]
	var boss := bool(s["boss"])
	var hold := float(s["boss_stun"]) if boss else float(s["seal_time"])
	s["bind"] = hold
	s["bind_max"] = hold
	enemies.stun_one(j, hold)
	enemies.vel[j] = Vector2.ZERO
	if boss:
		hit(&"grandmother_seal", j, float(s["boss_damage"]), Vector2.ZERO, 0.0)
		game.fx.shockwave(at, 60.0, COLOR, 1.6, 0.5)
		punch(2.6, 50)
	else:
		game.fx.shockwave(at, 28.0, COLOR, 0.9, 0.35)
		punch(1.4, 25)
	var fx := game.fx
	fx.flash(at, 30.0, Color(HOT, 0.9), 0.18)
	fx.play_anim("circle_spark", at, 1.4, 0.0, Color(0.8, 1.0, 0.9), 18.0, false, true)
	fx.sparks(at, Vector2.UP, HOT, [4, 8, 14][FxLayer.wfx], 120.0, PI, 0.25)
	play_sfx(String(s["sfx"]) + "_hit")


## Fim do selo num comum/elite: morte pelo caminho normal (abate, XP, missões) e o corpo se
## desfaz em luz.
func _dissolve(s: Dictionary, j: int) -> void:
	var enemies := game.enemies
	var at := enemies.pos[j]
	hit(&"grandmother_seal", j, maxf(enemies.hp[j], 1.0), Vector2.UP, 0.0)
	_dissolve_fx(at)
	s["last"] = at


func _dissolve_fx(at: Vector2) -> void:
	var fx := game.fx
	fx.play_anim("spirit", at + Vector2(0, -6), 1.0, 0.0, Color(0.75, 1.0, 0.88, 0.9), 18.0, false, true)
	fx.motes(at, COLOR, [2, 8, 14][FxLayer.wfx], 8.0, 40.0)
	fx.sparks(at, Vector2.UP, HOT, [3, 6, 10][FxLayer.wfx], 90.0, 0.6, 0.4)
	fx.flash(at, 22.0, Color(COLOR, 0.9), 0.2)
	fx.add_ring(at, 22.0, COLOR, 0.35)
	for k: int in range([2, 4, 6][FxLayer.wfx]):
		_add_bit(at, Vector2.from_angle(TAU * k / 6.0 + randf()) * 40.0, PAPER, 2.0)


## O alvo sumiu no meio do voo: os ofuda caem e se desfazem.
func _fizzle(s: Dictionary) -> void:
	var at: Vector2 = s["last"]
	game.fx.dust(at, 6.0, Color(PAPER, 0.9), [3, 5, 8][FxLayer.wfx], 40.0)
	for k: int in range([1, 3, 5][FxLayer.wfx]):
		_add_bit(at, Vector2.from_angle(TAU * k / 5.0) * 30.0, PAPER, 2.0)


# --- Bot, save e hash --------------------------------------------------------------------------

## Kekkai sem barreira de pé; Selo só num chefe ou elite no alcance, ou numa multidão (o mais
## forte dela); Purificação também quando há tiros perto.
func bot_should_cast(slot: int, ability: Dictionary) -> bool:
	var id := StringName(ability["id"])
	var at := game.player.sim_pos
	if id == &"kekkai" and _kek_time > 0.0:
		return false
	if id == &"grandmother_seal":
		var j := seal_target(at, param(ability, "reach", 200.0))
		if j < 0:
			return false
		return game.enemies.is_boss(j) or game.enemies.elite[j] == 1 \
				or game.enemies.count_in_circle(at, param(ability, "reach", 200.0), 12) >= 12
	if id == &"harae" and game.enemy_shots.count_alive > 0:
		var reach := area_of(ability, "reach")
		for i: int in range(EnemyShotManager.CAPACITY):
			if game.enemy_shots.alive[i] == 1 and game.enemy_shots.pos[i].distance_squared_to(at) < reach * reach:
				return true
	return super.bot_should_cast(slot, ability)


func state() -> Dictionary:
	var seals: Array = []
	for s: Dictionary in _seals:
		var row := s.duplicate()
		row["from"] = vec(s["from"])
		row["last"] = vec(s["last"])
		seals.append(row)
	return {"kekkai": [_kek_time, _kek_max, _kek_pos.x, _kek_pos.y, _kek_r, _kek_slow, _kek_damage, _kek_tick,
			_kek_tick_left, _kek_heal], "seals": seals}


func load_state(s: Dictionary) -> void:
	reset()
	var kek: Array = s.get("kekkai", [])
	if kek.size() >= 10:
		_kek_time = float(kek[0])
		_kek_max = float(kek[1])
		_kek_pos = Vector2(float(kek[2]), float(kek[3]))
		_kek_r = float(kek[4])
		_kek_slow = float(kek[5])
		_kek_damage = float(kek[6])
		_kek_tick = maxf(float(kek[7]), GameClock.STEP)
		_kek_tick_left = float(kek[8])
		_kek_heal = float(kek[9])
	for row: Variant in s.get("seals", []):
		var seal: Dictionary = (row as Dictionary).duplicate()
		seal["from"] = to_vec(seal.get("from"))
		seal["last"] = to_vec(seal.get("last"))
		seal["target"] = int(seal.get("target", -1))
		seal["boss"] = bool(seal.get("boss", false))
		seal["count"] = int(seal.get("count", 5))
		_seals.append(seal)


func hash_tag() -> String:
	var tag := " hana=%.3f,%d" % [_kek_time, _seals.size()]
	for s: Dictionary in _seals:
		tag += ",%d:%.3f:%.3f" % [int(s["target"]), float(s["fly"]), float(s["bind"])]
	return tag


# --- Desenho (só leitura) ----------------------------------------------------------------------

func has_visuals() -> bool:
	return not _sweeps.is_empty() or not _bits.is_empty() or _kek_time > 0.0 or not _seals.is_empty()


## Chão: brilho e desenho sagrado da barreira e o círculo do selo sob o alvo.
func draw_ground(canvas: CanvasItem) -> void:
	var t := GameClock.game_time
	if _kek_time > 0.0:
		var at := _kek_pos
		var r := _kekkai_radius()
		var fade := clampf(_kek_time / 0.4, 0.0, 1.0)
		var pulse := 0.85 + 0.15 * sin(t * 4.0)
		canvas.draw_circle(at, r, Color(COLOR, 0.1 * fade * pulse))
		canvas.draw_circle(at, r * 0.55, Color(COLOR, 0.07 * fade))
		Stroke.arc(canvas, at, r * 0.55, 0.0, TAU, 32, Color(COLOR, 0.35 * fade), 1.0)
		# Estrela de cinco pontas (seimei) girando devagar no chão.
		var pts := PackedVector2Array()
		for k: int in range(6):
			pts.append(at + Vector2.from_angle(-PI * 0.5 + TAU * 2.0 * k / 5.0 - t * 0.3) * r * 0.5)
		Stroke.line(canvas, pts, Color(COLOR, 0.3 * fade), 1.0)
	for s: Dictionary in _seals:
		if float(s["fly"]) > 0.0:
			continue
		var at := _seal_pos(s)
		var k := clampf(float(s["bind"]) / maxf(float(s["bind_max"]), 0.01), 0.0, 1.0)
		var r := 12.0 + (8.0 if bool(s["boss"]) else 0.0)
		Stroke.arc(canvas, at + Vector2(0, 4), r, t * 2.0, t * 2.0 + TAU, 24, Color(COLOR, 0.6 * k), 1.0)
		Stroke.arc(canvas, at + Vector2(0, 4), r * 0.7, -t * 3.0, -t * 3.0 + TAU, 20, Color(HOT, 0.4 * k), 1.0)


## Por cima: a cúpula do kekkai com shide e ofuda nos pontos cardeais, a varredura do gohei,
## os ofuda do selo (no voo e presos), o 封 e as pétalas e tiras de papel.
func draw_over(canvas: CanvasItem) -> void:
	var t := GameClock.game_time
	if _kek_time > 0.0:
		_draw_kekkai(canvas, t)
	for sw: Dictionary in _sweeps:
		_draw_sweep(canvas, sw)
	for s: Dictionary in _seals:
		_draw_seal(canvas, s, t)
	for b: Dictionary in _bits:
		var k := clampf(float(b["life"]) / 0.3, 0.0, 1.0)
		var size := float(b["size"])
		canvas.draw_set_transform((b["pos"] as Vector2).round(), float(b["rot"]))
		canvas.draw_rect(Rect2(-size * 0.5, -size, size, size * 2.0), Color(b["color"], 0.95 * k))
		canvas.draw_set_transform(Vector2.ZERO)


func _kekkai_radius() -> float:
	var age := _kek_max - _kek_time
	var k := clampf(age / KEKKAI_GROW, 0.0, 1.0)
	return _kek_r * (1.0 - (1.0 - k) * (1.0 - k))


func _draw_kekkai(canvas: CanvasItem, t: float) -> void:
	var at := _kek_pos
	var r := _kekkai_radius()
	var fade := clampf(_kek_time / 0.4, 0.0, 1.0)
	var segments := clampi(int(r * 0.7), 24, 64)
	# Borda forte que lê no meio da horda: sombra escura larga, faixa na cor da Prece, fio branco
	# por dentro e uma corda sagrada (shimenawa) pontilhada logo fora; pulsa de leve.
	var pulse := 0.85 + 0.15 * sin(t * 6.0)
	Stroke.arc(canvas, at, r, 0.0, TAU, segments, Color(KEK_SHADOW, 0.6 * fade), 5.0)
	Stroke.arc(canvas, at, r, 0.0, TAU, segments, Color(COLOR, 0.95 * fade * pulse), 3.0)
	Stroke.arc(canvas, at, r - 1.0, 0.0, TAU, segments, Color(HOT, 0.85 * fade), 1.0)
	Stroke.arc(canvas, at, r - 4.0, 0.0, TAU, segments, Color(COLOR, 0.35 * fade), 1.0)
	var knots := clampi(int(r * 0.4), 16, 40)
	for k: int in range(knots):
		var p := (at + Vector2.from_angle(TAU * k / knots - t * KEKKAI_SPIN) * (r + 3.5)).round()
		canvas.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(ROPE if k % 2 == 0 else KEK_SHADOW, 0.9 * fade))
	# Cúpula: arcos de cima sugerindo a abóbada (só a metade de trás, para não cobrir inimigos).
	Stroke.arc(canvas, at, r * 0.82, PI * 1.08, PI * 1.92, 20, Color(COLOR, 0.22 * fade), 1.0)
	Stroke.arc(canvas, at, r * 0.6, PI * 1.15, PI * 1.85, 16, Color(COLOR, 0.16 * fade), 1.0)
	# Shide (zigue-zague de papel) pendendo da corda sagrada, entre os ofuda.
	for k: int in range(8):
		var a := TAU * (k + 0.5) / 8.0 + t * KEKKAI_SPIN
		var p := (at + Vector2.from_angle(a) * r).round()
		var sway := sin(t * 5.0 + k) * 1.0
		canvas.draw_rect(Rect2(p + Vector2(-1 + sway, 0), Vector2(2, 2)), Color(PAPER, fade))
		canvas.draw_rect(Rect2(p + Vector2(0 + sway, 2), Vector2(2, 2)), Color(PAPER, fade))
		canvas.draw_rect(Rect2(p + Vector2(-1 + sway, 4), Vector2(2, 2)), Color(PAPER, 0.85 * fade))
	for k: int in range(4):
		var a := TAU * k / 4.0 + t * KEKKAI_SPIN
		_draw_ofuda(canvas, at + Vector2.from_angle(a) * r, sin(t * 3.0 + k) * 0.25, fade)
	# Sinos suzu dourados nas diagonais da corda.
	for k: int in range(4):
		var p := (at + Vector2.from_angle(TAU * (k + 0.5) / 4.0 + t * KEKKAI_SPIN) * (r + 3.0)).round()
		canvas.draw_circle(p, 1.8, Color(BELL, fade))
		canvas.draw_rect(Rect2(p + Vector2(-0.5, 0.5), Vector2(1, 1)), Color(0.4, 0.25, 0.05, fade))


## Ofuda: papel 4×8 com borda vermelha e a tinta no meio.
func _draw_ofuda(canvas: CanvasItem, at: Vector2, angle: float, alpha: float) -> void:
	canvas.draw_set_transform(at.round(), angle)
	canvas.draw_rect(Rect2(-2, -4, 4, 8), Color(PAPER, alpha))
	canvas.draw_rect(Rect2(-2, -4, 4, 1), Color(INK, alpha))
	canvas.draw_rect(Rect2(-1, -2, 1, 4), Color(INK, 0.9 * alpha))
	canvas.draw_rect(Rect2(0, -1, 1, 1), Color(INK, 0.9 * alpha))
	canvas.draw_set_transform(Vector2.ZERO)


## Leque do gohei: preenchido de leve, com o bastão varrendo de um lado ao outro e a esteira.
func _draw_sweep(canvas: CanvasItem, sw: Dictionary) -> void:
	var k := 1.0 - clampf(float(sw["life"]) / SWEEP_TIME, 0.0, 1.0)
	var at: Vector2 = sw["pos"]
	var dir: Vector2 = sw["dir"]
	var half := float(sw["half"])
	var reach := float(sw["reach"])
	var base := dir.angle()
	var fade := 1.0 - k * k
	var swept := lerpf(-half, half, minf(k * 1.6, 1.0))
	var fan := PackedVector2Array([at])
	for n: int in range(9):
		fan.append(at + Vector2.from_angle(base - half + (swept + half) * n / 8.0) * reach)
	Stroke.convex(canvas, fan, Color(COLOR, 0.18 * fade))
	Stroke.arc(canvas, at, reach, base - half, base + swept, 20, Color(HOT, 0.8 * fade), 2.0)
	Stroke.arc(canvas, at, reach * 0.7, base - half, base + swept, 16, Color(COLOR, 0.5 * fade), 1.0)
	var tip := at + Vector2.from_angle(base + swept) * reach * 0.9
	canvas.draw_line(at.round(), tip.round(), Color(0.55, 0.35, 0.2, fade), 2.0)
	_draw_ofuda(canvas, tip, base + swept + PI * 0.5, fade)


## Ofuda em espiral até o alvo (voo) e, preso, o anel de ofuda girando com o 封 por cima.
func _draw_seal(canvas: CanvasItem, s: Dictionary, t: float) -> void:
	var count := int(s.get("count", 5))
	var at := _seal_pos(s)
	if float(s["fly"]) > 0.0:
		var e := clampf(1.0 - (float(s["fly"]) - GameClock.alpha * GameClock.STEP) / SEAL_FLY, 0.0, 1.0)
		var from: Vector2 = s["from"]
		var center := from.lerp(at, e * e * (3.0 - 2.0 * e))
		for k: int in range(count):
			var a := float(s["phase"]) + TAU * k / count + e * TAU * SEAL_TURNS
			var p := center + Vector2.from_angle(a) * SEAL_SPIRAL * (1.0 - e) + Vector2(0, -10.0 * sin(PI * e))
			canvas.draw_line(p.round(), (p - Vector2.from_angle(a + 1.2) * 5.0).round(), Color(COLOR, 0.5), 1.0)
			_draw_ofuda(canvas, p, a, 1.0)
		return
	var k := clampf(float(s["bind"]) / maxf(float(s["bind_max"]), 0.01), 0.0, 1.0)
	var boss := bool(s["boss"])
	var ring := 16.0 if boss else 9.0
	var alpha := clampf(k / 0.25, 0.0, 1.0) if boss else 1.0
	# Círculo do selo apertando o alvo (lê no meio da horda): anel forte que fecha até os ofuda,
	# com quatro marcas de tinta nos pontos cardeais.
	var close := lerpf(ring + 2.0, ring + 14.0, k)
	var center := at + Vector2(0, -4)
	bold_ring(canvas, center, close, Color(COLOR, 0.95), PAPER, alpha, 2.0)
	for n: int in range(4):
		var d := Vector2.from_angle(TAU * n / 4.0 + t * 0.8)
		canvas.draw_line((center + d * (close + 2.0)).round(), (center + d * (close + 6.0)).round(), Color(INK, alpha), 2.0)
	for n: int in range(count):
		var a := TAU * n / count + t * (0.6 if boss else 2.0)
		_draw_ofuda(canvas, at + Vector2(0, -6) + Vector2.from_angle(a) * ring, a + PI * 0.5, alpha)
	var font := _font()
	if font == null:
		return
	var size := 24 if boss else 12
	var grow := 1.0 - k
	var glyph_alpha := alpha * (0.6 + 0.4 * sin(t * 12.0)) if not boss and k < 0.35 else alpha
	var lift := (26.0 if boss else 10.0) + (6.0 if boss else 2.0) * grow
	var p := (at + Vector2(-size * 0.5, -lift)).round()
	# Selo de papel: tinta vermelha com borda de papel claro e halo menta.
	canvas.draw_string_outline(font, p, SEAL_GLYPH, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5,
			Color(COLOR, 0.55 * glyph_alpha))
	canvas.draw_string_outline(font, p, SEAL_GLYPH, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3,
			Color(PAPER, 0.95 * glyph_alpha))
	canvas.draw_string(font, p, SEAL_GLYPH, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(INK, glyph_alpha))


## Posição do alvo (interpolada para o desenho) ou a última conhecida.
func _seal_pos(s: Dictionary) -> Vector2:
	var j := int(s["target"])
	var enemies := game.enemies
	if _target_alive(s):
		return enemies.prev[j].lerp(enemies.pos[j], GameClock.alpha)
	return s["last"]


static func _font() -> Font:
	if _glyph_font == null and ResourceLoader.exists(KANJI_FONT):
		_glyph_font = load(KANJI_FONT) as Font
	return _glyph_font


## Brilho (Alta): cúpula, ofuda do selo e o 封.
func draw_glow(canvas: CanvasItem) -> void:
	var t := GameClock.game_time
	if _kek_time > 0.0:
		var fade := clampf(_kek_time / 0.4, 0.0, 1.0)
		var r := _kekkai_radius()
		for k: int in range(4):
			var p := _kek_pos + Vector2.from_angle(TAU * k / 4.0 + t * KEKKAI_SPIN) * r
			FxLayer.draw_soft(canvas, p, 9.0, Color(COLOR, 0.5 * fade))
		FxLayer.draw_soft(canvas, _kek_pos, r * 0.9, Color(COLOR, 0.12 * fade * (0.85 + 0.15 * sin(t * 4.0))))
	for s: Dictionary in _seals:
		var at := _seal_pos(s)
		if float(s["fly"]) > 0.0:
			var e := 1.0 - float(s["fly"]) / SEAL_FLY
			FxLayer.draw_soft(canvas, (s["from"] as Vector2).lerp(at, e), 16.0, Color(COLOR, 0.6))
		else:
			var k := clampf(float(s["bind"]) / maxf(float(s["bind_max"]), 0.01), 0.0, 1.0)
			FxLayer.draw_soft(canvas, at + Vector2(0, -6), 20.0, Color(COLOR, 0.5 * k + 0.2))
