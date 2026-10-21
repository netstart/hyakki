class_name Player
extends Node2D
## A guardiã (ou outro herói): movimento, vida, invencibilidade e atributos
## (plano 4.1, 4.2 e 8.7). A simulação roda no passo fixo; o desenho interpola.

signal died

## Hitbox ~60% da largura do sprite: na dúvida, a favor do jogador (plano 8.7.2).
const RADIUS := 4.0
const ACCEL_TIME := 0.08
const INVULN_TIME := 0.5
const REVIVE_INVULN := 2.0

var hero: Dictionary = {}
var stats := StatBlock.new()
var sim_pos := Vector2.ZERO
var prev_pos := Vector2.ZERO
var velocity := Vector2.ZERO
## Direção pedida pelo joystick, teclado ou bot (comprimento até 1).
var move_input := Vector2.ZERO
var facing := Vector2.RIGHT
var facing_x: float = 1.0
var dir: int = SpriteSheet.Dir.DOWN
var hp: float = 100.0
var invuln: float = 0.0
var is_alive: bool = true
var revives_used: int = 0
var slow_time: float = 0.0
var slow_factor: float = 1.0
var lava_cd: float = 0.0
var no_regen: bool = false
var aura_radius: float = 0.0
var aura_color := Color(1.0, 0.85, 0.5)
var clone_time: float = 0.0
var clone_offset := Vector2(-18, -6)
var damage_taken_time: float = 0.0
var show_hitbox: bool = false
## Modo de teste: recebe dano visualmente, mas não morre.
var god_mode: bool = false
var lantern_tint := Color(1.0, 0.8, 0.3)

var _sheet: SpriteSheet
var _shadow: Texture2D
var _walk_time: float = 0.0
var _hit_flash: float = 0.0
## Só para heróis "side": tamanho do quadro e nº de quadros (parado, andando).
var _side_size := Vector2.ZERO
var _side_counts := Vector2i(1, 1)


func _ready() -> void:
	_shadow = load("res://assets/art/actors/shadow.png") as Texture2D


func setup(hero_data: Dictionary) -> void:
	hero = hero_data
	if String(hero_data.get("layout", "dir4")) == "side":
		# Herói desenhado de lado (2 linhas: parado e andando), espelhado para a esquerda.
		var frame: Array = hero_data.get("frame", [16, 16])
		_side_size = Vector2(float(frame[0]), float(frame[1]))
		_side_counts = Vector2i(int(hero_data.get("idle_frames", 1)), int(hero_data.get("walk_frames", 1)))
		_sheet = SpriteSheet.load_sheet(String(hero_data["sprite"]), "side", _side_size, 1)
	else:
		_side_size = Vector2.ZERO
		_sheet = SpriteSheet.load_sheet(String(hero_data["sprite"]), "dir4", Vector2(16, 16), 4)
	stats.clear()
	stats.set_source("hero", hero_data.get("modifiers", {}))


func reset() -> void:
	sim_pos = Vector2.ZERO
	prev_pos = Vector2.ZERO
	velocity = Vector2.ZERO
	move_input = Vector2.ZERO
	facing = Vector2.RIGHT
	facing_x = 1.0
	dir = SpriteSheet.Dir.DOWN
	hp = stats.get_stat("max_hp")
	invuln = 0.0
	is_alive = true
	revives_used = 0
	slow_time = 0.0
	slow_factor = 1.0
	lava_cd = 0.0
	no_regen = false
	aura_radius = 0.0
	clone_time = 0.0
	damage_taken_time = 0.0
	position = Vector2.ZERO


func max_hp() -> float:
	return stats.get_stat("max_hp")


func step(dt: float) -> void:
	prev_pos = sim_pos
	if not is_alive:
		return
	var wish := move_input.limit_length(1.0)
	var top_speed := stats.get_stat("speed")
	if slow_time > 0.0:
		slow_time -= dt
		top_speed *= slow_factor
	var rate := top_speed / ACCEL_TIME
	if wish.length_squared() < 0.0001:
		# Para mais rápido do que acelera, sem escorregar (plano 15.2).
		rate *= 2.0
	velocity = velocity.move_toward(wish * top_speed, rate * dt)
	var next := sim_pos + velocity * dt
	next = game().world.resolve(next, RADIUS + 1.0)
	next = game().world.clamp_to_bounds(next)
	sim_pos = next
	if wish.length_squared() > 0.01:
		facing = wish.normalized()
		if absf(wish.x) > 0.2:
			facing_x = signf(wish.x)
		dir = SpriteSheet.dir_from_vector(wish, dir)
	if invuln > 0.0:
		invuln -= dt
	if lava_cd > 0.0:
		lava_cd -= dt
	if clone_time > 0.0:
		clone_time -= dt
	if not no_regen:
		heal(stats.get_stat("regen") * dt)
	damage_taken_time += dt
	_walk_time += dt * (velocity.length() / maxf(top_speed, 1.0))


func game() -> HyakkiGame:
	return get_parent() as HyakkiGame


