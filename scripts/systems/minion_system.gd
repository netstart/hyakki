class_name MinionSystem
extends RefCounted
## Servos espectrais da Kuon (久遠, a Shinobi dos Mortos): almas de yōkai vencidos que ela pede, e não
## ordena, que lutem ao seu lado. Aliados leves em arrays, sem nó por servo, num laço só no passo fixo:
## - nascem de abates (Shiryō-fuda e Hyakki-shō), das habilidades (Tamashii-gari, Yomigaeri), da
##   união Yomi no Gunzei e do golpe da lanterna (Necro Rite, `start_rite`);
## - procuram o yōkai mais próximo (EnemyManager.nearest), correm até ele e golpeiam em volta do alvo
##   a cada ATTACK_EVERY s; sem alvo, seguem a Kuon em volta dela;
## - não recebem dano, somem no fim do tempo de vida (`life`) e contam como "caídos" (`fallen`, que o
##   Yomigaeri chama de volta);
## - teto: o maior "minion_cap" das armas dela (no mínimo BASE_CAP) + o atributo "minions" (Sino da
##   Itako), nunca acima de HARD_CAP; dano e alcance do golpe × atributo "minion_power" (Incenso);
## - dois tipos: SPIRIT (fantasma violeta) e SAMURAI (esqueleto de samurai espectral, mais forte e com
##   corte em meia-lua), o das armas com "minion_kind": "samurai" (Hyakki-shō e o Exército de Yomi).
## Tudo determinístico (sem sorteio): entra no hash (hash_tag) e na partida suspensa (state/load_state).
## Troca de reino (RiftPortal.clear_field) e começo de partida limpam tudo. O desenho só lê, em
## passadas por textura (sombras, contornos, corpos, brilho) para todos os servos de uma vez.

enum Kind { SPIRIT, SAMURAI }

## Teto mínimo (sem arma de servos) e o absoluto (desempenho e leitura da tela).
const BASE_CAP := 3
const HARD_CAP := 24
## Golpe: intervalo (s), raio em volta do alvo (px, × minion_power), recuo.
const ATTACK_EVERY: Array[float] = [0.8, 0.7]
const STRIKE_RADIUS: Array[float] = [11.0, 16.0]
const STRIKE_FORCE: Array[float] = [30.0, 60.0]
## Busca de alvo, troca de alvo (s), distância máxima da Kuon antes de voltar para o lado dela.
const CHASE_RANGE := 200.0
const RETARGET := 0.35
const LEASH := 300.0
const FOLLOW_GAP := 24.0
const SPAWN_RING := 14.0
## Velocidade padrão (px/s) e a do servo SAMURAI quando quem levanta não diz.
const DEFAULT_SPEED: Array[float] = [70.0, 85.0]
const DEFAULT_DAMAGE := 5.0
const DEFAULT_LIFE := 8.0
## "Caídos" lembrados para o Yomigaeri.
const FALLEN_MAX := 32
## Folhas do desenho: o fantasma (Monster/Spirit) e o esqueleto (Monster/Skeleton), Ninja Adventure (CC0).
const SHEETS: Array[String] = ["res://assets/art/actors/enemies/spirit/SpriteSheet.png",
		"res://assets/art/actors/enemies/skeleton/SpriteSheet.png"]
## Corpo (folha original tingida), contorno (silhueta clara por fora) e brilho de cada tipo.
const BODY: Array[Color] = [Color(0.78, 0.66, 1.0, 0.78), Color(0.72, 0.62, 0.98, 0.86)]
const RIM: Array[Color] = [Color(0.86, 0.72, 1.0, 0.75), Color(1.0, 0.86, 0.62, 0.7)]
const GLOW := Color(0.62, 0.42, 1.0, 0.45)
const SOUL := Color(0.72, 0.55, 1.0)
const SOUL_HOT := Color(0.94, 0.9, 1.0)
## Necro Rite (golpe da lanterna): a procissão entra por uma borda da tela e sai pela outra.
const RITE_MARGIN := 40.0
const RITE_FORCE := 140.0
## Arrays por servo (m_src, de StringName, vai à parte).
const _ARRAYS: Array[StringName] = [&"m_pos", &"m_prev", &"m_life", &"m_max", &"m_atk", &"m_retarget",
		&"m_target", &"m_kind", &"m_speed", &"m_damage", &"m_face", &"m_born", &"m_cut"]

var game: HyakkiGame
## Servos levantados na partida (o RunTracker também conta) e caídos à espera do Yomigaeri.
var raised_total: int = 0
var fallen: int = 0

