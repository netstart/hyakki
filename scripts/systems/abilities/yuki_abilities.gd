class_name YukiAbilities
extends HeroAbilities
## Yuki, a meio-oni que a luz queima e a noite rejeita (energia: Sangue Oni, 鬼血). Vermelho
## sangue, preto, chifres e fogo frio:
##   1. 鬼爪 Garra Oni: salto de até `distance` px rumo ao inimigo mais próximo (ou à frente),
##      com rastro vermelho; ao cair, `claws` garradas seguidas em volta dela (r `radius`), que
##      deixam três cortes de garra no chão.
##   2. 鬼哭 Rugido Oni: onda vermelha r `radius` com distorção grande e tremor: os inimigos comuns
##      fogem com medo por `fear_time` s, todos levam dano e os tiros inimigos viram cinza.
##   3. 鬼神斬 Redemoinho Onikiri: `time` s girando a lâmina (anéis de corte vermelhos): `hits`
##      golpes em r `radius`, rouba `lifesteal` do dano em vida (no máx. `lifesteal_max` por uso;
##      motes vermelhos voam dos inimigos até ela) e +`speed` de velocidade enquanto gira.
## Preço de sangue: quando falta energia e ela paga com vida (AbilitySystem.last_hp_price), o
## número vermelho já sai no AbilitySystem e aqui o corpo pulsa em vermelho com gotas de sangue.
## Efeitos persistentes (garradas por vir, redemoinho) vão no save da partida suspensa e no hash.
## Rastros, cortes no chão, ondas e motes são só desenho.

const COLOR := Color(1.0, 0.29, 0.29)
const BLOOD := Color(0.75, 0.04, 0.08)
const DEEP := Color(0.32, 0.0, 0.04)
const HOT := Color(1.0, 0.78, 0.74)
## Fogo frio dos chifres: o branco-azulado que corta o vermelho.
const COLD := Color(0.82, 0.88, 1.0)
const ASH := Color(0.5, 0.5, 0.53)
## Velocidade extra do redemoinho: fonte de atributo no StatBlock (sai ao acabar).
const WHIRL_SOURCE := "ability_onikiri_whirl"
## Intervalo entre as garradas ao cair (s) e quanto o corte fica no chão (s).
const CLAW_GAP := 0.09
const GASH_TIME := 1.4
const MAX_GASHES := 9
## Onda do rugido (só desenho): duração (s).
const ROAR_TIME := 0.6
## Motes do roubo de vida (só desenho): duração do voo (s), máximo ao mesmo tempo e por golpe.
const MOTE_TIME := 0.4
const MAX_MOTES := 40
const MOTES_PER_HIT: Array[int] = [1, 3, 5]
## Preço de sangue: duração do pulso no corpo (s).
const BLOOD_PULSE := 0.55
## Lâminas do redemoinho e a volta por segundo (rad).
const WHIRL_BLADES := 3
const WHIRL_SPIN := 15.0

# Garra Oni: salto em curso e as garradas ao cair.
var _claw_leaping: bool = false
var _claw_from := Vector2.ZERO
var _claw_left: int = 0
var _claw_tick: float = 0.0
var _claw_at := Vector2.ZERO
var _claw_r: float = 45.0
var _claw_damage: float = 0.0
var _claw_count: int = 3
var _claw_sfx: String = ""
## Rastro do salto (só desenho): {"a", "b", "life", "max"}.
var _claw_trail: Dictionary = {}
## Cortes de garra no chão (só desenho): {"pos", "angle", "life", "r"}.
var _gashes: Array[Dictionary] = []
## Ondas do rugido (só desenho): {"pos", "life", "r"}.
var _roars: Array[Dictionary] = []
# Redemoinho Onikiri.
var _whirl_time: float = 0.0
var _whirl_max: float = 0.0
var _whirl_r: float = 70.0
var _whirl_damage: float = 0.0
var _whirl_gap: float = 0.1
var _whirl_tick: float = 0.0
var _whirl_hits_left: int = 0
var _whirl_steal: float = 0.1
var _whirl_steal_left: float = 0.0
var _whirl_healed: float = 0.0
var _whirl_speed: float = 0.3
var _whirl_sfx: String = ""
## Motes de vida voando até ela (só desenho): {"from", "life"}.
var _motes: Array[Dictionary] = []
var _blood_time: float = 0.0
var _blood_price: float = 0.0


