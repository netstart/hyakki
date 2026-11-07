class_name RiftPortal
extends Node2D
## Os três níveis de cada fase e as travessias entre eles (`depth`):
##   0 a fase (o mundo dos vivos), 1 o Kakuriyo (隠世, o mundo oculto, bloco "otherworld" de
##   data/stages.json) e 2 o Tokoyo (常世, a Terra Eterna, bloco "tokoyo").
## - no meio da noite ("midboss", 7:30) o Guardião do Limiar (tier 1) guarda o primeiro limiar:
##   aviso 4 s antes (gongo, a horda recua, tela tinge), entrada com o painel do chefe e um
##   respiro curto do spawner (Spawner.hush) para a entrada não brigar com uma onda;
## - no Kakuriyo, a Sombra do Guardião ("midboss2", tier 2, selo 影) guarda o último limiar: nasce
##   em Spawner.shadow_time (relativo à chegada), com o mesmo aviso e a mesma entrada;
## - vencido, cada Guardião deixa DOIS baús de chefe num arco sobre o ponto da morte e um portal
##   num ponto livre logo abaixo: o do tier 1 é o torii laqueado com o vórtice violeta (leva ao
##   Kakuriyo); o do tier 2, o torii dourado com o vórtice de ouro e luz (leva ao Tokoyo). A HUD
##   aponta o portal fora da tela, na cor dele;
## - a guardiã entra só andando até o portal e tocando nele. O portal fica parado onde caiu, sem
##   puxar nem forçar: depois de INVITE_AFTER s ele chama (o brilho e as almas se intensificam e um
##   aviso curto volta a cada INVITE_EVERY s). Se o amanhecer chegar antes, a vitória é no mapa
##   em que ela está e o portal fecha. Inimigos não entram: o selo do portal os afasta;
## - a travessia (RealmCard na HUD): o relógio para, um redemoinho fecha a tela, o título do
##   reino aparece em kanji com o nome traduzido, o mundo é refeito com o bioma do nível
##   ("<fase>_ura" ou "<fase>_toko") e uma semente própria, a guardiã nasce na origem (área
##   segura), inimigos, tiros e áreas somem (chefes ativos vêm junto, na borda da tela), brasas e
##   itens do chão são coletados (baús vão para a fila e abrem um depois do outro) e o relógio
##   volta. Ondas, eventos, o amanhecer e a Noite Sem Fim seguem em todos os níveis;
## - o último chefe da fase (o das 10:00) só nasce no Tokoyo, em Spawner.final_time (relativo à
##   chegada), com o aviso "final.awakens" antes e o diálogo dele. Quem não chega ao Tokoyo vence
##   ao amanhecer sem a luta final.
##
## Simulação (passo fixo, determinística): step(), a abertura, o toque e a troca de mundo.
## A animação da travessia corre em tempo real com o relógio parado, então não muda a partida.
## Partida suspensa: snapshot()/restore() guardam o nível, a chegada, o portal aberto e os
## chefes vencidos (snapshot antigo com "in_realm" vira o nível 1).
##
## Arte (assets/art/fx/portal/): o vórtice abre com portal_open (8 quadros, uma vez) e segue em
## portal_loop (12 quadros), por trás do torii.png (o vórtice aparece entre os pilares); em escala
## inteira (1x, 2x no puxão). O torii dourado usa as mesmas folhas sem cor (Image.adjust_bcs, uma
## vez por partida) tingidas de ouro. Por cima ficam as camadas desenhadas aqui (com o Stroke,
## sem buffer novo por quadro): runas no chão, almas sugadas e o brilho que a lanterna lê como
## luz. Sem as texturas, vórtice e torii também são desenhados aqui. O zumbido (p_portal_hum, em
## loop; mais grave no torii dourado) é posicional: AudioStreamPlayer2D no portal, some com a
## distância da câmera, pausa com o relógio e para ao fechar, atravessar, reiniciar e no fim.

enum State { CLOSED, OPEN, CROSSING }

## Níveis da fase.
const DEPTH_STAGE := 0
const DEPTH_KAKURIYO := 1
const DEPTH_TOKOYO := 2
## Bloco de data/stages.json misturado à fase em cada nível (o nível 0 é a própria fase).
const REALM_BLOCKS: Array[String] = ["", "otherworld", "tokoyo"]
## Texto do título de cada nível (RealmCard): kanji de reserva, nome e legenda.
const REALM_GLYPHS: Array[String] = ["", "隠世", "常世"]
const REALM_KEYS: Array[String] = ["", "realm", "realm3"]