var m_pos := PackedVector2Array()
var m_prev := PackedVector2Array()
var m_life := PackedFloat32Array()
var m_max := PackedFloat32Array()
var m_atk := PackedFloat32Array()
var m_retarget := PackedFloat32Array()
var m_target := PackedInt32Array()
var m_kind := PackedInt32Array()
var m_speed := PackedFloat32Array()
var m_damage := PackedFloat32Array()
var m_face := PackedFloat32Array()
var m_src: Array[StringName] = []
## Só desenho: quando nasceu e o último golpe (tempo de jogo).
var m_born := PackedFloat32Array()
var m_cut := PackedFloat32Array()

## Procissão do Necro Rite (no save e no hash): tempo que falta, quanto andou, de que lado entrou
## (1 = da esquerda), quantos levantou e o teto, dano, largura, velocidade e quem já levou (uid).
var rite_time: float = 0.0
var rite_front: float = 0.0
var rite_dir: float = 1.0
var rite_raised: int = 0
var rite_raise_max: int = 0
var rite_damage: float = 0.0
var rite_width: float = 70.0
var rite_speed: float = 180.0
var rite_count: int = 30
var rite_hits: Dictionary = {}

var _sheets: Array[SpriteSheet] = []
var _near: Array[int] = []


func _init(p_game: HyakkiGame) -> void:
	game = p_game


func reset() -> void:
	clear()
	raised_total = 0
	fallen = 0


## Todos os servos e a procissão somem (troca de reino, começo de partida), sem recompensa.
func clear() -> void:
	for arr: StringName in _ARRAYS:
		var list: Variant = get(arr)
		list.clear()
		set(arr, list)
	m_src.clear()
	_end_rite()



func count() -> int:
	return m_pos.size()


## Teto de servos agora: o maior "minion_cap" das armas da guardiã (no mínimo BASE_CAP) + o atributo
## "minions", até HARD_CAP.
func cap() -> int:
	var best := BASE_CAP
	for weapon: Weapon in game.weapons:
		best = maxi(best, int(weapon.raw("minion_cap")))
	return clampi(best + int(game.player.stats.get_stat("minions")), 0, HARD_CAP)


## Multiplicador de dano e de alcance dos servos (atributo "minion_power", 1 = base).
func power() -> float:
	return game.player.stats.get_stat("minion_power")


## Tipo que as armas da guardiã levantam agora (SAMURAI com Hyakki-shō ou o Exército de Yomi).
func default_kind() -> int:
	for weapon: Weapon in game.weapons:
		if String(weapon.flags.get("minion_kind", "")) == "samurai":
			return Kind.SAMURAI
	return Kind.SPIRIT


## Dano base de um servo levantado por habilidade: o maior "minion_damage" das armas, ou o padrão.
func default_damage() -> float:
	var best := 0.0
	for weapon: Weapon in game.weapons:
		best = maxf(best, weapon.raw("minion_damage"))
	return best if best > 0.0 else DEFAULT_DAMAGE


## Levanta um servo em `at` com dano base `damage` (antes de Poder e minion_power), `life` s de vida
## (× atributo "duration"), `speed` px/s (0 = o padrão do tipo), creditado a `src` (registro de dano,
## cor e som do golpe). `over_cap`: o Yomigaeri passa do teto (nunca de HARD_CAP). Devolve se nasceu.
func raise(at: Vector2, src: StringName, damage: float, life: float, kind: int = Kind.SPIRIT,
		speed: float = 0.0, over_cap: bool = false) -> bool:
	if m_pos.size() >= (HARD_CAP if over_cap else cap()):
		return false
	var seconds := maxf(0.5, life * game.player.stats.get_stat("duration"))
	m_pos.append(at)
	m_prev.append(at)
	m_life.append(seconds)
	m_max.append(seconds)
	m_atk.append(ATTACK_EVERY[kind] * (0.3 + 0.7 * fmod(m_pos.size() * 0.618, 1.0)))
	m_retarget.append(0.0)
	m_target.append(-1)
	m_kind.append(kind)
	m_speed.append(speed if speed > 0.0 else DEFAULT_SPEED[kind])
	m_damage.append(damage)
	m_face.append(game.player.facing_x if game.player.facing_x != 0.0 else 1.0)
	m_src.append(src)
	m_born.append(GameClock.game_time)
	m_cut.append(-10.0)
	raised_total += 1
	if game.tracker != null:
		game.tracker.minions_raised += 1
	_raise_fx(at, kind)
	return true


