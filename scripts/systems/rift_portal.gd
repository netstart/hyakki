class_name RiftPortal
extends Node2D
## Guardião do Limiar e o Kakuriyo (隠世), o outro mundo de cada fase:
## - no meio da noite (data/stages.json "midboss", 7:30) um chefe intermediário guarda o limiar:
##   aviso 4 s antes (gongo, a horda recua, tela tinge), entrada com o painel do chefe e um
##   respiro curto do spawner (Spawner.hush) para a entrada não brigar com uma onda;
## - vencido, deixa DOIS baús de chefe num arco sobre o ponto da morte e um portal (um torii com
##   um vórtice de espíritos) num ponto livre logo abaixo; a HUD aponta o portal fora da tela;
## - a guardiã entra só andando até o portal e tocando nele. O portal fica parado onde caiu, sem
##   puxar nem forçar: depois de INVITE_AFTER s ele chama (o brilho e as almas se intensificam e um
##   aviso curto volta a cada INVITE_EVERY s). Se o amanhecer chegar antes, a vitória é no primeiro
##   mapa e o portal fecha. Inimigos não entram: o selo do portal os afasta;
## - a travessia (RealmCard na HUD): o relógio para, um redemoinho fecha a tela, o título do
##   reino aparece em kanji com o nome traduzido, o mundo é refeito com o bioma "<fase>_ura" e
##   uma semente nova, a guardiã nasce na origem (área segura), inimigos, tiros e áreas somem
##   (chefes ativos vêm junto, na borda da tela), brasas e itens do chão são coletados (baús vão
##   para a fila e abrem um depois do outro) e o relógio volta. Ondas, eventos, o chefe dos
##   10:00, o amanhecer e a Noite Sem Fim seguem no outro mundo.
##
## Simulação (passo fixo, determinística): step(), a abertura, o toque e a troca de mundo.
## A animação da travessia corre em tempo real com o relógio parado, então não muda a partida.
## Partida suspensa: snapshot()/restore() guardam o reino, o portal aberto e o chefe vencido.
##
## Arte (assets/art/fx/portal/): o vórtice abre com portal_open (8 quadros, uma vez) e segue em
## portal_loop (12 quadros), por trás do torii.png (o vórtice aparece entre os pilares); em escala
## inteira (1x, 2x no puxão). Por cima ficam as camadas desenhadas aqui: runas no chão, almas
## sugadas e o brilho que a lanterna lê como luz. Sem as texturas, vórtice e torii também são
## desenhados aqui. O zumbido (p_portal_hum, em loop) é posicional: AudioStreamPlayer2D no
## portal, some com a distância da câmera, pausa com o relógio e para ao fechar, atravessar,
## reiniciar e no fim da partida.

enum State { CLOSED, OPEN, CROSSING }

## Raio de toque do portal e folga do ponto livre onde ele nasce (o torii inteiro cabe).
const PORTAL_RADIUS := 14.0
const CLEARANCE := 22.0
## Abaixo do ponto da morte, para não cair sobre os baús (que ficam no arco de cima).
const PORTAL_OFFSET := Vector2(0.0, 46.0)
const CHEST_DIST := 30.0
const CHEST_SPREAD := 0.62
const CHEST_MIN_GAP := 14.0
## Aviso antes do chefe e respiro do spawner na entrada dele e na chegada ao outro mundo.
const WARN_LEAD := 4.0
const ENTRY_HUSH := 4.0
const ARRIVAL_HUSH := 3.0
const WARN_PUSH_RADIUS := 130.0
const WARN_PUSH_FORCE := 150.0
## Espera do aviso do portal para não cobrir o "chefe vencido".
const OPEN_TOAST_DELAY := 2.6
## Chamado do portal (só convite, nunca força): começa depois de INVITE_AFTER s aberto, cresce
## em BECKON_RAMP s e o aviso volta a cada INVITE_EVERY s.
const INVITE_AFTER := 20.0
const INVITE_EVERY := 40.0
const BECKON_RAMP := 25.0
## Selo: inimigos comuns não chegam a menos disto do centro do portal.
const WARD := 18.0
## Travessia em tempo real: o redemoinho fecha, o título fica, o redemoinho abre.
const CROSS_IN := 0.65
const CROSS_HOLD := 0.75
const CROSS_OUT := 0.6
## Tiras do vórtice (quadros de SPRITE_FRAME px lado a lado) e o torii; o último quadro da
## abertura emenda no primeiro do loop.
const SPRITE_OPEN := "res://assets/art/fx/portal/portal_open.png"
const SPRITE_LOOP := "res://assets/art/fx/portal/portal_loop.png"
const TORII_PATH := "res://assets/art/fx/portal/torii.png"
const SPRITE_FRAME := 32
const SPRITE_FPS := 12.0
## Centro do vórtice acima da base do torii (entre os pilares, abaixo da viga de baixo).
const VORTEX_LIFT := 19.0
## Zumbido em loop (p_portal_hum.wav) e o alcance em que ele some.
const HUM_PATH := "res://assets/audio/sfx/p_portal_hum.wav"
const HUM_DB := -6.0
const HUM_RANGE := 420.0
## Sons provisórios (AudioManager): trocar por zumbido do portal e teletransporte próprios.
const SFX_WARN := "midboss_intro"
const SFX_GONG := "j_gong"
const SFX_ROAR := "midboss_roar"
const SFX_OPEN := "portal_open"
const SFX_INVITE := "j_furin"
const SFX_ENTER := "teleport"
const SFX_ARRIVE := "j_temple_bell"
## Cores: vórtice, borda dele, torii laqueado e a seta da HUD.
const VOID := Color("2a0e4a")
const SWIRL := Color("b48cff")
const SWIRL_EDGE := Color("7ef0ff")
const TORII := Color("c0392b")
const ARROW_COLOR := Color("c7a4ff")
const LIGHT_COLOR := Color(0.72, 0.55, 1.0)

