class_name KuonAbilities
extends HeroAbilities
## Kuon, a última shinobi do clã Hakamori, guardiã dos túmulos (energia: Almas, 魂). Violeta de alma,
## osso velho, índigo e ouro gasto; ela pede aos mortos, não ordena (HeroAbilities explica o contrato):
##   1. 魂狩 Tamashii-gari: as almas em volta são puxadas (EnemyManager.pull_to, alcance `pull`) para
##      junto dela; `pull_time` s depois, um estouro de alma fere todos a até `radius` px, e até
##      `raise_max` dos que morrem voltam como servos (MinionSystem) por `raise_life` s.
##   2. 骨壁 Kotsu-heki: um anel de `spears` lanças de osso irrompe do chão a `radius` px dela: quem está
##      na faixa (`band`) leva `damage`, fica preso por `root_time` s e, por `time` s, o anel segue
##      ferindo e prendendo a cada `tick` s e apaga os tiros inimigos que o cruzam.
##   3. 黄泉返り Yomigaeri: os servos caídos voltam de Yomi (até `recall`, por `minion_life` s; no mínimo
##      RECALL_LEAST mesmo sem caídos), os de pé renovam a vida, um estouro fere e empurra em `radius`
##      e ela fica intangível por `invuln` s, com o contorno de alma.
## Estouros pendentes, o anel e o tempo intangível vão no save e no hash; os servos, no MinionSystem.
## Almas voando, rachaduras e colunas de luz são só desenho.

const COLOR := Color(0.72, 0.55, 1.0)
const HOT := Color(0.95, 0.9, 1.0)
const DEEP := Color(0.2, 0.1, 0.38)
const BONE := Color(0.92, 0.87, 0.76)
const BONE_DARK := Color(0.3, 0.24, 0.34)
const GOLD := Color(0.86, 0.7, 0.36)
## Mínimo de servos que o Yomigaeri levanta mesmo sem caídos.
const RECALL_LEAST := 3
## Almas voando para ela (só desenho): duração do voo, máximo ao mesmo tempo e por puxão.
const SOUL_TIME := 0.45
const MAX_SOULS := 48
const SOULS_PER_CAST: Array[int] = [4, 10, 18]
## Lanças subindo (s) e o anel de chão do Yomigaeri (só desenho, s).
const SPEAR_GROW := 0.15
const RISE_TIME := 0.8
## Folga além da faixa do anel em que os tiros inimigos se desfazem (px).
const SHOT_MARGIN := 4.0

## Estouros pendentes do Tamashii-gari (no save): {"pos", "left", "r", "damage", "raise", "life", "sfx"}.
var _harvests: Array[Dictionary] = []
## Kotsu-heki (no save).
var _wall_time: float = 0.0
var _wall_max: float = 0.0
var _wall_pos := Vector2.ZERO
var _wall_r: float = 0.0
var _wall_band: float = 12.0
var _wall_tick: float = 0.5
var _wall_tick_left: float = 0.0
var _wall_damage: float = 0.0
var _wall_root: float = 1.5
var _wall_spears: int = 14
## Yomigaeri: tempo intangível que falta (no save) e a coluna de almas (só desenho).
var _yomi_time: float = 0.0
var _yomi_max: float = 0.0
var _rise_time: float = 0.0
var _rise_pos := Vector2.ZERO
var _rise_r: float = 0.0
## Almas voando (só desenho): {"from", "life"}; e o anel do puxão (só desenho).
var _souls: Array[Dictionary] = []
var _pull_time: float = 0.0
var _pull_pos := Vector2.ZERO
var _pull_r: float = 0.0


func reset() -> void:
	_harvests.clear()
	_wall_time = 0.0
	_wall_max = 0.0
	_yomi_time = 0.0
	_yomi_max = 0.0
	_rise_time = 0.0
	_souls.clear()
	_pull_time = 0.0
	if game != null and game.player != null:
		game.player.ability_rim.a = 0.0


func cast(slot: int, ability: Dictionary, power: float) -> bool:
	match StringName(ability["id"]):
		&"tamashii_gari":
			return _cast_harvest(ability, power)
		&"kotsu_heki":
			return _cast_wall(ability, power)
		&"yomigaeri":
			return _cast_yomigaeri(ability, power)
	return super.cast(slot, ability, power)