## Todos os servos viram `kind` e passam a lutar por `src` (a evolução Hyakki-shō transforma os
## fantasmas da Shiryō-fuda em samurais dela).
func promote_all(kind: int, src: StringName) -> void:
	for k: int in range(m_kind.size()):
		m_src[k] = src
		if m_kind[k] != kind:
			m_kind[k] = kind
			m_speed[k] = maxf(m_speed[k], DEFAULT_SPEED[kind])
			_raise_fx(m_pos[k], kind)


## Servos a até `r` de `center` voltam a ter pelo menos `seconds` de vida (< 0: a vida cheia com que
## nasceram; o Barqueiro). Devolve quantos.
func refresh(center: Vector2, r: float, seconds: float = -1.0) -> int:
	var n := 0
	for k: int in range(m_pos.size()):
		var want := m_max[k] if seconds < 0.0 else seconds
		if (is_inf(r) or m_pos[k].distance_squared_to(center) <= r * r) and m_life[k] < want:
			m_life[k] = want
			m_max[k] = maxf(m_max[k], want)
			n += 1
	return n


## Chama de volta os caídos (Yomigaeri): até `most` servos em volta de `center`, no mínimo `least`
## mesmo sem caídos. Os vivos renovam a vida. Devolve quantos voltaram.
func recall(center: Vector2, src: StringName, most: int, least: int, life: float) -> int:
	var wanted := clampi(maxi(fallen, least), 0, most)
	var kind := default_kind()
	var damage := default_damage()
	var made := 0
	for n: int in range(wanted):
		var at := center + Vector2.from_angle(TAU * n / float(maxi(1, wanted))) * (SPAWN_RING + 10.0)
		if not raise(at, src, damage, life, kind, 0.0, true):
			break
		made += 1
	fallen = maxi(0, fallen - made)
	refresh(center, INF, life * game.player.stats.get_stat("duration"))
	return made


# --- Passo ----------------------------------------------------------------------------------

func step(dt: float) -> void:
	if rite_time > 0.0:
		_step_rite(dt)
	if m_pos.is_empty():
		return
	m_prev = m_pos.duplicate()
	var enemies := game.enemies
	var me := game.player.sim_pos
	var pw := power()
	for k: int in range(m_pos.size() - 1, -1, -1):
		m_life[k] -= dt
		if m_life[k] <= 0.0:
			_fade(k)
			continue
		var p: Vector2 = m_pos[k]
		if p.distance_squared_to(me) > LEASH * LEASH:
			p = me + Vector2.from_angle(k * 2.39996) * SPAWN_RING
			m_prev[k] = p
		m_retarget[k] -= dt
		var t := m_target[k]
		if t < 0 or enemies.alive[t] == 0 or m_retarget[k] <= 0.0:
			m_retarget[k] = RETARGET
			t = enemies.nearest(p, CHASE_RANGE)
			m_target[k] = t
		m_atk[k] = maxf(0.0, m_atk[k] - dt)
		var kind := m_kind[k]
		var spd := m_speed[k]
		if t >= 0:
			var to := enemies.pos[t] - p
			var dist := maxf(to.length(), 0.001)
			var r := STRIKE_RADIUS[kind] * pw
			var reach := r * 0.5 + enemies.radius[t]
			if dist > reach:
				p += to / dist * minf(spd * dt, dist - reach)
			if absf(to.x) > 0.5:
				m_face[k] = signf(to.x)
			if m_atk[k] <= 0.0 and dist <= r + enemies.radius[t]:
				m_atk[k] = ATTACK_EVERY[kind]
				m_pos[k] = p
				_strike(k, to / dist, r)
		else:
			var slot := me + Vector2.from_angle(k * 2.39996 + GameClock.game_time * 0.6) * FOLLOW_GAP
			var go := slot - p
			var gap := go.length()
			if gap > 1.0:
				p += go / gap * minf(spd * dt, gap)
				if absf(go.x) > 0.5:
					m_face[k] = signf(go.x)
		m_pos[k] = p