var game: HyakkiGame
var state: int = State.CLOSED
var portal_pos := Vector2.INF
## Segundos de simulação com o portal aberto.
var portal_age: float = 0.0
var portal_radius: float = PORTAL_RADIUS
var in_realm: bool = false
var midboss_done: bool = false
## A partida chegou ao outro mundo (resultados e estatísticas).
var reached: bool = false
var realm_seed: int = 0
## A fase como está em data/stages.json (game.stage vira a mistura com o "otherworld").
var base_stage: Dictionary = {}

var _toast_delay: float = -1.0
## Segundos de portal aberto em que o próximo aviso de convite aparece.
var _next_invite: float = INVITE_AFTER
## Tempo real desde o começo da travessia (-1 = sem travessia) e se o mundo já trocou.
var _cross_t: float = -1.0
var _swapped: bool = false
var _open_tex: Texture2D
var _loop_tex: Texture2D
var _torii_tex: Texture2D
var _glow: Node2D
var _hum: AudioStreamPlayer2D
var _near: Array[int] = []


func _ready() -> void:
	_open_tex = _texture(SPRITE_OPEN)
	_loop_tex = _texture(SPRITE_LOOP)
	_torii_tex = _texture(TORII_PATH)
	_hum = AudioStreamPlayer2D.new()
	_hum.bus = "SFX"
	_hum.volume_db = HUM_DB
	_hum.max_distance = HUM_RANGE
	_hum.attenuation = 1.6
	if ResourceLoader.exists(HUM_PATH):
		_hum.stream = load(HUM_PATH) as AudioStream
	add_child(_hum)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow = Node2D.new()
	_glow.material = additive
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