func step(dt: float) -> void:
	if not _harvests.is_empty():
		_step_harvests(dt)
	if _wall_time > 0.0:
		_step_wall(dt)
	if _yomi_time > 0.0:
		_yomi_time = maxf(0.0, _yomi_time - dt)
		var player := game.player
		player.invuln = maxf(player.invuln, _yomi_time)
		var fade := clampf(_yomi_time / 0.3, 0.0, 1.0)
		player.ability_rim = Color(COLOR.lerp(HOT, 0.3 + 0.3 * sin(GameClock.game_time * 9.0)), 0.8 * fade)
		if _yomi_time <= 0.0:
			player.ability_rim.a = 0.0
	if _rise_time > 0.0:
		_rise_time = maxf(0.0, _rise_time - dt)
	if _pull_time > 0.0:
		_pull_time = maxf(0.0, _pull_time - dt)
	for k: int in range(_souls.size() - 1, -1, -1):
		_souls[k]["life"] = float(_souls[k]["life"]) - dt
		if float(_souls[k]["life"]) <= 0.0:
			_souls.remove_at(k)


# --- 魂狩 Tamashii-gari ------------------------------------------------------------------------

func _cast_harvest(ability: Dictionary, power: float) -> bool:
	var at := game.player.sim_pos
	var pull := area_of(ability, "pull")
	var r := area_of(ability, "radius")
	game.enemies.pull_to(at, pull, 14.0)
	_harvests.append({"pos": at, "left": maxf(param(ability, "pull_time", 0.35), GameClock.STEP), "r": r,
			"damage": dmg(ability, "damage", power), "raise": int(param(ability, "raise_max", 4.0)),
			"life": param(ability, "raise_life", 10.0), "sfx": String(ability.get("sfx", ""))})
	_pull_time = param(ability, "pull_time", 0.35)
	_pull_pos = at
	_pull_r = pull
	_spawn_souls(at, pull)
	var fx := game.fx
	fx.add_ring(at, pull, Color(COLOR, 0.8), 0.3)
	fx.flash(at, 20.0, Color(COLOR, 0.8), 0.15)
	fx.play_anim("spirit", at, 1.1, 0.0, Color(COLOR, 0.9), 16.0, false, true)
	return true


func _step_harvests(dt: float) -> void:
	for k: int in range(_harvests.size() - 1, -1, -1):
		var h := _harvests[k]
		h["left"] = float(h["left"]) - dt
		if float(h["left"]) > 0.0:
			continue
		_harvests.remove_at(k)
		_burst(h)


## O estouro de alma: fere em volta e os que morrem (até "raise") levantam como servos.
func _burst(h: Dictionary) -> void:
	var at: Vector2 = h["pos"]
	var r := float(h["r"])
	var enemies := game.enemies
	var minions := game.minions
	enemies.query_circle(at, r, _hits)
	var raised := 0
	var kind := minions.default_kind() if minions != null else 0
	for j: int in _hits.duplicate():
		if enemies.alive[j] == 0 or enemies.is_prop(j):
			continue
		var where := enemies.pos[j]
		hit(&"tamashii_gari", j, float(h["damage"]), (where - at).normalized(), 60.0)
		if enemies.alive[j] == 0 and minions != null and raised < int(h["raise"]):
			if minions.raise(where, &"tamashii_gari", minions.default_damage(), float(h["life"]), kind):
				raised += 1
	var fx := game.fx
	fx.shockwave(at, r, COLOR, 1.0, 0.4)
	fx.flash(at, r * 0.5, Color(COLOR, 0.8), 0.18)
	fx.motes(at, HOT, [3, 8, 14][FxLayer.wfx], r * 0.4, 30.0)
	play_sfx(String(h["sfx"]) + "_hit")
	WeaponSfx.play("soul_pickup")
	punch(1.0, 25)


func _spawn_souls(at: Vector2, r: float) -> void:
	var n := SOULS_PER_CAST[FxLayer.wfx]
	for k: int in range(n):
		if _souls.size() >= MAX_SOULS:
			_souls.pop_front()
		var a := TAU * k / float(n) + GameClock.game_time
		var d := r * (0.55 + 0.45 * fmod(k * 0.618, 1.0))
		_souls.append({"from": at + Vector2.from_angle(a) * d, "life": SOUL_TIME * (0.7 + 0.3 * fmod(k * 0.37, 1.0))})


