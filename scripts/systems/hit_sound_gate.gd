class_name HitSoundGate
extends RefCounted
## Som do golpe no inimigo (HyakkiGame.deal_damage), agrupado por passo de simulação: no máximo
## um som por arma e um "crit" por passo (um corte da katana em 150 inimigos toca um golpe só,
## não 150). O tipo do som sai de HitSounds, em cache por arma. Desligado pela opção
## "damage_sounds", lida uma vez por passo (e de novo quando muda nas Opções).
## Só áudio: não toca no rng da partida (fora do hash da simulação).

## Último golpe com som (testes), mesmo quando o som em si foi agrupado; "" com a opção desligada.
var last: String = ""
## Sons de golpe e de crítico tocados de fato (testes do agrupamento por passo).
var played: int = 0
var crit_played: int = 0

var _cache: Dictionary = {}
## Opção em cache (-1 = ler de novo), passo atual, armas que já soaram nele e se o "crit" já soou.
var _enabled: int = -1
var _step: int = -1
var _sounded: Dictionary = {}
var _crit_sounded: bool = false


## Golpe da arma `weapon_id` no passo `step` (HyakkiGame.step_index).
func hit(weapon_id: StringName, crit: bool, step: int) -> void:
	if _step != step:
		_step = step
		_sounded.clear()
		_crit_sounded = false
		_enabled = -1
	if _enabled < 0:
		_enabled = 1 if bool(Settings.get_value("damage_sounds")) else 0
		if not Settings.changed.is_connected(_on_setting):
			Settings.changed.connect(_on_setting)
	if _enabled == 0:
		last = ""
		return
	var id: String = _cache.get(weapon_id, "")
	if id == "":
		id = HitSounds.for_weapon(DB.weapon(weapon_id))
		_cache[weapon_id] = id
	last = id
	if not _sounded.has(weapon_id):
		_sounded[weapon_id] = true
		played += 1
		HitSounds.play(id)
	if crit and not _crit_sounded:
		_crit_sounded = true
		crit_played += 1
		AudioManager.play("crit", 1.0, 0.08, -10.0)


func _on_setting(key: String) -> void:
	if key == "damage_sounds":
		_enabled = -1
