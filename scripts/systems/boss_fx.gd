class_name BossFx
extends Node2D
## Apresentação dos chefes (só desenho e som; nada aqui entra na simulação):
## - entrada: portal de névoa no chão, colunas de luz, fumaça e rugido;
## - aura sob o chefe na cor dele; enfurecido: aura vermelha, línguas de fogo e brasas;
## - avisos de ataque animados por cima dos de AreaEffects (anel tracejado que gira, anel que
##   fecha marcando o tempo, "!" no fim) e seta em chevrons na investida;
## - troca de fase: clarão, anéis e faíscas;
## - morte épica: o corpo pisca branco e treme, explosões em camadas, clarão, câmera lenta só
##   dos efeitos, dissolve de baixo para cima e chuva de almas.
## Fica dentro do BossDirector (z -3: acima dos avisos do chão, abaixo dos inimigos); as
## partículas vão para o EnemyFx (z 9, acima de todos).

const PORTAL_TIME := 1.8
const DEATH_TIME := 2.2
const DEFAULT_AURA := Color(0.75, 0.4, 1.0)
const ENRAGED := Color(1.0, 0.18, 0.1)
const WARN := Color(1.0, 0.25, 0.22)
## Explosões da morte: [segundo, deslocamento em fração do raio, tamanho].
const BLASTS := [[0.0, Vector2(0.0, -0.4), 1.0], [0.25, Vector2(-0.8, -0.9), 0.8], [0.45, Vector2(0.7, -0.2), 0.9],
		[0.7, Vector2(-0.3, -1.3), 0.8], [0.95, Vector2(0.9, -1.0), 1.0], [1.2, Vector2(-0.9, 0.0), 0.9],
		[1.5, Vector2(0.0, -0.7), 2.2]]

var director: BossDirector
var detail: int = 2
var glow: bool = true

## Portais de entrada: {"pos", "t", "color"}.
var _portals: Array[Dictionary] = []
## Mortes em andamento: {"pos", "t", "sheet", "src", "scale", "flip", "tint", "radius", "next", "color"}.
var _deaths: Array[Dictionary] = []
var _soft: Texture2D
var _add: Node2D
var _look := RandomNumberGenerator.new()
var _emit_left: float = 0.0


func _ready() -> void:
	_soft = EnemyFx.soft_texture()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add = Node2D.new()
	_add.material = additive
	_add.draw.connect(_draw_glow)
	add_child(_add)
	_look.randomize()
	apply_quality()
	var settings := get_node_or_null(^"/root/Settings")
	if settings:
		settings.connect("changed", func(k: String) -> void:
			if k == GfxQuality.changed_signal_key():
				apply_quality())


func apply_quality() -> void:
	detail = int(GfxQuality.budget("enemy_fx"))
	glow = bool(GfxQuality.budget("glow"))


func reset() -> void:
	_portals.clear()
	_deaths.clear()


func deaths_active() -> int:
	return _deaths.size()


static func aura_color(data: Dictionary) -> Color:
	return Color(String(data.get("aura", DEFAULT_AURA.to_html(false))))


func _enemies() -> EnemyManager:
	return director.game.enemies


# --- Eventos ------------------------------------------------------------------------------

func on_spawn(boss: Dictionary) -> void:
	var i := int(boss["index"])
	var at: Vector2 = _enemies().pos[i]
	var color := aura_color(boss["data"])
	_portals.append({"pos": at, "t": 0.0, "color": color})
	var fx := _enemies().fx
	for k: int in range(4 + 4 * detail):
		var angle := TAU * k / float(4 + 4 * detail)
		fx.add(EnemyFx.Kind.SMOKE, at + Vector2.from_angle(angle) * 14.0, Vector2.from_angle(angle) * 20.0, 1.4,
				12.0, Color(0.12, 0.06, 0.16, 0.7))
	fx.add(EnemyFx.Kind.RING, at, Vector2.ZERO, 0.9, 60.0, Color(color, 1.0))
	roar(boss["data"])
	director.game.shake(2.5 * float(GfxQuality.budget("screen_shake")))


func roar(data: Dictionary, pitch_mult: float = 1.0) -> void:
	var audio := get_node_or_null(^"/root/AudioManager")
	if audio:
		audio.call("play", "e_roar_%d" % _look.randi_range(0, 2), float(data.get("roar_pitch", 1.0)) * pitch_mult,
				0.05, -2.0)


