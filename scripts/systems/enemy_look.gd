class_name EnemyLook
extends RefCounted
## Desenho dos inimigos e chefes (chamado pelo _draw do EnemyManager e das duas camadas
## aditivas dele). Tudo em lote: só os visíveis, sombras numa passada (um lote de textura),
## depois os corpos ordenados por Y. Só lê a simulação; o que guarda aqui é só de desenho.
##
## - Sombra suave (degradê) em Média/Alta, elipse dura em Baixa; menor e mais clara em quem voa.
## - Squash & stretch: passo (respira no ritmo da animação), golpe (achata e estica) e entrada.
## - Clarão de dano: o corpo normal e, por cima, a silhueta branca que se desfaz.
## - Elites: aura que pulsa embaixo, contorno dourado, coroa e brilho.
## - Onis: chifres em brasa, vapor do corpo e pisadas (tremor só em Alta, perto da guardiã).
## - Investida: "!" e seta vermelha na direção do bote durante a preparação.
## - Chefes: anda com a folha de andar, prepara com a de ataque e o Dragão de Cinza é montado
##   em partes (cabeça, asas, corpo e cauda que seguem o caminho da cabeça).
## - Chefes de frente, sem folha de andar (Onibi, Yomi-hebi, Nuppeppō: data "breathe"): respiram
##   (squash lento, parados ou não) e, preparando um golpe, a silhueta pulsa na cor da aura.
## - Estados das habilidades dos guardiões (status_flags): lento (tom azulado e flocos caindo
##   devagar), preso (argola de ferro aos pés), com medo (treme, gota e linhas de pavor acima),
##   atraído pela isca (seta no chão para a isca) e atordoado (estrelas). Só retângulos e o
##   próprio sprite tingido, desenhados só em quem está afetado (500 inimigos sem custo extra).

const SPAWN_TIME := 0.35
const BOSS_SPAWN_TIME := 1.4
const HIT_SQUASH := 0.16
const WALK_SQUASH := 0.06
const ELITE_AURA := Color(1.0, 0.78, 0.3)
const HORN_GLOW := Color(1.0, 0.32, 0.12)
const STEP_SHAKE_RANGE := 90.0
const STEP_SHAKE_GAP := 0.35
## Dragão montado: distância entre os gomos ao longo do rastro da cabeça.
const DRAGON_GAP := 11.0
const DRAGON_SEGMENTS := 6
const DRAGON_DIR := "res://assets/art/bosses/dragon/"
## Estados das habilidades (status_flags): bits e as cores dos indicadores.
const STATUS_SLOW := 1
const STATUS_ROOT := 2
const STATUS_FEAR := 4
const STATUS_LURE := 8
const STATUS_STUN := 16
## Fogo e gelo: queimando (chama sobre a cabeça, corpo puxado para o laranja) e congelado
## (bloco de gelo em volta do corpo, tom FROZEN_TINT só nele; sem as estrelas do atordoado).
const STATUS_BURN := 32
const STATUS_FROZEN := 64
const BURN_TINT := Color(1.0, 0.62, 0.38)
const FLAME_OUTER := Color(1.0, 0.42, 0.12, 0.95)
const FLAME_INNER := Color(1.0, 0.86, 0.45, 0.95)
const ICE_FILL := Color(0.72, 0.9, 1.0, 0.28)
const ICE_EDGE := Color(0.88, 0.97, 1.0, 0.85)
const SLOW_TINT := Color(0.55, 0.75, 1.0)
const SLOW_FLAKE := Color(0.75, 0.9, 1.0, 0.85)
const ROOT_IRON := Color(0.3, 0.31, 0.36)
const ROOT_SHINE := Color(0.86, 0.88, 0.92)
const FEAR_DROP := Color(0.55, 0.82, 1.0)
const FEAR_GLOOM := Color(0.62, 0.55, 1.0, 0.8)
const LURE_MARK := Color(1.0, 0.84, 0.4)
## Inimigos com marca de estado (atordoado, lento, preso, medo, isca) desenhada por quadro.
const MAX_STATUS_MARKS := 48
## Elos da argola de quem está preso (pontos de uma elipse unitária, feitos uma vez).
const ROOT_LINKS := 10

var m: EnemyManager
## Qualidade atual (GfxQuality): sombras suaves, nível de efeitos e brilho aditivo.
var soft_shadows: bool = true
var detail: int = 2

# Dados visuais por tipo (mesmo índice de m.type_ids).
var oni := PackedByteArray()
var heavy := PackedByteArray()
var death_styles := PackedStringArray()
var spawn_styles := PackedStringArray()
var walk_sheets: Array[SpriteSheet] = []
var attack_sheets: Array[SpriteSheet] = []
var composite := PackedStringArray()
## Amplitude do "respiro" do chefe (data "breathe"; 0 = sem) e a cor da aura dele.
var breathe := PackedFloat32Array()
var aura := PackedColorArray()
## Indicadores de estado desenhados no último quadro (testes e benchmark).
var status_drawn: int = 0