func reset() -> void:
	_claw_leaping = false
	_claw_left = 0
	_claw_trail = {}
	_gashes.clear()
	_roars.clear()
	_end_whirl(false)
	_motes.clear()
	_blood_time = 0.0


func cast(slot: int, ability: Dictionary, power: float) -> bool:
	var used := false
	match StringName(ability["id"]):
		&"oni_claw":
			used = _cast_claw(ability, power)
		&"oni_roar":
			used = _cast_roar(ability, power)
		&"onikiri_whirl":
			used = _cast_whirl(ability, power)
		_:
			used = super.cast(slot, ability, power)
	if used and system.last_hp_price > 0.0:
		_blood_paid(system.last_hp_price)
	return used


func step(dt: float) -> void:
	if _claw_leaping:
		_step_leap()
	if _claw_left > 0:
		_step_claws(dt)
	if _whirl_time > 0.0:
		_step_whirl(dt)
	_step_visuals(dt)


# --- Preço de sangue ---------------------------------------------------------------------

## Pagou com vida: pulso vermelho no corpo e gotas de sangue (o número sai no AbilitySystem).
func _blood_paid(price: float) -> void:
	_blood_time = BLOOD_PULSE
	_blood_price = price
	var player := game.player
	var body := player.sim_pos + Vector2(0.0, player.sprite_top() * 0.5)
	var fx := game.fx
	fx.flash(body, 18.0, Color(BLOOD, 0.9), 0.18)
	fx.sparks(body, Vector2.UP, COLOR, [3, 6, 10][FxLayer.wfx], 70.0, 1.4, 0.3)
	fx.burst(body, BLOOD, [4, 6, 9][FxLayer.wfx])
	fx.add_ring(body, 16.0, Color(BLOOD, 0.9), 0.3, 1.0)
	punch(0.6, 25)


# --- 鬼爪 Garra Oni ---------------------------------------------------------------------------

func _cast_claw(ability: Dictionary, power: float) -> bool:
	var player := game.player
	var enemies := game.enemies
	var from := player.sim_pos
	var distance := param(ability, "distance", 100.0)
	var target := enemies.nearest(from, param(ability, "reach", 160.0))
	var dir := player.aim_direction(Player.Aim.MOVE)
	var leap := distance
	if target >= 0 and enemies.pos[target].distance_squared_to(from) > 0.01:
		var to := enemies.pos[target] - from
		dir = to.normalized()
		# Cai colada no alvo, sem passar dele.
		leap = clampf(to.length() - enemies.radius[target] - 2.0, 0.0, distance)
	player.dash(dir, maxf(leap, 1.0), param(ability, "leap_time", 0.16), param(ability, "invuln", 0.12))
	_claw_leaping = true
	_claw_from = from
	_claw_left = 0
	_claw_r = area_of(ability, "radius")
	_claw_damage = dmg(ability, "damage", power)
	_claw_count = maxi(1, int(param(ability, "claws", 3.0)))
	_claw_sfx = String(ability.get("sfx", ""))
	_claw_trail = {"a": from, "b": from, "life": 0.5, "max": 0.5}
	var fx := game.fx
	fx.sparks(from, -dir, COLOR, [3, 6, 10][FxLayer.wfx], 120.0, 0.6, 0.25)
	fx.dust(from + Vector2(0, 3), 5.0, Color(DEEP, 0.8), [3, 6, 9][FxLayer.wfx], 45.0)
	fx.play_anim("boost", from, 0.6, dir.angle() - PI * 0.5, Color(1.0, 0.45, 0.45), 30.0, false, true)
	punch(0.8, 15)
	return true


