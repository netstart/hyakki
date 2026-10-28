extends Node
## Música com crossfade e efeitos com limite de polifonia (plano 9.1–9.3 e 15.7).
## - No máximo MAX_PER_SOUND instâncias do mesmo efeito tocando juntas; o resto é descartado.
## - Cooldown por efeito (30 ms) e variação de tom ±8% nos acertos.
## - O limite e o cooldown contam em tempo real, para não embolar em 2x/3x (plano 4.14).
## - Sons de perigo (prioridade) nunca são descartados e abaixam os outros (ducking).
## - Acertos ("hit", "crit", "hit_*") são de baixa prioridade: ocupam no máximo 2/3 do pool,
##   nunca roubam canal, e qualquer outro som rouba o acerto mais antigo com o pool cheio.
##   Assim o golpe das armas (1 por recarga) não some no meio de dezenas de acertos.
## - Sons importantes ("ult_*", o golpe da lanterna) nunca ficam sem canal: roubam o acerto
##   mais antigo ou, sem acertos, o som comum mais antigo (sem abaixar a música).

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
const MAX_PER_SOUND := 4
const SOUND_COOLDOWN_MS := 30
const POOL_SIZE := 32
## Teto de canais com acertos tocando (2/3 do pool).
const MAX_HIT_PLAYERS := 21
const CROSSFADE := 1.5
## Volume da música "apagada" por fade_music (o mesmo piso do crossfade).
const MUSIC_SILENT := -40.0
const PRIORITY := ["alert", "alert3", "jingle_gameover"]
## Grupos de variações (plano 15.7: 6+ variações por som evitam a fadiga em 15 min).
## `play("hit")` sorteia um dos arquivos. Sorteio fora da simulação: não afeta o determinismo.
const VARIANTS := {
	"hit": ["hit1", "hit2", "hit3", "k_hit_punch_0", "k_hit_punch_1", "k_hit_punch_2",
			"k_hit_punch_3", "k_hit_punch_4", "k_hit_soft_0", "k_hit_soft_1", "k_hit_soft_2",
			"hy_smack_0", "hy_smack_1", "hy_smack_2", "hy_smack_3", "hy_smack_4", "hy_smack_5"],
	"player_hurt": ["hit5", "k_hurt_0", "k_hurt_1", "k_hurt_2"],
	"bell": ["k_bell_0", "k_bell_1", "k_bell_2"],
	"prop_break": ["impact", "k_wood_0", "k_wood_1"],
	"ui_accept": ["ui_accept", "k_ui_select_0", "k_ui_select_1", "k_ui_select_2", "k_ui_select_3"],
	"ui_confirm": ["k_ui_confirm_0", "k_ui_confirm_1"],
	"ui_cancel": ["ui_cancel", "k_ui_back_0", "k_ui_back_1"],
	"ui_move": ["ui_move", "k_ui_tick_0", "k_ui_tick_1"],
	"achievement": ["k_jingle_pizzi_0", "k_jingle_pizzi_1", "k_jingle_pizzi_2", "k_jingle_pizzi_3"],
	"fanfare": ["k_jingle_steel_0", "k_jingle_steel_1"],
	"taiko": ["j_taiko_0", "j_taiko_1"],
	# Sem slash.wav e whoosh.wav (rms -28/-32 dB): baixos demais para o golpe das armas.
	"slash": ["hy_slash_0", "hy_slash_1", "hy_slash_2", "hy_slash_3", "hy_slash_4", "hy_slash_5"],
	"whoosh": ["hy_swish_0", "hy_swish_1", "hy_swish_2", "hy_swish_3", "hy_swish_4", "hy_swish_5"],
	"crit": ["hy_crit_0", "hy_crit_1", "hy_crit_2", "hy_crit_3", "hy_crit_4", "hy_crit_5"],
	# Efeitos procedurais do projeto (g_*, CC0, tools/gen_sfx.py) por tipo de arma/acerto.
	"thunder": ["g_thunder_0", "g_thunder_1", "g_thunder_2"],
	"zap": ["g_zap_0", "g_zap_1", "g_zap_2"],
	"chain_zap": ["g_chain_zap_0", "g_chain_zap_1", "g_chain_zap_2"],
	"hit_blade": ["g_hit_blade_0", "g_hit_blade_1", "g_hit_blade_2", "slash2", "slash3",
			"hy_slash_0", "hy_slash_2", "hy_slash_4"],
	"hit_projectile": ["g_hit_projectile_0", "g_hit_projectile_1", "g_hit_projectile_2",
			"k_hit_punch_0", "k_hit_punch_2", "hy_smack_1", "hy_smack_3"],
	"hit_fire": ["g_hit_fire_0", "g_hit_fire_1", "g_hit_fire_2"],
	"hit_thunder": ["g_hit_thunder_0", "g_hit_thunder_1", "g_hit_thunder_2"],
	"hit_wind": ["g_hit_wind_0", "g_hit_wind_1", "g_hit_wind_2"],
	"hit_area": ["g_hit_area_0", "g_hit_area_1", "g_hit_area_2", "k_hit_soft_0", "k_hit_soft_1",
			"k_hit_soft_2"],
	"hit_orbit": ["g_hit_orbit_0", "g_hit_orbit_1", "g_hit_orbit_2"],
	"hit_poison": ["g_hit_poison_0", "g_hit_poison_1", "g_hit_poison_2"],
	"ofuda_cast": ["g_ofuda_cast_0", "g_ofuda_cast_1", "g_ofuda_cast_2"],
	"incense_pulse": ["g_incense_pulse_0", "g_incense_pulse_1", "g_incense_pulse_2"],
	"chest_open": ["g_chest_open_0", "g_chest_open_1"],
	# Kenney RPG Audio e Casino Audio (CC0): lâmina e papel.
	"katana": ["k_blade_slice_0", "k_blade_slice_1"],
	"ofuda_fan": ["k_paper_fan_0", "k_paper_fan_1", "k_paper_shove_0", "k_paper_shove_1",
			"k_paper_shove_2", "k_paper_shove_3"],
	"paper_flutter": ["k_paper_slide_0", "k_paper_slide_1", "k_paper_slide_2", "k_paper_slide_3",
			"k_paper_slide_4", "k_paper_slide_5", "k_paper_slide_6", "k_paper_slide_7"],
	"paper_fold": ["k_paper_place_0", "k_paper_place_1", "k_paper_place_2", "k_paper_place_3"],
	# Flecha: o swish forte (hy_swish), tocado agudo pelo Yumi.
	"arrow": ["hy_swish_0", "hy_swish_1", "hy_swish_2", "hy_swish_3", "hy_swish_4", "hy_swish_5"],
	# Estalo curto de madeira (Kenney Impact), agudo: a corda do arco.
	"bow": ["k_wood_0", "k_wood_1"],
	# Lançamento das armas (g_*, tools/gen_sfx.py; Kenney RPG/Impact): ver WeaponSfx.
	"shuriken_whirl": ["g_shuriken_whirl_0", "g_shuriken_whirl_1", "g_shuriken_whirl_2"],
	"kunai_throw": ["g_kunai_throw_0", "g_kunai_throw_1", "g_kunai_throw_2"],
	"bow_twang": ["g_bow_twang_0", "g_bow_twang_1", "g_bow_twang_2"],
	"chain_rattle": ["g_chain_rattle_0", "g_chain_rattle_1", "g_chain_rattle_2"],
	"smoke_pop": ["g_smoke_pop_0", "g_smoke_pop_1", "g_smoke_pop_2"],
	"spirit_flame": ["g_spirit_flame_0", "g_spirit_flame_1", "g_spirit_flame_2"],
	"wind_gust": ["g_wind_gust_0", "g_wind_gust_1", "g_wind_gust_2"],
	"heavy_blade": ["g_heavy_blade_0", "g_heavy_blade_1", "g_heavy_blade_2"],
	"suzu": ["g_suzu_0", "g_suzu_1", "g_suzu_2"],
	"draw_knife": ["k_draw_knife_0", "k_draw_knife_1", "k_draw_knife_2"],
	"metal_light": ["k_metal_light_0", "k_metal_light_1", "k_metal_light_2"],
	"ult_burst": ["g_ult_burst_0", "g_ult_burst_1"],
	# Portal do 隠世 e chefe intermediário (p_*, CC0, tools/gen_portal_sfx.py). O zumbido
	# p_portal_hum é tocado pelo nome e tem loop no .import: quem tocar precisa pará-lo.
	"portal_open": ["p_portal_open_0", "p_portal_open_1"],
	"teleport": ["p_teleport_0", "p_teleport_1"],
	"midboss_roar": ["p_midboss_roar_0", "p_midboss_roar_1", "p_midboss_roar_2"],
	"midboss_intro": ["p_midboss_intro_0"],
}