func on_phase(boss: Dictionary) -> void:
	var i := int(boss["index"])
	var at: Vector2 = _enemies().pos[i]
	var color := aura_color(boss["data"])
	var fx := _enemies().fx
	fx.add(EnemyFx.Kind.RING, at, Vector2.ZERO, 0.6, 90.0, Color(1, 1, 1, 1))
	fx.add(EnemyFx.Kind.RING, at, Vector2.ZERO, 0.9, 130.0, Color(color, 1.0))
	for _k: int in range(6 + 10 * detail):
		fx.spark(at + Vector2(_look.randf_range(-20.0, 20.0), _look.randf_range(-30.0, 0.0)), color, 60.0)
	roar(boss["data"], 0.9)
	_hud_flash(0.35)


func on_enrage(boss: Dictionary) -> void:
	var at: Vector2 = _enemies().pos[int(boss["index"])]
	_enemies().fx.add(EnemyFx.Kind.RING, at, Vector2.ZERO, 0.7, 110.0, Color(ENRAGED, 1.0))
	_enemies().fx.explosion(at + Vector2(0, -10), 1.0, ENRAGED)
	roar(boss["data"], 0.8)
	director.game.shake(3.0)


## Guarda a pose do chefe na hora da morte e começa a sequência.
func on_dead(boss: Dictionary) -> void:
	var enemies := _enemies()
	var i := int(boss["index"])
	var t := enemies.kind[i]
	var sheet := enemies.type_sheets[t]
	var src := sheet.region(int(GameClock.game_time * 8.0), enemies.facing[i])
	_deaths.append({"pos": enemies.pos[i] + Vector2(0, enemies.radius[i] * 0.6), "t": 0.0, "sheet": sheet,
			"src": src, "scale": enemies.type_scale[t], "flip": sheet.needs_flip(enemies.facing[i]),
			"tint": enemies.type_tint[t], "radius": enemies.radius[i], "next": 0,
			"color": aura_color(boss["data"])})
	enemies.fx.slow_motion(0.9, 0.3)
	_hud_flash(0.8)
	director.game.shake(3.0)
	var audio := get_node_or_null(^"/root/AudioManager")
	if audio:
		audio.call("play", "e_boss_fall_0", 1.0, 0.0, 0.0)
		roar(boss["data"], 0.7)


func _hud_flash(strength: float) -> void:
	var hud := director.game.hud
	if hud and hud.has_method("boss_flash") and not bool(Settings.get_value("reduce_flashes")):
		hud.call("boss_flash", strength)


# --- Passo e desenho ----------------------------------------------------------------------

func _process(delta: float) -> void:
	var dt := 0.0 if GameClock.paused else minf(delta, 0.1) * GameClock.speed
	for k: int in range(_portals.size() - 1, -1, -1):
		_portals[k]["t"] = float(_portals[k]["t"]) + dt
		if float(_portals[k]["t"]) >= PORTAL_TIME:
			_portals.remove_at(k)
	for k: int in range(_deaths.size() - 1, -1, -1):
		_step_death(_deaths[k], dt)
		if float(_deaths[k]["t"]) >= DEATH_TIME:
			_deaths.remove_at(k)
	_emit_left -= dt
	if _emit_left <= 0.0 and director != null:
		_emit_left = [0.25, 0.12, 0.06][detail]
		_emit_auras()
	queue_redraw()
	_add.queue_redraw()


func _step_death(d: Dictionary, dt: float) -> void:
	d["t"] = float(d["t"]) + dt
	var fx := _enemies().fx
	var at: Vector2 = d["pos"]
	var r := float(d["radius"])
	while int(d["next"]) < BLASTS.size() and float(d["t"]) >= float(BLASTS[int(d["next"])][0]):
		var blast: Array = BLASTS[int(d["next"])]
		d["next"] = int(d["next"]) + 1
		if detail == 0 and int(d["next"]) % 2 == 0 and int(d["next"]) < BLASTS.size():
			continue
		var p := at + (blast[1] as Vector2) * r
		fx.explosion(p, float(blast[2]), (d["color"] as Color).lerp(Color(1.0, 0.6, 0.2), 0.5))
		var audio := get_node_or_null(^"/root/AudioManager")
		if audio:
			audio.call("play", "explosion", 0.8 + 0.1 * int(d["next"]), 0.05, -8.0)
		director.game.shake(1.5)
		if int(d["next"]) == BLASTS.size():
			fx.soul_rain(at + Vector2(0, -r), [14, 30, 56][detail])
			fx.add(EnemyFx.Kind.RING, at, Vector2.ZERO, 0.8, 150.0, Color(1, 0.95, 0.8, 1))
			_hud_flash(1.0)


