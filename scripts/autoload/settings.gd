extends Node
## Preferências do jogador (plano 7.5 e 7.6), salvas em user://settings.cfg.
## Ficam separadas do save de progresso: apagar uma não afeta a outra.

signal changed(key: String)

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"language": "",
	"music_volume": 0.7,
	"sfx_volume": 0.8,
	"ui_volume": 0.8,
	"vibration": true,
	"joystick_mode": "floating",
	"joystick_side": "left",
	"fps": 60,
	"ui_scale": 1.0,
	"colorblind": false,
	"reduce_flashes": false,
	"damage_numbers": true,
	"hp_bar_below": true,
	"speed": 1,
	"notifications": false,
	"show_fps": false,
}

var _values: Dictionary = {}
var _last_vibration_ms: int = 0


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	_values = DEFAULTS.duplicate(true)
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		for key: String in DEFAULTS:
			if config.has_section_key("settings", key):
				_values[key] = config.get_value("settings", key)
	apply_engine_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	for key: String in _values:
		config.set_value("settings", key, _values[key])
	config.save(PATH)


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	_values[key] = value
	save_settings()
	apply_engine_settings()
	changed.emit(key)


func apply_engine_settings() -> void:
	Engine.max_fps = int(get_value("fps"))


## Vibração curta, respeitando a opção e um intervalo mínimo de 80 ms reais (plano 4.14).
func vibrate(duration_ms: int, amplitude: float = -1.0) -> void:
	if not bool(get_value("vibration")):
		return
	var now := Time.get_ticks_msec()
	if now - _last_vibration_ms < 80:
		return
	_last_vibration_ms = now
	Input.vibrate_handheld(duration_ms, amplitude)
