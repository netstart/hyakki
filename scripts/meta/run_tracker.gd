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
## Habilidades dos guardiões usadas na partida (total e por id), só registro (Missões).
var abilities: int = 0
var ability_uses: Dictionary = {}
var evolutions: Array[StringName] = []
var unions: Array[StringName] = []
var bosses: Array[StringName] = []
var kami: Array[StringName] = []
var items: Dictionary = {}
## Saldo de ryō da partida (o que vai para o perfil no fim) e o que já saiu dele na própria
## partida (Rerrolar pago): o gasto conta como ganho no total da vida (MetaProgress.apply_run).
var ryo: int = 0
var ryo_spent: int = 0
var max_level: int = 1
var dark_seconds: float = 0.0
var max_dark_streak: float = 0.0
var max_no_damage: float = 0.0
var max_kills_10s: int = 0
var revived_by_ad: bool = false
var doubled_ryo: bool = false
## Atravessou o portal do Guardião do Limiar e jogou no Kakuriyo.
var realm_reached: bool = false
## Atravessou o torii dourado da Sombra do Guardião e jogou no Tokoyo (onde mora o último chefe).
var tokoyo_reached: bool = false
## Abates fora da luz da lanterna (Missões do Santuário).
var dark_kills: int = 0
## Altares do Selo (AltarSystem, Missões e Diário): selos quebrados, emboscadas, Elites com afixos
## vencidos, o maior número de afixos de um Elite vencido e os afixos já vencidos ({id: true}).
var altars_awakened: int = 0
var altar_ambushes: int = 0
var altar_elites_slain: int = 0
var elite_affix_max: int = 0
var elite_affixes_slain: Dictionary = {}
## Afixos dos Elites que surgiram nesta partida ({id: true}): o Guia os mostra (Discovery.affix_known).
var elite_affixes_seen: Dictionary = {}
## Lutas com chefes em andamento: {id: {start, hits}} (golpes do chefe na guardiã na entrada).
var boss_fights: Dictionary = {}
## Chefes vencidos nesta partida: {id: {time (s da entrada à derrota), clean (sem golpe dele)}}.
var boss_results: Dictionary = {}

var _kill_times: PackedFloat32Array = []


func on_kill(enemy_id: StringName, time: float, dark: bool = false) -> void:
	kills += 1
	dark_kills += int(dark)
	kills_by_enemy[enemy_id] = int(kills_by_enemy.get(enemy_id, 0)) + 1
	_kill_times.append(time)
	while not _kill_times.is_empty() and time - _kill_times[0] > 10.0:
		_kill_times.remove_at(0)
	max_kills_10s = maxi(max_kills_10s, _kill_times.size())


## Um altar quebrou o selo (`outcome` &"elite" ou &"ambush").
func on_altar(outcome: StringName) -> void:
	altars_awakened += 1
	if outcome == &"ambush":
		altar_ambushes += 1


## Um Elite de altar surgiu com estes afixos (só registro).
func on_elite_spawned(affixes: Array) -> void:
	for id: Variant in affixes:
		elite_affixes_seen[StringName(id)] = true


## Um Elite de altar foi vencido com estes afixos.
func on_elite_slain(affixes: Array) -> void:
	altar_elites_slain += 1
	elite_affix_max = maxi(elite_affix_max, affixes.size())
	for id: Variant in affixes:
		elite_affixes_slain[StringName(id)] = true


## Gasta ryō da partida (o HUD lê `ryo` a cada quadro).
func spend_ryo(amount: int) -> void:
	ryo -= amount
	ryo_spent += amount


## Uma habilidade saiu (AbilitySystem.activate).
func on_ability(id: StringName) -> void:
	abilities += 1
	ability_uses[id] = int(ability_uses.get(id, 0)) + 1


## Entrada do chefe (fim do diálogo): guarda o instante e quantos golpes dele a guardiã já levou.
func on_boss_start(id: StringName, time: float, damage: DamageControl) -> void:
	boss_fights[id] = {"start": time, "hits": _hits(damage, id)}


