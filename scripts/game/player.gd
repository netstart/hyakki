class_name Player
extends Node2D
## A guardiã (ou outro herói): movimento, vida, invencibilidade e atributos
## (plano 4.1, 4.2 e 8.7). A simulação roda no passo fixo; o desenho interpola.

signal died

## Hitbox ~60% da largura do sprite: na dúvida, a favor do jogador (plano 8.7.2).
const RADIUS := 4.0
const ACCEL_TIME := 0.08
const INVULN_TIME := DamageControl.INVULN_TIME
const REVIVE_INVULN := 2.0
const HURT_NUMBER_COLOR := Color("ff5a4f")
## Duração da pose de ataque e intervalo mínimo entre duas poses (várias armas disparando).
const CAST_TIME := 0.25
const CAST_GAP := 0.45

var hero: Dictionary = {}
var stats := StatBlock.new()
var damage := DamageControl.new()
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
## Pose de ataque procedural (só desenho): tempo restante, de CAST_TIME até 0.
var cast_time: float = 0.0

var _sheet: SpriteSheet
var _shadow: Texture2D
var _walk_time: float = 0.0
var _hit_flash: float = 0.0
## Só para heróis "side": tamanho do quadro e nº de quadros (parado, andando).
var _side_size := Vector2.ZERO
var _side_counts := Vector2i(1, 1)
## O desenho "side" original olha para a esquerda ("faces_left" em heroes.json).
var _faces_left: bool = false
## Mão de onde saem os poderes ("hand" em heroes.json): deslocamento a partir de sim_pos,
## x positivo = lado para onde o herói olha. Sem "hand", os poderes saem de sim_pos.
var _hand := Vector2.ZERO
var _has_hand: bool = false
## Trava da pose de ataque: evita reiniciar a pose sem parar.
var _cast_lock: float = 0.0
var _cast_color := Color(1.0, 0.92, 0.65)


func _ready() -> void:
	_shadow = load("res://assets/art/actors/shadow.png") as Texture2D


func setup(hero_data: Dictionary) -> void:
	hero = hero_data
	if String(hero_data.get("layout", "dir4")) == "side":
		# Herói desenhado de lado (2 linhas: parado e andando), espelhado para a esquerda.
		# "draw_scale" reduz a folha uma vez, em quadros de pixels inteiros (sem escala no desenho).
		var frame: Array = hero_data.get("frame", [16, 16])
		_side_counts = Vector2i(int(hero_data.get("idle_frames", 1)), int(hero_data.get("walk_frames", 1)))
		_faces_left = bool(hero_data.get("faces_left", false))
		_sheet = SpriteSheet.load_sheet(String(hero_data["sprite"]), "side",
				Vector2(float(frame[0]), float(frame[1])), 1, false, float(hero_data.get("draw_scale", 1.0)))
		_side_size = _sheet.frame_size
	else:
		_side_size = Vector2.ZERO
		_faces_left = false
		_sheet = SpriteSheet.load_sheet(String(hero_data["sprite"]), "dir4", Vector2(16, 16), 4)
	var hand: Array = hero_data.get("hand", [])
	_has_hand = hand.size() == 2
	_hand = Vector2(float(hand[0]), float(hand[1])) if _has_hand else Vector2.ZERO
	_cast_color = Color(String(hero_data.get("cast_color", "ffeba6")))
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
	cast_time = 0.0
	_cast_lock = 0.0
	damage.reset()
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


## Som de dano no herói; desligado pela opção "hurt_sounds". Diz se tocou (testes).
func play_hurt_sound() -> bool:
	if not bool(Settings.get_value("hurt_sounds")):
		return false
	AudioManager.play("player_hurt", 1.0, 0.05, -2.0)
	return true


## Única porta de entrada do dano recebido (plano 4.15). `source` é o id do inimigo, do
## chefe ou do perigo, para o registro e a causa da morte.
func take_damage(amount: float, source: StringName = DamageControl.UNKNOWN) -> void:
	if not is_alive:
		return
	if invuln > 0.0:
		damage.blocked += 1
		return
	var now := GameClock.game_time
	var final := damage.resolve(amount, stats.get_stat("armor"), max_hp(), game().mode == "brisa", now)
	invuln = INVULN_TIME
	if final <= 0.0:
		return
	damage.record(source, final, now)
	hp -= final
	_hit_flash = 0.12
	damage_taken_time = 0.0
	game().fx.add_number(sim_pos + Vector2(0.0, sprite_top()), final, false, HURT_NUMBER_COLOR)
	Events.player_hit.emit(final)
	play_hurt_sound()
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


func has_hand() -> bool:
	return _has_hand