## Raio de toque do portal e folga do ponto livre onde ele nasce (o torii inteiro cabe).
const PORTAL_RADIUS := 14.0
const CLEARANCE := 22.0
## Abaixo do ponto da morte, para não cair sobre os baús (que ficam no arco de cima).
const PORTAL_OFFSET := Vector2(0.0, 46.0)
## Baús de chefe deixados por cada Guardião.
const MIDBOSS_CHESTS := 2
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
## Zumbido em loop (p_portal_hum.wav), o alcance em que ele some e o tom do torii dourado.
const HUM_PATH := "res://assets/audio/sfx/p_portal_hum.wav"
const HUM_DB := -6.0
const HUM_RANGE := 420.0
const HUM_GOLD_PITCH := 0.8
## Sons provisórios (AudioManager): trocar por zumbido do portal e teletransporte próprios.
const SFX_WARN := "midboss_intro"
const SFX_GONG := "j_gong"
const SFX_ROAR := "midboss_roar"
const SFX_OPEN := "portal_open"
const SFX_INVITE := "j_furin"
const SFX_ENTER := "teleport"
const SFX_ARRIVE := "j_temple_bell"
## Cores do portal violeta (Kakuriyo): vórtice, borda dele, torii laqueado, seta da HUD e luz.
const VOID := Color("2a0e4a")
const SWIRL := Color("b48cff")
const SWIRL_EDGE := Color("7ef0ff")
const TORII := Color("c0392b")
const ARROW_COLOR := Color("c7a4ff")
const LIGHT_COLOR := Color(0.72, 0.55, 1.0)
## Cores do torii dourado (Tokoyo): miolo âmbar, ouro, branco de luz, torii folheado e a luz.
const GOLD_VOID := Color("5a3a08")
const GOLD_SWIRL := Color("ffd166")
const GOLD_EDGE := Color("fff8e0")
const GOLD_TORII := Color("e8b43a")
const GOLD_ARROW := Color("ffe08a")
const GOLD_LIGHT := Color(1.0, 0.86, 0.52)
## Tinta das folhas sem cor no torii dourado (vórtice e torii) e o clareamento de cada uma.
const GOLD_ART := Color(1.0, 0.88, 0.5)
const GOLD_TORII_ART := Color(1.0, 0.82, 0.36)
const GOLD_ART_LIFT := 1.3
const GOLD_TORII_LIFT := 2.1
## Almas a mais em volta do torii dourado.
const GOLD_EXTRA_MOTES := 4
## Paletas por destino (palette()).
const VIOLET_TONES := {"void": VOID, "swirl": SWIRL, "edge": SWIRL_EDGE, "torii": TORII,
		"arrow": ARROW_COLOR, "light": LIGHT_COLOR, "flash": Color(0.55, 0.25, 0.9)}
const GOLD_TONES := {"void": GOLD_VOID, "swirl": GOLD_SWIRL, "edge": GOLD_EDGE, "torii": GOLD_TORII,
		"arrow": GOLD_ARROW, "light": GOLD_LIGHT, "flash": Color(1.0, 0.85, 0.45)}

var game: HyakkiGame
var state: int = State.CLOSED
var portal_pos := Vector2.INF
## Segundos de simulação com o portal aberto.
var portal_age: float = 0.0
var portal_radius: float = PORTAL_RADIUS
## Nível em que a guardiã está (DEPTH_*) e o destino do portal aberto (ou da travessia).
var depth: int = DEPTH_STAGE
var portal_to: int = DEPTH_KAKURIYO
## Compatibilidade: está em outro mundo (Kakuriyo ou Tokoyo).
var in_realm: bool:
	get:
		return depth >= DEPTH_KAKURIYO
	set(value):
		depth = maxi(depth, DEPTH_KAKURIYO) if value else DEPTH_STAGE
## Guardião do Limiar (tier 1), Sombra do Guardião (tier 2) e último chefe vencidos.
var midboss_done: bool = false
var midboss2_done: bool = false
var final_done: bool = false
## A partida chegou ao Kakuriyo / ao Tokoyo (resultados e estatísticas).
var reached: bool = false
var reached_tokoyo: bool = false
## Tempo da noite em que a guardiã chegou ao nível atual (agenda da Sombra e do último chefe).
var arrived_at: float = 0.0
## Sementes do Kakuriyo e do Tokoyo.
var realm_seed: int = 0
var tokoyo_seed: int = 0
## A fase como está em data/stages.json (game.stage vira a mistura com o bloco do nível).
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
var _gold_open: Texture2D
var _gold_loop: Texture2D
var _gold_torii: Texture2D
var _glow: Node2D
var _hum: AudioStreamPlayer2D
var _near: Array[int] = []
## Guardião cuja entrada ainda vai mostrar o aviso e o rugido (spawn_midboss).
var _title_for: StringName = &""


func _ready() -> void:
	_open_tex = _texture(SPRITE_OPEN)
	_loop_tex = _texture(SPRITE_LOOP)
	_torii_tex = _texture(TORII_PATH)
	_gold_open = _golden(_open_tex, GOLD_ART_LIFT)
	_gold_loop = _golden(_loop_tex, GOLD_ART_LIFT)
	_gold_torii = _golden(_torii_tex, GOLD_TORII_LIFT)
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
	Events.boss_defeated.connect(on_boss_defeated)