# --- 骨壁 Kotsu-heki ---------------------------------------------------------------------------

func _cast_wall(ability: Dictionary, power: float) -> bool:
	_wall_pos = game.player.sim_pos
	_wall_r = area_of(ability, "radius")
	_wall_band = area_of(ability, "band")
	_wall_max = dur(ability, "time")
	_wall_time = _wall_max
	_wall_tick = maxf(param(ability, "tick", 0.5), GameClock.STEP)
	_wall_tick_left = _wall_tick
	_wall_damage = dmg(ability, "damage", power)
	_wall_root = dur(ability, "root_time")
	_wall_spears = maxi(4, int(param(ability, "spears", 14.0)))
	_wall_hit(_wall_damage)
	var fx := game.fx
	fx.shockwave(_wall_pos, _wall_r, BONE, 1.2, 0.4)
	fx.dust(_wall_pos, _wall_r, Color(0.85, 0.8, 0.72, 0.7), [3, 8, 14][FxLayer.wfx], 40.0)
	punch(1.4, 35)
	return true


## A faixa do anel: fere (dano `amount`) e prende quem está nela.
func _wall_hit(amount: float) -> int:
	var enemies := game.enemies
	enemies.query_circle(_wall_pos, _wall_r + _wall_band, _hits)
	var count := 0
	for j: int in _hits.duplicate():
		if enemies.alive[j] == 0 or enemies.is_prop(j):
			continue
		var d := enemies.pos[j].distance_to(_wall_pos)
		if d < _wall_r - _wall_band - enemies.radius[j]:
			continue
		hit(&"kotsu_heki", j, amount, (enemies.pos[j] - _wall_pos).normalized(), 30.0)
		if enemies.alive[j] == 1:
			enemies.root_one(j, _wall_root)
		count += 1
	return count


func _step_wall(dt: float) -> void:
	_wall_time = maxf(0.0, _wall_time - dt)
	_wall_tick_left -= dt
	if _wall_tick_left <= 0.0 and _wall_time > 0.0:
		_wall_tick_left += _wall_tick
		if _wall_hit(_wall_damage * 0.25) > 0:
			play_sfx("ab_kotsu_heki_hit")
	var shots := game.enemy_shots
	if shots != null and shots.count_alive > 0:
		var erased := shots.clear_circle(_wall_pos, _wall_r + _wall_band + SHOT_MARGIN,
				maxf(0.0, _wall_r - _wall_band - SHOT_MARGIN))
		if erased > 0 and game.fx != null:
			for p: Vector2 in shots.cleared.slice(0, 4):
				game.fx.sparks(p, (_wall_pos - p).normalized(), BONE, [1, 2, 3][FxLayer.wfx], 60.0, 1.0, 0.15)
			WeaponSfx.play("bone_crack", 1.2)


# --- 黄泉返り Yomigaeri ------------------------------------------------------------------------

func _cast_yomigaeri(ability: Dictionary, power: float) -> bool:
	var player := game.player
	var at := player.sim_pos
	var r := area_of(ability, "radius")
	if game.minions != null:
		game.minions.recall(at, &"yomigaeri", int(param(ability, "recall", 12.0)), RECALL_LEAST,
				param(ability, "minion_life", 12.0))
	hit_circle(&"yomigaeri", at, r, dmg(ability, "damage", power), param(ability, "knockback", 200.0))
	_yomi_max = param(ability, "invuln", 1.5)
	_yomi_time = _yomi_max
	player.invuln = maxf(player.invuln, _yomi_time)
	_rise_time = RISE_TIME
	_rise_pos = at
	_rise_r = r
	var fx := game.fx
	fx.shockwave(at, r, COLOR, 1.6, 0.55)
	fx.flash(at, r * 0.7, Color(COLOR, 0.9), 0.25)
	fx.play_anim("circle_spark", at, r / 16.0, 0.0, Color(COLOR, 0.9), 16.0, false, true)
	fx.motes(at, HOT, [4, 10, 18][FxLayer.wfx], r * 0.5, 40.0)
	punch(2.0, 60)
	return true