## Estica o rastro no salto; ao cair, começa as garradas no ponto de queda.
func _step_leap() -> void:
	var player := game.player
	if not _claw_trail.is_empty():
		_claw_trail["b"] = player.sim_pos
	if FxLayer.wfx > 0:
		game.fx.motes(player.sim_pos + Vector2(0, -5), COLOR, FxLayer.wfx, 4.0, 20.0)
	if player.is_dashing():
		return
	_claw_leaping = false
	_claw_at = player.sim_pos
	_claw_left = _claw_count
	_claw_tick = 0.0
	game.fx.dust(_claw_at + Vector2(0, 3), 6.0, Color(DEEP, 0.85), [4, 8, 12][FxLayer.wfx], 60.0)
	game.fx.add_ring(_claw_at, _claw_r, Color(COLOR, 0.8), 0.3, 1.5)


func _step_claws(dt: float) -> void:
	_claw_tick -= dt
	if _claw_tick > 0.0:
		return
	_claw_tick += CLAW_GAP
	var k := _claw_count - _claw_left
	_claw_left -= 1
	var at := _claw_at
	var n := hit_circle(&"oni_claw", at, _claw_r, _claw_damage, 60.0)
	# Cada garrada num ângulo (alternando os lados), com o corte que fica no chão.
	var angle := -0.6 + 1.2 * float(k % 2) + 0.35 * float(k) + game.player.facing.angle()
	var fx := game.fx
	var scale := _claw_r / 18.0
	fx.play_anim("claw", at + Vector2(0, -4), scale, angle, Color(1.0, 0.5, 0.5), 26.0, k % 2 == 1, true)
	fx.flash(at, _claw_r * 0.7, Color(COLOR, 0.75), 0.1)
	fx.sparks(at, Vector2.from_angle(angle), HOT, [3, 6, 9][FxLayer.wfx], 160.0, 0.5, 0.18)
	if k == 0:
		fx.shockwave(at, _claw_r * 1.1, COLOR, 1.0, 0.35)
	if _gashes.size() >= MAX_GASHES:
		_gashes.pop_front()
	_gashes.append({"pos": at + Vector2.from_angle(angle + PI * 0.5) * (k - 1) * 5.0, "angle": angle,
			"life": GASH_TIME, "r": _claw_r * 0.75})
	if n > 0:
		play_sfx(_claw_sfx + "_hit")
		punch(1.2 + 0.4 * k, 20)
	else:
		punch(0.6, 10)


# --- 鬼哭 Rugido Oni --------------------------------------------------------------------------

func _cast_roar(ability: Dictionary, power: float) -> bool:
	var at := game.player.sim_pos
	var r := area_of(ability, "radius")
	var enemies := game.enemies
	enemies.fear_circle(at, r, dur(ability, "fear_time"), at)
	hit_circle(&"oni_roar", at, r, dmg(ability, "damage", power), param(ability, "knockback", 110.0))
	var fx := game.fx
	var shots := game.enemy_shots
	if shots.clear_circle(at, r) > 0:
		for p: Vector2 in shots.cleared:
			fx.dust(p, 2.0, Color(ASH, 0.9), [2, 3, 5][FxLayer.wfx], 22.0)
			if FxLayer.wfx > 0:
				fx.add_wisp(p, FxLayer.wfx)
	_roars.append({"pos": at, "life": ROAR_TIME, "r": r})
	fx.shockwave(at, r, COLOR, 2.0, 0.6)
	fx.distort(at, r * 1.35, 2.0, 0.75)
	# Clarão só no centro (a onda é que cobre o raio; os inimigos continuam legíveis).
	fx.flash(at, 30.0, Color(BLOOD, 0.8), 0.2)
	fx.play_anim("circle_spark2", at, 2.2, 0.0, Color(1.0, 0.35, 0.35, 0.8), 20.0, false, FxLayer.glow)
	fx.sparks(at, Vector2.UP, COLOR, [8, 16, 26][FxLayer.wfx], 220.0, PI, 0.35)
	fx.dust(at, r * 0.35, Color(DEEP, 0.8), [6, 12, 20][FxLayer.wfx], 120.0)
	punch(4.5, 90)
	return true


# --- 鬼神斬 Redemoinho Onikiri -----------------------------------------------------------------

