class_name PickupManager
extends Node2D
## Brasas de alma (XP), moedas, comida, itens especiais e baús (plano 4.3, 4.8 e 10.8).
## - Brasas em arrays; acima de 300 no chão, as novas se fundem na mais próxima.
## - Brasas atraídas nunca orbitam: se a passada alcança a guardiã, são coletadas.
## - A coleta de brasas em sequência sobe o tom numa escala pentatônica (plano 15.7).

const CAPACITY := 400
const MERGE_AT := 300
const COLLECT_RADIUS := 8.0
const ITEM_RADIUS := 10.0
const ATTRACT_ACCEL := 600.0
const ATTRACT_MAX_SPEED := 420.0
## Folga de quem nasce no chão: o corpo da guardiã (Player.RADIUS + 1 no resolve) e mais um
## pouco, para não cair numa fresta entre os círculos de uma casa onde ela não chega.
const SPAWN_CLEARANCE := Player.RADIUS + 4.0
## Escala pentatônica japonesa "in" (miyako-bushi), em semitons a partir da tônica.
const SCALE := [0, 1, 5, 7, 8, 12, 13, 17, 19, 20, 24]
const SCALE_RESET_MS := 1500

var game: HyakkiGame
var count_alive: int = 0
## Itens no chão (poucos): comida, ryō, sino, ampulheta, baús...
var items: Array[Dictionary] = []

var pos := PackedVector2Array()
var prev := PackedVector2Array()
var value := PackedInt32Array()
var spd := PackedFloat32Array()
var attracted := PackedByteArray()
var alive := PackedByteArray()

var _free: Array[int] = []
var _gem_tex: Array[Texture2D] = []
var _item_tex: Dictionary = {}
var _note: int = 0
var _last_note_ms: int = 0


func _ready() -> void:
	for gem: String in ["GemPurple", "GemGreen", "GemRed", "GemYellow"]:
		_gem_tex.append(load("res://assets/art/items/resource/%s.png" % gem) as Texture2D)
	for id: StringName in DB.ids("items"):
		var path := String(DB.items[id]["icon"])
		if ResourceLoader.exists(path):
			_item_tex[id] = load(path)
	pos.resize(CAPACITY)
	prev.resize(CAPACITY)
	value.resize(CAPACITY)
	spd.resize(CAPACITY)
	attracted.resize(CAPACITY)
	alive.resize(CAPACITY)
	reset()


func reset() -> void:
	_free.clear()
	for i: int in range(CAPACITY - 1, -1, -1):
		_free.append(i)
	alive.fill(0)
	count_alive = 0
	items.clear()


