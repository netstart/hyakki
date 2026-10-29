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
## Duração da pose de ataque e intervalo mínimo entre duas poses (várias armas disparando).
const CAST_TIME := 0.25
const CAST_GAP := 0.45
## Sequência de morte (DeathSequence): cor fria do corpo caído e largura da sombra deitada.
const CORPSE_TINT := Color(0.84, 0.88, 1.0)
const LYING_SHADOW := 2.2
## Contorno de luar frio no corpo caído (a silhueta branca deslocada 1 px), para o corpo
## escuro ler sobre o chão escurecido.
const CORPSE_RIM := Color(0.74, 0.84, 1.0, 0.7)
const RIM_DIRS: Array[Vector2] = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
## Golpe de espada procedural (só desenho, on_slash): duração do golpe comum e do arremate
## (passo 2 do combo). Fases: preparo (recua e agacha), corte (avança e estica) e retorno.
const SLASH_TIME := 0.26
const SLASH_FINISHER_TIME := 0.34
const SLASH_WINDUP := 0.05
const SLASH_WINDUP_FINISHER := 0.07
const SLASH_STRIKE := 0.06
const SLASH_STRIKE_FINISHER := 0.08
## Quadro parado (linha 0) mostrado durante o golpe: postura firme, com a espada à vista.
const SLASH_FRAME := 0
## Vultos do avanço: atraso (s) e opacidade de cada um, atrás do corpo.
const SLASH_GHOST_LAG: Array[float] = [0.022, 0.045]
const SLASH_GHOST_ALPHA: Array[float] = [0.35, 0.18]
## Tempo para os vultos sumirem depois do corte.
const SLASH_GHOST_FADE := 0.07

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
## Pose da morte (só desenho, controlada pela DeathSequence): 0 = de pé, 1 = deitada no chão,
## girando em torno dos pés para o lado em que olha.
var down: float = 0.0
## 0 = cor normal, 1 = cinza-azulado frio do corpo.
var chill: float = 0.0
## Brilho da lanterna na mão: 1 = acesa, 0 = apagada.
var glow: float = 1.0
## Golpe de espada (só desenho): tempo restante, de SLASH_TIME (ou SLASH_FINISHER_TIME) até 0.
## O lado do corte vira o corpo só no desenho (facing_x, da simulação, não muda).
var slash_time: float = 0.0

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
## Duração do golpe atual, lado do corte e passo do combo (0, 1 ou 2 = arremate).
var _slash_len: float = 0.0
var _slash_dir: float = 1.0
var _slash_step: int = 0
## Polimento só de desenho (sombra suave, aura, poeira, tremor, nível novo): guardian_fx.gd.
var _fx: GuardianFx


func _ready() -> void:
	_shadow = load("res://assets/art/actors/shadow.png") as Texture2D
	_fx = GuardianFx.new()
	add_child(_fx)


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
	slash_time = 0.0
	_slash_len = 0.0
	down = 0.0
	chill = 0.0
	glow = 1.0
	damage.reset()
	position = Vector2.ZERO


func max_hp() -> float:
	return stats.get_stat("max_hp")


func step(dt: float) -> void:
	prev_pos = sim_pos
	if not is_alive:
		return
	var wish := move_input.limit_length(1.0)
	# Superfícies lentas (SurfaceSystem): mais lento só sobre o solo; ao sair recupera até 1.0.
	var top_speed := stats.get_stat("speed") * _surface_speed()
	if slow_time > 0.0:
		slow_time -= dt
		top_speed *= slow_factor
	var rate := top_speed / ACCEL_TIME * _surface_accel()  # óleo: acelera e freia menos (escorrega)
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


func _surface_speed() -> float:
	var surfaces := SurfaceSystem.of(get_parent())
	return 1.0 if surfaces == null else surfaces.player_factor(sim_pos)


func _surface_accel() -> float:
	var surfaces := SurfaceSystem.of(get_parent())
	return 1.0 if surfaces == null else surfaces.player_accel()


