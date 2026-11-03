class_name GoroAbilities
extends HeroAbilities
## Goro, o monge que não envelhece, preso a um voto (energia: Penitência, 業). Ouro, bronze de
## templo, mantra e incenso (HeroAbilities explica o contrato):
##   1. 金剛身 Corpo de Diamante: por `time` s o dano recebido cai (`reduction`) e parte do dano de
##      contato volta a quem encostou (`thorns`, Player.add_guard / add_thorns). O corpo fica com
##      contorno dourado e uma casca facetada; cada golpe aparado solta um lampejo de diamante.
##   2. 錫杖 Golpe do Shakujō: o cajado sobe (antecipação curta) e bate no chão: onda de choque que
##      fere e atordoa em volta; rachaduras e poeira no chão, argolas tilintando no topo do cajado.
##   3. 師の真言 Mantra do Mestre: `pulses` pulsos a cada `interval` s em volta do Goro; cada inimigo
##      atingido cura `heal_per_hit` (no máximo `heal_max` por pulso). Três anéis de sílabas giram
##      em volta dele e cada pulso solta um anel de sílabas douradas que se expande.
## Corpo de Diamante, o golpe ainda no ar e os pulsos que faltam vão no save e no hash (o Corpo
## de Diamante é reaplicado ao Player ao retomar). Rachaduras e anéis de sílabas são só desenho.

const GOLD := Color(1.0, 0.83, 0.42)
const HOT := Color(1.0, 0.97, 0.84)
const BRONZE := Color(0.74, 0.5, 0.22)
const DUST := Color(0.78, 0.68, 0.5)
const INCENSE := Color(0.9, 0.86, 0.74)
## Antecipação do Shakujō: o cajado sobe antes de bater (s).
const SLAM_WINDUP := 0.14
## Cajado fincado no chão depois da batida (só desenho, s) e altura do cajado (px).
const STAFF_TIME := 0.7
const STAFF_HEIGHT := 26.0
## Rachaduras do Shakujō: quantas, quantos trechos cada uma e quanto duram (só desenho).
const CRACKS: Array[int] = [5, 7, 9]
const CRACK_PARTS := 4
const CRACK_TIME := 1.4
## Casca facetada do Corpo de Diamante: raio (px), lados e o tempo do lampejo do golpe aparado.
const SHELL_R := 13.0
const SHELL_SIDES := 6
const BLOCK_FLASH := 0.2
## Sílabas do mantra (Kōmyō Shingon e o nembutsu), anéis em volta do Goro (raio, sílabas, giro).
const MANTRA_TEXT := "オンアボキャベイロシャノウ"
const NEMBUTSU := "南無阿弥陀仏"
const MANTRA_RINGS: Array[Vector3] = [Vector3(18.0, 6.0, 1.3), Vector3(28.0, 9.0, -0.9), Vector3(38.0, 12.0, 0.6)]
## Sílabas do anel que se expande em cada pulso em cada nível gráfico, e a duração do anel (s).
const WAVE_GLYPHS: Array[int] = [10, 16, 22]
const WAVE_TIME := 0.55
const GLYPH_SIZE := 12

static var _font: Font

# Corpo de Diamante (no save).
var _diamond_time: float = 0.0
var _diamond_max: float = 0.0
var _diamond_mult: float = 1.0
var _diamond_thorns: float = 0.0
## Lampejo do golpe aparado (só desenho).
var _block_flash: float = 0.0
## Batidas do Shakujō esperando a antecipação: {"left", "r", "damage", "stun", "force", "sfx"}.
var _slams: Array[Dictionary] = []
## Cajado fincado (só desenho): tempo restante e onde.
var _staff_time: float = 0.0
var _staff_pos := Vector2.ZERO
## Rachaduras (só desenho): {"pos", "lines": Array[PackedVector2Array], "life"}.
var _cracks: Array[Dictionary] = []
# Mantra do Mestre (no save).
var _mantra_left: int = 0
var _mantra_tick: float = 0.0
var _mantra_interval: float = 0.6
var _mantra_r: float = 0.0
var _mantra_damage: float = 0.0
var _mantra_heal: float = 1.0
var _mantra_heal_max: float = 15.0
var _mantra_sfx: String = ""
## Anéis de sílabas e o fim suave dos anéis em volta (só desenho).
var _waves: Array[Dictionary] = []
var _mantra_fade: float = 0.0