func spawn(at: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	if count_alive >= MERGE_AT or _free.is_empty():
		var target := _nearest(at)
		if target >= 0:
			value[target] += amount
		return
	at = _place(at)
	var i: int = _free.pop_back()
	pos[i] = at
	prev[i] = at
	value[i] = amount
	spd[i] = 0.0
	attracted[i] = 0
	alive[i] = 1
	count_alive += 1


func spawn_item(id: StringName, at: Vector2, extra: Dictionary = {}) -> void:
	var data: Dictionary = DB.items.get(id, {})
	if data.is_empty():
		return
	var item := {"id": id, "pos": _place(at), "effect": String(data["effect"]), "value": data["value"],
			"phase": game.rng.randf() * TAU}
	item.merge(extra, true)
	items.append(item)


## Ponto do chão onde a guardiã alcança: fora de casas, muros e estátuas e dentro dos limites.
## Sem mapa (testes isolados), fica onde pediram.
func _place(at: Vector2) -> Vector2:
	if game == null or game.world == null:
		return at
	return game.world.free_point(at, SPAWN_CLEARANCE)


## Sorteia um item de lanterna destrutível pelos pesos de items.json.
func random_item_id() -> StringName:
	var total := 0.0
	for id: StringName in DB.ids("items"):
		total += float(DB.items[id].get("weight", 0))
	var roll := game.rng.randf() * total
	for id: StringName in DB.ids("items"):
		roll -= float(DB.items[id].get("weight", 0))
		if roll <= 0.0:
			return id
	return &"onigiri"


func step(dt: float) -> void:
	prev = pos.duplicate()
	var player := game.player
	var target := player.sim_pos
	var magnet := player.stats.get_stat("magnet")
	for i: int in range(CAPACITY):
		if alive[i] == 0:
			continue
		var d: Vector2 = target - pos[i]
		var dist := d.length()
		if dist <= COLLECT_RADIUS:
			_collect(i)
			continue
		if attracted[i] == 0 and dist > magnet:
			continue
		attracted[i] = 1
		spd[i] = minf(spd[i] + ATTRACT_ACCEL * dt, ATTRACT_MAX_SPEED)
		var travel: float = spd[i] * dt
		if travel >= dist - COLLECT_RADIUS:
			_collect(i)
			continue
		pos[i] = pos[i] + d / dist * travel
	for k: int in range(items.size() - 1, -1, -1):
		var item := items[k]
		if target.distance_to(item["pos"]) <= ITEM_RADIUS + Player.RADIUS:
			items.remove_at(k)
			game.collect_item(item)


## Travessia para o Kakuriyo: nada do chão se perde. Brasas viram XP na hora e os itens são
## coletados (baús vão para a fila de baús e abrem um depois do outro).
func collect_all() -> void:
	for i: int in range(CAPACITY):
		if alive[i] == 1:
			_collect(i)
	var held := items.duplicate()
	items.clear()
	for item: Dictionary in held:
		game.collect_item(item)


## Ímã total: todas as brasas do chão voam para a guardiã.
func magnet_all() -> void:
	for i: int in range(CAPACITY):
		if alive[i] == 1:
			attracted[i] = 1


## Puxa brasas para um ponto (Furacão de Fūjin). Elas deslizam pela borda dos obstáculos em vez
## de atravessar: puxadas para dentro de uma casa, ficariam fora do alcance do ímã.
func pull_gems(center: Vector2, r: float, strength: float, dt: float) -> void:
	var world: WorldMap = game.world if game != null else null
	for i: int in range(CAPACITY):
		if alive[i] == 1 and attracted[i] == 0:
			var d := center - pos[i]
			if d.length() < r and d.length() > 2.0:
				var next := pos[i] + d.normalized() * strength * dt
				pos[i] = world.resolve(next, SPAWN_CLEARANCE) if world != null else next


func total_value() -> int:
	var total := 0
	for i: int in range(CAPACITY):
		if alive[i] == 1:
			total += value[i]
	return total


func _collect(i: int) -> void:
	alive[i] = 0
	_free.append(i)
	count_alive -= 1
	game.add_xp(value[i])
	var now := Time.get_ticks_msec()
	if now - _last_note_ms > SCALE_RESET_MS:
		_note = 0
	_last_note_ms = now
	var semitone: int = SCALE[mini(_note, SCALE.size() - 1)]
	_note += 1
	AudioManager.play("coin", pow(2.0, semitone / 12.0), 0.0, -10.0)


func _nearest(at: Vector2) -> int:
	var best := -1
	var best_d2 := INF
	for i: int in range(CAPACITY):
		if alive[i] == 0:
			continue
		var d2 := at.distance_squared_to(pos[i])
		if d2 < best_d2:
			best_d2 = d2
			best = i
	return best


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var a := GameClock.alpha
	var time := GameClock.game_time
	var colorblind := bool(Settings.get_value("colorblind"))
	var calm := bool(Settings.get_value("reduce_flashes"))
	for i: int in range(CAPACITY):
		if alive[i] == 0:
			continue
		var p: Vector2 = prev[i].lerp(pos[i], a)
		if attracted[i] == 0:
			p.y += roundf(sin(time * 3.0 + float(i)))
		var v := value[i]
		var tier := 0 if v < 5 else (1 if v < 25 else (2 if v < 100 else 3))
		var tex := _gem_tex[tier]
		var s := 0.6 if tier == 0 else (0.8 if tier == 1 else 1.0)
		# No modo daltônico, as brasas maiores ganham um contorno branco para diferenciar pela forma.
		draw_set_transform(p.round(), 0.0, Vector2(s, s))
		if colorblind and tier >= 2:
			draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 12, Color.WHITE, 1.0)
		draw_texture(tex, -tex.get_size() * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for item: Dictionary in items:
		var tex: Texture2D = _item_tex.get(item["id"])
		if tex == null:
			continue
		_draw_item(tex, item["pos"], time + float(item["phase"]), calm)


## Item no chão chamando atenção (pedido de 21/10): halo que pulsa, pulinho com sombra
## e um brilho em cruz que gira. Sem piscar: piscar lê como "vai sumir" ou como dano, e
## incomoda quem pede menos flashes (nesse modo o halo pulsa mais devagar e sem brilho).
func _draw_item(tex: Texture2D, at: Vector2, t: float, calm: bool) -> void:
	var pulse := 0.5 + 0.5 * sin(t * (2.0 if calm else 5.0))
	# Pulinho a cada 1,2 s: sobe 4 px e cai, a sombra encolhe enquanto ele está no ar.
	var hop := absf(sin(t * PI / 1.2)) * (2.0 if calm else 4.0)
	var p := at - Vector2(0.0, roundf(hop))
	draw_circle(at + Vector2(0, 6), 5.0 - hop * 0.4, Color(0, 0, 0, 0.3))
	draw_circle(p, 11.0 + 3.0 * pulse, Color(1.0, 0.9, 0.45, 0.10 + 0.12 * pulse))
	draw_arc(p, 10.0 + 2.0 * pulse, 0.0, TAU, 20, Color(1.0, 0.95, 0.6, 0.45 + 0.35 * pulse), 1.0)
	if not calm:
		var spin := t * 2.5
		var reach := 13.0 + 2.0 * pulse
		for k: int in range(4):
			var dir := Vector2.from_angle(spin + k * PI * 0.5)
			draw_line(p + dir * (reach - 4.0), p + dir * reach, Color(1.0, 1.0, 0.85, 0.5 + 0.5 * pulse), 1.0)
	# Folha de quadros (o baú é fechado | aberto lado a lado): só o primeiro quadro, senão um baú
	# aparece como dois no chão.
	var frame := tex.get_size()
	if frame.x >= frame.y * 2.0:
		frame.x = frame.y
	draw_texture_rect_region(tex, Rect2((p - frame * 0.5).round(), frame), Rect2(Vector2.ZERO, frame))


## Cores das brasas por valor; no modo daltônico usa azul/laranja/branco (plano 7.5).
static func gem_color(v: int, colorblind: bool = false) -> Color:
	if colorblind:
		if v >= 100:
			return Color("ffffff")
		if v >= 25:
			return Color("ff9f1c")
		if v >= 5:
			return Color("2ec4b6")
		return Color("8ecae6")
	if v >= 100:
		return Color("ffd166")
	if v >= 25:
		return Color("ef476f")
	if v >= 5:
		return Color("06d6a0")
	return Color("6ab7ff")