## Yomigaeri também quando a vida está baixa (os servos e o tempo intangível salvam a guardiã).
func bot_should_cast(slot: int, ability: Dictionary) -> bool:
	if StringName(ability["id"]) == &"yomigaeri" and game.player.hp < game.player.max_hp() * 0.35:
		return true
	return super.bot_should_cast(slot, ability)


# --- Save e hash -------------------------------------------------------------------------------

func state() -> Dictionary:
	var harvests: Array = []
	for h: Dictionary in _harvests:
		var row := h.duplicate()
		row["pos"] = vec(h["pos"])
		harvests.append(row)
	return {"harvests": harvests, "wall": [_wall_time, _wall_max, _wall_pos.x, _wall_pos.y, _wall_r, _wall_band,
			_wall_tick, _wall_tick_left, _wall_damage, _wall_root, _wall_spears], "yomi": [_yomi_time, _yomi_max]}


func load_state(s: Dictionary) -> void:
	reset()
	for row: Variant in s.get("harvests", []):
		var h: Dictionary = (row as Dictionary).duplicate()
		h["pos"] = to_vec(h.get("pos", []))
		h["left"] = float(h.get("left", 0.0))
		h["r"] = float(h.get("r", 0.0))
		h["damage"] = float(h.get("damage", 0.0))
		h["raise"] = int(h.get("raise", 0))
		h["life"] = float(h.get("life", 10.0))
		h["sfx"] = String(h.get("sfx", ""))
		_harvests.append(h)
	var wall: Array = s.get("wall", [])
	if wall.size() >= 11:
		_wall_time = float(wall[0])
		_wall_max = float(wall[1])
		_wall_pos = Vector2(float(wall[2]), float(wall[3]))
		_wall_r = float(wall[4])
		_wall_band = float(wall[5])
		_wall_tick = maxf(float(wall[6]), GameClock.STEP)
		_wall_tick_left = float(wall[7])
		_wall_damage = float(wall[8])
		_wall_root = float(wall[9])
		_wall_spears = int(wall[10])
	var yomi: Array = s.get("yomi", [])
	if yomi.size() >= 2:
		_yomi_time = float(yomi[0])
		_yomi_max = float(yomi[1])


func hash_tag() -> String:
	var tag := " kuon=%d,%.3f,%.3f,%.3f" % [_harvests.size(), _wall_time, _wall_tick_left, _yomi_time]
	for h: Dictionary in _harvests:
		tag += ",%.1f:%.1f" % [(h["pos"] as Vector2).x, (h["pos"] as Vector2).y]
	# Os servos espectrais (MinionSystem) entram aqui: só a Kuon os levanta.
	return tag + (game.minions.hash_tag() if game.minions != null else "")


# --- Desenho (só leitura) -------------------------------------------------------------------

func has_visuals() -> bool:
	return not _harvests.is_empty() or _wall_time > 0.0 or _yomi_time > 0.0 or _rise_time > 0.0 \
			or not _souls.is_empty() or _pull_time > 0.0


## Chão: o círculo de alma do puxão encolhendo, as rachaduras do anel de ossos e o selo do Yomigaeri.
func draw_ground(canvas: CanvasItem) -> void:
	var t := GameClock.game_time
	if _pull_time > 0.0:
		var k := _pull_time / maxf(0.01, 0.35)
		bold_ring(canvas, _pull_pos, _pull_r * clampf(k, 0.15, 1.0), COLOR, HOT, clampf(k * 1.5, 0.0, 1.0), 2.0)
	if _wall_time > 0.0:
		var fade := clampf(_wall_time / 0.3, 0.0, 1.0)
		bold_ring(canvas, _wall_pos, _wall_r, Color(BONE_DARK, 0.8), Color(BONE, 0.6), fade * 0.7, 2.0)
		for k: int in range(_wall_spears):
			var a := TAU * k / float(_wall_spears)
			var from := _wall_pos + Vector2.from_angle(a) * (_wall_r - _wall_band)
			var to := _wall_pos + Vector2.from_angle(a + 0.05) * (_wall_r + _wall_band)
			Stroke.line(canvas, PackedVector2Array([from, to]), Color(0.12, 0.08, 0.14, 0.5 * fade), 1.0)
	if _rise_time > 0.0:
		var k := _rise_time / RISE_TIME
		var r := _rise_r * (1.1 - 0.3 * k)
		bold_ring(canvas, _rise_pos, r, COLOR, HOT, k, 3.0)
		bold_ring(canvas, _rise_pos, r * 0.6, Color(GOLD, 0.8), HOT, k * 0.8, 1.0)
		for s: int in range(6):
			var a := TAU * s / 6.0 + t * 0.8
			canvas.draw_rect(Rect2((_rise_pos + Vector2.from_angle(a) * r * 0.8).round() - Vector2(1, 1), Vector2(3, 3)),
					Color(GOLD, 0.8 * k))