## Afundamento visual (0..2 px) sobre o solo lento; some quando a velocidade volta a 100%.
func _surface_sink() -> float:
	var surfaces := SurfaceSystem.of(get_parent())
	return 0.0 if surfaces == null else surfaces.sink_px(surfaces.player_mult)


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
	game().fx.add_number(sim_pos + Vector2(0.0, sprite_top()), final,
			DamagePalette.classify_taken(final, max_hp()), max_hp())
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


## `show_number`: mostra o "+N" verde (itens, carta de cura e especial; o roubo de vida
## contínuo não mostra, para não poluir a tela). Só aparece se curou pelo menos 1 HP.
func heal(amount: float, show_number: bool = false) -> void:
	if amount <= 0.0 or not is_alive:
		return
	var before := hp
	hp = minf(max_hp(), hp + amount)
	if show_number and hp - before >= 1.0:
		game().fx.add_number(sim_pos + Vector2(0.0, sprite_top()), hp - before, DamagePalette.Kind.HEAL,
				max_hp())


func clone_position() -> Vector2:
	return sim_pos + clone_offset.rotated(GameClock.game_time * 1.5)


## Apaga o clarão branco do golpe (opção "reduce_flashes" na morte).
func clear_flash() -> void:
	_hit_flash = 0.0


## Ângulo da queda: 90° na pose deitada, para o lado em que o herói olha.
func fall_angle() -> float:
	return down * PI * 0.5 * facing_x


## Lanterna relativa a sim_pos, acompanhando a queda (gira em torno dos pés).
func lantern_offset() -> Vector2:
	var at := _hand_offset() if _has_hand else Vector2(5.0 * facing_x, -5.0)
	if down <= 0.0:
		return at
	var feet := Vector2(0.0, 3.0)
	return feet + (at - feet).rotated(fall_angle())


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


## Um golpe de espada (chamado pela arma a cada corte): o corpo prepara, avança e volta,
## virado para `dir_x` só no desenho. `step` é o passo do combo: 0 e 1 alternam o corte
## (descendente e ascendente), 2 é o arremate, mais longo e forte. Não toca na simulação.
func on_slash(dir_x: float, step: int) -> void:
	if not is_alive or down > 0.0:
		return
	_slash_dir = -1.0 if dir_x < 0.0 else 1.0
	_slash_step = clampi(step, 0, 2)
	_slash_len = SLASH_FINISHER_TIME if _slash_step == 2 else SLASH_TIME
	slash_time = _slash_len
	# O golpe manda no corpo: sem a pose genérica por cima, nem ela recomeçando no meio.
	cast_time = 0.0
	_cast_lock = maxf(_cast_lock, _slash_len)


## Golpe de espada visível agora (de pé e viva).
func is_slashing() -> bool:
	return slash_time > 0.0 and is_alive and down <= 0.0


## Lado para onde o corpo olha no desenho: o do golpe durante o corte, senão facing_x.
func visual_facing_x() -> float:
	return _slash_dir if is_slashing() else facing_x