func _cast_whirl(ability: Dictionary, power: float) -> bool:
	_whirl_max = maxf(dur(ability, "time"), GameClock.STEP)
	_whirl_time = _whirl_max
	_whirl_r = area_of(ability, "radius")
	_whirl_damage = dmg(ability, "damage", power)
	_whirl_hits_left = maxi(1, int(param(ability, "hits", 12.0)))
	_whirl_gap = maxf(_whirl_max / _whirl_hits_left, GameClock.STEP)
	_whirl_tick = _whirl_gap * 0.5
	_whirl_steal = param(ability, "lifesteal", 0.1)
	_whirl_steal_left = param(ability, "lifesteal_max", 30.0)
	_whirl_healed = 0.0
	_whirl_speed = param(ability, "speed", 0.3)
	_whirl_sfx = String(ability.get("sfx", ""))
	game.player.stats.set_source(WHIRL_SOURCE, {"speed": _whirl_speed})
	var at := game.player.sim_pos
	var fx := game.fx
	fx.shockwave(at, _whirl_r, COLOR, 1.2, 0.4)
	fx.flash(at, _whirl_r * 0.5, Color(COLOR, 0.8), 0.2)
	fx.dust(at, _whirl_r * 0.4, Color(DEEP, 0.8), [6, 12, 18][FxLayer.wfx], 90.0)
	punch(1.8, 35)
	return true


## Golpes em volta dela a cada `_whirl_gap` s (segue a Yuki); cada golpe rouba vida até o teto.
func _step_whirl(dt: float) -> void:
	_whirl_time -= dt
	_whirl_tick -= dt
	var player := game.player
	var center := player.sim_pos
	if _whirl_tick <= 0.0 and _whirl_hits_left > 0:
		_whirl_tick += _whirl_gap
		_whirl_hits_left -= 1
		var n := hit_circle(&"onikiri_whirl", center, _whirl_r, _whirl_damage, 45.0)
		if n > 0:
			var steal := minf(_whirl_steal_left, _whirl_damage * n * _whirl_steal)
			if steal > 0.0 and player.is_alive:
				var before := player.hp
				player.heal(steal)
				_whirl_healed += player.hp - before
				_whirl_steal_left -= steal
				_add_motes()
			play_sfx(_whirl_sfx + "_hit")
		var angle := GameClock.game_time * WHIRL_SPIN
		game.fx.play_anim("slash_circular", center + Vector2(0, -4), _whirl_r / 15.0, angle,
				Color(1.0, 0.42, 0.42, 0.9), 34.0, _whirl_hits_left % 2 == 0, true)
		if FxLayer.wfx > 0:
			game.fx.sparks(center + Vector2.from_angle(angle) * _whirl_r, Vector2.from_angle(angle + PI * 0.5), HOT,
					FxLayer.wfx * 2, 140.0, 0.4, 0.15)
		punch(0.5, 8)
	if _whirl_time <= 0.0:
		_end_whirl(true)


## Motes de sangue dos inimigos golpeados (os do último hit_circle, em `_hits`) até ela.
func _add_motes() -> void:
	var enemies := game.enemies
	var per := MOTES_PER_HIT[FxLayer.wfx]
	var added := 0
	for j: int in _hits:
		if added >= per:
			break
		if _motes.size() >= MAX_MOTES:
			_motes.pop_front()
		_motes.append({"from": enemies.pos[j] + Vector2(0, -4), "life": MOTE_TIME})
		added += 1


func _end_whirl(effects: bool) -> void:
	game.player.stats.remove_source(WHIRL_SOURCE)
	if effects:
		var player := game.player
		game.fx.add_ring(player.sim_pos, _whirl_r * 1.1, COLOR, 0.35)
		game.fx.dust(player.sim_pos, _whirl_r * 0.8, Color(DEEP, 0.7), [4, 8, 12][FxLayer.wfx], 30.0)
		if _whirl_healed >= 1.0:
			game.fx.add_number(player.sim_pos + Vector2(0.0, player.sprite_top()), _whirl_healed,
					DamagePalette.Kind.HEAL, player.max_hp())
	_whirl_time = 0.0
	_whirl_hits_left = 0