var _shadow: Texture2D
var _soft: Texture2D
var _visible := PackedInt32Array()
var _step_frame := PackedInt32Array()
## Fase da animação de andar por inimigo: avança com a velocidade real (lama, lentidão e
## congelamento desaceleram o passo junto com o movimento).
var _anim := PackedFloat32Array()
var _emit_left: float = 0.0
var _shake_left: float = 0.0
var _trails: Dictionary = {}
var _dragon: Dictionary = {}
var _look := RandomNumberGenerator.new()
var _ring := PackedVector2Array()
## Inimigos com marca neste quadro (desenhadas depois de todos os corpos) e onde desenhar.
var _marks := PackedInt32Array()
var _mark_body := PackedVector2Array()
var _mark_top := PackedFloat32Array()
var _mark_feet := PackedFloat32Array()


func _init(manager: EnemyManager) -> void:
	m = manager
	for k: int in range(ROOT_LINKS):
		_ring.append(Vector2.from_angle(TAU * k / ROOT_LINKS))
	_shadow = load("res://assets/art/actors/shadow.png") as Texture2D
	_soft = EnemyFx.soft_texture()
	_step_frame.resize(EnemyManager.CAPACITY)
	_anim.resize(EnemyManager.CAPACITY)
	_look.randomize()
	for t: int in range(m.type_ids.size()):
		var data := m.type_data[t]
		var id := String(m.type_ids[t])
		var is_boss := m.type_ai[t] == EnemyManager.AI.BOSS
		oni.append(1 if bool(data.get("oni", id.contains("oni"))) else 0)
		heavy.append(1 if oni[t] == 1 or m.type_scale[t] >= 1.3 or m.type_ai[t] == EnemyManager.AI.TANK else 0)
		var d := data.duplicate()
		d["id"] = id
		death_styles.append(EnemyFx.death_style(d))
		spawn_styles.append(EnemyFx.spawn_style(d))
		var sprite: Dictionary = data.get("sprite", {}) if is_boss else {}
		walk_sheets.append(_extra_sheet(data.get("walk_sprite", {}), sprite))
		attack_sheets.append(_extra_sheet(data.get("attack_sprite", {}), sprite))
		composite.append(String(sprite.get("composite", "")))
		breathe.append(float(data.get("breathe", 0.0)) if is_boss else 0.0)
		aura.append(Color(String(data.get("aura", "#ffffff"))))
		if composite[t] == "dragon" and _dragon.is_empty():
			_load_dragon()
	apply_quality()


static func _extra_sheet(spec: Variant, base: Dictionary) -> SpriteSheet:
	if not spec is Dictionary or (spec as Dictionary).is_empty():
		return null
	var s: Dictionary = spec
	var frame: Array = s.get("frame", base.get("frame", [0, 0]))
	return SpriteSheet.load_sheet(s["path"], s.get("layout", "strip"), Vector2(frame[0], frame[1]), 0,
			bool(s.get("faces_left", base.get("faces_left", false))))


func _load_dragon() -> void:
	for part: String in ["Head", "Body1", "Body2", "BodyEnd", "Wing"]:
		var path := DRAGON_DIR + part + ".png"
		if ResourceLoader.exists(path):
			_dragon[part] = SpriteSheet.load_sheet(path, "strip", Vector2.ZERO, 1)


func apply_quality() -> void:
	soft_shadows = bool(GfxQuality.budget("soft_shadows"))
	detail = int(GfxQuality.budget("enemy_fx"))


## Quem está na tela (com folga), já em ordem de Y; chamado uma vez por quadro.
func collect(view: Rect2) -> void:
	_visible.clear()
	var a := GameClock.alpha
	for i: int in m._order:
		if m.alive[i] == 0 or m.submerged[i] == 1:
			continue
		if view.has_point(m.prev[i].lerp(m.pos[i], a)):
			_visible.append(i)


func visible_count() -> int:
	return _visible.size()


func foot_of(i: int) -> Vector2:
	return (m.prev[i].lerp(m.pos[i], GameClock.alpha) + Vector2(0.0, m.radius[i] * 0.6)).round()


func body_scale(i: int) -> float:
	return m.type_scale[m.kind[i]] * (EnemyManager.ELITE_SCALE if m.elite[i] == 1 else 1.0)


# --- Emissores (vapor, faíscas, pisadas) -----------------------------------------------