## Pose do golpe `lag` s atrás do instante atual (os vultos usam lag > 0): "lunge" = avanço
## em px para o lado do corte, "lift" = deslocamento vertical em px, "scale" = escala do corpo
## e "tilt" = giro em rad (positivo = inclina para a frente). Fora do golpe, a pose de repouso.
func slash_pose(lag: float = 0.0) -> Dictionary:
	var elapsed := _slash_len - slash_time - lag
	var rest := {"lunge": 0.0, "lift": 0.0, "scale": Vector2.ONE, "tilt": 0.0}
	if slash_time <= 0.0 or elapsed < 0.0 or elapsed >= _slash_len:
		return rest
	var fin := _slash_step == 2
	var windup := SLASH_WINDUP_FINISHER if fin else SLASH_WINDUP
	var strike := SLASH_STRIKE_FINISHER if fin else SLASH_STRIKE
	# Preparo: recua 1 px, agacha e inclina para trás. Corte: avança, estica e inclina para a
	# frente. Passo 0 corta de cima para baixo (inclina mais e achata); passo 1 sobe (inclina
	# menos, cresce para cima e ergue 1 px); o arremate vai mais longe e mais fundo.
	var back_scale := Vector2(1.06, 0.94)
	var back_tilt := deg_to_rad(6.0 if fin else 4.0)
	var reach := 3.0 if fin else 2.0
	var hit_scale := Vector2(1.18, 0.9) if fin else (Vector2(1.08, 1.06) if _slash_step == 1 else Vector2(1.14, 0.93))
	var hit_tilt := deg_to_rad(14.0 if fin else (7.0 if _slash_step == 1 else 11.0))
	var hit_lift := -1.0 if _slash_step == 1 else 0.0
	if elapsed < windup:
		var a := smoothstep(0.0, 1.0, elapsed / windup)
		return {"lunge": -a, "lift": 0.0, "scale": Vector2.ONE.lerp(back_scale, a), "tilt": -back_tilt * a}
	if elapsed < windup + strike:
		# Ease-out cúbico: o corte sai de uma vez e freia na ponta.
		var s := 1.0 - pow(1.0 - (elapsed - windup) / strike, 3.0)
		return {"lunge": lerpf(-1.0, reach, s), "lift": hit_lift * s, "scale": back_scale.lerp(hit_scale, s),
				"tilt": lerpf(-back_tilt, hit_tilt, s)}
	# Retorno em ease-in-out (smoothstep) até o repouso.
	var r := smoothstep(0.0, 1.0, (elapsed - windup - strike) / (_slash_len - windup - strike))
	return {"lunge": lerpf(reach, 0.0, r), "lift": lerpf(hit_lift, 0.0, r), "scale": hit_scale.lerp(Vector2.ONE, r),
			"tilt": lerpf(hit_tilt, 0.0, r)}


func _process(delta: float) -> void:
	position = prev_pos.lerp(sim_pos, GameClock.alpha).round()
	if _hit_flash > 0.0:
		_hit_flash -= delta
	if cast_time > 0.0:
		cast_time = maxf(0.0, cast_time - delta)
	if _cast_lock > 0.0:
		_cast_lock -= delta
	if slash_time > 0.0:
		slash_time = maxf(0.0, slash_time - delta)
	queue_redraw()


func _draw() -> void:
	# Caída (ou morta): sem aura, clone e barra de vida; só o corpo no chão.
	var posed := down > 0.0 or not is_alive
	if aura_radius > 0.0 and not posed:
		draw_circle(Vector2.ZERO, aura_radius, Color(aura_color.r, aura_color.g, aura_color.b, 0.07))
		Stroke.arc(self, Vector2.ZERO, aura_radius, 0.0, TAU, 40, Color(aura_color.r, aura_color.g, aura_color.b, 0.25), 1.0)
	if _sheet == null:
		return
	if clone_time > 0.0 and not posed:
		var offset := clone_position() - sim_pos
		_draw_body(offset, Color(0.35, 0.3, 0.55, 0.6), false)
	_draw_body(Vector2.ZERO, Color.WHITE, true)
	if not posed:
		var below := bool(Settings.get_value("hp_bar_below"))
		_draw_hp(Vector2(-8.0, 7.0) if below else Vector2(-8.0, sprite_top() - 9.0))
	if show_hitbox:
		Stroke.arc(self, Vector2.ZERO, RADIUS, 0.0, TAU, 16, Color.CYAN, 1.0)


