class_name RunTracker
extends RefCounted
## Estatísticas de uma partida: alimentam a tela de resultados, as conquistas e a
## telemetria local de balanceamento (plano 4.11, 4.12 e 14.3).

var kills: int = 0
var kills_by_enemy: Dictionary = {}
var damage_by_weapon: Dictionary = {}
var weapon_level: Dictionary = {}
var chests: int = 0
var ultimates: int = 0
var evolutions: Array[StringName] = []
var unions: Array[StringName] = []
var bosses: Array[StringName] = []
var kami: Array[StringName] = []
var items: Dictionary = {}
var ryo: int = 0
var max_level: int = 1
var dark_seconds: float = 0.0
var max_dark_streak: float = 0.0
var max_no_damage: float = 0.0
var max_kills_10s: int = 0
var revived_by_ad: bool = false
var doubled_ryo: bool = false

var _kill_times: PackedFloat32Array = []


func on_kill(enemy_id: StringName, time: float) -> void:
	kills += 1
	kills_by_enemy[enemy_id] = int(kills_by_enemy.get(enemy_id, 0)) + 1
	_kill_times.append(time)
	while not _kill_times.is_empty() and time - _kill_times[0] > 10.0:
		_kill_times.remove_at(0)
	max_kills_10s = maxi(max_kills_10s, _kill_times.size())


func on_damage(weapon_id: StringName, amount: float) -> void:
	damage_by_weapon[weapon_id] = float(damage_by_weapon.get(weapon_id, 0.0)) + amount


func step(dt: float, light_radius: float, time_since_damage: float) -> void:
	if light_radius < 60.0:
		dark_seconds += dt
		max_dark_streak = maxf(max_dark_streak, dark_seconds)
	else:
		dark_seconds = 0.0
	max_no_damage = maxf(max_no_damage, time_since_damage)


## Linha de telemetria local (CSV) para o balanceamento (plano 14.3).
func csv_line(result: Dictionary) -> String:
	var weapons: PackedStringArray = []
	for id: StringName in damage_by_weapon:
		weapons.append("%s:%d:%d" % [id, int(weapon_level.get(id, 0)), roundi(float(damage_by_weapon[id]))])
	var damage: Dictionary = result.get("damage_taken", {})
	return "%s,%s,%s,%s,%d,%.1f,%d,%d,%d,%s,%s,%d,%s" % [
		Time.get_datetime_string_from_system(), result.get("hero", ""), result.get("stage", ""),
		result.get("mode", ""), int(result.get("moon", 0)), float(result.get("time", 0.0)),
		int(result.get("level", 1)), kills, ryo, "win" if bool(result.get("victory", false)) else "death",
		"|".join(weapons), roundi(float(damage.get("total", 0.0))), damage.get("cause", ""),
	]