func reset() -> void:
	_diamond_time = 0.0
	_diamond_max = 0.0
	_diamond_mult = 1.0
	_diamond_thorns = 0.0
	_block_flash = 0.0
	_slams.clear()
	_staff_time = 0.0
	_cracks.clear()
	_mantra_left = 0
	_mantra_tick = 0.0
	_waves.clear()
	_mantra_fade = 0.0
	if game != null and game.player != null:
		game.player.ability_rim.a = 0.0


func cast(slot: int, ability: Dictionary, power: float) -> bool:
	match StringName(ability["id"]):
		&"diamond_body":
			return _cast_diamond(ability)
		&"shakujo":
			return _cast_shakujo(ability, power)
		&"master_mantra":
			return _cast_mantra(ability, power)
	return super.cast(slot, ability, power)


func step(dt: float) -> void:
	if _diamond_time > 0.0:
		_step_diamond(dt)
	if _block_flash > 0.0:
		_block_flash = maxf(0.0, _block_flash - dt)
	if not _slams.is_empty():
		_step_slams(dt)
	if _staff_time > 0.0:
		_staff_time = maxf(0.0, _staff_time - dt)
	for k: int in range(_cracks.size() - 1, -1, -1):
		_cracks[k]["life"] = float(_cracks[k]["life"]) - dt
		if float(_cracks[k]["life"]) <= 0.0:
			_cracks.remove_at(k)
	if _mantra_left > 0:
		_step_mantra(dt)
	elif _mantra_fade > 0.0:
		_mantra_fade = maxf(0.0, _mantra_fade - dt)
	for k: int in range(_waves.size() - 1, -1, -1):
		_waves[k]["age"] = float(_waves[k]["age"]) + dt
		if float(_waves[k]["age"]) >= WAVE_TIME:
			_waves.remove_at(k)


# --- 金剛身 Corpo de Diamante ----------------------------------------------------------------

func _cast_diamond(ability: Dictionary) -> bool:
	_diamond_max = dur(ability, "time")
	_diamond_time = _diamond_max
	_diamond_mult = clampf(1.0 - param(ability, "reduction", 0.6), 0.0, 1.0)
	_diamond_thorns = param(ability, "thorns", 0.5)
	_apply_diamond()
	var at := game.player.sim_pos + Vector2(0.0, -6.0)
	var fx := game.fx
	fx.play_anim("shield", at, 1.0, 0.0, Color(1.0, 0.88, 0.55, 0.6), 24.0, false, true)
	fx.flash(at, 22.0, Color(GOLD, 0.7), 0.14)
	fx.shockwave(game.player.sim_pos, 48.0, GOLD, 0.8, 0.35)
	fx.sparks(at, Vector2.UP, HOT, [5, 10, 16][FxLayer.wfx], 130.0, PI, 0.3)
	fx.motes(at, GOLD, [2, 6, 10][FxLayer.wfx], 12.0, 24.0)
	punch(1.2, 30)
	return true


func _apply_diamond() -> void:
	game.player.add_guard(_diamond_mult, _diamond_time)
	game.player.add_thorns(_diamond_thorns, _diamond_time, &"diamond_body")