func _draw_body(offset: Vector2, tint: Color, main: bool) -> void:
	var angle := fall_angle() if main else 0.0
	if main:
		offset.y += _surface_sink()
	if main and _fx:
		offset += _fx.jitter()
	_draw_shadow(offset, angle)
	var swing := angle == 0.0 and is_slashing()
	# No golpe o corpo segura um quadro parado em vez de seguir o ciclo de passos.
	var moving := velocity.length() > 5.0 and angle == 0.0 and not swing
	var frame := int(_walk_time * 8.0) if moving else 0
	# Caída ou com o relógio parado (pausa, contagem depois do reviver), o corpo não pisca: o
	# invuln fica congelado e o quadro "piscando" viraria um branco fixo.
	var blink := main and invuln > 0.0 and down <= 0.0 and not GameClock.paused and int(invuln * 20.0) % 2 == 0
	var tex := _sheet.flash_texture if (blink or (main and _hit_flash > 0.0)) else _sheet.texture
	if main and swing and _side_size != Vector2.ZERO:
		_draw_slash_trail(offset)
	if main and chill > 0.0:
		tint = tint.lerp(CORPSE_TINT, chill)
		var rim := Color(CORPSE_RIM.r, CORPSE_RIM.g, CORPSE_RIM.b, CORPSE_RIM.a * chill)
		for d: Vector2 in RIM_DIRS:
			_draw_sprite(_sheet.flash_texture, offset + d, false, rim, angle, frame)
	_draw_sprite(tex, offset, moving, tint, angle, frame)
	if main and glow > 0.0:
		# Brilho da lanterna carregada pela guardiã (na mão, para heróis com "hand").
		var at := offset + lantern_offset() + (_swing_shift() if swing else Vector2.ZERO)
		draw_circle(at, 3.0, Color(lantern_tint.r, lantern_tint.g, lantern_tint.b, 0.35 * glow))
		draw_circle(at, 1.5, Color(1.0, 0.95, 0.7, 0.9 * glow))
	if cast_time > 0.0 and _has_hand and angle == 0.0:
		_draw_cast_spark(offset + _hand_offset())


func _draw_sprite(tex: Texture2D, offset: Vector2, moving: bool, tint: Color, angle: float, frame: int) -> void:
	if _side_size != Vector2.ZERO:
		_draw_side(tex, offset, moving, tint, angle)
	elif angle != 0.0:
		draw_set_transform(offset + Vector2(0.0, 3.0), angle)
		draw_texture_rect_region(tex, Rect2(Vector2(-8.0, -16.0), Vector2(16, 16)), _sheet.region(frame, dir), tint)
		draw_set_transform(Vector2.ZERO)
	else:
		# Heróis de 4 direções só dão o passo do golpe (sem giro: o quadro de frente não inclina).
		var shift := _swing_shift() if is_slashing() else Vector2.ZERO
		draw_texture_rect_region(tex, Rect2(offset + shift + Vector2(-8.0, -13.0), Vector2(16, 16)),
				_sheet.region(frame, dir), tint)


## Deslocamento do corpo no golpe agora, em px inteiros (o desenho fica nítido).
func _swing_shift(lag: float = 0.0) -> Vector2:
	var p := slash_pose(lag)
	return Vector2(roundf(float(p["lunge"])) * _slash_dir, roundf(float(p["lift"])))


## Rastro do golpe atrás do corpo: dois vultos na cor dos poderes, nas poses de instantes
## antes (ficam para trás no avanço), que só aparecem do corte em diante e somem logo. No
## arremate, vultos mais fortes e um contorno branco no fim do corte.
func _draw_slash_trail(offset: Vector2) -> void:
	var fin := _slash_step == 2
	var windup := SLASH_WINDUP_FINISHER if fin else SLASH_WINDUP
	var strike := SLASH_STRIKE_FINISHER if fin else SLASH_STRIKE
	var since := _slash_len - slash_time - windup
	if since < 0.0:
		return
	var fade := 1.0 - clampf((since - strike) / SLASH_GHOST_FADE, 0.0, 1.0)
	if fade > 0.0:
		var c := _cast_color
		var boost := 1.35 if fin else 1.0
		for i: int in range(SLASH_GHOST_LAG.size()):
			var a := minf(SLASH_GHOST_ALPHA[i] * boost, 1.0) * fade
			_draw_side(_sheet.flash_texture, offset, false, Color(c.r, c.g, c.b, a), 0.0, SLASH_GHOST_LAG[i])
	if not fin:
		return
	# Contorno branco da segunda metade do corte até pouco depois: o golpe "acende".
	var rim := 1.0 - absf(since - strike) / (strike * 0.5 + 0.03)
	if rim <= 0.0:
		return
	var calm := bool(Settings.get_value("reduce_flashes"))
	var white := Color(1.0, 1.0, 1.0, rim * (0.35 if calm else 0.85))
	for d: Vector2 in RIM_DIRS:
		_draw_side(_sheet.flash_texture, offset + d, false, white)