## Golpe do servo `k` na direção `dir`: tudo a até `r` do ponto à frente dele leva o dano.
func _strike(k: int, dir: Vector2, r: float) -> void:
	var kind := m_kind[k]
	var at := m_pos[k] + dir * r * 0.5
	var dmg := m_damage[k] * power() * game.player.stats.get_stat("might") * game.damage_bonus()
	game.enemies.query_circle(at, r, _near)
	for j: int in _near.duplicate():
		if game.enemies.alive[j] == 1 and not game.enemies.is_prop(j):
			game.deal_damage(m_src[k], j, dmg, dir, STRIKE_FORCE[kind])
	m_cut[k] = GameClock.game_time
	var fx := game.fx
	if fx != null and game.enemies.view_rect.has_point(at):
		if kind == Kind.SAMURAI:
			fx.play_anim("slash", at, clampf(r / 16.0, 0.8, 1.6), dir.angle(), Color(0.86, 0.74, 1.0, 0.95), 26.0,
					false, FxLayer.glow)
		elif FxLayer.wfx > 0:
			fx.motes(at, SOUL, FxLayer.wfx, 3.0, 16.0)
	WeaponSfx.play("minion_hit")


func _remove(k: int) -> void:
	for arr: StringName in _ARRAYS:
		var list: Variant = get(arr)
		list.remove_at(k)
		set(arr, list)
	m_src.remove_at(k)


## Fim da vida do servo `k`: some em névoa e vira um "caído" (Yomigaeri).
func _fade(k: int) -> void:
	var at := m_pos[k]
	_remove(k)
	fallen = mini(FALLEN_MAX, fallen + 1)
	var fx := game.fx
	if fx != null and game.enemies.view_rect.has_point(at):
		fx.play_anim("smoke", at - Vector2(0, 5), 0.6, 0.0, Color(0.8, 0.7, 1.0, 0.7), 18.0)
		if FxLayer.wfx > 0:
			fx.motes(at, SOUL, 2 * FxLayer.wfx, 4.0, 22.0)
	WeaponSfx.play("minion_fade")


func _raise_fx(at: Vector2, kind: int) -> void:
	var fx := game.fx
	if fx == null:
		return
	if game.enemies.view_rect.has_point(at):
		fx.play_anim("spirit", at - Vector2(0, 4), 0.55 if kind == Kind.SPIRIT else 0.7, 0.0, Color(SOUL, 0.9),
				18.0, false, true)
		if FxLayer.wfx > 0:
			fx.motes(at, SOUL_HOT, 2 + FxLayer.wfx, 5.0, 26.0)
	WeaponSfx.play("minion_raise")


# --- Necro Rite (golpe da lanterna da Kuon) --------------------------------------------------

## A procissão dos mortos ao contrário: `count` figuras espectrais numa coluna da altura da tela
## entram por um lado (o oposto ao que a Kuon olha) e atravessam até o outro a `speed` px/s, por até
## `duration` s: cada yōkai tocado pela frente (largura `width`) leva `damage` uma vez e é empurrado;
## os que morrem viram servos, até `raise` deles.
func start_rite(ult: Dictionary, damage: float) -> void:
	rite_dir = -signf(game.player.facing_x) if game.player.facing_x != 0.0 else 1.0
	rite_time = float(ult.get("duration", 5.0))
	rite_front = 0.0
	rite_raised = 0
	rite_raise_max = int(ult.get("raise", 12))
	rite_damage = damage
	rite_width = float(ult.get("width", 70.0))
	rite_speed = float(ult.get("speed", 180.0))
	rite_count = int(ult.get("count", 30))
	rite_hits.clear()


func rite_active() -> bool:
	return rite_time > 0.0


## Meia largura da tela + a folga: a coluna nasce fora da tela e acaba fora dela.
func _rite_half() -> Vector2:
	return game.view_size() * 0.5 + Vector2(RITE_MARGIN, RITE_MARGIN)


## X da frente da procissão relativo à Kuon (a coluna segue a câmera).
func rite_x() -> float:
	var half := _rite_half()
	return rite_dir * (-half.x + rite_front)


func _step_rite(dt: float) -> void:
	rite_time -= dt
	rite_front += rite_speed * dt
	var half := _rite_half()
	if rite_time <= 0.0 or rite_front >= half.x * 2.0:
		_end_rite()
		return
	var enemies := game.enemies
	var me := game.player.sim_pos
	var x := me.x + rite_x()
	var dir := Vector2(rite_dir, 0.0)
	var kind := default_kind()
	for i: int in range(EnemyManager.CAPACITY):
		if enemies.alive[i] == 0 or enemies.is_prop(i):
			continue
		var p := enemies.pos[i]
		if absf(p.x - x) > rite_width * 0.5 or absf(p.y - me.y) > half.y:
			continue
		var key := enemies.uid[i]
		if rite_hits.has(key):
			continue
		rite_hits[key] = true
		game.deal_damage(&"ultimate", i, rite_damage, dir, RITE_FORCE)
		if enemies.alive[i] == 0 and rite_raised < rite_raise_max:
			if raise(p, &"ultimate", default_damage(), DEFAULT_LIFE * 1.5, kind):
				rite_raised += 1