## Último som pedido e quantos pedidos por id (inclusive os descartados), para os testes,
## como o last_hit_sound do HyakkiGame.
var last_requested: String = ""
var request_count: Dictionary = {}

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _music_id: String = ""
var _pool: Array[AudioStreamPlayer] = []
var _playing_ids: Dictionary = {}
var _last_play_ms: Dictionary = {}
var _streams: Dictionary = {}
var _duck_tween: Tween
var _music_fade: Tween
## Crossfade em andamento e a faixa que ele está calando.
var _crossfade: Tween
var _crossfade_old: AudioStreamPlayer
var _heartbeat: AudioStreamPlayer
var _beating: bool = false
var _low_pass: AudioEffectLowPassFilter
## Ordem de início dos efeitos, para achar o acerto mais antigo.
var _seq: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_active_music = _music_a
	for i: int in range(POOL_SIZE):
		var player := _make_player("SFX")
		player.finished.connect(_on_sfx_finished.bind(player))
		_pool.append(player)
	_heartbeat = _make_player("SFX")
	_heartbeat.finished.connect(_beat_again)
	apply_volumes()
	Settings.changed.connect(func(_key: String) -> void: apply_volumes())


func _setup_buses() -> void:
	for bus_name: String in ["Music", "SFX", "UI", "Ambience"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")
	var music := AudioServer.get_bus_index("Music")
	_low_pass = AudioEffectLowPassFilter.new()
	_low_pass.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(music, _low_pass)


func _make_player(bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


func apply_volumes() -> void:
	_set_bus_volume("Music", float(Settings.get_value("music_volume")))
	_set_bus_volume("SFX", float(Settings.get_value("sfx_volume")))
	_set_bus_volume("UI", float(Settings.get_value("ui_volume")))
	_set_bus_volume("Ambience", float(Settings.get_value("sfx_volume")) * 0.6)


func _set_bus_volume(bus: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(index, linear <= 0.001)


func play_music(id: String, fade: float = CROSSFADE) -> void:
	if id == _music_id:
		return
	_music_id = id
	# .ogg (Ninja Adventure) ou .mp3 (甘茶の音楽工房); toda música de fundo repete.
	var path := MUSIC_DIR + id + ".ogg"
	if not ResourceLoader.exists(path):
		path = MUSIC_DIR + id + ".mp3"
	var stream := _load(path)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	if _music_fade and _music_fade.is_valid():
		_music_fade.kill()
	var next := _music_b if _active_music == _music_a else _music_a
	next.stream = stream
	next.volume_db = -40.0
	next.play()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(next, "volume_db", 0.0, fade)
	tween.tween_property(_active_music, "volume_db", -40.0, fade)
	var old := _active_music
	tween.chain().tween_callback(old.stop)
	_active_music = next
	_crossfade = tween
	_crossfade_old = old


func stop_music(fade: float = 1.0) -> void:
	_music_id = ""
	var tween := create_tween()
	tween.tween_property(_active_music, "volume_db", -40.0, fade)
	tween.tween_callback(_active_music.stop)


## Leva o volume da faixa atual a `to_db` sem trocar nem parar a faixa: a sequência de morte
## silencia a música (MUSIC_SILENT) e, no reviver, a mesma faixa volta (0 dB) de onde estava.
func fade_music(to_db: float, seconds: float) -> void:
	if _music_fade and _music_fade.is_valid():
		_music_fade.kill()
	# Um crossfade no meio subiria a faixa de volta: termina já, calando a faixa antiga.
	if _crossfade and _crossfade.is_valid():
		_crossfade.kill()
		if _crossfade_old != _active_music:
			_crossfade_old.stop()
	_music_fade = create_tween()
	_music_fade.tween_property(_active_music, "volume_db", to_db, maxf(seconds, 0.01))


## Volume atual da faixa de fundo, em dB (testes).
func music_volume_db() -> float:
	return _active_music.volume_db


## Id da faixa de fundo atual ("" sem música).
func music_id() -> String:
	return _music_id


## Toca um efeito. `pitch_jitter` em fração (0,08 = ±8%). `pitch` permite a escala das brasas.
func play(id: String, pitch: float = 1.0, pitch_jitter: float = 0.0, volume_db: float = 0.0,
		bus: String = "SFX") -> void:
	var priority := PRIORITY.has(id)
	var important := is_important(id)
	var hit := is_hit(id)
	last_requested = id
	request_count[id] = int(request_count.get(id, 0)) + 1
	var now := Time.get_ticks_msec()
	if not priority:
		if now - int(_last_play_ms.get(id, -1000)) < SOUND_COOLDOWN_MS:
			return
		if int(_playing_ids.get(id, 0)) >= MAX_PER_SOUND:
			return
	if hit and _hits_playing() >= MAX_HIT_PLAYERS:
		return
	var file := String((VARIANTS[id] as Array).pick_random()) if VARIANTS.has(id) else id
	var stream := _sfx(file)
	if stream == null:
		return
	var player := _free_player(priority or important, hit)
	if player == null:
		return
	_last_play_ms[id] = now
	_playing_ids[id] = int(_playing_ids.get(id, 0)) + 1
	_seq += 1
	player.set_meta("sound_id", id)
	player.set_meta("counted", true)
	player.set_meta("hit", hit)
	player.set_meta("seq", _seq)
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	player.pitch_scale = pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	player.play()
	if priority:
		duck(4.0, 0.6)


func play_ui(id: String) -> void:
	play(id, 1.0, 0.0, 0.0, "UI")


## Abaixa música e efeitos não prioritários por um tempo (plano 15.7).
func duck(db: float, seconds: float) -> void:
	var music := AudioServer.get_bus_index("Music")
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	var base := linear_to_db(maxf(float(Settings.get_value("music_volume")), 0.0001))
	AudioServer.set_bus_volume_db(music, base - db)
	_duck_tween = create_tween()
	_duck_tween.tween_interval(seconds)
	_duck_tween.tween_callback(apply_volumes)


## Batimento e passa-baixa leve na música quando a vida está baixa (plano 15.7).
func set_low_health(active: bool) -> void:
	_low_pass.cutoff_hz = 1800.0 if active else 20000.0
	if active and not _beating:
		_beating = true
		_heartbeat.stream = _load(SFX_DIR + "bounce.wav")
		_heartbeat.volume_db = -6.0
		_heartbeat.pitch_scale = 0.55
		_heartbeat.play()
	elif not active and _beating:
		_beating = false
		_heartbeat.stop()


## Ligado uma vez em _ready; repete o batimento enquanto a vida estiver baixa.
func _beat_again() -> void:
	if not _beating:
		return
	await get_tree().create_timer(0.45).timeout
	if _beating and not _heartbeat.playing:
		_heartbeat.play()


## Sons que sempre acham canal: perigo (PRIORITY) e o golpe da lanterna ("ult_*").
static func is_important(id: String) -> bool:
	return PRIORITY.has(id) or id.begins_with("ult_")


## Quantas instâncias de `id` estão contadas como tocando (testes do limite de vozes).
func playing_count(id: String) -> int:
	return int(_playing_ids.get(id, 0))


## Acertos ("hit", "crit", "hit_*"): baixa prioridade no pool. "player_hurt" não é acerto.
static func is_hit(id: String) -> bool:
	return id == "hit" or id == "crit" or id.begins_with("hit_")


## Ids dos efeitos tocando agora (testes e depuração).
func active_sounds() -> Array[String]:
	var ids: Array[String] = []
	for player: AudioStreamPlayer in _pool:
		if player.playing:
			ids.append(String(player.get_meta("sound_id", "")))
	return ids


## Para todos os efeitos do pool e zera as contagens.
func stop_sfx() -> void:
	for player: AudioStreamPlayer in _pool:
		player.stop()
		player.set_meta("counted", false)
	_playing_ids.clear()
	_last_play_ms.clear()


func _hits_playing() -> int:
	var count := 0
	for player: AudioStreamPlayer in _pool:
		if player.playing and bool(player.get_meta("hit", false)):
			count += 1
	return count


## Canal livre; com o pool cheio, um som que não é acerto rouba o acerto mais antigo, e o
## som importante, sem acertos tocando, rouba o som comum mais antigo. Acerto nunca rouba.
func _free_player(priority: bool, hit: bool) -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _pool:
		if not player.playing:
			# O som pode ter acabado no servidor de áudio antes do sinal finished chegar.
			_release(player)
			return player
	if hit:
		return null
	var stolen: AudioStreamPlayer = null
	for player: AudioStreamPlayer in _pool:
		if bool(player.get_meta("hit", false)) and (stolen == null
				or int(player.get_meta("seq", 0)) < int(stolen.get_meta("seq", 0))):
			stolen = player
	if stolen == null and priority:
		for player: AudioStreamPlayer in _pool:
			if not is_important(String(player.get_meta("sound_id", ""))) and (stolen == null
					or int(player.get_meta("seq", 0)) < int(stolen.get_meta("seq", 0))):
				stolen = player
		if stolen == null:
			stolen = _pool[0]
	if stolen == null:
		return null
	# Toma o lugar do som interrompido e ajusta a contagem dele.
	_release(stolen)
	stolen.stop()
	return stolen


func _on_sfx_finished(player: AudioStreamPlayer) -> void:
	_release(player)


## Devolve a vaga do som do canal na contagem por id, uma vez só por som tocado: o canal
## reaproveitado (ou roubado) antes do finished não deixa a contagem presa no teto.
func _release(player: AudioStreamPlayer) -> void:
	if not bool(player.get_meta("counted", false)):
		return
	player.set_meta("counted", false)
	var id := String(player.get_meta("sound_id", ""))
	_playing_ids[id] = maxi(0, int(_playing_ids.get(id, 0)) - 1)


## Efeito por nome: .wav (Ninja Adventure), .ogg (Kenney) ou .mp3 (効果音ラボ).
func _sfx(file: String) -> AudioStream:
	for ext: String in [".wav", ".ogg", ".mp3"]:
		if ResourceLoader.exists(SFX_DIR + file + ext):
			return _load(SFX_DIR + file + ext)
	return _load(SFX_DIR + file + ".wav")


func _load(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: som não encontrado " + path)
		_streams[path] = null
		return null
	var stream := load(path) as AudioStream
	_streams[path] = stream
	return stream