## Sombra nos pés; deitada, ela se alarga e acompanha o corpo para o lado da queda.
func _draw_shadow(offset: Vector2, angle: float) -> void:
	var w := float(_shadow.get_width())
	if angle == 0.0 and _fx and _fx.draws_shadow():
		return
	if angle == 0.0:
		draw_texture(_shadow, offset + Vector2(-w * 0.5, 1.0))
		return
	var k := absf(angle) / (PI * 0.5)
	var width := w * lerpf(1.0, LYING_SHADOW, k)
	var center := offset.x + signf(angle) * body_height() * 0.45 * k
	# Mais rasa e clara deitada, para não engolir o contorno do corpo.
	draw_texture_rect(_shadow, Rect2(center - width * 0.5, offset.y + 2.0, width, float(_shadow.get_height())), false,
			Color(1.0, 1.0, 1.0, lerpf(1.0, 0.45, k)))


## Mão relativa a sim_pos, já espelhada para o lado em que o herói olha no desenho (durante
## o golpe, o lado do corte). Os disparos usam hand_position(), que só lê facing_x.
func _hand_offset() -> Vector2:
	return Vector2(_hand.x * visual_facing_x(), _hand.y)


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
## No golpe de espada segura o quadro SLASH_FRAME, vira para o corte e segue slash_pose(lag).
func _draw_side(tex: Texture2D, offset: Vector2, moving: bool, tint: Color, angle: float = 0.0,
		lag: float = 0.0) -> void:
	var swing := angle == 0.0 and is_slashing()
	moving = moving and not swing
	var row := 1 if moving else 0
	var count := _side_counts.y if moving else _side_counts.x
	var t := _walk_time * 14.0 if moving else Time.get_ticks_msec() / 110.0
	var col := SLASH_FRAME if swing else posmod(int(t), maxi(1, count))
	var src := Rect2(Vector2(col * _side_size.x, row * _side_size.y), _side_size)
	var look := visual_facing_x()
	# Espelha quando o lado do desenho original difere do lado para onde o herói olha.
	var flip := -1.0 if (look < 0.0) != _faces_left else 1.0
	var feet := offset + Vector2(0.0, 3.0)
	var stretch := Vector2.ONE
	if swing:
		var p := slash_pose(lag)
		feet += _swing_shift(lag)
		stretch = p["scale"]
		angle = float(p["tilt"]) * look
	else:
		var pose := _cast_pose()
		feet.x += roundf(pose) * look
		stretch = Vector2(1.0 - 0.06 * pose, 1.0 + 0.08 * pose)
	var dest := Rect2(Vector2(-_side_size.x * 0.5, -_side_size.y), _side_size)
	draw_set_transform(feet, angle, Vector2(flip * stretch.x, stretch.y))
	draw_texture_rect_region(tex, dest, src, tint)
	draw_set_transform(Vector2.ZERO)


## Altura do desenho (pés à cabeça): o comprimento do corpo deitado.
func body_height() -> float:
	return _side_size.y if _side_size != Vector2.ZERO else 16.0


## Topo do desenho da guardiã (para a barra de vida acima da cabeça).
func sprite_top() -> float:
	return 3.0 - _side_size.y if _side_size != Vector2.ZERO else -13.0


func _draw_hp(at: Vector2) -> void:
	var fraction := clampf(hp / maxf(max_hp(), 1.0), 0.0, 1.0)
	draw_rect(Rect2(at, Vector2(16.0, 2.0)), Color(0.0, 0.0, 0.0, 0.7))
	draw_rect(Rect2(at, Vector2(16.0 * fraction, 2.0)), Color("e74c3c") if fraction > 0.25 else Color("ff2d2d"))