## Conta o tempo, acende o contorno e, a cada golpe recebido neste passo (o Player zera
## damage_taken_time no take_damage), o lampejo de diamante e as faíscas em quem encostou.
func _step_diamond(dt: float) -> void:
	var player := game.player
	_diamond_time -= dt
	if player.damage_taken_time == 0.0 and player.is_alive:
		_on_block()
	if _diamond_time <= 0.0:
		_diamond_time = 0.0
		player.ability_rim.a = 0.0
		var at := player.sim_pos + Vector2(0.0, -6.0)
		game.fx.dust(at, SHELL_R, Color(GOLD, 0.9), [4, 8, 12][FxLayer.wfx], 50.0)
		game.fx.add_ring(at, SHELL_R * 1.8, GOLD, 0.3, 1.0)
		return
	var fade := clampf(_diamond_time / 0.4, 0.0, 1.0)
	var pulse := 0.4 + 0.15 * sin(GameClock.game_time * 9.0) + _block_flash * 2.0
	player.ability_rim = Color(GOLD.lerp(HOT, _block_flash * 2.0), clampf(pulse, 0.0, 0.8) * fade)


func _on_block() -> void:
	_block_flash = BLOCK_FLASH
	var player := game.player
	var at := player.sim_pos + Vector2(0.0, -6.0)
	var fx := game.fx
	fx.flash(at, 12.0, Color(GOLD, 0.6), 0.1)
	fx.sparks(at, Vector2.ZERO, GOLD, [3, 6, 10][FxLayer.wfx], 120.0, PI, 0.2)
	if FxLayer.wfx > 0:
		fx.play_anim("spark", at + Vector2(0.0, -SHELL_R), 0.4, 0.0, Color(1.0, 0.9, 0.6), 30.0, false, true)
	# Quem encostou leva a faísca dourada do dano devolvido (o golpe em si é do EnemyManager).
	var enemies := game.enemies
	enemies.query_circle(player.sim_pos, 18.0, _hits)
	var shown := 0
	for j: int in _hits:
		if shown >= 3 or enemies.alive[j] == 0 or enemies.is_prop(j):
			continue
		var d := enemies.pos[j] - player.sim_pos
		fx.sparks(enemies.pos[j], d, HOT, [2, 4, 6][FxLayer.wfx], 100.0, 0.6, 0.18)
		shown += 1
	impact_sfx({"sfx": "ab_diamond_body"})
	punch(0.6, 15)


# --- 錫杖 Golpe do Shakujō ------------------------------------------------------------------

func _cast_shakujo(ability: Dictionary, power: float) -> bool:
	_slams.append({"left": SLAM_WINDUP, "r": area_of(ability, "radius"), "damage": dmg(ability, "damage", power),
			"stun": dur(ability, "stun"), "force": param(ability, "knockback", 110.0),
			"sfx": String(ability.get("sfx", ""))})
	_staff_time = STAFF_TIME + SLAM_WINDUP
	_staff_pos = game.player.sim_pos
	var at := game.player.sim_pos + Vector2(0.0, -STAFF_HEIGHT)
	game.fx.flash(at, 14.0, Color(GOLD, 0.8), 0.12)
	game.fx.motes(at, GOLD, [1, 3, 5][FxLayer.wfx], 6.0, 20.0)
	return true


func _step_slams(dt: float) -> void:
	var landed: Array[Dictionary] = []
	for slam: Dictionary in _slams:
		slam["left"] = float(slam["left"]) - dt
		if float(slam["left"]) <= 0.0:
			landed.append(slam)
	for slam: Dictionary in landed:
		_slams.erase(slam)
		_slam(slam)