static func _texture(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Texturas do portal carregadas (testes: a arte importada está em uso, não o desenho reserva).
func has_art() -> bool:
	return _open_tex != null and _loop_tex != null and _torii_tex != null


## O zumbido do portal está tocando (testes).
func hum_playing() -> bool:
	return _hum != null and _hum.playing


func _exit_tree() -> void:
	_stop_hum()


func _start_hum() -> void:
	if _hum == null or _hum.stream == null:
		return
	_hum.position = portal_pos
	_hum.play()


func _stop_hum() -> void:
	if _hum != null:
		_hum.stop()


func reset() -> void:
	_stop_hum()
	state = State.CLOSED
	portal_pos = Vector2.INF
	portal_age = 0.0
	portal_radius = PORTAL_RADIUS
	in_realm = false
	midboss_done = false
	reached = false
	realm_seed = 0
	base_stage = game.stage if game != null else {}
	_toast_delay = -1.0
	_cross_t = -1.0
	_swapped = false
	if game != null and game.hud != null and game.hud.realm_card_exists():
		game.hud.realm_card().close()


func is_open() -> bool:
	return state == State.OPEN


func crossing() -> bool:
	return state == State.CROSSING


## {"t", "id"} do chefe intermediário da fase (vazio se a fase não tiver).
static func midboss_of(stage_data: Dictionary) -> Dictionary:
	return stage_data.get("midboss", {})


static func is_midboss(id: StringName) -> bool:
	return bool((DB.bosses.get(id, {}) as Dictionary).get("midboss", false))


## A fase misturada com o "otherworld" dela: bioma, tinta, luz, música, clima, limites e perigo.
static func realm_stage(stage_data: Dictionary) -> Dictionary:
	var realm := stage_data.duplicate()
	var ow: Dictionary = stage_data.get("otherworld", {})
	for key: String in ow:
		if key != "kanji":
			realm[key] = ow[key]
	realm["realm"] = true
	return realm


# --- Chefe intermediário --------------------------------------------------------------

## Aviso WARN_LEAD s antes: gongo, a horda recua e a tela tinge (o ar prende a respiração).
func warn_midboss() -> void:
	game.hud.toast(tr("midboss.warning"), WARN_LEAD)
	game.hud.flash_screen(Color(0.55, 0.25, 0.9))
	game.enemies.push_from(game.player.sim_pos, WARN_PUSH_RADIUS, WARN_PUSH_FORCE)
	game.fx.add_ring(game.player.sim_pos, WARN_PUSH_RADIUS, SWIRL)
	game.shake(2.0)
	AudioManager.play(SFX_WARN, 1.0, 0.0, -2.0)
	AudioManager.play(SFX_GONG, 0.8, 0.0, -6.0)


func spawn_midboss(id: StringName) -> void:
	game.spawner.hush(ENTRY_HUSH)
	game.bosses.spawn(id)
	game.hud.toast(tr("midboss.title"), 3.0)
	AudioManager.play(SFX_ROAR, 1.0, 0.05, -2.0)


## Morte do Guardião: dois baús num arco sobre o ponto da morte e o portal logo abaixo.
func on_midboss_defeated(at: Vector2) -> void:
	midboss_done = true
	var placed: Array[Vector2] = []
	for k: int in 2:
		var angle := -PI * 0.5 + (-1.0 if k == 0 else 1.0) * CHEST_SPREAD
		placed.append(_drop_chest(at, angle, placed))
	# O portal desce até não encostar nos baús (num canto apertado o ponto livre sobe).
	var spot := at + PORTAL_OFFSET
	for _try: int in 8:
		var free := game.world.free_point(spot, CLEARANCE)
		if placed.all(func(p: Vector2) -> bool: return free.distance_to(p) >= CLEARANCE + 6.0):
			break
		spot += PORTAL_OFFSET * 0.5
	open_portal(spot)


## Baú de chefe num ponto livre do arco; se cair em cima do outro (os dois empurrados para o
## mesmo canto de uma casa), gira o ângulo até separar.
func _drop_chest(at: Vector2, angle: float, placed: Array[Vector2]) -> Vector2:
	var pickups := game.pickups
	for step: int in 12:
		pickups.spawn_item(&"chest", at + Vector2.from_angle(angle + step * 0.5) * CHEST_DIST, {"boss": true})
		var pos: Vector2 = pickups.items.back()["pos"]
		var clear := true
		for p: Vector2 in placed:
			clear = clear and pos.distance_to(p) >= CHEST_MIN_GAP
		if clear or step == 11:
			return pos
		pickups.items.pop_back()
	return at


func open_portal(at: Vector2) -> void:
	portal_pos = game.world.free_point(at, CLEARANCE)
	state = State.OPEN
	portal_age = 0.0
	portal_radius = PORTAL_RADIUS
	_next_invite = INVITE_AFTER
	_toast_delay = OPEN_TOAST_DELAY
	game.fx.add_ring(portal_pos, 70.0, SWIRL)
	game.fx.add_ring(portal_pos, 40.0, SWIRL_EDGE)
	AudioManager.play(SFX_OPEN, 1.0, 0.0, -2.0)
	_start_hum()


func close_portal() -> void:
	_stop_hum()
	if is_open():
		state = State.CLOSED
		portal_pos = Vector2.INF


# --- Simulação --------------------------------------------------------------------------

func step(dt: float) -> void:
	if _toast_delay > 0.0:
		_toast_delay -= dt
		if _toast_delay <= 0.0 and is_open():
			game.hud.toast(tr("portal.opened"), 4.0)
	if not is_open():
		return
	portal_age += dt
	_ward()
	# Convite: o aviso volta de tempos em tempos enquanto ela não entra (nada se move).
	if portal_age >= _next_invite:
		_next_invite += INVITE_EVERY
		game.hud.toast(tr("portal.invite"), 3.0)
		AudioManager.play(SFX_INVITE, 0.9, 0.0, -6.0)
	var player := game.player
	if player.is_alive and player.sim_pos.distance_to(portal_pos) <= portal_radius + Player.RADIUS:
		begin_crossing()


## 0 → 1: o quanto o portal está chamando (brilho, almas e runas mais vivos), sem mexer nele.
func beckon() -> float:
	return clampf((portal_age - INVITE_AFTER) / BECKON_RAMP, 0.0, 1.0)


## Inimigos comuns não pisam no portal: quem entra no selo volta para a borda dele.
func _ward() -> void:
	var enemies := game.enemies
	var reach := portal_radius + WARD
	enemies.query_circle(portal_pos, reach, _near)
	for i: int in _near:
		if enemies.alive[i] == 0 or enemies.is_boss(i) or enemies.is_prop(i):
			continue
		var d := enemies.pos[i] - portal_pos
		var dist := d.length()
		if dist < reach:
			enemies.pos[i] = portal_pos + (d / dist if dist > 0.001 else Vector2.RIGHT) * reach


# --- Travessia --------------------------------------------------------------------------

func begin_crossing() -> void:
	if state == State.CROSSING:
		return
	state = State.CROSSING
	_stop_hum()
	GameClock.paused = true
	game.player.move_input = Vector2.ZERO
	game.hud.joystick.release()
	AudioManager.play(SFX_ENTER, 0.7, 0.0, -2.0)
	AudioManager.duck(8.0, CROSS_IN + CROSS_HOLD)
	Settings.vibrate(60)
	_cross_t = 0.0
	_swapped = false
	var stage_id := String(base_stage.get("id", "village"))
	var ow: Dictionary = base_stage.get("otherworld", {})
	var at := get_canvas_transform() * portal_pos if is_inside_tree() else game.view_size() * 0.5
	game.hud.realm_card().begin(String(ow.get("kanji", "隠世")), tr("realm.%s.name" % stage_id), tr("realm.caption"), at)
	if game.is_bot():
		finish_crossing_now()


## Testes e bot: completa a travessia na hora (troca o mundo e devolve o relógio).
func finish_crossing_now() -> void:
	if state != State.CROSSING:
		return
	if not _swapped:
		_swap_realm()
	_end_crossing()


func _process(delta: float) -> void:
	queue_redraw()
	_glow.queue_redraw()
	if _hum.playing:
		# Segue o portal que flutua no puxão; cala junto com o relógio (pausa, morte, travessia).
		_hum.position = portal_pos
		_hum.stream_paused = GameClock.paused
	if _cross_t < 0.0:
		return
	_cross_t += delta
	game.hud.realm_card().set_time(_cross_t)
	if not _swapped and _cross_t >= CROSS_IN:
		_swap_realm()
	if _cross_t >= CROSS_IN + CROSS_HOLD + CROSS_OUT:
		_end_crossing()


## O mundo do outro lado: coleta o chão, limpa o campo e refaz o mapa com o bioma do reino.
func _swap_realm() -> void:
	_swapped = true
	var shrine_offset := game.kami.shrine_pos - game.player.sim_pos if game.kami.has_shrine() else Vector2.INF
	clear_field()
	game.pickups.collect_all()
	enter_realm()
	game.bosses.relocate_all()
	if shrine_offset != Vector2.INF:
		game.kami.shrine_pos = game.world.free_point(game.world.clamp_to_bounds(shrine_offset), 20.0).round()
	AudioManager.play(SFX_ARRIVE, 0.9, 0.0, -2.0)


func _end_crossing() -> void:
	_cross_t = -1.0
	state = State.CLOSED
	portal_pos = Vector2.INF
	game.hud.realm_card().close()
	game.spawner.hush(ARRIVAL_HUSH)
	game.hud.toast(tr("realm.entered"), 3.5)
	game._resume_if_clear(false)


## Inimigos (menos os chefes em campo), lanternas, tiros, áreas e efeitos somem, sem recompensa.
func clear_field() -> void:
	var enemies := game.enemies
	var keep: Array[int] = []
	for boss: Dictionary in game.bosses.bosses:
		keep.append(int(boss["index"]))
	for i: int in range(EnemyManager.CAPACITY):
		if enemies.alive[i] == 1 and not keep.has(i):
			enemies.despawn(i)
	for key: StringName in enemies.get_meta_list():
		if String(key).begins_with("lantern_"):
			enemies.remove_meta(key)
	game.enemy_shots.clear_all()
	game.projectiles.reset()
	game.areas.reset()
	game.fx.reset()


## Refaz o mundo com o bioma do reino e uma semente própria; a guardiã nasce na origem.
func enter_realm() -> void:
	if base_stage.is_empty():
		base_stage = game.stage
	if realm_seed == 0:
		realm_seed = absi(hash([game.world.seed_value, "kakuriyo"])) | 1
	game.stage = realm_stage(base_stage)
	var player := game.player
	player.sim_pos = Vector2.ZERO
	player.prev_pos = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.position = Vector2.ZERO
	game.world.setup(game.stage, realm_seed)
	in_realm = true
	reached = true
	game.tracker.realm_reached = true
	if game.bosses.active_count() == 0:
		AudioManager.play_music("endless" if game.endless_phase else String(game.stage.get("music", "stage_village")))


# --- Partida suspensa e cenários de teste -----------------------------------------------

func snapshot() -> Dictionary:
	return {"in_realm": in_realm or state == State.CROSSING, "midboss_done": midboss_done, "seed": realm_seed,
			"portal": [portal_pos.x, portal_pos.y] if is_open() else [], "age": portal_age}


## Depois do start_run e do Spawner.skip_until: volta ao reino (sem a travessia), reabre o
## portal ou chama de novo o Guardião que estava em campo (inimigos não entram no snapshot).
func restore(s: Dictionary) -> void:
	midboss_done = bool(s.get("midboss_done", false))
	realm_seed = int(s.get("seed", 0))
	var portal: Array = s.get("portal", [])
	var mid := midboss_of(base_stage)
	if bool(s.get("in_realm", false)):
		midboss_done = true
		clear_field()
		enter_realm()
	elif portal.size() == 2:
		midboss_done = true
		portal_pos = Vector2(float(portal[0]), float(portal[1]))
		portal_age = float(s.get("age", 0.0))
		_next_invite = INVITE_AFTER if portal_age < INVITE_AFTER else portal_age + INVITE_EVERY
		state = State.OPEN
		_start_hum()
	elif not midboss_done and not mid.is_empty() and GameClock.game_time > float(mid["t"]):
		spawn_midboss(StringName(mid["id"]))


## Cenários de depuração (HyakkiGame.apply_scenario): "midboss" (pouco antes do aviso),
## "portal" (Guardião vencido: baús e portal ao lado) e "realm" (portal sob a guardiã: a
## travessia começa no próximo passo).
func scenario(scenario_name: String) -> void:
	var mid := midboss_of(base_stage)
	if mid.is_empty():
		return
	var t := float(mid["t"])
	GameClock.game_time = t - WARN_LEAD - 1.0 if scenario_name == "midboss" else t + 15.0
	game.spawner.skip_until(GameClock.game_time)
	if scenario_name == "portal":
		on_midboss_defeated(game.player.sim_pos + Vector2(84.0, -10.0))
	elif scenario_name == "realm":
		midboss_done = true
		open_portal(game.player.sim_pos)


## Luz do portal para a lanterna (o vórtice brilha na escuridão): [posição, cor, raio, força].
func collect_lights(center: Vector2, half: Vector2) -> Array:
	if not is_open():
		return []
	var r := 70.0 + portal_radius * 1.5
	if not Rect2(center - half, half * 2.0).grow(r).has_point(portal_pos):
		return []
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.004)
	return [[portal_pos + Vector2(0.0, -VORTEX_LIFT), LIGHT_COLOR, r, pulse]]