func process(delta: float) -> void:
	if GameClock.paused or m.game == null:
		return
	_emit_left -= delta
	_shake_left -= delta
	var fx := m.fx
	var emit_now := _emit_left <= 0.0
	if emit_now:
		_emit_left = [0.3, 0.16, 0.1][detail]
	var player := m.game.player.position
	var game_dt := minf(delta, 0.1) * GameClock.speed
	for i: int in _visible:
		var t := m.kind[i]
		_anim[i] += game_dt * 8.0 * anim_rate(i)
		var s := body_scale(i)
		var foot := foot_of(i)
		if composite[t] == "dragon":
			_record_trail(i, foot)
		if emit_now and m.elite[i] == 1:
			fx.spark(foot + Vector2(_look.randf_range(-6.0, 6.0) * s, -_look.randf_range(4.0, 14.0) * s), ELITE_AURA)
		if oni[t] == 1 and detail >= 1:
			if emit_now and _look.randf() < 0.5:
				fx.steam(foot + Vector2(_look.randf_range(-4.0, 4.0) * s, -9.0 * s))
		if heavy[t] == 1 and detail >= 1 and m.vel[i].length() > 3.0:
			var frame := walk_frame(i)
			if frame != _step_frame[i] and frame % 2 == 0:
				fx.stomp(foot, s * (1.6 if m.is_boss(i) else 1.0))
				if detail >= 2 and _shake_left <= 0.0 and foot.distance_to(player) < STEP_SHAKE_RANGE * s:
					_shake_left = STEP_SHAKE_GAP
					m.game.shake(0.6 if not m.is_boss(i) else 1.2)
			_step_frame[i] = frame


## Ritmo do passo: 1 na velocidade normal do bicho; cai junto com a lentidão (lama, slow).
func anim_rate(i: int) -> float:
	if m.controlled[i] == 1:
		return 1.0
	var base := maxf(m.speed[i], 1.0)
	return clampf(m.vel[i].length() / base, 0.35, 1.4)


func walk_frame(i: int) -> int:
	return int(_anim[i] + m.phase[i])


func _record_trail(i: int, head: Vector2) -> void:
	var trail: PackedVector2Array = _trails.get(i, PackedVector2Array())
	if trail.is_empty() or trail[0].distance_to(head) >= 2.0:
		trail.insert(0, head)
		if trail.size() > 64:
			trail.resize(64)
	_trails[i] = trail


func forget(i: int) -> void:
	_trails.erase(i)


# --- Desenho ---------------------------------------------------------------------------