## A batida: fere e atordoa no raio, onda de choque com distorção, poeira, pedras e rachaduras.
func _slam(slam: Dictionary) -> void:
	var at := game.player.sim_pos
	var r := float(slam["r"])
	hit_circle(&"shakujo", at, r, float(slam["damage"]), float(slam["force"]), false, float(slam["stun"]))
	_staff_pos = at
	_staff_time = STAFF_TIME
	var fx := game.fx
	fx.shockwave(at, r, GOLD, 1.8, 0.5)
	fx.add_ring(at, r * 0.55, Color(BRONZE, 0.9), 0.35, 3.0)
	fx.flash(at, r * 0.6, Color(GOLD, 0.85), 0.2)
	fx.dust(at, 8.0, Color(DUST, 0.9), [8, 16, 26][FxLayer.wfx], 140.0)
	fx.dust(at, r * 0.8, Color(DUST, 0.6), [4, 10, 16][FxLayer.wfx], 30.0)
	fx.sparks(at + Vector2(0.0, -STAFF_HEIGHT), Vector2.ZERO, HOT, [4, 8, 12][FxLayer.wfx], 90.0, PI, 0.25)
	var spikes: int = [0, 4, 6][FxLayer.wfx]
	for k: int in range(spikes):
		var p := at + Vector2.from_angle(TAU * k / float(spikes) + 0.4) * r * 0.45
		fx.play_anim("rock_spike", p, 0.45, 0.0, Color(0.95, 0.85, 0.65), 22.0)
	_add_cracks(at, r)
	play_sfx(String(slam.get("sfx", "")) + "_hit")
	punch(3.0, 60)


## Rachaduras em zigue-zague a partir do centro (só desenho: usa randf, fora da simulação).
func _add_cracks(at: Vector2, r: float) -> void:
	var lines: Array[PackedVector2Array] = []
	var count: int = CRACKS[FxLayer.wfx]
	for k: int in range(count):
		var a := TAU * k / float(count) + randf_range(-0.3, 0.3)
		var reach := r * randf_range(0.45, 0.75)
		var pts := PackedVector2Array([at])
		for p: int in range(1, CRACK_PARTS + 1):
			var along := reach * p / float(CRACK_PARTS)
			var side := Vector2.from_angle(a).orthogonal() * randf_range(-4.0, 4.0)
			pts.append((at + Vector2.from_angle(a) * along + side).round())
		lines.append(pts)
	if _cracks.size() >= 3:
		_cracks.pop_front()
	_cracks.append({"pos": at, "lines": lines, "life": CRACK_TIME})


# --- 師の真言 Mantra do Mestre --------------------------------------------------------------

func _cast_mantra(ability: Dictionary, power: float) -> bool:
	_mantra_left = maxi(1, int(param(ability, "pulses", 3.0)))
	_mantra_interval = maxf(param(ability, "interval", 0.6), GameClock.STEP)
	_mantra_r = area_of(ability, "radius")
	_mantra_damage = dmg(ability, "damage", power)
	_mantra_heal = param(ability, "heal_per_hit", 1.0)
	_mantra_heal_max = param(ability, "heal_max", 15.0)
	_mantra_sfx = String(ability.get("sfx", ""))
	_mantra_tick = 0.0
	var at := game.player.sim_pos
	game.fx.flash(at, 40.0, Color(GOLD, 0.8), 0.25)
	game.fx.shockwave(at, 46.0, GOLD, 0.8, 0.35)
	game.fx.embers(at, INCENSE, [3, 6, 10][FxLayer.wfx], 10.0)
	_pulse()
	return true


func _step_mantra(dt: float) -> void:
	_mantra_tick -= dt
	if _mantra_tick <= 0.0:
		_pulse()


## Um pulso: fere no raio e cura pelo número de atingidos (com teto).
func _pulse() -> void:
	_mantra_left -= 1
	_mantra_tick += _mantra_interval
	_mantra_fade = 0.35
	var player := game.player
	var at := player.sim_pos
	var count := hit_circle(&"master_mantra", at, _mantra_r, _mantra_damage, 50.0)
	player.heal(minf(count * _mantra_heal, _mantra_heal_max), true)
	if _waves.size() >= 4:
		_waves.pop_front()
	_waves.append({"pos": at, "age": 0.0})
	var fx := game.fx
	fx.add_ring(at, _mantra_r, Color(GOLD, 0.8), WAVE_TIME, 2.0)
	fx.distort(at, _mantra_r, 0.6, WAVE_TIME)
	fx.flash(at, 24.0, Color(HOT, 0.7), 0.12)
	fx.motes(at, GOLD, [2, 6, 10][FxLayer.wfx], _mantra_r * 0.5, 30.0)
	play_sfx(_mantra_sfx + "_hit")
	punch(1.0, 20)
	if _mantra_left <= 0:
		_mantra_left = 0
		_mantra_tick = 0.0