# --- Desenho ------------------------------------------------------------------------------

func _draw() -> void:
	if not is_open():
		return
	var t := Time.get_ticks_msec() / 1000.0
	var calm := bool(Settings.get_value("reduce_flashes"))
	var grow := portal_radius / PORTAL_RADIUS
	var base := portal_pos.round()
	var scale := art_scale()
	var core := base + Vector2(0.0, -VORTEX_LIFT * scale)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Sombra e runas no chão: anel tracejado achatado que gira, e o anel do selo.
	_ellipse(base, Vector2(24.0, 8.0) * grow, Color(0, 0, 0, 0.35), true)
	var spin := t * (0.6 if calm else 1.2) * (1.0 + 1.5 * beckon())
	for k: int in 12:
		var a0 := spin + TAU * k / 12.0
		var p0 := base + Vector2(cos(a0) * 26.0, sin(a0) * 9.0) * grow
		var p1 := base + Vector2(cos(a0 + 0.3) * 26.0, sin(a0 + 0.3) * 9.0) * grow
		draw_line(p0, p1, Color(SWIRL, 0.75), 1.0)
	_ellipse(base, Vector2(30.0, 11.0) * grow, Color(SWIRL_EDGE, 0.35), false)
	if _loop_tex != null:
		_draw_sprite(core, scale)
	else:
		_draw_vortex(core, grow, t, calm)
	if _torii_tex != null:
		var size := _torii_tex.get_size() * scale
		draw_texture_rect(_torii_tex, Rect2((base - Vector2(size.x * 0.5, size.y)).round(), size), false)
	else:
		_draw_torii(base, grow)
	_draw_motes(core, grow, t)