func take_damage(amount: float) -> void:
	if invuln > 0.0 or not is_alive:
		return
	var final := maxf(1.0, amount - stats.get_stat("armor"))
	if game().mode == "brisa":
		final *= 0.6
	hp -= final
	invuln = INVULN_TIME
	_hit_flash = 0.12
	damage_taken_time = 0.0
	Events.player_hit.emit(final)
	AudioManager.play("player_hurt", 1.0, 0.05, -2.0)
	Settings.vibrate(40)
	game().shake(2.0)
	if god_mode:
		hp = maxf(hp, 1.0)
	if hp > 0.0:
		return
	hp = 0.0
	# Revive do Santuário/Kami primeiro (plano 17.6).
	if revives_used < int(stats.get_stat("revive")) and not game().no_revive:
		revives_used += 1
		revive()
		return
	is_alive = false
	died.emit()


func revive(fraction: float = 0.5) -> void:
	is_alive = true
	hp = max_hp() * fraction
	invuln = REVIVE_INVULN
	game().enemies.push_from(sim_pos, 120.0, 400.0)
	game().fx.add_ring(sim_pos, 120.0, Color(1.0, 0.95, 0.6))
	AudioManager.play("heal")


func heal(amount: float) -> void:
	if amount <= 0.0 or not is_alive:
		return
	hp = minf(max_hp(), hp + amount)


func clone_position() -> Vector2:
	return sim_pos + clone_offset.rotated(GameClock.game_time * 1.5)


func _process(delta: float) -> void:
	position = prev_pos.lerp(sim_pos, GameClock.alpha).round()
	if _hit_flash > 0.0:
		_hit_flash -= delta
	queue_redraw()


func _draw() -> void:
	if aura_radius > 0.0:
		draw_circle(Vector2.ZERO, aura_radius, Color(aura_color.r, aura_color.g, aura_color.b, 0.07))
		draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 40, Color(aura_color.r, aura_color.g, aura_color.b, 0.25), 1.0)
	if _sheet == null:
		return
	if clone_time > 0.0:
		var offset := clone_position() - sim_pos
		_draw_body(offset, Color(0.35, 0.3, 0.55, 0.6), false)
	_draw_body(Vector2.ZERO, Color.WHITE, true)
	if bool(Settings.get_value("hp_bar_below")):
		_draw_hp(Vector2(-8.0, 7.0))
	else:
		_draw_hp(Vector2(-8.0, sprite_top() - 9.0))
	if show_hitbox:
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 16, Color.CYAN, 1.0)


func _draw_body(offset: Vector2, tint: Color, main: bool) -> void:
	draw_texture(_shadow, offset + Vector2(-_shadow.get_width() * 0.5, 1.0))
	var moving := velocity.length() > 5.0
	var frame := int(_walk_time * 8.0) if moving else 0
	var blink := main and invuln > 0.0 and int(invuln * 20.0) % 2 == 0
	var tex := _sheet.flash_texture if (blink or (main and _hit_flash > 0.0)) else _sheet.texture
	if not is_alive and main:
		tint = Color(0.6, 0.6, 0.7)
	if _side_size != Vector2.ZERO:
		_draw_side(tex, offset, moving, tint)
	else:
		draw_texture_rect_region(tex, Rect2(offset + Vector2(-8.0, -13.0), Vector2(16, 16)), _sheet.region(frame, dir), tint)
	if main:
		# Brilho da lanterna carregada pela guardiã.
		var glow := offset + Vector2(5.0 * facing_x, -5.0)
		draw_circle(glow, 3.0, Color(lantern_tint.r, lantern_tint.g, lantern_tint.b, 0.35))
		draw_circle(glow, 1.5, Color(1.0, 0.95, 0.7, 0.9))


## Linha 0 = parado (anima sempre), linha 1 = andando (conforme a distância). Pés na base.
func _draw_side(tex: Texture2D, offset: Vector2, moving: bool, tint: Color) -> void:
	var row := 1 if moving else 0
	var count := _side_counts.y if moving else _side_counts.x
	var t := _walk_time * 14.0 if moving else Time.get_ticks_msec() / 110.0
	var src := Rect2(Vector2(posmod(int(t), maxi(1, count)) * _side_size.x, row * _side_size.y), _side_size)
	var dest := Rect2(offset + Vector2(-_side_size.x * 0.5, 3.0 - _side_size.y), _side_size)
	if facing_x < 0.0:
		draw_set_transform(Vector2(offset.x * 2.0, 0.0), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect_region(tex, dest, src, tint)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect_region(tex, dest, src, tint)


## Topo do desenho da guardiã (para a barra de vida acima da cabeça).
func sprite_top() -> float:
	return 3.0 - _side_size.y if _side_size != Vector2.ZERO else -13.0


func _draw_hp(at: Vector2) -> void:
	var fraction := clampf(hp / maxf(max_hp(), 1.0), 0.0, 1.0)
	draw_rect(Rect2(at, Vector2(16.0, 2.0)), Color(0.0, 0.0, 0.0, 0.7))
	draw_rect(Rect2(at, Vector2(16.0 * fraction, 2.0)), Color("e74c3c") if fraction > 0.25 else Color("ff2d2d"))
