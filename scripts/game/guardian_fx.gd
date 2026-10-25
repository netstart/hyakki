class_name GuardianFx
extends Node2D
## Polimento visual da guardiã (o herói em jogo), filho do Player e só de desenho:
## - sombra suave nos pés (Média/Alta; em Baixa fica a elipse do próprio Player);
## - aura sutil na cor do herói, que respira (Baixa: um aro fino; Alta: brilho e faíscas);
## - poeira dos passos (e brilhos na cor do herói em Alta);
## - golpe recebido: tremor curto do corpo, anel vermelho e estilhaços;
## - nível novo: coluna de luz, anel dourado e faíscas que sobem.
## Ouve Events.player_hit/player_leveled; nada aqui mexe em posição, hitbox ou velocidade.

const AURA := {"aki": Color("ffd27a"), "kenta": Color("8fb8ff"), "hana": Color("ff9ccf"), "goro": Color("ff8a4c"),
		"rin": Color("8be08b"), "tora": Color("ffc04d"), "yuki": Color("a8dcff")}
const HURT_TIME := 0.22
const HURT_JITTER := 1.5
const LEVEL_TIME := 1.1
const STEP_GAP := 0.42

var player: Player
var detail: int = 2
var soft_shadows: bool = true

var _soft: Texture2D
var _under: Node2D
var _hurt: float = 0.0
var _level: float = 0.0
var _step_dist: float = 0.0
var _look := RandomNumberGenerator.new()


func _ready() -> void:
	player = get_parent() as Player
	_soft = EnemyFx.soft_texture()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Por baixo do corpo: sombra (normal) e aura (aditiva, em outro nó).
	show_behind_parent = true
	_under = Node2D.new()
	_under.material = additive
	_under.show_behind_parent = true
	_under.draw.connect(_draw_aura)
	add_child(_under)
	_look.randomize()
	apply_quality()
	var settings := get_node_or_null(^"/root/Settings")
	if settings:
		settings.connect("changed", func(k: String) -> void:
			if k == GfxQuality.changed_signal_key():
				apply_quality())
	var events := get_node_or_null(^"/root/Events")
	if events:
		events.connect("player_hit", _on_hit)
		events.connect("player_leveled", _on_level)


func apply_quality() -> void:
	detail = int(GfxQuality.budget("enemy_fx"))
	soft_shadows = bool(GfxQuality.budget("soft_shadows"))


## O Player pula a própria sombra quando esta camada desenha a suave.
func draws_shadow() -> bool:
	return soft_shadows


func aura_color() -> Color:
	var id := String(player.hero.get("id", "")) if player else ""
	if AURA.has(id):
		return AURA[id]
	return Color(String(player.hero.get("cast_color", "ffeba6"))) if player else Color.WHITE


## Deslocamento do corpo no tremor do golpe (px inteiros; zero fora dele).
func jitter() -> Vector2:
	if _hurt <= 0.0 or bool(Settings.get_value("reduce_flashes")):
		return Vector2.ZERO
	var k := _hurt / HURT_TIME
	return Vector2(roundf(sin(_hurt * 90.0) * HURT_JITTER * k), 0.0)


func hurt_active() -> bool:
	return _hurt > 0.0


func level_active() -> bool:
	return _level > 0.0


func _fx() -> EnemyFx:
	var game := player.game() if player else null
	return game.enemies.fx if game and game.enemies else null


func _on_hit(_amount: float) -> void:
	if player == null or not player.is_alive:
		return
	_hurt = HURT_TIME
	var fx := _fx()
	if fx == null:
		return
	var at := player.sim_pos + Vector2(0, -6)
	fx.add(EnemyFx.Kind.RING, at, Vector2.ZERO, 0.3, 12.0, Color(1.0, 0.3, 0.25, 0.9))
	for _k: int in range(3 + 3 * detail):
		fx.add(EnemyFx.Kind.PIXEL, at, Vector2.from_angle(_look.randf() * TAU) * _look.randf_range(30.0, 70.0), 0.3,
				1.0, Color(1.0, 0.35, 0.3), 120.0)