## Escala inteira da arte (pixel perfeito, 1x como os atores): o portal nunca muda de tamanho.
func art_scale() -> float:
	return 1.0


## Vórtice desenhado (sem a arte): miolo escuro, braços em espiral e o aro claro (gira mais
## rápido quando o portal chama).
func _draw_vortex(core: Vector2, grow: float, t: float, calm: bool) -> void:
	var r := Vector2(10.0, 14.0) * grow
	_ellipse(core, r, Color(VOID, 0.92), true)
	var speed := (1.6 if calm else 3.2) * (1.0 + beckon())
	for arm: int in 4:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for s: int in 14:
			var k := float(s) / 13.0
			var a := t * speed + arm * TAU / 4.0 + k * 4.2
			pts.append(core + Vector2(cos(a) * r.x, sin(a) * r.y) * (1.0 - k * 0.92))
			cols.append(Color(SWIRL.lerp(SWIRL_EDGE, k), 0.25 + 0.75 * k))
		draw_polyline_colors(pts, cols, 1.0)
	var pulse := 0.5 + 0.5 * sin(t * (3.0 if calm else 6.0))
	_ellipse(core, r, Color(SWIRL_EDGE, 0.55 + 0.4 * pulse), false)
	_ellipse(core, r + Vector2(2.0, 2.0), Color(SWIRL, 0.3 + 0.3 * pulse), false)
	draw_circle(core, 2.0 + pulse, Color(1.0, 0.95, 1.0, 0.9))