# --- Bot, save e hash --------------------------------------------------------------------------

## Corpo de Diamante só quando já não está ativo; o Mantra também para curar (vida abaixo de
## 60% com alguém perto); o resto pela regra do JSON.
func bot_should_cast(slot: int, ability: Dictionary) -> bool:
	var id := StringName(ability["id"])
	if id == &"diamond_body" and _diamond_time > 0.0:
		return false
	if id == &"master_mantra":
		if _mantra_left > 0:
			return false
		var player := game.player
		if player.hp < player.max_hp() * 0.6 and game.enemies.count_in_circle(player.sim_pos, 130.0, 4) >= 4:
			return true
	return super.bot_should_cast(slot, ability)


func state() -> Dictionary:
	var slams: Array = []
	for s: Dictionary in _slams:
		slams.append(s.duplicate())
	return {"diamond": [_diamond_time, _diamond_max, _diamond_mult, _diamond_thorns], "slams": slams,
			"mantra": [_mantra_left, _mantra_tick, _mantra_interval, _mantra_r, _mantra_damage, _mantra_heal,
					_mantra_heal_max, _mantra_sfx]}


func load_state(s: Dictionary) -> void:
	reset()
	var d: Array = s.get("diamond", [])
	if d.size() >= 4:
		_diamond_time = float(d[0])
		_diamond_max = float(d[1])
		_diamond_mult = float(d[2])
		_diamond_thorns = float(d[3])
		if _diamond_time > 0.0:
			_apply_diamond()
	for row: Variant in s.get("slams", []):
		_slams.append((row as Dictionary).duplicate())
	var m: Array = s.get("mantra", [])
	if m.size() >= 8:
		_mantra_left = int(m[0])
		_mantra_tick = float(m[1])
		_mantra_interval = maxf(float(m[2]), GameClock.STEP)
		_mantra_r = float(m[3])
		_mantra_damage = float(m[4])
		_mantra_heal = float(m[5])
		_mantra_heal_max = float(m[6])
		_mantra_sfx = String(m[7])
	if not _slams.is_empty():
		_staff_time = STAFF_TIME + SLAM_WINDUP
		_staff_pos = game.player.sim_pos


func hash_tag() -> String:
	return " goro=%.3f,%d,%d,%.3f" % [_diamond_time, _slams.size(), _mantra_left, _mantra_tick]


# --- Desenho (só leitura) -------------------------------------------------------------------

func has_visuals() -> bool:
	return _diamond_time > 0.0 or not _slams.is_empty() or _staff_time > 0.0 or not _cracks.is_empty() \
			or _mantra_left > 0 or _mantra_fade > 0.0 or not _waves.is_empty()


static func _glyph_font() -> Font:
	if _font == null:
		_font = load(AbilityLayer.KANJI_FONT) as Font if ResourceLoader.exists(AbilityLayer.KANJI_FONT) \
				else ThemeDB.fallback_font
	return _font


## Rachaduras do Shakujō (escuras com um fio de luz dourada que apaga) e o sinal do mantra no chão.
func draw_ground(canvas: CanvasItem) -> void:
	for c: Dictionary in _cracks:
		var k := clampf(float(c["life"]) / CRACK_TIME, 0.0, 1.0)
		var fade := minf(1.0, k * 2.5)
		for pts: PackedVector2Array in c["lines"]:
			Stroke.line(canvas, pts, Color(0.12, 0.08, 0.04, 0.7 * fade), 2.0)
			if k > 0.55:
				Stroke.line(canvas, pts, Color(GOLD, (k - 0.55) * 1.8), 1.0)
	if _mantra_left > 0 or _mantra_fade > 0.0:
		var center := game.player.position
		var fade := 1.0 if _mantra_left > 0 else _mantra_fade / 0.35
		canvas.draw_circle(center, 44.0, Color(GOLD, 0.06 * fade))
		Stroke.arc(canvas, center, 44.0, 0.0, TAU, 40, Color(BRONZE, 0.5 * fade), 1.0)