## Chefe vencido: soma à lista da partida e, se a entrada foi registrada, o tempo da luta e se a
## guardiã passou sem nenhum golpe dele.
func on_boss_defeated(id: StringName, time: float, damage: DamageControl) -> void:
	bosses.append(id)
	if not boss_fights.has(id):
		return
	var fight: Dictionary = boss_fights[id]
	boss_fights.erase(id)
	boss_results[id] = {"time": time - float(fight["start"]), "clean": _hits(damage, id) == int(fight["hits"])}


static func _hits(damage: DamageControl, id: StringName) -> int:
	return int((damage.by_source.get(id, {}) as Dictionary).get("hits", 0)) if damage != null else 0


## Campos das Missões para a partida suspensa (snapshot/restore do HyakkiGame).
func snapshot() -> Dictionary:
	var items_out := {}
	for id: StringName in items:
		items_out[String(id)] = int(items[id])
	var uses_out := {}
	for id: StringName in ability_uses:
		uses_out[String(id)] = int(ability_uses[id])
	return {"dark_kills": dark_kills, "items": items_out, "boss_fights": _str_keys(boss_fights),
			"boss_results": _str_keys(boss_results), "max_dark_streak": max_dark_streak,
			"max_no_damage": max_no_damage, "ultimates": ultimates, "chests": chests,
			"abilities": abilities, "ability_uses": uses_out, "ryo_spent": ryo_spent,
			"kami": Array(kami).map(func(k: StringName) -> String: return String(k)),
			"tokoyo_reached": tokoyo_reached, "altars_awakened": altars_awakened, "altar_ambushes": altar_ambushes,
			"altar_elites_slain": altar_elites_slain, "elite_affix_max": elite_affix_max,
			"elite_affixes_slain": elite_affixes_slain.keys().map(func(k: StringName) -> String: return String(k)),
			"elite_affixes_seen": elite_affixes_seen.keys().map(func(k: StringName) -> String: return String(k))}


func restore(s: Dictionary) -> void:
	dark_kills = int(s.get("dark_kills", 0))
	for id: String in (s.get("items", {}) as Dictionary):
		items[StringName(id)] = int(s["items"][id])
	for key: String in ["boss_fights", "boss_results"]:
		var table: Dictionary = get(key)
		for id: String in (s.get(key, {}) as Dictionary):
			table[StringName(id)] = (s[key][id] as Dictionary).duplicate()
	max_dark_streak = float(s.get("max_dark_streak", 0.0))
	max_no_damage = float(s.get("max_no_damage", 0.0))
	ultimates = int(s.get("ultimates", 0))
	abilities = int(s.get("abilities", 0))
	for id: String in (s.get("ability_uses", {}) as Dictionary):
		ability_uses[StringName(id)] = int(s["ability_uses"][id])
	chests = int(s.get("chests", 0))
	ryo_spent = int(s.get("ryo_spent", 0))
	for k: Variant in s.get("kami", []):
		kami.append(StringName(String(k)))
	tokoyo_reached = tokoyo_reached or bool(s.get("tokoyo_reached", false))
	altars_awakened = int(s.get("altars_awakened", 0))
	altar_ambushes = int(s.get("altar_ambushes", 0))
	altar_elites_slain = int(s.get("altar_elites_slain", 0))
	elite_affix_max = int(s.get("elite_affix_max", 0))
	for id: Variant in s.get("elite_affixes_slain", []):
		elite_affixes_slain[StringName(String(id))] = true
	for id: Variant in s.get("elite_affixes_seen", []):
		elite_affixes_seen[StringName(String(id))] = true


static func _str_keys(table: Dictionary) -> Dictionary:
	var out := {}
	for id: StringName in table:
		out[String(id)] = (table[id] as Dictionary).duplicate()
	return out


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