func draw(canvas: CanvasItem) -> void:
	var time := GameClock.game_time
	_draw_shadows(canvas)
	var reduce_flash := bool(Settings.get_value("reduce_flashes"))
	var light_r := -1.0 if RedMoon.shades_in_light(m.game.moon) else m.game.lantern.radius
	var player_pos := m.game.player.position
	var frozen := m.freeze_time > 0.0
	status_drawn = 0
	for i: int in _visible:
		var t := m.kind[i]
		if composite[t] == "dragon" and not _dragon.is_empty():
			_draw_dragon(canvas, i, reduce_flash)
			continue
		var sheet := _sheet_for(i)
		var s := body_scale(i)
		var foot := foot_of(i)
		var color := m.type_tint[t]
		if m.type_ai[t] == EnemyManager.AI.SHADE and foot.distance_to(player_pos) > light_r:
			color.a = EnemyManager.SHADE_DARK_ALPHA
		if m.decoy[i] == 1:
			color.a = 0.85
		var status := status_flags(i)
		color = EnemyManager.frozen_tint(color, frozen or status & STATUS_FROZEN)
		if status & STATUS_SLOW and not status & STATUS_FROZEN:
			color = slow_tint(color)
		if status & STATUS_BURN:
			color = burn_tint(color)
		var src: Rect2
		var flip := false
		if sheet.layout == "region":
			src = sheet.get_meta("region")
		else:
			var moving := m.vel[i].length() > 3.0 or m.controlled[i] == 1
			src = sheet.region(walk_frame(i) if moving else 0, m.facing[i])
			flip = sheet.needs_flip(m.facing[i])
		var size := src.size
		var squash := _squash(i, time)
		var bob := 0.0
		if m.type_flying[t] == 1:
			bob = roundf(sin(time * 6.0 + m.phase[i]) * 1.5) - 4.0
		var born := _born_progress(i, time)
		color.a *= born
		# Elite com afixos (EliteAffixes): surgindo do altar (escala com sobre-salto e silhueta na cor
		# do afixo) ou sumindo na Miragem (transparente).
		# Selados da emboscada (sem afixos) piscam claros e meio transparentes até serem soltos.
		var rise := Vector3(1.0, 0.0, 1.0)
		if (m.elite[i] == 1 or m.sealed[i] == 1) and m.game.altars != null:
			rise = m.game.altars.affixes.body_look(i)
			if m.sealed[i] == 1 and rise == Vector3(1.0, 0.0, 1.0):
				rise = Vector3(1.0, 0.45 + 0.25 * sin(time * 30.0), 0.85)
			s *= rise.x
			color.a *= rise.z
		# Atolado numa superfície lenta: desce 1–2 px (SurfaceSystem), volta ao recuperar.
		var body := foot + Vector2(0.0, bob * s + _sink(i))
		if status & STATUS_FEAR:
			# Com medo: treme de um lado para o outro (1 px).
			body.x += roundf(sin(time * 47.0 + i * 1.3) * 0.8)
		canvas.draw_set_transform(body, 0.0, Vector2((-s if flip else s) * squash.x, s * squash.y * (0.4 + 0.6 * born)))
		var rect := Rect2(Vector2(-size.x * 0.5, -size.y + 2.0), size)
		var tex: Texture2D = sheet.outline_texture if m.elite[i] == 1 else sheet.texture
		canvas.draw_texture_rect_region(tex, rect, src, color)
		if rise.y > 0.0:
			var tint := m.game.altars.affixes.silhouette_color(i)
			canvas.draw_texture_rect_region(sheet.flash_texture, rect, src, Color(tint, rise.y * color.a))
		if breathe[t] > 0.0 and m.pose[i] == 1 and not reduce_flash:
			var glow := 0.25 + 0.25 * sin(time * 16.0)
			canvas.draw_texture_rect_region(sheet.flash_texture, rect, src, Color(aura[t], glow * color.a))
		if m.flash[i] > 0.0:
			# Chefes levam golpe o tempo todo: clarão mais leve para o corpo continuar legível.
			var f := clampf(m.flash[i] / 0.08, 0.0, 1.0) * (0.55 if m.is_boss(i) else 1.0)
			var flash_color := Color(1.0, 0.35, 0.3, 0.5 * f) if reduce_flash else Color(1, 1, 1, f * color.a)
			canvas.draw_texture_rect_region(sheet.flash_texture, rect, src, flash_color)
		if status != 0 or m.elite[i] == 1 or m.state[i] == EnemyManager.State.WINDUP:
			_marks.append(i)
			_mark_body.append(body)
			_mark_top.append(-(size.y - 2.0) * s * squash.y)
			_mark_feet.append(-bob * s)
	# Marcas (coroa, estrelas, alerta e estados das habilidades) numa 2ª passada, por cima de todos
	# os corpos: retângulos no meio dos sprites quebravam o lote de desenho a cada inimigo marcado
	# (centenas de chamadas com a horda atordoada), e por cima elas leem no meio da multidão.
	var shown := 0
	for k: int in range(_marks.size()):
		var i := _marks[k]
		var top := _mark_top[k]
		canvas.draw_set_transform(_mark_body[k], 0.0, Vector2.ONE)
		var status := status_flags(i)
		# Teto de marcas de estado por quadro (horda inteira atordoada ou presa): o resto do bando
		# já lê pelo efeito da habilidade, e cada marca custa várias chamadas em GDScript.
		if status != 0:
			shown += 1
			if shown > MAX_STATUS_MARKS:
				status = 0
		# Elites com afixos têm brasão e barra próprios (EliteAffixes.draw_over).
		if m.elite[i] == 1 and (m.game.altars == null or not m.game.altars.affixes.has(i)):
			_draw_crown(canvas, Vector2(0, top - 4.0 + sin(time * 4.0 + i) * 1.0))
		if status & STATUS_STUN:
			_draw_stars(canvas, Vector2(0, top - 2.0), time)
		if m.state[i] == EnemyManager.State.WINDUP and not m.is_boss(i):
			_draw_alert(canvas, Vector2(0, top - 5.0), time)
		if status & ~STATUS_STUN:
			_draw_status(canvas, i, status, Vector2(0.0, _mark_feet[k]), top, time)
	_marks.clear()
	_mark_body.clear()
	_mark_top.clear()
	_mark_feet.clear()
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Estados das habilidades no inimigo `i` agora (bits STATUS_*; 0 = nenhum). Só leitura.
func status_flags(i: int) -> int:
	var flags := 0
	if m.slow[i] > 0.0:
		flags |= STATUS_SLOW
	if m.root[i] > 0.0:
		flags |= STATUS_ROOT
	if m.fear[i] > 0.0:
		flags |= STATUS_FEAR
	elif m.lure[i] > 0.0:
		flags |= STATUS_LURE
	if m.frozen[i] > 0.0:
		flags |= STATUS_FROZEN
	elif m.stun[i] > 0.0:
		flags |= STATUS_STUN
	if m.burn_time[i] > 0.0:
		flags |= STATUS_BURN
	return flags


## Lento: o próprio sprite puxado para o azul (sem desenho extra).
static func slow_tint(base: Color) -> Color:
	var tint := base.lerp(SLOW_TINT, 0.4)
	tint.a = base.a
	return tint