# --- Só desenho (no passo, para seguir a pausa e a velocidade do jogo) --------------------

func _step_visuals(dt: float) -> void:
	if _blood_time > 0.0:
		_blood_time = maxf(0.0, _blood_time - dt)
	if not _claw_trail.is_empty() and not _claw_leaping:
		_claw_trail["life"] = float(_claw_trail["life"]) - dt
		if float(_claw_trail["life"]) <= 0.0:
			_claw_trail = {}
	for list: Array in [_gashes, _roars, _motes]:
		for k: int in range(list.size() - 1, -1, -1):
			list[k]["life"] = float(list[k]["life"]) - dt
			if float(list[k]["life"]) <= 0.0:
				list.remove_at(k)


# --- Bot, save e hash --------------------------------------------------------------------------

## Não gira de novo girando nem salta no meio de outro salto; não gasta vida no rugido e no
## redemoinho com a vida baixa (abaixo de 60%); o resto pela regra do JSON.
func bot_should_cast(slot: int, ability: Dictionary) -> bool:
	var id := StringName(ability["id"])
	if id == &"onikiri_whirl" and _whirl_time > 0.0:
		return false
	if id == &"oni_claw" and (_claw_leaping or _claw_left > 0):
		return false
	var player := game.player
	if system.hp_price(slot) > 0.0 and player.hp < player.max_hp() * 0.6:
		return false
	return super.bot_should_cast(slot, ability)


func state() -> Dictionary:
	return {"claw": [1 if _claw_leaping else 0, _claw_left, _claw_tick, vec(_claw_at), _claw_r, _claw_damage,
			_claw_count, _claw_sfx, vec(_claw_from)],
			"whirl": [_whirl_time, _whirl_max, _whirl_r, _whirl_damage, _whirl_gap, _whirl_tick, _whirl_hits_left,
			_whirl_steal, _whirl_steal_left, _whirl_healed, _whirl_speed, _whirl_sfx]}


func load_state(s: Dictionary) -> void:
	reset()
	var claw: Array = s.get("claw", [])
	if claw.size() >= 9:
		_claw_leaping = int(claw[0]) == 1
		_claw_left = int(claw[1])
		_claw_tick = float(claw[2])
		_claw_at = to_vec(claw[3])
		_claw_r = float(claw[4])
		_claw_damage = float(claw[5])
		_claw_count = maxi(1, int(claw[6]))
		_claw_sfx = String(claw[7])
		_claw_from = to_vec(claw[8])
	var whirl: Array = s.get("whirl", [])
	if whirl.size() >= 12:
		_whirl_time = float(whirl[0])
		_whirl_max = float(whirl[1])
		_whirl_r = float(whirl[2])
		_whirl_damage = float(whirl[3])
		_whirl_gap = maxf(float(whirl[4]), GameClock.STEP)
		_whirl_tick = float(whirl[5])
		_whirl_hits_left = int(whirl[6])
		_whirl_steal = float(whirl[7])
		_whirl_steal_left = float(whirl[8])
		_whirl_healed = float(whirl[9])
		_whirl_speed = float(whirl[10])
		_whirl_sfx = String(whirl[11])
		if _whirl_time > 0.0:
			game.player.stats.set_source(WHIRL_SOURCE, {"speed": _whirl_speed})


func hash_tag() -> String:
	return " yuki=%d,%d,%.3f,%.3f,%d,%.2f" % [1 if _claw_leaping else 0, _claw_left, _claw_tick, _whirl_time,
			_whirl_hits_left, _whirl_steal_left]


# --- Desenho (só leitura) -------------------------------------------------------------------

func has_visuals() -> bool:
	return _claw_leaping or _claw_left > 0 or not _claw_trail.is_empty() or not _gashes.is_empty() \
			or not _roars.is_empty() or _whirl_time > 0.0 or not _motes.is_empty() or _blood_time > 0.0