func _end_rite() -> void:
	rite_time = 0.0
	rite_front = 0.0
	rite_hits.clear()


# --- Save e hash -------------------------------------------------------------------------------

func state() -> Dictionary:
	var rows: Array = []
	for k: int in range(m_pos.size()):
		rows.append([m_pos[k].x, m_pos[k].y, m_life[k], m_max[k], m_atk[k], m_kind[k], m_speed[k],
				m_damage[k], m_face[k], String(m_src[k])])
	var hits: Array = rite_hits.keys()
	return {"raised": raised_total, "fallen": fallen, "minions": rows,
			"rite": [rite_time, rite_front, rite_dir, rite_raised, rite_raise_max, rite_damage, rite_width,
					rite_speed, rite_count, hits]}


func load_state(s: Dictionary) -> void:
	clear()
	raised_total = int(s.get("raised", 0))
	fallen = int(s.get("fallen", 0))
	for row: Variant in s.get("minions", []):
		var r: Array = row
		if r.size() < 10:
			continue
		var at := Vector2(float(r[0]), float(r[1]))
		m_pos.append(at)
		m_prev.append(at)
		m_life.append(float(r[2]))
		m_max.append(float(r[3]))
		m_atk.append(float(r[4]))
		m_retarget.append(0.0)
		m_target.append(-1)
		m_kind.append(clampi(int(r[5]), Kind.SPIRIT, Kind.SAMURAI))
		m_speed.append(float(r[6]))
		m_damage.append(float(r[7]))
		m_face.append(float(r[8]))
		m_src.append(StringName(String(r[9])))
		m_born.append(GameClock.game_time - 1.0)
		m_cut.append(-10.0)
	var rite: Array = s.get("rite", [])
	if rite.size() >= 10 and float(rite[0]) > 0.0:
		rite_time = float(rite[0])
		rite_front = float(rite[1])
		rite_dir = float(rite[2])
		rite_raised = int(rite[3])
		rite_raise_max = int(rite[4])
		rite_damage = float(rite[5])
		rite_width = float(rite[6])
		rite_speed = float(rite[7])
		rite_count = int(rite[8])
		for key: Variant in rite[9]:
			rite_hits[int(key)] = true


## Parte do hash de determinismo: "" enquanto nenhum servo nasceu (o hash das outras guardiãs não muda).
func hash_tag() -> String:
	if raised_total == 0 and rite_time <= 0.0:
		return ""
	var sum := Vector2.ZERO
	var life := 0.0
	for k: int in range(m_pos.size()):
		sum += m_pos[k]
		life += m_life[k]
	return " servos=%d,%d,%d,%.3f,%.3f,%.3f,%.3f,%.3f" % [m_pos.size(), raised_total, fallen, sum.x, sum.y, life,
			rite_time, rite_front]


# --- Desenho (só leitura) ----------------------------------------------------------------------

func _sheet(kind: int) -> SpriteSheet:
	if _sheets.is_empty():
		for path: String in SHEETS:
			_sheets.append(SpriteSheet.load_sheet(path))
	return _sheets[kind]


## Servos e a procissão: sombras, depois o contorno claro (silhueta deslocada 1 px), os corpos
## tingidos e, por cima, o fio da alma; em passadas por tipo e textura (poucos lotes para 24 servos).
## Entram e saem esmaecendo; flutuam (fantasma) ou marcham (samurai).
func draw(canvas: CanvasItem) -> void:
	if not m_pos.is_empty():
		_draw_minions(canvas)
	if rite_time > 0.0:
		_draw_rite(canvas)