## Casca facetada do Corpo de Diamante, o cajado com as argolas, os anéis de sílabas.
func draw_over(canvas: CanvasItem) -> void:
	var t := GameClock.game_time
	if _diamond_time > 0.0:
		_draw_shell(canvas, t)
	if _staff_time > 0.0 or not _slams.is_empty():
		_draw_staff(canvas, t)
	if _mantra_left > 0 or _mantra_fade > 0.0:
		var fade := 1.0 if _mantra_left > 0 else _mantra_fade / 0.35
		var center := game.player.position + Vector2(0.0, -4.0)
		for k: int in range(MANTRA_RINGS.size()):
			var ring := MANTRA_RINGS[k]
			var text := NEMBUTSU if k == 1 else MANTRA_TEXT
			_draw_glyph_ring(canvas, center, ring.x, int(ring.y), t * ring.z, text, Color(GOLD, 0.8 * fade))
	for w: Dictionary in _waves:
		var k := float(w["age"]) / WAVE_TIME
		var r := _mantra_r * (1.0 - (1.0 - k) * (1.0 - k))
		var color := Color(GOLD.lerp(HOT, 1.0 - k), (1.0 - k) * 0.95)
		bold_ring(canvas, w["pos"], r, GOLD.lerp(HOT, 1.0 - k), HOT, 1.0 - k, 2.0)
		_draw_glyph_ring(canvas, w["pos"], r, WAVE_GLYPHS[FxLayer.wfx], k * 1.5, MANTRA_TEXT, color)


## Hexágono de cristal em volta do Goro que gira devagar, com as facetas até o centro e quatro
## brilhos de diamante em órbita; no golpe aparado, tudo acende e a casca incha.
func _draw_shell(canvas: CanvasItem, t: float) -> void:
	var center := game.player.position + Vector2(0.0, -6.0)
	var fade := clampf(_diamond_time / 0.4, 0.0, 1.0) * clampf((_diamond_max - _diamond_time) / 0.12, 0.0, 1.0)
	var flash := _block_flash / BLOCK_FLASH
	var r := SHELL_R + 2.0 * flash
	var spin := t * 0.8
	var pts := PackedVector2Array()
	for k: int in range(SHELL_SIDES + 1):
		pts.append(center + Vector2.from_angle(spin + TAU * k / SHELL_SIDES) * Vector2(r, r * 1.15))
	var edge := Color(GOLD.lerp(HOT, flash), (0.8 + 0.2 * flash) * fade)
	# Casca com sombra escura e borda dourada larga: lê no meio da horda.
	Stroke.line(canvas, pts, Color(RING_SHADOW, 0.6 * fade), 4.0)
	Stroke.line(canvas, pts, edge, 2.0)
	Stroke.line(canvas, pts, Color(HOT, 0.7 * fade), 1.0)
	if FxLayer.wfx > 0:
		for k: int in range(0, SHELL_SIDES, 2):
			Stroke.line(canvas, PackedVector2Array([pts[k], center + Vector2(0.0, -2.0)]),
					Color(GOLD, (0.18 + 0.4 * flash) * fade), 1.0)
	for k: int in range(4):
		var p := center + Vector2.from_angle(-t * 1.6 + TAU * k / 4.0) * (r + 4.0)
		var s := 1.5 + 0.8 * sin(t * 6.0 + k * 1.7) + flash * 1.5
		Stroke.convex(canvas, PackedVector2Array([p + Vector2(0, -s - 1.0), p + Vector2(s, 0), p + Vector2(0, s + 1.0),
				p + Vector2(-s, 0)]), Color(HOT, 0.85 * fade))


