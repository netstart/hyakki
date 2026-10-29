extends Node
## Preferências do jogador (plano 7.5 e 7.6), salvas em user://settings.cfg.
## Ficam separadas do save de progresso: apagar uma não afeta a outra.

signal changed(key: String)

const PATH := "user://settings.cfg"
## Arquivo dos testes de integração (use_test_file): o do jogador nunca é tocado por eles.
const TEST_PATH := "user://test_settings.cfg"
## 2: barra de vida passa a ficar sobre a cabeça por padrão.
const VERSION := 2
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
	## Números por tipo (DamagePalette.SETTING_KEYS); a opção geral acima vale por cima.
	"damage_show_hit": true,
	"damage_show_high": true,
	"damage_show_crit": true,
	"damage_show_dot": true,
	"damage_show_taken": true,
	"damage_show_taken_heavy": true,
	"damage_show_heal": true,
	"damage_sounds": true,
	"hurt_sounds": true,
	"hp_bar_below": false,
	"speed": 1,
	"notifications": false,
	"show_fps": false,
	## Qualidade gráfica (GfxQuality): "auto" | "low" | "medium" | "high".
	"graphics_quality": "auto",
}

## Arquivo em uso: PATH no jogo, TEST_PATH nos testes.
var path: String = PATH
var _values: Dictionary = {}
var _last_vibration_ms: int = 0


func _ready() -> void:
	load_settings()


## Testes: passa a ler e gravar em TEST_PATH, começando dos padrões. Mesmo um teste
## interrompido no meio não deixa opções trocadas no settings.cfg do jogador.
func use_test_file() -> void:
	path = TEST_PATH
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	load_settings()


func load_settings() -> void:
	_values = DEFAULTS.duplicate(true)
	var config := ConfigFile.new()
	if config.load(path) == OK:
		for key: String in DEFAULTS:
			if config.has_section_key("settings", key):
				_values[key] = config.get_value("settings", key)
		if int(config.get_value("meta", "version", 1)) < 2:
			_values["hp_bar_below"] = false
	apply_engine_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	for key: String in _values:
		config.set_value("settings", key, _values[key])
	config.set_value("meta", "version", VERSION)
	config.save(path)


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	_values[key] = value
	save_settings()
	apply_engine_settings()
	changed.emit(key)


## Limite de FPS pela opção, sem brigar com o VSync quando ela pede a taxa da tela (FramePacing).
func apply_engine_settings() -> void:
	FramePacing.apply(int(get_value("fps")))


## Vibração curta, respeitando a opção e um intervalo mínimo de 80 ms reais (plano 4.14).
func vibrate(duration_ms: int, amplitude: float = -1.0) -> void:
	if not bool(get_value("vibration")):
		return
	var now := Time.get_ticks_msec()
	if now - _last_vibration_ms < 80:
		return
	_last_vibration_ms = now
	Input.vibrate_handheld(duration_ms, amplitude)