static func _texture(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## A folha sem cor e clareada (`lift`), para ser tingida de ouro no desenho (operações nativas
## de Image, uma vez por partida; nada de laço por pixel).
static func _golden(tex: Texture2D, lift: float) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.adjust_bcs(lift, 1.1, 0.0)
	return ImageTexture.create_from_image(img)


## Texturas do portal carregadas (testes: a arte importada está em uso, não o desenho reserva).
func has_art() -> bool:
	return _open_tex != null and _loop_tex != null and _torii_tex != null


## As folhas douradas do torii do Tokoyo existem (testes).
func has_gold_art() -> bool:
	return _gold_open != null and _gold_loop != null and _gold_torii != null


## O zumbido do portal está tocando (testes).
func hum_playing() -> bool:
	return _hum != null and (_hum.playing or _hum.stream_paused)


## Tom do zumbido (testes: o torii dourado é mais grave).
func hum_pitch() -> float:
	return _hum.pitch_scale if _hum != null else 1.0


func _exit_tree() -> void:
	_stop_hum()


func _start_hum() -> void:
	if _hum == null or _hum.stream == null:
		return
	_hum.position = portal_pos
	_hum.pitch_scale = HUM_GOLD_PITCH if golden() else 1.0
	_hum.stream_paused = false
	_hum.play()


func _stop_hum() -> void:
	if _hum != null:
		_hum.stream_paused = false
		_hum.stop()


func reset() -> void:
	_stop_hum()
	state = State.CLOSED
	portal_pos = Vector2.INF
	portal_age = 0.0
	portal_radius = PORTAL_RADIUS
	depth = DEPTH_STAGE
	portal_to = DEPTH_KAKURIYO
	midboss_done = false
	midboss2_done = false
	final_done = false
	reached = false
	reached_tokoyo = false
	arrived_at = 0.0
	realm_seed = 0
	tokoyo_seed = 0
	base_stage = game.stage if game != null else {}
	_toast_delay = -1.0
	_title_for = &""
	_cross_t = -1.0
	_swapped = false
	if game != null and game.hud != null and game.hud.realm_card_exists():
		game.hud.realm_card().close()


func is_open() -> bool:
	return state == State.OPEN


func crossing() -> bool:
	return state == State.CROSSING


## O portal aberto (ou a travessia) leva ao Tokoyo: torii dourado.
func golden() -> bool:
	return portal_to >= DEPTH_TOKOYO


## Cores do portal aberto: "void", "swirl", "edge", "torii", "arrow", "light" e "flash".
func tones() -> Dictionary:
	return palette(golden())


static func palette(gold: bool) -> Dictionary:
	return GOLD_TONES if gold else VIOLET_TONES


## {"t", "id"} do Guardião do Limiar da fase (vazio se a fase não tiver).
static func midboss_of(stage_data: Dictionary) -> Dictionary:
	return stage_data.get("midboss", {})


## {"t", "id", "after"} da Sombra do Guardião (nasce no Kakuriyo; vazio se a fase não tiver).
static func midboss2_of(stage_data: Dictionary) -> Dictionary:
	return stage_data.get("midboss2", {})


## {"t", "id"} do último chefe da fase (só nasce no Tokoyo; vazio se a fase não tiver chefes).
static func final_boss_of(stage_data: Dictionary) -> Dictionary:
	var list: Array = stage_data.get("bosses", [])
	return list.back() if not list.is_empty() else {}


static func is_midboss(id: StringName) -> bool:
	return bool((DB.bosses.get(id, {}) as Dictionary).get("midboss", false))


## 1 = Guardião do Limiar (abre o Kakuriyo), 2 = Sombra do Guardião (abre o Tokoyo).
static func tier_of(id: StringName) -> int:
	return int((DB.bosses.get(id, {}) as Dictionary).get("tier", 1))


## A fase misturada com o bloco do nível `level` ("otherworld" no 1, "tokoyo" no 2): bioma,
## tinta, luz, música, clima, limites e perigo. O nível 0 é a própria fase.
static func realm_stage(stage_data: Dictionary, level: int = DEPTH_KAKURIYO) -> Dictionary:
	if level <= DEPTH_STAGE:
		return stage_data
	var realm := stage_data.duplicate()
	var block: Dictionary = stage_data.get(REALM_BLOCKS[mini(level, DEPTH_TOKOYO)], {})
	for key: String in block:
		if key != "kanji":
			realm[key] = block[key]
	realm["realm"] = true
	realm["depth"] = mini(level, DEPTH_TOKOYO)
	return realm


# --- Guardiões ------------------------------------------------------------------------

## Aviso WARN_LEAD s antes: gongo, a horda recua e a tela tinge (o ar prende a respiração).
## `tier` 2 é a Sombra do Guardião (aviso e cor próprios).
func warn_midboss(tier: int = 1) -> void:
	var tone := palette(false)
	game.hud.toast(tr("midboss2.warning") if tier >= 2 else tr("midboss.warning"), WARN_LEAD)
	game.hud.flash_screen(tone["flash"])
	game.enemies.push_from(game.player.sim_pos, WARN_PUSH_RADIUS, WARN_PUSH_FORCE)
	game.fx.add_ring(game.player.sim_pos, WARN_PUSH_RADIUS, tone["swirl"])
	game.shake(2.0)
	AudioManager.play(SFX_WARN, 0.85 if tier >= 2 else 1.0, 0.0, -2.0)
	AudioManager.play(SFX_GONG, 0.7 if tier >= 2 else 0.8, 0.0, -6.0)


## Entrada de um Guardião (tier 1 ou 2). O aviso do título e o rugido vêm com a entrada do chefe
## (Events.boss_spawned): depois do diálogo, quando há um. `dialogue` false na retomada.
func spawn_midboss(id: StringName, dialogue: bool = true) -> void:
	game.spawner.hush(ENTRY_HUSH)
	_listen_spawns()
	_title_for = id
	game.bosses.spawn(id, dialogue)


## O último chefe desperta no Tokoyo: o aviso dourado, um sino e o respiro (antes da entrada).
func warn_final() -> void:
	game.hud.toast(tr("final.awakens"), WARN_LEAD)
	game.hud.flash_screen(GOLD_TONES["flash"])
	game.fx.add_ring(game.player.sim_pos, WARN_PUSH_RADIUS, GOLD_SWIRL)
	game.shake(1.5)
	game.spawner.hush(WARN_LEAD + ENTRY_HUSH)
	AudioManager.play(SFX_ARRIVE, 0.75, 0.0, -2.0)
	AudioManager.play(SFX_GONG, 0.6, 0.0, -6.0)


## Entrada do último chefe (com o diálogo que ele tem).
func spawn_final(id: StringName, dialogue: bool = true) -> void:
	game.spawner.hush(ENTRY_HUSH)
	game.bosses.spawn(id, dialogue)


func _listen_spawns() -> void:
	if not Events.boss_spawned.is_connected(_on_boss_spawned):
		Events.boss_spawned.connect(_on_boss_spawned)


func _on_boss_spawned(id: StringName) -> void:
	if _title_for == &"" or id != _title_for:
		return
	_title_for = &""
	game.hud.toast(tr("midboss2.title") if tier_of(id) >= 2 else tr("midboss.title"), 3.0)
	AudioManager.play(SFX_ROAR, 0.85 if tier_of(id) >= 2 else 1.0, 0.05, -2.0)


## Morte de um Guardião: dois baús num arco sobre o ponto da morte e o portal logo abaixo (o
## violeta para o Kakuriyo no tier 1, o torii dourado para o Tokoyo no tier 2).
func on_midboss_defeated(at: Vector2, tier: int = 1) -> void:
	if tier >= 2:
		midboss2_done = true
	else:
		midboss_done = true
	var placed: Array[Vector2] = []
	for k: int in MIDBOSS_CHESTS:
		var angle := -PI * 0.5 + (-1.0 if k == 0 else 1.0) * CHEST_SPREAD
		placed.append(_drop_chest(at, angle, placed))
	# O portal desce até não encostar nos baús (num canto apertado o ponto livre sobe).
	var spot := at + PORTAL_OFFSET
	for _try: int in 8:
		var free := game.world.free_point(spot, CLEARANCE)
		if placed.all(func(p: Vector2) -> bool: return free.distance_to(p) >= CLEARANCE + 6.0):
			break
		spot += PORTAL_OFFSET * 0.5
	open_portal(spot, DEPTH_TOKOYO if tier >= 2 else DEPTH_KAKURIYO)


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


## Abre o portal para o nível `to` (padrão: o próximo).
func open_portal(at: Vector2, to: int = -1) -> void:
	portal_to = clampi(to if to > 0 else depth + 1, DEPTH_KAKURIYO, DEPTH_TOKOYO)
	portal_pos = game.world.free_point(at, CLEARANCE)
	state = State.OPEN
	portal_age = 0.0
	portal_radius = PORTAL_RADIUS
	_next_invite = INVITE_AFTER
	_toast_delay = OPEN_TOAST_DELAY
	var tone := tones()
	game.fx.add_ring(portal_pos, 70.0, tone["swirl"])
	game.fx.add_ring(portal_pos, 40.0, tone["edge"])
	AudioManager.play(SFX_OPEN, 0.8 if golden() else 1.0, 0.0, -2.0)
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
			game.hud.toast(tr("portal2.opened") if golden() else tr("portal.opened"), 4.0)
	if not is_open():
		return
	portal_age += dt
	_ward()
	# Convite: o aviso volta de tempos em tempos enquanto ela não entra (nada se move).
	if portal_age >= _next_invite:
		_next_invite += INVITE_EVERY
		game.hud.toast(tr("portal2.invite") if golden() else tr("portal.invite"), 3.0)
		AudioManager.play(SFX_INVITE, 0.75 if golden() else 0.9, 0.0, -6.0)
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
	AudioManager.play(SFX_ENTER, 0.6 if golden() else 0.7, 0.0, -2.0)
	AudioManager.duck(8.0, CROSS_IN + CROSS_HOLD)
	Settings.vibrate(60)
	_cross_t = 0.0
	_swapped = false
	var at := get_canvas_transform() * portal_pos if is_inside_tree() else game.view_size() * 0.5
	var title := realm_title(base_stage, portal_to)
	game.hud.realm_card().begin(title[0], title[1], title[2], at, golden())
	if game.is_bot():
		finish_crossing_now()


## [kanji, nome traduzido, legenda traduzida] do título do nível `level` da fase.
static func realm_title(stage_data: Dictionary, level: int) -> Array[String]:
	var to := clampi(level, DEPTH_KAKURIYO, DEPTH_TOKOYO)
	var block: Dictionary = stage_data.get(REALM_BLOCKS[to], {})
	var key := REALM_KEYS[to]
	var stage_id := String(stage_data.get("id", "village"))
	var out: Array[String] = [String(block.get("kanji", REALM_GLYPHS[to])),
			String(TranslationServer.translate("%s.%s.name" % [key, stage_id])),
			String(TranslationServer.translate("%s.caption" % key))]
	return out


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
	# Pausado, `playing` fica falso: sem olhar stream_paused o zumbido nunca voltava da pausa.
	if _hum.playing or _hum.stream_paused:
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


## O mundo do outro lado: coleta o chão, limpa o campo e refaz o mapa com o bioma do nível.
func _swap_realm() -> void:
	_swapped = true
	var shrine_offset := game.kami.shrine_pos - game.player.sim_pos if game.kami.has_shrine() else Vector2.INF
	clear_field()
	game.pickups.collect_all()
	enter_realm(portal_to)
	game.bosses.relocate_all()
	if shrine_offset != Vector2.INF:
		game.kami.shrine_pos = game.world.free_point(game.world.clamp_to_bounds(shrine_offset), 20.0).round()
	AudioManager.play(SFX_ARRIVE, 0.75 if depth >= DEPTH_TOKOYO else 0.9, 0.0, -2.0)


func _end_crossing() -> void:
	_cross_t = -1.0
	state = State.CLOSED
	portal_pos = Vector2.INF
	game.hud.realm_card().close()
	game.spawner.hush(ARRIVAL_HUSH)
	game.hud.toast(tr("realm3.entered") if depth >= DEPTH_TOKOYO else tr("realm.entered"), 3.5)
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
	for weapon: Weapon in game.weapons:
		weapon.on_realm_change()
	game.fx.reset()


## Refaz o mundo com o bioma do nível `level` e a semente própria dele; a guardiã nasce na
## origem. `arrived` (retomada) é a hora da chegada salva; sem ela, agora. A agenda do nível
## (Sombra no Kakuriyo, último chefe no Tokoyo) vai para o spawner, relativa à chegada.
func enter_realm(level: int = DEPTH_KAKURIYO, arrived: float = -1.0) -> void:
	if base_stage.is_empty():
		base_stage = game.stage
	depth = clampi(level, DEPTH_KAKURIYO, DEPTH_TOKOYO)
	arrived_at = arrived if arrived >= 0.0 else GameClock.game_time
	if realm_seed == 0:
		realm_seed = absi(hash([game.world.seed_value, "kakuriyo"])) | 1
	if depth >= DEPTH_TOKOYO and tokoyo_seed == 0:
		tokoyo_seed = absi(hash([realm_seed, "tokoyo"])) | 1
	game.stage = realm_stage(base_stage, depth)
	var player := game.player
	player.sim_pos = Vector2.ZERO
	player.prev_pos = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.position = Vector2.ZERO
	game.world.setup(game.stage, tokoyo_seed if depth >= DEPTH_TOKOYO else realm_seed)
	reached = true
	game.tracker.realm_reached = true
	if depth >= DEPTH_TOKOYO:
		reached_tokoyo = true
		game.tracker.tokoyo_reached = true
	game.spawner.on_arrival(depth, arrived_at)
	if game.bosses.active_count() == 0:
		AudioManager.play_music("endless" if game.endless_phase else String(game.stage.get("music", "stage_village")))


## Hora em que o próximo chefe do nível atual nasce (a Sombra no Kakuriyo, o último chefe no
## Tokoyo; INF sem chefe agendado), pela agenda do Spawner.
func next_boss_time() -> float:
	if depth == DEPTH_KAKURIYO and not midboss2_of(base_stage).is_empty():
		return Spawner.shadow_time(base_stage, arrived_at)
	if depth >= DEPTH_TOKOYO and not final_boss_of(base_stage).is_empty():
		return Spawner.final_time(base_stage, arrived_at)
	return INF


## Chefe vencido (Events.boss_defeated): o último chefe da fase, no Tokoyo, conta aqui.
func on_boss_defeated(id: StringName) -> void:
	if depth >= DEPTH_TOKOYO and id == StringName(final_boss_of(base_stage).get("id", "")):
		final_done = true


## Níveis da fase e chefes vencidos na ordem (o bot e a jornada do run_checks conferem no FIM).
func journey_line() -> String:
	var ids := PackedStringArray()
	for id: StringName in game.tracker.bosses:
		ids.append(String(id))
	return "CHEFES reino=%d tokoyo=%s vencidos=%s" % [depth, reached_tokoyo, ",".join(ids)]


# --- Partida suspensa e cenários de teste -----------------------------------------------

func snapshot() -> Dictionary:
	var level := portal_to if crossing() else depth
	return {"depth": level, "in_realm": level >= DEPTH_KAKURIYO, "midboss_done": midboss_done,
			"midboss2_done": midboss2_done, "final_done": final_done, "seed": realm_seed, "seed2": tokoyo_seed,
			"arrived": GameClock.game_time if crossing() else arrived_at,
			"portal": [portal_pos.x, portal_pos.y] if is_open() else [], "to": portal_to, "age": portal_age}


## Depois do start_run e do Spawner.skip_until: volta ao nível salvo (sem a travessia), reabre o
## portal ou chama de novo o chefe que estava em campo (inimigos não entram no snapshot): o
## Guardião na fase, a Sombra no Kakuriyo, o último chefe no Tokoyo. Snapshot antigo (sem
## "depth") com "in_realm" volta ao Kakuriyo, com a chegada na hora salva.
func restore(s: Dictionary) -> void:
	midboss_done = bool(s.get("midboss_done", false))
	midboss2_done = bool(s.get("midboss2_done", false))
	final_done = bool(s.get("final_done", false))
	realm_seed = int(s.get("seed", 0))
	tokoyo_seed = int(s.get("seed2", 0))
	var level := clampi(int(s.get("depth", DEPTH_KAKURIYO if bool(s.get("in_realm", false)) else DEPTH_STAGE)),
			DEPTH_STAGE, DEPTH_TOKOYO)
	var now := GameClock.game_time
	var portal: Array = s.get("portal", [])
	if level >= DEPTH_KAKURIYO:
		midboss_done = true
		midboss2_done = midboss2_done or level >= DEPTH_TOKOYO
		clear_field()
		enter_realm(level, float(s.get("arrived", now)))
	if portal.size() == 2:
		portal_to = clampi(int(s.get("to", level + 1)), DEPTH_KAKURIYO, DEPTH_TOKOYO)
		if portal_to >= DEPTH_TOKOYO:
			midboss2_done = true
		else:
			midboss_done = true
		portal_pos = Vector2(float(portal[0]), float(portal[1]))
		portal_age = float(s.get("age", 0.0))
		_next_invite = INVITE_AFTER if portal_age < INVITE_AFTER else portal_age + INVITE_EVERY
		state = State.OPEN
		_start_hum()
		return
	var mid := midboss_of(base_stage)
	var mid2 := midboss2_of(base_stage)
	var last := final_boss_of(base_stage)
	if level == DEPTH_STAGE and not midboss_done and not mid.is_empty() and now > float(mid["t"]):
		spawn_midboss(StringName(mid["id"]), false)
	elif level == DEPTH_KAKURIYO and not midboss2_done and not mid2.is_empty() and now > next_boss_time():
		spawn_midboss(StringName(mid2["id"]), false)
	elif level >= DEPTH_TOKOYO and not final_done and not last.is_empty() and now > next_boss_time():
		spawn_final(StringName(last["id"]), false)


## Cenários de depuração (HyakkiGame.apply_scenario): "midboss" (pouco antes do aviso),
## "portal" (Guardião vencido: baús e portal ao lado), "realm" (portal sob a guardiã: a
## travessia começa no próximo passo), "midboss2" (no Kakuriyo, pouco antes do aviso da
## Sombra), "portal2" (Sombra vencida: baús e o torii dourado ao lado) e "tokoyo" (torii dourado
## sob a guardiã no Kakuriyo: a travessia para o Tokoyo começa no próximo passo).
func scenario(scenario_name: String) -> void:
	var mid := midboss_of(base_stage)
	if mid.is_empty():
		return
	var t := float(mid["t"])
	match scenario_name:
		"midboss":
			_jump(t - WARN_LEAD - 1.0)
		"portal":
			_jump(t + 15.0)
			on_midboss_defeated(game.player.sim_pos + Vector2(84.0, -10.0))
		"realm":
			_jump(t + 15.0)
			midboss_done = true
			open_portal(game.player.sim_pos, DEPTH_KAKURIYO)
		"midboss2", "portal2", "tokoyo":
			var mid2 := midboss2_of(base_stage)
			if mid2.is_empty():
				return
			_jump(t + 15.0)
			midboss_done = true
			clear_field()
			enter_realm(DEPTH_KAKURIYO)
			var shadow := next_boss_time()
			if scenario_name == "midboss2":
				_jump(shadow - WARN_LEAD - 1.0)
				return
			_jump(shadow + 15.0)
			if scenario_name == "portal2":
				on_midboss_defeated(game.player.sim_pos + Vector2(84.0, -10.0), 2)
			else:
				midboss2_done = true
				open_portal(game.player.sim_pos, DEPTH_TOKOYO)


func _jump(time: float) -> void:
	GameClock.game_time = time
	game.spawner.skip_until(time)


## Luz do portal para a lanterna (o vórtice brilha na escuridão): [posição, cor, raio, força].
func collect_lights(center: Vector2, half: Vector2) -> Array:
	if not is_open():
		return []
	var r := (70.0 + portal_radius * 1.5) * (1.25 if golden() else 1.0)
	if not Rect2(center - half, half * 2.0).grow(r).has_point(portal_pos):
		return []
	var pulse := 0.85 + 0.15 * sin(UiClock.msec() * 0.004)
	return [[portal_pos + Vector2(0.0, -VORTEX_LIFT), tones()["light"], r, pulse]]


# --- Desenho ------------------------------------------------------------------------------

func _draw() -> void:
	if not is_open():
		return
	var tone := tones()
	var swirl: Color = tone["swirl"]
	var edge: Color = tone["edge"]
	var t := UiClock.msec() / 1000.0
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
		draw_line(p0, p1, Color(swirl, 0.75), 1.0)
	_ellipse(base, Vector2(30.0, 11.0) * grow, Color(edge, 0.35), false)
	if _loop_tex != null:
		_draw_sprite(core, scale)
	else:
		_draw_vortex(core, grow, t, calm)
	var torii := _gold_torii if golden() and _gold_torii != null else _torii_tex
	if torii != null:
		var size := torii.get_size() * scale
		draw_texture_rect(torii, Rect2((base - Vector2(size.x * 0.5, size.y)).round(), size), false,
				GOLD_TORII_ART if torii == _gold_torii else Color.WHITE)
	else:
		_draw_torii(base, grow)
	_draw_motes(core, grow, t)


## Escala inteira da arte (pixel perfeito, 1x como os atores): o portal nunca muda de tamanho.
func art_scale() -> float:
	return 1.0


## Vórtice desenhado (sem a arte): miolo escuro, braços em espiral e o aro claro (gira mais
## rápido quando o portal chama).
func _draw_vortex(core: Vector2, grow: float, t: float, calm: bool) -> void:
	var tone := tones()
	var swirl: Color = tone["swirl"]
	var edge: Color = tone["edge"]
	var r := Vector2(10.0, 14.0) * grow
	_ellipse(core, r, Color(tone["void"] as Color, 0.92), true)
	var speed := (1.6 if calm else 3.2) * (1.0 + beckon())
	for arm: int in 4:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for s: int in 14:
			var k := float(s) / 13.0
			var a := t * speed + arm * TAU / 4.0 + k * 4.2
			pts.append(core + Vector2(cos(a) * r.x, sin(a) * r.y) * (1.0 - k * 0.92))
			cols.append(Color(swirl.lerp(edge, k), 0.25 + 0.75 * k))
		Stroke.polyline(self, pts, cols, 1.0)
	var pulse := 0.5 + 0.5 * sin(t * (3.0 if calm else 6.0))
	_ellipse(core, r, Color(edge, 0.55 + 0.4 * pulse), false)
	_ellipse(core, r + Vector2(2.0, 2.0), Color(swirl, 0.3 + 0.3 * pulse), false)
	draw_circle(core, 2.0 + pulse, Color(1.0, 0.95, 1.0, 0.9))


## Quadro do vórtice: a abertura uma vez (no tempo de simulação do portal), depois o loop (no
## torii dourado, as folhas sem cor).
func sprite_frame() -> Array:
	var gold := golden() and has_gold_art()
	var open_tex := _gold_open if gold else _open_tex
	var loop_tex := _gold_loop if gold else _loop_tex
	var opening := int(open_tex.get_width() / float(SPRITE_FRAME)) if open_tex != null else 0
	var k := int(portal_age * SPRITE_FPS)
	if k < opening:
		return [open_tex, k]
	var loop := maxi(1, int(loop_tex.get_width() / float(SPRITE_FRAME)))
	return [loop_tex, (k - opening) % loop]


func _draw_sprite(core: Vector2, scale: float) -> void:
	var pick := sprite_frame()
	var tex: Texture2D = pick[0]
	var size := Vector2(SPRITE_FRAME, SPRITE_FRAME) * scale
	var tint := GOLD_ART if tex == _gold_open or tex == _gold_loop else Color.WHITE
	draw_texture_rect_region(tex, Rect2((core - size * 0.5).round(), size),
			Rect2(int(pick[1]) * SPRITE_FRAME, 0, SPRITE_FRAME, SPRITE_FRAME), tint)


## Torii (laqueado ou dourado) emoldurando o vórtice: dois pilares, a viga de cima com as pontas
## erguidas e a viga de baixo.
func _draw_torii(base: Vector2, grow: float) -> void:
	var color: Color = tones()["torii"]
	var g := minf(grow, 1.8)
	var half := 15.0 * g
	var top := base.y - 36.0 * g
	var dark := color.darkened(0.45)
	for side: float in [-1.0, 1.0]:
		var x := base.x + side * half
		draw_rect(Rect2(x - 1.5, top + 2.0, 3.0, base.y - top - 2.0), color)
		draw_rect(Rect2(x - 1.5 + (1.0 if side < 0 else 2.0), top + 2.0, 1.0, base.y - top - 2.0), dark)
		draw_rect(Rect2(x - 2.5, base.y - 2.0, 5.0, 2.0), Color(0.12, 0.08, 0.08))
	draw_rect(Rect2(base.x - half - 6.0, top, half * 2.0 + 12.0, 3.0), color)
	draw_rect(Rect2(base.x - half - 7.0, top - 1.0, 3.0, 2.0), color)
	draw_rect(Rect2(base.x + half + 4.0, top - 1.0, 3.0, 2.0), color)
	draw_rect(Rect2(base.x - half - 6.0, top - 1.0, half * 2.0 + 12.0, 1.0), Color(0.1, 0.06, 0.08))
	draw_rect(Rect2(base.x - half - 2.0, top + 7.0 * g, half * 2.0 + 4.0, 2.0), color)
	draw_rect(Rect2(base.x - 1.0, top + 3.0, 2.0, 4.0 * g), color.lightened(0.15))


## Almas sendo sugadas: sem estado (função do tempo), espiralam do raio de fora para o miolo
## (douradas no torii do Tokoyo).
func _draw_motes(core: Vector2, grow: float, t: float) -> void:
	var tone := tones()
	var edge: Color = tone["edge"] if not golden() else tone["swirl"]
	var count := 6 + 6 * GfxQuality.level() + (GOLD_EXTRA_MOTES if golden() else 0)
	for i: int in count:
		var phase := fmod(t * (0.45 + 0.45 * beckon()) + float(i) / count, 1.0)
		var r := (1.0 - phase) * 34.0 * grow
		var a := i * 2.399 + phase * 5.0
		var p := core + Vector2(cos(a) * r, sin(a) * r * 0.75)
		draw_circle(p.round(), 1.0, Color(edge.lerp(Color.WHITE, phase), 0.2 + 0.8 * phase))


## Brilho aditivo atrás do vórtice (só Média/Alta; mais largo no torii dourado).
func _draw_glow() -> void:
	if not is_open() or not bool(GfxQuality.budget("glow")):
		return
	var tone := tones()
	var tex := TerrainArt.halo_texture()
	var grow := portal_radius / PORTAL_RADIUS
	var core := portal_pos + Vector2(0.0, -VORTEX_LIFT * art_scale())
	var call := beckon()
	var pulse := 0.8 + (0.2 + 0.15 * call) * sin(UiClock.msec() * (0.005 + 0.004 * call))
	var r := 34.0 * grow * pulse * (1.0 + 0.35 * call) * (1.3 if golden() else 1.0)
	_glow.draw_texture_rect(tex, Rect2(core - Vector2(r, r), Vector2(r, r) * 2.0), false,
			Color(tone["swirl"] as Color, 0.45 + 0.25 * call))
	var c := 12.0 * grow
	_glow.draw_texture_rect(tex, Rect2(core - Vector2(c, c), Vector2(c, c) * 2.0), false,
			Color(tone["edge"] as Color, 0.6))


## Elipse cheia (leque convexo) ou contorno, pelo Stroke (sem buffer novo por quadro).
func _ellipse(center: Vector2, radii: Vector2, color: Color, filled: bool) -> void:
	var pts := PackedVector2Array()
	for k: int in 25:
		var a := TAU * k / 24.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	if filled:
		pts.remove_at(pts.size() - 1)
		Stroke.convex(self, pts, color)
	else:
		Stroke.line(self, pts, color, 1.0)


# --- Seta da HUD ----------------------------------------------------------------------------

## Seta do portal fora da tela: chevron que pulsa e um vórtice pequeno atrás da base, violeta
## (Kakuriyo) ou dourado (`gold`, Tokoyo). `edge` vem de Hud.arrow_point (com folga da borda e
## do recorte da câmera).
static func draw_arrow(canvas: CanvasItem, edge: Vector2, dir: Vector2, now: float, gold: bool = false) -> void:
	var tone := palette(gold)
	var pulse := 0.5 + 0.5 * sin(now * 6.0)
	var glyph := edge - dir * 4.0
	canvas.draw_circle(glyph, 6.0, Color(tone["void"] as Color, 0.85))
	Stroke.arc(canvas, glyph, 6.0, now * 4.0, now * 4.0 + PI * 1.4, 10, Color(tone["edge"] as Color, 0.9), 1.0)
	Stroke.arc(canvas, glyph, 3.5, -now * 5.0, -now * 5.0 + PI * 1.2, 8, Color(tone["swirl"] as Color, 0.9), 1.0)
	var tip := edge + dir * (8.0 + pulse * 2.0)
	var side := dir.orthogonal() * 5.0
	var back := edge + dir * 2.0
	Stroke.convex(canvas, PackedVector2Array([tip, back + side, back - side]),
			Color(tone["arrow"] as Color, 0.75 + 0.25 * pulse))


## Caixa que a seta do portal ocupa (testes de layout): o vórtice e a ponta no pulso máximo.
static func arrow_rect(edge: Vector2, dir: Vector2) -> Rect2:
	var glyph := Rect2(edge - dir * 4.0, Vector2.ZERO).grow(6.0)
	var tip := edge + dir * 10.0
	var side := dir.orthogonal() * 5.0
	var back := edge + dir * 2.0
	return glyph.expand(tip).expand(back + side).expand(back - side)