## Mão do herói em coordenadas do mundo, a partir de `from` (sim_pos ou a posição do clone).
## Só usa estado da simulação (sim_pos e facing_x): determinística. Sem "hand", devolve `from`.
func hand_position(from: Vector2 = Vector2.INF) -> Vector2:
	if from == Vector2.INF:
		from = sim_pos
	if not _has_hand:
		return from
	return from + Vector2(_hand.x * facing_x, _hand.y)


## Uma arma disparou: começa a pose de ataque, no máximo uma a cada CAST_GAP s. Só desenho.
func on_cast() -> void:
	if _cast_lock > 0.0:
		return
	cast_time = CAST_TIME
	_cast_lock = CAST_GAP


func _process(delta: float) -> void:
	position = prev_pos.lerp(sim_pos, GameClock.alpha).round()
	if _hit_flash > 0.0:
		_hit_flash -= delta
	if cast_time > 0.0:
		cast_time = maxf(0.0, cast_time - delta)
	if _cast_lock > 0.0:
		_cast_lock -= delta
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
		# Brilho da lanterna carregada pela guardiã (na mão, para heróis com "hand").
		var glow := offset + (_hand_offset() if _has_hand else Vector2(5.0 * facing_x, -5.0))
		draw_circle(glow, 3.0, Color(lantern_tint.r, lantern_tint.g, lantern_tint.b, 0.35))
		draw_circle(glow, 1.5, Color(1.0, 0.95, 0.7, 0.9))
	if cast_time > 0.0 and _has_hand:
		_draw_cast_spark(offset + _hand_offset())


## Mão relativa a sim_pos, já espelhada para o lado em que o herói olha.
func _hand_offset() -> Vector2:
	return Vector2(_hand.x * facing_x, _hand.y)


## Fração da pose de ataque: 0 → 1 → 0 ao longo de CAST_TIME.
func _cast_pose() -> float:
	if cast_time <= 0.0:
		return 0.0
	return sin(PI * (1.0 - cast_time / CAST_TIME))


## Faísca na mão durante a pose de ataque: núcleo claro, halo e quatro raios que somem.
func _draw_cast_spark(at: Vector2) -> void:
	var k := clampf(cast_time / CAST_TIME, 0.0, 1.0)
	var calm := bool(Settings.get_value("reduce_flashes"))
	var c := _cast_color
	var a := k * (0.5 if calm else 1.0)
	draw_circle(at, 2.0 + 4.0 * (1.0 - k), Color(c.r, c.g, c.b, 0.3 * a))
	draw_circle(at, 1.5 + k, Color(1.0, 1.0, 1.0, 0.9 * a))
	if calm:
		return
	var reach := 3.0 + 5.0 * (1.0 - k)
	for i: int in range(4):
		var d := Vector2.from_angle(TAU * i / 4.0 + PI * 0.25 + (1.0 - k))
		draw_line(at + d * 1.5, at + d * reach, Color(c.r, c.g, c.b, 0.85 * a), 1.0)


## Linha 0 = parado (anima sempre), linha 1 = andando (conforme a distância). Pés na base.
## Na pose de ataque o corpo avança 1 px para o lado em que olha e estica um pouco para cima.
func _draw_side(tex: Texture2D, offset: Vector2, moving: bool, tint: Color) -> void:
	var row := 1 if moving else 0
	var count := _side_counts.y if moving else _side_counts.x
	var t := _walk_time * 14.0 if moving else Time.get_ticks_msec() / 110.0
	var src := Rect2(Vector2(posmod(int(t), maxi(1, count)) * _side_size.x, row * _side_size.y), _side_size)
	var pose := _cast_pose()
	# Espelha quando o lado do desenho original difere do lado para onde o herói olha.
	var flip := -1.0 if (facing_x < 0.0) != _faces_left else 1.0
	var feet := offset + Vector2(roundf(pose) * facing_x, 3.0)
	var stretch := Vector2(1.0 - 0.06 * pose, 1.0 + 0.08 * pose)
	var dest := Rect2(Vector2(-_side_size.x * 0.5, -_side_size.y), _side_size)
	draw_set_transform(feet, 0.0, Vector2(flip * stretch.x, stretch.y))
	draw_texture_rect_region(tex, dest, src, tint)
	draw_set_transform(Vector2.ZERO)


## Topo do desenho da guardiã (para a barra de vida acima da cabeça).
func sprite_top() -> float:
	return 3.0 - _side_size.y if _side_size != Vector2.ZERO else -13.0


func _draw_hp(at: Vector2) -> void:
	var fraction := clampf(hp / maxf(max_hp(), 1.0), 0.0, 1.0)
	draw_rect(Rect2(at, Vector2(16.0, 2.0)), Color(0.0, 0.0, 0.0, 0.7))
	draw_rect(Rect2(at, Vector2(16.0 * fraction, 2.0)), Color("e74c3c") if fraction > 0.25 else Color("ff2d2d"))