## Queimando: o sprite puxado de leve para o laranja (sem desenho extra).
static func burn_tint(base: Color) -> Color:
	var tint := base.lerp(BURN_TINT, 0.3)
	tint.a = base.a
	return tint


## Indicadores de lento, preso, medo e isca, no espaço do corpo (`feet` = chão, `top` = cabeça).
func _draw_status(canvas: CanvasItem, i: int, status: int, feet: Vector2, top: float, time: float) -> void:
	var r := maxf(5.0, m.radius[i] * 1.2)
	if status & STATUS_FROZEN:
		status_drawn += 1
		# Bloco de gelo em volta do corpo: miolo translúcido, aresta clara e um brilho que corre.
		var box := Rect2(Vector2(-r - 1.0, top - 1.0), Vector2(r * 2.0 + 2.0, feet.y - top + 2.0)).abs()
		box.position = box.position.round()
		box.size = box.size.round()
		canvas.draw_rect(box, ICE_FILL)
		canvas.draw_rect(Rect2(box.position, Vector2(box.size.x, 1)), ICE_EDGE)
		canvas.draw_rect(Rect2(box.position, Vector2(1, box.size.y)), ICE_EDGE)
		canvas.draw_rect(Rect2(box.position + Vector2(box.size.x - 1, 0), Vector2(1, box.size.y)), Color(ICE_EDGE, 0.5))
		canvas.draw_rect(Rect2(box.position + Vector2(0, box.size.y - 1), Vector2(box.size.x, 1)), Color(ICE_EDGE, 0.5))
		var glint := fmod(time * 0.9 + i * 0.37, 1.0) * box.size.y
		canvas.draw_rect(Rect2(box.position + Vector2(2, roundf(glint)), Vector2(2, 1)), Color(1, 1, 1, 0.8))
	if status & STATUS_BURN:
		status_drawn += 1
		# Chama pequena tremulando acima da cabeça (três camadas de retângulos).
		var flick := sin(time * 23.0 + i * 1.9)
		var h := 4.0 + roundf(flick)
		var base := Vector2(-1.0 + roundf(sin(time * 9.0 + i)), top - 2.0)
		canvas.draw_rect(Rect2(base + Vector2(-1, -h + 1), Vector2(4, h)), Color(0.25, 0.05, 0.02, 0.6))
		canvas.draw_rect(Rect2(base + Vector2(-1, -h + 1), Vector2(3, h - 1)), FLAME_OUTER)
		canvas.draw_rect(Rect2(base + Vector2(0, -h + 2), Vector2(1, h - 2)), FLAME_INNER)
		canvas.draw_rect(Rect2(base + Vector2(0, -h - 1), Vector2(1, 1)), Color(FLAME_OUTER, 0.6 + 0.4 * flick))
	if status & STATUS_ROOT:
		status_drawn += 1
		# Argola de ferro aos pés: elos alternados claro/escuro e um brilho que corre.
		var shine := int(time * 12.0 + i) % ROOT_LINKS
		for k: int in range(ROOT_LINKS):
			var p := (feet + Vector2(_ring[k].x * r, _ring[k].y * r * 0.4)).round()
			var c := ROOT_SHINE if k == shine else (ROOT_IRON if k % 2 == 0 else ROOT_IRON.lerp(ROOT_SHINE, 0.55))
			canvas.draw_rect(Rect2(p - Vector2(1, 0), Vector2(3, 2)), Color(0.05, 0.05, 0.08, 0.8))
			canvas.draw_rect(Rect2(p - Vector2(1, 0), Vector2(2, 1)), c)
		# Cadeado de ferro acima da cabeça: a argola aos pés some atrás da horda, o cadeado não.
		var lock := Vector2(-2.0, top - 7.0).round()
		canvas.draw_rect(Rect2(lock + Vector2(-1, -1), Vector2(7, 7)), Color(0.05, 0.05, 0.08, 0.85))
		canvas.draw_rect(Rect2(lock + Vector2(1, 0), Vector2(3, 1)), ROOT_SHINE)
		canvas.draw_rect(Rect2(lock + Vector2(0, 1), Vector2(1, 2)), ROOT_SHINE)
		canvas.draw_rect(Rect2(lock + Vector2(4, 1), Vector2(1, 2)), ROOT_SHINE)
		canvas.draw_rect(Rect2(lock + Vector2(0, 2), Vector2(5, 3)), ROOT_IRON.lerp(ROOT_SHINE, 0.35))
		canvas.draw_rect(Rect2(lock + Vector2(2, 3), Vector2(1, 1)), Color(0.05, 0.05, 0.08))
	if status & STATUS_SLOW:
		status_drawn += 1
		# Dois flocos frios caindo devagar ao lado do corpo.
		for k: int in range(2):
			var fall := fmod(time * 5.0 + i * 1.7 + k * 4.0, 9.0)
			var x := (-r * 0.8 if k == 0 else r * 0.8) + sin(time * 2.0 + k + i) * 0.8
			canvas.draw_rect(Rect2(Vector2(x, top + 2.0 + fall).round(), Vector2(1, 1)),
					Color(SLOW_FLAKE, SLOW_FLAKE.a * (1.0 - fall / 9.0)))
	if status & STATUS_FEAR:
		status_drawn += 1
		# Gota de suor ao lado da cabeça e linhas de pavor acima.
		var drop := Vector2(r * 0.7 + 1.0, top + 1.0 + fmod(time * 6.0 + i, 3.0)).round()
		canvas.draw_rect(Rect2(drop + Vector2(1, 0), Vector2(1, 1)), FEAR_DROP)
		canvas.draw_rect(Rect2(drop + Vector2(0, 1), Vector2(3, 2)), FEAR_DROP)
		canvas.draw_rect(Rect2(drop + Vector2(0, 1), Vector2(1, 1)), Color(1, 1, 1, 0.9))
		for k: int in range(3):
			var h := 3.0 if k == 1 else 2.0
			canvas.draw_rect(Rect2(Vector2(-2.0 + k * 2.0, top - 3.0 - h).round(), Vector2(1, h)), FEAR_GLOOM)
	if status & STATUS_LURE:
		status_drawn += 1
		# Seta no chão apontando para a isca (pulsa).
		var to: Vector2 = m.goal[i] - m.pos[i]
		if to.length_squared() > 1.0:
			var dir := to.normalized()
			var side := dir.orthogonal()
			var tip := feet + dir * (r + 4.0)
			var a := 0.6 + 0.4 * sin(time * 9.0 + i)
			var c := Color(LURE_MARK, a)
			canvas.draw_rect(Rect2(tip.round(), Vector2(1, 1)), c)
			for k: int in range(1, 3):
				canvas.draw_rect(Rect2((tip - dir * k + side * k).round(), Vector2(1, 1)), c)
				canvas.draw_rect(Rect2((tip - dir * k - side * k).round(), Vector2(1, 1)), c)