## Cortes de garra no chão: três rasgos paralelos, vermelho vivo que escurece até sumir.
func draw_ground(canvas: CanvasItem) -> void:
	for g: Dictionary in _gashes:
		var k := clampf(float(g["life"]) / GASH_TIME, 0.0, 1.0)
		var fresh := clampf((k - 0.8) / 0.2, 0.0, 1.0)
		var at: Vector2 = g["pos"]
		var d := Vector2.from_angle(float(g["angle"]))
		var side := d.orthogonal()
		var r := float(g["r"])
		for c: int in range(3):
			var off := side * (c - 1) * 4.0
			var half := r * (0.55 if c != 1 else 0.7)
			var a := (at + off - d * half).round()
			var b := (at + off + d * half).round()
			canvas.draw_line(a, b, Color(DEEP, 0.75 * k), 3.0)
			canvas.draw_line(a, b, COLOR.lerp(BLOOD, 1.0 - fresh) * Color(1, 1, 1, 0.9 * k), 1.0)
	if _whirl_time > 0.0:
		var center := game.player.position
		var fade := clampf(_whirl_time / 0.25, 0.0, 1.0) * clampf((_whirl_max - _whirl_time) / 0.1, 0.0, 1.0)
		canvas.draw_set_transform(center, 0.0, Vector2(1.0, 0.55))
		canvas.draw_circle(Vector2.ZERO, _whirl_r, Color(DEEP, 0.22 * fade))
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Rastro do salto, a onda do rugido, os anéis de corte do redemoinho, os motes de vida e o
## pulso do preço de sangue.
func draw_over(canvas: CanvasItem) -> void:
	var t := GameClock.game_time
	if not _claw_trail.is_empty():
		var a: Vector2 = (_claw_trail["a"] as Vector2) + Vector2(0, -6)
		var b: Vector2 = (game.player.position if _claw_leaping else (_claw_trail["b"] as Vector2)) + Vector2(0, -6)
		var k := 1.0 if _claw_leaping else clampf(float(_claw_trail["life"]) / float(_claw_trail["max"]), 0.0, 1.0)
		# Traço de comprimento zero com largura vira polígono degenerado no motor: só desenha andando.
		if a.round() != b.round():
			canvas.draw_line(a.round(), b.round(), Color(DEEP, 0.6 * k), 6.0 * k + 1.0)
			canvas.draw_line(a.round(), b.round(), Color(COLOR, 0.8 * k), 2.0)
			canvas.draw_line(a.round(), b.round(), Color(HOT, 0.7 * k), 1.0)
	for roar: Dictionary in _roars:
		var k := 1.0 - float(roar["life"]) / ROAR_TIME
		var at: Vector2 = roar["pos"]
		var r := float(roar["r"])
		var fade := 1.0 - k
		for w: int in range(3):
			var rr := r * clampf(k * 1.25 - w * 0.12, 0.0, 1.0)
			if rr <= 2.0:
				continue
			var seg := clampi(int(rr * 0.5), 20, 64)
			Stroke.arc(canvas, at, rr, 0.0, TAU, seg, Color(COLOR if w == 0 else BLOOD, (0.9 - w * 0.25) * fade),
					3.0 - w)
		if FxLayer.wfx > 0:
			Stroke.arc(canvas, at, r * clampf(k * 1.25, 0.0, 1.0) + 3.0, 0.0, TAU, 48, Color(COLD, 0.35 * fade), 1.0)
	if _whirl_time > 0.0:
		_draw_whirl(canvas, t)
	var hero := game.player.position + Vector2(0, -6)
	for m: Dictionary in _motes:
		var k := 1.0 - float(m["life"]) / MOTE_TIME
		var p := (m["from"] as Vector2).lerp(hero, k * k)
		canvas.draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(2, 2)), Color(COLOR, 0.95))
		canvas.draw_rect(Rect2(p.round(), Vector2(1, 1)), Color(HOT, 1.0))
	if _blood_time > 0.0:
		_draw_blood(canvas)