func _on_level(_level_number: int) -> void:
	if player == null:
		return
	_level = LEVEL_TIME
	var fx := _fx()
	if fx == null:
		return
	var at := player.sim_pos
	var gold := Color(1.0, 0.85, 0.45)
	fx.add(EnemyFx.Kind.RING, at, Vector2.ZERO, 0.6, 30.0, Color(gold, 1.0))
	if detail >= 1:
		fx.add(EnemyFx.Kind.RING, at, Vector2.ZERO, 0.9, 48.0, Color(aura_color(), 0.9))
	for _k: int in range(6 + 8 * detail):
		var p := at + Vector2(_look.randf_range(-8.0, 8.0), _look.randf_range(-4.0, 2.0))
		fx.spark(p, gold.lerp(aura_color(), _look.randf()), _look.randf_range(40.0, 90.0))


func _process(delta: float) -> void:
	if player == null:
		return
	var dt := 0.0 if GameClock.paused else delta
	_hurt = maxf(0.0, _hurt - dt)
	_level = maxf(0.0, _level - dt)
	if dt > 0.0 and player.is_alive and player.down <= 0.0:
		_step_dust(dt)
	queue_redraw()
	_under.queue_redraw()


func _step_dust(dt: float) -> void:
	var speed := player.velocity.length()
	if speed < 10.0:
		return
	_step_dist += speed * dt * GameClock.speed
	var gap := STEP_GAP * player.stats.get_stat("speed") * (1.4 if detail == 0 else 1.0)
	if _step_dist < gap:
		return
	_step_dist = 0.0
	var fx := _fx()
	if fx == null:
		return
	var foot := player.sim_pos + Vector2(_look.randf_range(-2.0, 2.0), 3.0)
	var back := -player.velocity.normalized()
	fx.add(EnemyFx.Kind.SMOKE, foot, back * 12.0 + Vector2(0, -4), 0.4, 2.5 + detail * 0.5, Color(0.75, 0.7, 0.6, 0.45))
	if detail >= 2:
		fx.add(EnemyFx.Kind.GLOW, foot + Vector2(0, -2), back * 8.0 + Vector2(0, -10), 0.5, 1.2, aura_color())


func _draw() -> void:
	if player == null or player.down > 0.0 or not player.is_alive:
		return
	if soft_shadows:
		draw_texture_rect(_soft, Rect2(Vector2(-9, -1), Vector2(18, 7)), false, Color(0.02, 0.0, 0.05, 0.7))
	if _level > 0.0:
		_draw_pillar()


## Coluna de luz do nível novo (desenho normal; o brilho fica na aura aditiva).
func _draw_pillar() -> void:
	var k := _level / LEVEL_TIME
	var rise := 1.0 - k
	var h := 70.0 * minf(1.0, rise * 4.0)
	var w := 10.0 * k + 2.0
	var gold := Color(1.0, 0.9, 0.55, 0.55 * k)
	draw_rect(Rect2(Vector2(-w * 0.5, -h), Vector2(w, h)), gold)
	draw_rect(Rect2(Vector2(-1, -h), Vector2(2, h)), Color(1, 1, 1, 0.8 * k))
	for j: int in range(3):
		var y := -fmod(rise * 90.0 + j * 22.0, 70.0)
		draw_rect(Rect2(Vector2(-w * 0.5 - 3.0, y), Vector2(w + 6.0, 1.0)), Color(1.0, 0.95, 0.7, 0.5 * k))


func _draw_aura() -> void:
	if player == null or player.down > 0.0 or not player.is_alive:
		return
	var time := Time.get_ticks_msec() / 1000.0
	var c := aura_color()
	var breath := 0.75 + 0.25 * sin(time * 2.2)
	match detail:
		0:
			_under.draw_arc(Vector2(0, 2), 8.0, 0.0, TAU, 20, Color(c, 0.18 * breath), 1.0)
		_:
			_under.draw_texture_rect(_soft, Rect2(Vector2(-12, -3), Vector2(24, 10)), false, Color(c, 0.3 * breath))
			if detail >= 2:
				_under.draw_texture_rect(_soft, Rect2(Vector2(-9, -20), Vector2(18, 22)), false, Color(c, 0.1 * breath))
	if _hurt > 0.0:
		var k := _hurt / HURT_TIME
		_under.draw_texture_rect(_soft, Rect2(Vector2(-14, -20), Vector2(28, 26)), false, Color(1.0, 0.15, 0.1, 0.6 * k))
	if _level > 0.0:
		var k := _level / LEVEL_TIME
		_under.draw_texture_rect(_soft, Rect2(Vector2(-20, -60), Vector2(40, 70)), false, Color(1.0, 0.85, 0.4, 0.6 * k))