func _sheet_for(i: int) -> SpriteSheet:
	var t := m.kind[i]
	if m.type_ai[t] == EnemyManager.AI.BOSS:
		if m.pose[i] == 1 and attack_sheets[t] != null:
			return attack_sheets[t]
		if walk_sheets[t] != null and m.vel[i].length() > 3.0:
			return walk_sheets[t]
	return m.type_sheets[t]


## Escala (x, y) do squash & stretch: passo, golpe e o "respiro" do chefe preparando.
func _squash(i: int, time: float) -> Vector2:
	var sx := 1.0
	var sy := 1.0
	if detail >= 1 and m.vel[i].length() > 3.0 and m.type_flying[m.kind[i]] == 0:
		var w := sin((_anim[i] + m.phase[i]) * PI) * WALK_SQUASH
		sy += w
		sx -= w * 0.5
	var age := time - m.hit_at[i]
	if age >= 0.0 and age < HIT_SQUASH:
		var k := sin(age / HIT_SQUASH * PI) * (0.6 if m.is_boss(i) else 1.0)
		sx += 0.22 * k
		sy -= 0.18 * k
	var b := breathe[m.kind[i]]
	if b > 0.0:
		var r := sin(time * 2.6 + m.phase[i])
		sy += r * b
		sx -= r * b * 0.6
	if m.pose[i] == 1:
		var p := 0.5 + 0.5 * sin(time * 18.0)
		sx += 0.05 * p
		sy -= 0.05 * p
	return Vector2(sx, sy)


## 0 → 1 na entrada (com um leve exagero no fim, para "assentar").
func _born_progress(i: int, time: float) -> float:
	var span := BOSS_SPAWN_TIME if m.is_boss(i) else SPAWN_TIME
	var k := clampf((time - m.born[i]) / span, 0.0, 1.0)
	return k


func _draw_shadows(canvas: CanvasItem) -> void:
	var a := 0.42
	for i: int in _visible:
		var t := m.kind[i]
		var s := body_scale(i)
		var foot := foot_of(i)
		var w := maxf(8.0, m.radius[i] * 2.4 / (EnemyManager.ELITE_SCALE if m.elite[i] == 1 else 1.0)) * s
		if m.type_ai[t] == EnemyManager.AI.BOSS:
			w = m.radius[i] * 2.6
		var alpha := a * _born_progress(i, GameClock.game_time)
		if m.type_flying[t] == 1:
			w *= 0.7
			alpha *= 0.6
		if composite[t] == "dragon":
			for p: Vector2 in dragon_points(i):
				_shadow_at(canvas, p, w * 0.6, alpha)
		_shadow_at(canvas, foot, w, alpha)