## O shakujō: sobe na antecipação e fica fincado ao lado do Goro, com a argola grande no topo e
## as seis argolas pequenas tilintando.
func _draw_staff(canvas: CanvasItem, t: float) -> void:
	var base := (game.player.position if not _slams.is_empty() else _staff_pos) + Vector2(7.0, 2.0)
	var lift := 0.0
	if not _slams.is_empty():
		lift = 10.0 * (1.0 - float(_slams[0]["left"]) / SLAM_WINDUP)
	var fade := clampf(_staff_time / 0.25, 0.0, 1.0) if _slams.is_empty() else 1.0
	var top := base + Vector2(0.0, -STAFF_HEIGHT - lift)
	var bottom := base + Vector2(0.0, -lift)
	Stroke.line(canvas, PackedVector2Array([bottom.round(), top.round()]), Color(0.36, 0.22, 0.1, fade), 2.0)
	Stroke.line(canvas, PackedVector2Array([bottom.round() + Vector2(0.5, 0), top.round() + Vector2(0.5, 0)]),
			Color(BRONZE, 0.8 * fade), 1.0)
	var loop := top + Vector2(0.0, -4.0)
	Stroke.arc(canvas, loop, 4.0, 0.0, TAU, 12, Color(GOLD, fade), 1.0)
	var since := STAFF_TIME - _staff_time
	var jingle := 2.0 * exp(-since * 5.0) if _slams.is_empty() else 1.0
	for k: int in range(6):
		var side := -1.0 if k < 3 else 1.0
		var a := PI * 0.5 + side * (0.5 + 0.35 * (k % 3)) + sin(t * 26.0 + k) * 0.25 * jingle
		var p := loop + Vector2.from_angle(a) * 4.5
		Stroke.arc(canvas, p, 1.5, 0.0, TAU, 6, Color(HOT, fade), 1.0)


func _draw_glyph_ring(canvas: CanvasItem, center: Vector2, r: float, count: int, spin: float, text: String,
		color: Color) -> void:
	if r < 4.0 or count <= 0 or color.a <= 0.01:
		return
	var font := _glyph_font()
	for k: int in range(count):
		var p := center + Vector2.from_angle(spin + TAU * k / float(count)) * r
		var ch := text.substr(k % text.length(), 1)
		canvas.draw_char_outline(font, (p + Vector2(-GLYPH_SIZE * 0.5, GLYPH_SIZE * 0.4)).round(), ch, GLYPH_SIZE, 3,
				Color(RING_SHADOW, RING_SHADOW.a * color.a))
		canvas.draw_char(font, (p + Vector2(-GLYPH_SIZE * 0.5, GLYPH_SIZE * 0.4)).round(), ch, GLYPH_SIZE, color)


## Brilho (Alta): halo dourado no Corpo de Diamante, no topo do cajado e nas ondas do mantra.
func draw_glow(canvas: CanvasItem) -> void:
	var t := GameClock.game_time
	if _diamond_time > 0.0:
		var fade := clampf(_diamond_time / 0.4, 0.0, 1.0)
		var flash := _block_flash / BLOCK_FLASH
		FxLayer.draw_soft(canvas, game.player.position + Vector2(0.0, -6.0), 18.0 + 8.0 * flash,
				Color(GOLD, (0.14 + 0.05 * sin(t * 9.0) + 0.3 * flash) * fade))
	if _staff_time > 0.0:
		FxLayer.draw_soft(canvas, _staff_pos + Vector2(7.0, -STAFF_HEIGHT - 2.0), 9.0,
				Color(GOLD, 0.5 * clampf(_staff_time / 0.25, 0.0, 1.0)))
	if _mantra_left > 0:
		FxLayer.draw_soft(canvas, game.player.position, 46.0, Color(GOLD, 0.1 + 0.04 * sin(t * 5.0)))
	for w: Dictionary in _waves:
		var k := float(w["age"]) / WAVE_TIME
		FxLayer.draw_soft(canvas, w["pos"], _mantra_r * (0.4 + 0.6 * k), Color(GOLD, 0.12 * (1.0 - k)))
