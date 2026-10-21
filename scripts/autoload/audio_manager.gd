extends Node
## Música com crossfade e efeitos com limite de polifonia (plano 9.1–9.3 e 15.7).
## - No máximo MAX_PER_SOUND instâncias do mesmo efeito tocando juntas; o resto é descartado.
## - Cooldown por efeito (30 ms) e variação de tom ±8% nos acertos.
## - O limite e o cooldown contam em tempo real, para não embolar em 2x/3x (plano 4.14).
## - Sons de perigo (prioridade) nunca são descartados e abaixam os outros (ducking).

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
const MAX_PER_SOUND := 4
const SOUND_COOLDOWN_MS := 30
const POOL_SIZE := 24
const CROSSFADE := 1.5
const PRIORITY := ["alert", "alert3", "jingle_gameover"]

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _music_id: String = ""
var _pool: Array[AudioStreamPlayer] = []
var _playing_ids: Dictionary = {}
var _last_play_ms: Dictionary = {}
var _streams: Dictionary = {}
var _duck_tween: Tween
var _heartbeat: AudioStreamPlayer
var _beating: bool = false
var _low_pass: AudioEffectLowPassFilter


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
	var stream := _load(MUSIC_DIR + id + ".ogg")
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
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


func stop_music(fade: float = 1.0) -> void:
	_music_id = ""
	var tween := create_tween()
	tween.tween_property(_active_music, "volume_db", -40.0, fade)
	tween.tween_callback(_active_music.stop)


## Toca um efeito. `pitch_jitter` em fração (0,08 = ±8%). `pitch` permite a escala das brasas.
func play(id: String, pitch: float = 1.0, pitch_jitter: float = 0.0, volume_db: float = 0.0,
		bus: String = "SFX") -> void:
	var priority := PRIORITY.has(id)
	var now := Time.get_ticks_msec()
	if not priority:
		if now - int(_last_play_ms.get(id, -1000)) < SOUND_COOLDOWN_MS:
			return
		if int(_playing_ids.get(id, 0)) >= MAX_PER_SOUND:
			return
	var stream := _load(SFX_DIR + id + ".wav")
	if stream == null:
		return
	var player := _free_player(priority)
	if player == null:
		return
	_last_play_ms[id] = now
	_playing_ids[id] = int(_playing_ids.get(id, 0)) + 1
	player.set_meta("sound_id", id)
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


func _free_player(priority: bool) -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _pool:
		if not player.playing:
			return player
	if priority:
		# Toma o lugar do mais antigo; ajusta a contagem do som interrompido.
		var stolen := _pool[0]
		var old_id := String(stolen.get_meta("sound_id", ""))
		_playing_ids[old_id] = maxi(0, int(_playing_ids.get(old_id, 0)) - 1)
		stolen.stop()
		return stolen
	return null


func _on_sfx_finished(player: AudioStreamPlayer) -> void:
	var id := String(player.get_meta("sound_id", ""))
	_playing_ids[id] = maxi(0, int(_playing_ids.get(id, 0)) - 1)


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