## Quadro do vórtice: a abertura uma vez (no tempo de simulação do portal), depois o loop.
func sprite_frame() -> Array:
	var opening := int(_open_tex.get_width() / float(SPRITE_FRAME)) if _open_tex != null else 0
	var k := int(portal_age * SPRITE_FPS)
	if k < opening:
		return [_open_tex, k]
	var loop := maxi(1, int(_loop_tex.get_width() / float(SPRITE_FRAME)))
	return [_loop_tex, (k - opening) % loop]


func _draw_sprite(core: Vector2, scale: float) -> void:
	var pick := sprite_frame()
	var tex: Texture2D = pick[0]
	var size := Vector2(SPRITE_FRAME, SPRITE_FRAME) * scale
	draw_texture_rect_region(tex, Rect2((core - size * 0.5).round(), size),
			Rect2(int(pick[1]) * SPRITE_FRAME, 0, SPRITE_FRAME, SPRITE_FRAME))


## Torii laqueado emoldurando o vórtice: dois pilares, a viga de cima com as pontas erguidas
## e a viga de baixo.
func _draw_torii(base: Vector2, grow: float) -> void:
	var g := minf(grow, 1.8)
	var half := 15.0 * g
	var top := base.y - 36.0 * g
	var dark := TORII.darkened(0.45)
	for side: float in [-1.0, 1.0]:
		var x := base.x + side * half
		draw_rect(Rect2(x - 1.5, top + 2.0, 3.0, base.y - top - 2.0), TORII)
		draw_rect(Rect2(x - 1.5 + (1.0 if side < 0 else 2.0), top + 2.0, 1.0, base.y - top - 2.0), dark)
		draw_rect(Rect2(x - 2.5, base.y - 2.0, 5.0, 2.0), Color(0.12, 0.08, 0.08))
	draw_rect(Rect2(base.x - half - 6.0, top, half * 2.0 + 12.0, 3.0), TORII)
	draw_rect(Rect2(base.x - half - 7.0, top - 1.0, 3.0, 2.0), TORII)
	draw_rect(Rect2(base.x + half + 4.0, top - 1.0, 3.0, 2.0), TORII)
	draw_rect(Rect2(base.x - half - 6.0, top - 1.0, half * 2.0 + 12.0, 1.0), Color(0.1, 0.06, 0.08))
	draw_rect(Rect2(base.x - half - 2.0, top + 7.0 * g, half * 2.0 + 4.0, 2.0), TORII)
	draw_rect(Rect2(base.x - 1.0, top + 3.0, 2.0, 4.0 * g), TORII.lightened(0.15))