## Lâminas girando (arcos que somem atrás do fio), o anel de corte e o contorno frio.
func _draw_whirl(canvas: CanvasItem, t: float) -> void:
	var center := game.player.position + Vector2(0, -3)
	var r := _whirl_r
	var fade := clampf(_whirl_time / 0.25, 0.0, 1.0) * clampf((_whirl_max - _whirl_time) / 0.1, 0.0, 1.0)
	var spin := t * WHIRL_SPIN
	for b: int in range(WHIRL_BLADES):
		var head := spin + TAU * b / WHIRL_BLADES
		# Rastro do fio: três arcos cada vez mais curtos e claros perto da lâmina.
		Stroke.arc(canvas, center, r, head - 1.4, head, 10, Color(BLOOD, 0.45 * fade), 3.0)
		Stroke.arc(canvas, center, r - 1.0, head - 0.8, head, 7, Color(COLOR, 0.8 * fade), 2.0)
		Stroke.arc(canvas, center, r - 1.0, head - 0.3, head, 4, Color(HOT, 0.95 * fade), 1.0)
		var tip := center + Vector2.from_angle(head) * r
		canvas.draw_line((center + Vector2.from_angle(head) * r * 0.55).round(), tip.round(), Color(COLD, 0.7 * fade), 1.0)
	Stroke.arc(canvas, center, r * 0.6, 0.0, TAU, 32, Color(BLOOD, 0.3 * fade), 1.0)
	if FxLayer.wfx > 0:
		Stroke.arc(canvas, center, r + 3.0, -spin, -spin + PI, 16, Color(COLD, 0.25 * fade), 1.0)


## Preço de sangue: anel vermelho que fecha sobre o corpo, gotas que escorrem e o valor pago.
func _draw_blood(canvas: CanvasItem) -> void:
	var player := game.player
	var k := 1.0 - _blood_time / BLOOD_PULSE
	var body := player.position + Vector2(0.0, player.sprite_top() * 0.5)
	var fade := clampf(_blood_time / 0.2, 0.0, 1.0)
	var r := lerpf(16.0, 5.0, k)
	Stroke.arc(canvas, body, r, 0.0, TAU, 20, Color(BLOOD, 0.9 * fade), 2.0)
	Stroke.arc(canvas, body, r + 2.0, 0.0, TAU, 20, Color(COLOR, 0.45 * fade), 1.0)
	for d: int in range(4):
		var x := -4.0 + d * 2.7
		var y := player.sprite_top() * 0.4 + k * (6.0 + d * 1.5)
		var p := (player.position + Vector2(x, y)).round()
		canvas.draw_rect(Rect2(p, Vector2(1, 2)), Color(BLOOD, fade))


## Brilho (Alta): o corpo pulsando no preço de sangue, a borda do redemoinho e os motes.
func draw_glow(canvas: CanvasItem) -> void:
	var t := GameClock.game_time
	if _blood_time > 0.0:
		var player := game.player
		var k := _blood_time / BLOOD_PULSE
		var pulse := 0.6 + 0.4 * sin(t * 30.0)
		FxLayer.draw_soft(canvas, player.position + Vector2(0.0, player.sprite_top() * 0.5), 14.0,
				Color(COLOR, 0.75 * k * pulse))
	if _whirl_time > 0.0:
		var center := game.player.position + Vector2(0, -3)
		var spin := t * WHIRL_SPIN
		for b: int in range(WHIRL_BLADES):
			var tip := center + Vector2.from_angle(spin + TAU * b / WHIRL_BLADES) * _whirl_r
			FxLayer.draw_soft(canvas, tip, 9.0, Color(COLOR, 0.6))
		FxLayer.draw_soft(canvas, center, _whirl_r * 0.8, Color(BLOOD, 0.12))
	var hero := game.player.position + Vector2(0, -6)
	for m: Dictionary in _motes:
		var k := 1.0 - float(m["life"]) / MOTE_TIME
		FxLayer.draw_soft(canvas, (m["from"] as Vector2).lerp(hero, k * k), 5.0, Color(COLOR, 0.7))
	for roar: Dictionary in _roars:
		var k := 1.0 - float(roar["life"]) / ROAR_TIME
		FxLayer.draw_soft(canvas, roar["pos"], float(roar["r"]) * 0.5 * k + 6.0, Color(BLOOD, 0.3 * (1.0 - k)))