func _draw_minions(canvas: CanvasItem) -> void:
	var a := GameClock.alpha
	var time := GameClock.game_time
	var spots := PackedVector2Array()
	var fades := PackedFloat32Array()
	var frames := PackedInt32Array()
	var dirs := PackedInt32Array()
	for k: int in range(m_pos.size()):
		var at := m_prev[k].lerp(m_pos[k], a)
		var fade := clampf((time - m_born[k]) / 0.25, 0.0, 1.0) * clampf(m_life[k] / 0.6, 0.0, 1.0)
		if m_kind[k] == Kind.SPIRIT:
			at.y += roundf(sin(time * 3.0 + k * 1.3) * 1.5) - 2.0
		if time - m_cut[k] < 0.12:
			at.x += m_face[k] * 2.0
		var moving := m_prev[k].distance_squared_to(m_pos[k]) > 0.01
		spots.append(at.round())
		fades.append(fade)
		frames.append(int(time * (8.0 if moving else 4.0) + k))
		dirs.append(SpriteSheet.Dir.LEFT if m_face[k] < 0.0 else SpriteSheet.Dir.RIGHT)
	for n: int in range(spots.size()):
		canvas.draw_rect(Rect2(spots[n] + Vector2(-4, 6 if m_kind[n] == Kind.SPIRIT else 5), Vector2(8, 2)),
				Color(0.05, 0.0, 0.1, 0.35 * fades[n]))
	for kind: int in [Kind.SPIRIT, Kind.SAMURAI]:
		var sheet := _sheet(kind)
		var half := sheet.frame_size * 0.5
		for n: int in range(spots.size()):
			if m_kind[n] != kind:
				continue
			var src := sheet.region(frames[n], dirs[n])
			var rim := Color(RIM[kind], RIM[kind].a * fades[n])
			for off: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				canvas.draw_texture_rect_region(sheet.flash_texture, Rect2(spots[n] - half + off, sheet.frame_size), src, rim)
		for n: int in range(spots.size()):
			if m_kind[n] != kind:
				continue
			var src := sheet.region(frames[n], dirs[n])
			canvas.draw_texture_rect_region(sheet.texture, Rect2(spots[n] - half, sheet.frame_size), src,
					Color(BODY[kind], BODY[kind].a * fades[n]))
	# Fio da alma: um ponto claro que pulsa no peito de cada servo.
	for n: int in range(spots.size()):
		var pulse := 0.6 + 0.4 * sin(time * 5.0 + n)
		canvas.draw_rect(Rect2(spots[n] + Vector2(0, -1), Vector2(1, 1)), Color(SOUL_HOT, 0.9 * pulse * fades[n]))


## A coluna da procissão: figuras espectrais em fila na altura da tela, alternando fantasma e
## samurai, com a faixa violeta que fere e lanternas de alma (o brilho vai em draw_glow).
func _draw_rite(canvas: CanvasItem) -> void:
	var me := game.player.position
	var half := _rite_half()
	var x := me.x + rite_x()
	var time := GameClock.game_time
	var fade := clampf(rite_time / 0.4, 0.0, 1.0) * clampf(rite_front / 60.0, 0.0, 1.0)
	canvas.draw_rect(Rect2(Vector2(x - rite_width * 0.5, me.y - half.y), Vector2(rite_width, half.y * 2.0)),
			Color(0.45, 0.25, 0.85, 0.12 * fade))
	var n := maxi(1, rite_count)
	var dir := SpriteSheet.Dir.RIGHT if rite_dir > 0.0 else SpriteSheet.Dir.LEFT
	for kind: int in [Kind.SPIRIT, Kind.SAMURAI]:
		var sheet := _sheet(kind)
		var fh := sheet.frame_size * 0.5
		for i: int in range(n):
			if i % 2 != kind:
				continue
			var y := me.y - half.y + (i + 0.5) * half.y * 2.0 / n
			var at := Vector2(x + sin(i * 1.7) * rite_width * 0.3, y + sin(time * 4.0 + i) * 1.5).round()
			var src := sheet.region(int(time * 8.0) + i, dir)
			canvas.draw_texture_rect_region(sheet.texture, Rect2(at - fh, sheet.frame_size), src,
					Color(BODY[kind], BODY[kind].a * fade))


func draw_glow(canvas: CanvasItem) -> void:
	if m_pos.is_empty() and rite_time <= 0.0:
		return
	var a := GameClock.alpha
	for k: int in range(m_pos.size()):
		FxLayer.draw_soft(canvas, m_prev[k].lerp(m_pos[k], a) - Vector2(0, 3), 9.0 if m_kind[k] == Kind.SPIRIT else 11.0,
				GLOW)
	if rite_time > 0.0:
		var me := game.player.position
		var half := _rite_half()
		var x := me.x + rite_x()
		var n := maxi(1, rite_count)
		var fade := clampf(rite_time / 0.4, 0.0, 1.0)
		for i: int in range(0, n, 3):
			var y := me.y - half.y + (i + 0.5) * half.y * 2.0 / n
			FxLayer.draw_soft(canvas, Vector2(x + rite_dir * 8.0, y - 6.0), 14.0, Color(0.75, 0.55, 1.0, 0.5 * fade))