## Almas sendo sugadas: sem estado (função do tempo), espiralam do raio de fora para o miolo.
func _draw_motes(core: Vector2, grow: float, t: float) -> void:
	var count := 6 + 6 * GfxQuality.level()
	for i: int in count:
		var phase := fmod(t * (0.45 + 0.45 * beckon()) + float(i) / count, 1.0)
		var r := (1.0 - phase) * 34.0 * grow
		var a := i * 2.399 + phase * 5.0
		var p := core + Vector2(cos(a) * r, sin(a) * r * 0.75)
		draw_circle(p.round(), 1.0, Color(SWIRL_EDGE.lerp(Color.WHITE, phase), 0.2 + 0.8 * phase))


## Brilho aditivo atrás do vórtice (só Média/Alta).
func _draw_glow() -> void:
	if not is_open() or not bool(GfxQuality.budget("glow")):
		return
	var tex := TerrainArt.halo_texture()
	var grow := portal_radius / PORTAL_RADIUS
	var core := portal_pos + Vector2(0.0, -VORTEX_LIFT * art_scale())
	var call := beckon()
	var pulse := 0.8 + (0.2 + 0.15 * call) * sin(Time.get_ticks_msec() * (0.005 + 0.004 * call))
	var r := 34.0 * grow * pulse * (1.0 + 0.35 * call)
	_glow.draw_texture_rect(tex, Rect2(core - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(SWIRL, 0.45 + 0.25 * call))
	var c := 12.0 * grow
	_glow.draw_texture_rect(tex, Rect2(core - Vector2(c, c), Vector2(c, c) * 2.0), false, Color(SWIRL_EDGE, 0.6))


func _ellipse(center: Vector2, radii: Vector2, color: Color, filled: bool) -> void:
	var pts := PackedVector2Array()
	for k: int in 25:
		var a := TAU * k / 24.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	if filled:
		pts.remove_at(pts.size() - 1)
		draw_colored_polygon(pts, color)
	else:
		draw_polyline(pts, color, 1.0)


# --- Seta da HUD ----------------------------------------------------------------------------

## Seta do portal fora da tela: chevron violeta que pulsa e um vórtice pequeno atrás da base.
## `edge` vem de Hud.arrow_point (com folga da borda e do recorte da câmera).
static func draw_arrow(canvas: CanvasItem, edge: Vector2, dir: Vector2, now: float) -> void:
	var pulse := 0.5 + 0.5 * sin(now * 6.0)
	var glyph := edge - dir * 4.0
	canvas.draw_circle(glyph, 6.0, Color(VOID, 0.85))
	canvas.draw_arc(glyph, 6.0, now * 4.0, now * 4.0 + PI * 1.4, 10, Color(SWIRL_EDGE, 0.9), 1.0)
	canvas.draw_arc(glyph, 3.5, -now * 5.0, -now * 5.0 + PI * 1.2, 8, Color(SWIRL, 0.9), 1.0)
	var tip := edge + dir * (8.0 + pulse * 2.0)
	var side := dir.orthogonal() * 5.0
	var back := edge + dir * 2.0
	canvas.draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]),
			Color(ARROW_COLOR, 0.75 + 0.25 * pulse))


## Caixa que a seta do portal ocupa (testes de layout): o vórtice e a ponta no pulso máximo.
static func arrow_rect(edge: Vector2, dir: Vector2) -> Rect2:
	var glyph := Rect2(edge - dir * 4.0, Vector2.ZERO).grow(6.0)
	var tip := edge + dir * 10.0
	var side := dir.orthogonal() * 5.0
	var back := edge + dir * 2.0
	return glyph.expand(tip).expand(back + side).expand(back - side)