func _shadow_at(canvas: CanvasItem, foot: Vector2, w: float, alpha: float) -> void:
	if soft_shadows:
		var h := w * 0.42
		canvas.draw_texture_rect(_soft, Rect2(foot - Vector2(w * 0.6, h * 0.6), Vector2(w * 1.2, h * 1.2)), false,
				Color(0.02, 0.0, 0.05, alpha * 1.5))
	else:
		var ss := w / float(_shadow.get_width())
		canvas.draw_set_transform(foot, 0.0, Vector2(ss, ss))
		canvas.draw_texture(_shadow, -_shadow.get_size() * 0.5, Color(1, 1, 1, minf(1.0, alpha * 2.4)))
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_crown(canvas: CanvasItem, at: Vector2) -> void:
	var gold := Color("ffd166")
	var p := at.round()
	canvas.draw_rect(Rect2(p + Vector2(-3, 0), Vector2(7, 2)), Color("8a5a00"))
	canvas.draw_rect(Rect2(p + Vector2(-3, -1), Vector2(7, 2)), gold)
	for x: float in [-3.0, 0.0, 3.0]:
		canvas.draw_rect(Rect2(p + Vector2(x, -3), Vector2(1, 2)), gold)
	canvas.draw_rect(Rect2(p + Vector2(0, -2), Vector2(1, 1)), Color("ff5d5d"))


func _draw_stars(canvas: CanvasItem, at: Vector2, time: float) -> void:
	for k: int in range(3):
		var angle := time * 5.0 + TAU * k / 3.0
		var p := (at + Vector2(cos(angle) * 5.0, sin(angle) * 1.5)).round()
		canvas.draw_rect(Rect2(p, Vector2(1, 1)), Color(1.0, 0.95, 0.5, 0.95))
		canvas.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), Color(0.6, 0.85, 1.0, 0.5))


## "!" piscando sobre quem prepara o bote.
func _draw_alert(canvas: CanvasItem, at: Vector2, time: float) -> void:
	if int(time * 10.0) % 2 == 1:
		return
	var p := at.round()
	canvas.draw_rect(Rect2(p + Vector2(-1, -7), Vector2(3, 7)), Color(0.15, 0.0, 0.0))
	canvas.draw_rect(Rect2(p + Vector2(0, -6), Vector2(1, 4)), Color(1.0, 0.3, 0.25))
	canvas.draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 1)), Color(1.0, 0.3, 0.25))


## Camada aditiva por baixo dos corpos: aura das elites e brasa no chão dos onis.
func draw_under(canvas: CanvasItem) -> void:
	if detail == 0:
		return
	var time := GameClock.game_time
	for i: int in _visible:
		var t := m.kind[i]
		if m.elite[i] == 1:
			var foot := foot_of(i)
			var s := body_scale(i)
			var pulse := 0.6 + 0.4 * sin(time * 5.0 + i)
			var r := 12.0 * s * (0.9 + 0.1 * pulse)
			canvas.draw_texture_rect(_soft, Rect2(foot - Vector2(r, r * 0.55 + 6.0 * s), Vector2(r * 2.0, r * 1.1)),
					false, Color(ELITE_AURA, 0.35 * pulse))
			if detail >= 2:
				canvas.draw_texture_rect(_soft, Rect2(foot - Vector2(r * 0.7, r * 1.6), Vector2(r * 1.4, r * 1.6)),
						false, Color(ELITE_AURA, 0.18 * pulse))
		elif oni[t] == 1 and detail >= 2 and not m.is_boss(i):
			var foot := foot_of(i)
			canvas.draw_texture_rect(_soft, Rect2(foot - Vector2(10, 4), Vector2(20, 8)), false,
					Color(HORN_GLOW, 0.25 + 0.1 * sin(time * 3.0 + i)))


## Camada aditiva por cima: chifres em brasa, seta do bote e brilho das elites.
func draw_over(canvas: CanvasItem) -> void:
	if detail == 0:
		return
	var time := GameClock.game_time
	for i: int in _visible:
		var t := m.kind[i]
		var s := body_scale(i)
		var foot := foot_of(i)
		if oni[t] == 1 and not m.is_boss(i):
			var top := foot + Vector2(0, -13.0 * s)
			var pulse := 0.7 + 0.3 * sin(time * 6.0 + i)
			for side: float in [-1.0, 1.0]:
				var horn := top + Vector2(side * 3.5 * s, 0)
				canvas.draw_texture_rect(_soft, Rect2(horn - Vector2(3, 3) * s * 0.8, Vector2(6, 6) * s * 0.8), false,
						Color(HORN_GLOW, 0.8 * pulse))
		if m.state[i] == EnemyManager.State.WINDUP and not m.is_boss(i):
			var params: Dictionary = m.type_data[t].get("ai", {})
			var reach := float(params.get("dash_speed", 180)) * float(params.get("dash_time", 0.45)) * 0.8
			var dir: Vector2 = m.ai_dir[i]
			var pulse := 0.5 + 0.5 * sin(time * 25.0)
			canvas.draw_line(foot, foot + dir * reach, Color(1.0, 0.2, 0.15, 0.25 + 0.25 * pulse), 4.0)
			var tip := foot + dir * reach
			Stroke.convex(canvas, PackedVector2Array([tip + dir * 5.0, tip + dir.orthogonal() * 4.0,
					tip - dir.orthogonal() * 4.0]), Color(1.0, 0.3, 0.2, 0.5 + 0.3 * pulse))
		if m.elite[i] == 1 and detail >= 2:
			var glint := 0.5 + 0.5 * sin(time * 3.0 + i * 1.7)
			canvas.draw_texture_rect(_soft, Rect2(foot + Vector2(-8, -24) * s * 0.6, Vector2(16, 16) * s * 0.6), false,
					Color(ELITE_AURA, 0.18 * glint))