func _emit_auras() -> void:
	var enemies := _enemies()
	for boss: Dictionary in director.bosses:
		var i := int(boss["index"])
		if enemies.alive[i] == 0 or enemies.submerged[i] == 1:
			continue
		var at: Vector2 = enemies.pos[i]
		var r := enemies.radius[i]
		var color := ENRAGED if bool(boss["enraged"]) else aura_color(boss["data"])
		enemies.fx.spark(at + Vector2(_look.randf_range(-r, r), _look.randf_range(-r * 0.4, r * 0.4)), color,
				35.0 if not bool(boss["enraged"]) else 70.0)
		if bool(boss["enraged"]) and detail >= 1:
			enemies.fx.add(EnemyFx.Kind.GLOW, at + Vector2(_look.randf_range(-r, r), 0), Vector2(0, -60), 0.6, 2.0,
					Color(1.0, _look.randf_range(0.3, 0.6), 0.1), -20.0)


func _draw() -> void:
	var time := GameClock.game_time
	_draw_portals(time)
	_draw_telegraphs(time)
	for boss: Dictionary in director.bosses:
		_draw_charge_line(boss, time)
	for d: Dictionary in _deaths:
		_draw_corpse(d)


func _draw_portals(time: float) -> void:
	for p: Dictionary in _portals:
		var k := float(p["t"]) / PORTAL_TIME
		var at: Vector2 = p["pos"]
		var color: Color = p["color"]
		var fade := sin(k * PI)
		var r := 34.0 * minf(1.0, k * 3.0)
		draw_set_transform(at, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, r, Color(0.05, 0.0, 0.08, 0.7 * fade))
		for ring: int in range(3):
			var spin := time * (2.0 + ring) * (1.0 if ring % 2 == 0 else -1.0)
			for seg: int in range(6):
				var start := spin + seg * TAU / 6.0
				draw_arc(Vector2.ZERO, r * (0.5 + 0.25 * ring), start, start + 0.6, 6, Color(color, 0.8 * fade), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Avisos por cima dos de AreaEffects (lidos, nunca alterados).
func _draw_telegraphs(time: float) -> void:
	var areas := director.game.areas
	if areas == null:
		return
	for e: Dictionary in areas.effects:
		var kind := int(e["kind"])
		var at: Vector2 = (e["pos"] as Vector2).round()
		if kind == AreaEffects.Kind.TELEGRAPH:
			var left := float(e["life"])
			var total := maxf(float(e["max_life"]), 0.001)
			var k := 1.0 - clampf(left / total, 0.0, 1.0)
			var r := float(e["radius"])
			var segs := 10 if r > 25.0 else 6
			for seg: int in range(segs):
				var start := time * 2.5 + seg * TAU / segs
				draw_arc(at, r + 1.0, start, start + PI / segs, 4, Color(WARN, 0.9), 1.5)
			# Anel que fecha: quando encosta no centro, o golpe cai.
			draw_arc(at, maxf(1.0, r * (1.0 - k)), 0.0, TAU, 24, Color(1.0, 0.85, 0.7, 0.35 + 0.5 * k), 1.0)
			if left < 0.3 and int(time * 16.0) % 2 == 0:
				draw_rect(Rect2(at + Vector2(-1, -6), Vector2(2, 7)), Color(1.0, 0.95, 0.9, 0.9))
				draw_rect(Rect2(at + Vector2(-1, 3), Vector2(2, 2)), Color(1.0, 0.95, 0.9, 0.9))
		elif kind == AreaEffects.Kind.BEAM and float(e["life"]) > float(e["max_life"]):
			var a0 := float(e["angle"])
			var length := float(e["length"])
			var sweep := float(e["sweep"])
			var pts := PackedVector2Array([at])
			for s: int in range(13):
				pts.append(at + Vector2.from_angle(a0 + sweep * s / 12.0) * length)
			var pulse := 0.5 + 0.5 * sin(time * 14.0)
			draw_colored_polygon(pts, Color(WARN, 0.07 + 0.08 * pulse))
			draw_arc(at, length, a0, a0 + sweep, 16, Color(WARN, 0.6), 1.0)
		elif kind == AreaEffects.Kind.HAZARD_POOL and float(e["life"]) > float(e["max_life"]):
			var r := float(e["radius"])
			for seg: int in range(8):
				var start := -time * 2.0 + seg * TAU / 8.0
				draw_arc(at, r + 1.0, start, start + 0.35, 3, Color(0.5, 0.75, 1.0, 0.9), 1.5)


func _draw_charge_line(boss: Dictionary, time: float) -> void:
	var line: Array = boss["line"]
	if line.size() != 2:
		return
	var from: Vector2 = line[0]
	var to: Vector2 = line[1]
	var dir := (to - from).normalized()
	var length := from.distance_to(to)
	var side := dir.orthogonal()
	var flow := fmod(time * 90.0, 18.0)
	var d := flow
	while d < length:
		var p := from + dir * d
		var a := 0.35 + 0.55 * (d / length)
		draw_polyline(PackedVector2Array([p - dir * 4.0 + side * 5.0, p, p - dir * 4.0 - side * 5.0]),
				Color(1.0, 0.35, 0.25, a), 2.0)
		d += 18.0
	draw_arc(to, 8.0, 0.0, TAU, 16, Color(WARN, 0.8), 1.5)


func _draw_corpse(d: Dictionary) -> void:
	var t := float(d["t"])
	var sheet: SpriteSheet = d["sheet"]
	var src: Rect2 = d["src"]
	var s := float(d["scale"])
	var at: Vector2 = d["pos"]
	var shake := Vector2(_look.randf_range(-1.5, 1.5), _look.randf_range(-1.0, 1.0)) * (1.0 - t / DEATH_TIME) * 2.0
	# Dissolve de baixo para cima a partir de 1,2 s.
	var keep := 1.0 - clampf((t - 1.2) / 0.6, 0.0, 1.0)
	if keep <= 0.0:
		return
	var size := src.size
	var cut := Rect2(src.position, Vector2(size.x, size.y * keep))
	draw_set_transform(at + shake, 0.0, Vector2(-s if bool(d["flip"]) else s, s))
	var rect := Rect2(Vector2(-size.x * 0.5, -size.y + 2.0), Vector2(size.x, size.y * keep))
	draw_texture_rect_region(sheet.texture, rect, cut, d["tint"])
	var blink := 0.5 + 0.5 * sin(t * 30.0)
	draw_texture_rect_region(sheet.flash_texture, rect, cut, Color(1, 1, 1, 0.4 + 0.5 * blink))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Aura dos chefes vivos e clarão das mortes (aditivo).
func _draw_glow() -> void:
	if director == null:
		return
	var enemies := _enemies()
	var time := GameClock.game_time
	for boss: Dictionary in director.bosses:
		var i := int(boss["index"])
		if enemies.alive[i] == 0 or enemies.submerged[i] == 1:
			continue
		var at := enemies.prev[i].lerp(enemies.pos[i], GameClock.alpha) + Vector2(0, enemies.radius[i] * 0.6)
		var r := enemies.radius[i] * 1.8
		var enraged := bool(boss["enraged"])
		var color := ENRAGED if enraged else aura_color(boss["data"])
		var pulse := 0.6 + 0.4 * sin(time * (9.0 if enraged else 3.0))
		_add.draw_texture_rect(_soft, Rect2(at - Vector2(r, r * 0.45), Vector2(r * 2.0, r * 0.9)), false,
				Color(color, (0.45 if enraged else 0.3) * pulse))
		if detail >= 1:
			_add.draw_texture_rect(_soft, Rect2(at - Vector2(r * 0.8, r * 1.9), Vector2(r * 1.6, r * 2.0)), false,
					Color(color, (0.3 if enraged else 0.12) * pulse))
		if enraged and detail >= 1:
			# Línguas de fogo em volta do corpo.
			for k: int in range(7):
				var x := (k - 3) * r * 0.25
				var h := r * (0.7 + 0.35 * sin(time * 11.0 + k * 1.9))
				_add.draw_colored_polygon(PackedVector2Array([at + Vector2(x - 4, 0), at + Vector2(x, -h),
						at + Vector2(x + 4, 0)]), Color(1.0, 0.3 + 0.05 * k, 0.1, 0.35 * pulse))
	for d: Dictionary in _deaths:
		var t := float(d["t"])
		var at: Vector2 = d["pos"]
		var r := float(d["radius"]) * (2.0 + t * 2.0)
		var a := clampf(1.0 - t / DEATH_TIME, 0.0, 1.0)
		_add.draw_texture_rect(_soft, Rect2(at - Vector2(r, r * 1.2), Vector2(r * 2.0, r * 2.0)), false,
				Color(d["color"] as Color, 0.6 * a))
		if glow and t > 1.4:
			var burst := clampf((t - 1.4) / 0.8, 0.0, 1.0)
			var big := 30.0 + 220.0 * burst
			_add.draw_texture_rect(_soft, Rect2(at - Vector2(big, big), Vector2(big, big) * 2.0), false,
					Color(1.0, 0.95, 0.8, 0.7 * (1.0 - burst)))
