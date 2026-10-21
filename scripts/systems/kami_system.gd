class_name KamiSystem
extends Node2D
## Pactos com Kami (plano 2.1 e 4.9): aos 5:00 e 10:00 surge um santuário a 600–800 px.
## Ao tocá-lo, o jogo pausa e oferece 3 bênçãos com custo. Ignorar é permitido.

const SHRINE_RADIUS := 16.0
const OFFER_COUNT := 3

var game: HyakkiGame
## Santuário ativo no mapa (Vector2.INF se não houver).
var shrine_pos := Vector2.INF
var accepted: Array[StringName] = []
var specials: Dictionary = {}

var _tex: Texture2D
var _src := Rect2(0, 80, 48, 32)


func _ready() -> void:
	_tex = load("res://assets/art/tilesets/house.png") as Texture2D
	z_index = -5


func reset() -> void:
	shrine_pos = Vector2.INF
	accepted.clear()
	specials.clear()


func has_shrine() -> bool:
	return shrine_pos != Vector2.INF


func spawn_shrine() -> void:
	var angle := game.rng.randf() * TAU
	for _try: int in range(12):
		var at := game.player.sim_pos + Vector2.from_angle(angle) * game.rng.randf_range(600.0, 800.0)
		at = game.world.clamp_to_bounds(at)
		if at.distance_to(game.player.sim_pos) > 300.0:
			shrine_pos = at.round()
			game.hud.toast(tr("kami.appeared"))
			AudioManager.play("magic1", 0.8)
			AudioManager.play("j_furin", 1.0, 0.0, -6.0)
			return
		angle += 0.6
	shrine_pos = (game.player.sim_pos + Vector2(0, -320)).round()


func step(_dt: float) -> void:
	if not has_shrine() or game.hud.overlay_open():
		return
	if game.player.sim_pos.distance_to(shrine_pos) < SHRINE_RADIUS + Player.RADIUS:
		shrine_pos = Vector2.INF
		game.open_kami(offer())


## 3 Kami ainda não aceitos nesta partida, sorteados com a semente da partida.
func offer() -> Array[StringName]:
	var pool: Array[StringName] = []
	for id: StringName in DB.ids("kami"):
		if not accepted.has(id):
			pool.append(id)
	var picks: Array[StringName] = []
	while picks.size() < OFFER_COUNT and not pool.is_empty():
		picks.append(pool.pop_at(game.rng.randi_range(0, pool.size() - 1)))
	return picks


func accept(id: StringName, silent: bool = false) -> void:
	var data: Dictionary = DB.kami[id]
	accepted.append(id)
	var mods: Dictionary = (data.get("blessing", {}) as Dictionary).duplicate()
	for stat: String in data.get("cost", {}):
		mods[stat] = float(mods.get(stat, 0.0)) + float(data["cost"][stat])
	game.player.stats.set_source("kami_" + String(id), mods)
	var special: Dictionary = data.get("special", {})
	for key: String in special:
		specials[key] = special[key]
	game.apply_kami_specials(specials)
	game.level_up.apply_stats()
	if silent:
		return
	Events.kami_accepted.emit(id)
	AudioManager.play("powerup")
	AudioManager.play("j_koto")
	game.fx.add_ring(game.player.sim_pos, 90.0, Color(String(data["color"])))


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not has_shrine():
		return
	var pulse := 0.5 + 0.5 * sin(GameClock.game_time * 3.0)
	draw_circle(shrine_pos, 26.0, Color(1.0, 0.9, 0.5, 0.12 + 0.1 * pulse))
	draw_texture_rect_region(_tex, Rect2(shrine_pos - Vector2(24, 30), _src.size), _src)
	for k: int in range(6):
		var a := GameClock.game_time * 1.5 + TAU * k / 6.0
		draw_circle(shrine_pos + Vector2.from_angle(a) * 22.0 + Vector2(0, -10), 1.2,
				Color(1.0, 0.95, 0.7, 0.8))