# --- Dragão montado ---------------------------------------------------------------------

func _draw_dragon(canvas: CanvasItem, i: int, reduce_flash: bool) -> void:
	var time := GameClock.game_time
	var head := foot_of(i) + Vector2(0, -16)
	var tint := EnemyManager.frozen_tint(m.type_tint[m.kind[i]], m.freeze_time > 0.0)
	tint.a *= _born_progress(i, time)
	var trail: PackedVector2Array = _trails.get(i, PackedVector2Array([foot_of(i)]))
	var flash := 0.0 if reduce_flash else clampf(m.flash[i] / 0.08, 0.0, 1.0) * 0.55
	# Gomos do rabo para a cabeça: o da frente cobre o de trás.
	var points: Array[Vector2] = []
	for k: int in range(DRAGON_SEGMENTS):
		points.append(_trail_point(trail, (k + 1) * DRAGON_GAP, foot_of(i), i, k) + Vector2(0, -14))
	for k: int in range(DRAGON_SEGMENTS - 1, -1, -1):
		var part := "BodyEnd" if k == DRAGON_SEGMENTS - 1 else ("Body1" if k % 2 == 0 else "Body2")
		var ahead: Vector2 = head if k == 0 else points[k - 1]
		var angle := (ahead - points[k]).angle() - PI * 0.5 if part == "BodyEnd" else 0.0
		_draw_part(canvas, part, points[k], angle, Vector2.ONE * (1.0 - 0.06 * k), tint, flash)
	var flap := 0.75 + 0.25 * sin(time * 5.0)
	_draw_part(canvas, "Wing", head + Vector2(-20, -8), 0.0, Vector2(1.0, flap), tint, flash)
	_draw_part(canvas, "Wing", head + Vector2(20, -8), 0.0, Vector2(-1.0, flap), tint, flash)
	var sq := _squash(i, time)
	_draw_part(canvas, "Head", head, 0.0, sq, tint, flash)


func _trail_point(trail: PackedVector2Array, distance: float, foot: Vector2, i: int, k: int) -> Vector2:
	var walked := 0.0
	var last := trail[0]
	for p: Vector2 in trail:
		var step := last.distance_to(p)
		if walked + step >= distance and step > 0.0:
			return last.lerp(p, (distance - walked) / step)
		walked += step
		last = p
	# Rastro curto (acabou de nascer): o corpo sobe atrás da cabeça, ondulando.
	var angle := -PI * 0.5 + sin(GameClock.game_time * 2.0 + k + i) * 0.5
	return foot + Vector2.from_angle(angle) * distance * 0.7


func _draw_part(canvas: CanvasItem, part: String, at: Vector2, angle: float, scale: Vector2, tint: Color,
		flash: float) -> void:
	var sheet: SpriteSheet = _dragon.get(part)
	if sheet == null:
		return
	var size := Vector2(sheet.texture.get_size())
	canvas.draw_set_transform(at.round(), angle, scale)
	var rect := Rect2(-size * 0.5, size)
	canvas.draw_texture_rect(sheet.texture, rect, false, tint)
	if flash > 0.0:
		canvas.draw_texture_rect(sheet.flash_texture, rect, false, Color(1, 1, 1, flash * tint.a))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Sombras do dragão montado (o _draw_shadows só faz a da cabeça).
func dragon_points(i: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var trail: PackedVector2Array = _trails.get(i, PackedVector2Array([foot_of(i)]))
	for k: int in range(DRAGON_SEGMENTS):
		out.append(_trail_point(trail, (k + 1) * DRAGON_GAP, foot_of(i), i, k))
	return out


func _sink(i: int) -> float:
	var surfaces := SurfaceSystem.of(m.game)
	return 0.0 if surfaces == null or m.type_flying[m.kind[i]] == 1 else surfaces.enemy_sink(i)