## Por cima: as lanças de osso do anel (sobem em SPEAR_GROW s, tremem e afundam no fim), as almas
## voando para a Kuon e a coluna de almas do Yomigaeri.
func draw_over(canvas: CanvasItem) -> void:
	var t := GameClock.game_time
	if _wall_time > 0.0:
		var grow := clampf((_wall_max - _wall_time) / SPEAR_GROW, 0.0, 1.0)
		var sink := clampf(_wall_time / 0.3, 0.0, 1.0)
		var h := 12.0 * grow * sink
		for k: int in range(_wall_spears):
			var a := TAU * k / float(_wall_spears)
			var base := (_wall_pos + Vector2.from_angle(a) * _wall_r).round()
			var lean := Vector2.from_angle(a) * 3.0 * grow
			var tip := base + Vector2(0, -h) + lean + Vector2(sin(t * 20.0 + k) * 0.4, 0)
			Stroke.line(canvas, PackedVector2Array([base, tip]), Color(BONE_DARK, 0.9 * sink), 3.0)
			Stroke.line(canvas, PackedVector2Array([base, tip]), Color(BONE, sink), 1.0)
			canvas.draw_rect(Rect2(tip.round() - Vector2(1, 1), Vector2(2, 2)), Color(HOT, 0.9 * sink))
	if not _souls.is_empty():
		var me := game.player.position
		for soul: Dictionary in _souls:
			var u := 1.0 - float(soul["life"]) / SOUL_TIME
			var from: Vector2 = soul["from"]
			var p := from.lerp(me + Vector2(0, -6), clampf(u * u, 0.0, 1.0))
			p += (me - from).orthogonal().normalized() * sin(u * PI) * 8.0
			canvas.draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(2, 2)), Color(HOT, 0.9))
			canvas.draw_rect(Rect2(p.round() - Vector2(2, 0), Vector2(1, 1)), Color(COLOR, 0.6))
	if _rise_time > 0.0:
		var k := _rise_time / RISE_TIME
		var at := _rise_pos.round()
		for s: int in range(5):
			var x := (s - 2) * 5.0
			var y := -fmod(t * 60.0 + s * 13.0, 40.0)
			canvas.draw_rect(Rect2(at + Vector2(x, y - 4.0), Vector2(1, 3)), Color(HOT, 0.7 * k))


func draw_glow(canvas: CanvasItem) -> void:
	if _yomi_time > 0.0:
		FxLayer.draw_soft(canvas, game.player.position + Vector2(0, -6), 22.0,
				Color(COLOR, 0.45 * clampf(_yomi_time / 0.3, 0.0, 1.0)))
	if _rise_time > 0.0:
		FxLayer.draw_soft(canvas, _rise_pos, _rise_r * 0.6, Color(COLOR, 0.35 * _rise_time / RISE_TIME))
	if _wall_time > 0.0:
		var fade := clampf(_wall_time / 0.3, 0.0, 1.0)
		for k: int in range(0, _wall_spears, 2):
			var a := TAU * k / float(_wall_spears)
			FxLayer.draw_soft(canvas, _wall_pos + Vector2.from_angle(a) * _wall_r + Vector2(0, -8), 6.0,
					Color(HOT, 0.3 * fade))
	for soul: Dictionary in _souls:
		var u := 1.0 - float(soul["life"]) / SOUL_TIME
		var from: Vector2 = soul["from"]
		FxLayer.draw_soft(canvas, from.lerp(game.player.position, clampf(u * u, 0.0, 1.0)), 5.0, Color(COLOR, 0.5))
