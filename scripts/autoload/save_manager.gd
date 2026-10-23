extends Node
## Progresso do jogador (plano 10.10): JSON em user://save.json, com backup e migração
## por versão. A gravação escreve primeiro num arquivo temporário e só então troca,
## para um app morto no meio da gravação não corromper o save (teste 14.2).

signal saved
signal unlocked(kind: String, id: StringName)

const PATH := "user://save.json"
const BACKUP_PATH := "user://save.bak"
const TEMP_PATH := "user://save.tmp"
const VERSION := 1

var data: Dictionary = {}
## true quando o save principal estava corrompido e o backup foi usado.
var recovered_from_backup: bool = false


func _ready() -> void:
	load_profile()


static func default_profile() -> Dictionary:
	return {
		"version": VERSION,
		"ryo": 0,
		"ryo_total": 0,
		"spent": 0,
		"powerups": {},
		"unlocked": {"heroes": ["aki"], "weapons": [], "passives": [], "stages": ["village"],
				"cosmetics": [], "kami": []},
		"achievements": {},
		"stats": {"kills": 0, "runs": 0, "wins": 0, "deaths": 0, "time_played": 0.0,
				"evolved": [], "kills_by_enemy": {}, "bosses_defeated": {}, "revives_by_ad": 0,
				"chests": 0, "max_level": 0, "max_kills_10s": 0},
		"stage_best": {},
		"story": {"intro_seen": false, "ending_seen": false, "secret_ending_seen": false},
		"tutorial_done": false,
		"launches": 0,
		"last_open_ad_unix": 0,
		"open_ads_seen": 0,
		"remove_ad_offer_shown": false,
		"shop": {"slots": {}, "max_seen_unix": 0, "next_run": {}},
		"purchases": {"remove_open_ad": false, "pending": false},
		"consent": {"asked": false, "personalized": false},
		"daily": {"date": "", "best_time": 0.0, "best_kills": 0, "best_revived": false},
		"defeat_streak": {},
		"selected": {"hero": "aki", "stage": "village", "moon": 0, "mode": "normal",
				"cosmetic": ""},
		"suspended": {},
	}


func load_profile() -> void:
	recovered_from_backup = false
	var loaded := _read(PATH)
	if loaded.is_empty() and FileAccess.file_exists(PATH):
		loaded = _read(BACKUP_PATH)
		recovered_from_backup = not loaded.is_empty()
	data = migrate(loaded) if not loaded.is_empty() else default_profile()


## Leva saves antigos para a versão atual e completa campos que faltam.
static func migrate(old: Dictionary) -> Dictionary:
	var fresh := default_profile()
	_fill_missing(old, fresh)
	old["version"] = VERSION
	return old


static func _fill_missing(target: Dictionary, defaults: Dictionary) -> void:
	for key: String in defaults:
		if not target.has(key):
			target[key] = defaults[key]
		elif typeof(defaults[key]) == TYPE_DICTIONARY and typeof(target[key]) == TYPE_DICTIONARY:
			_fill_missing(target[key], defaults[key])


func save_profile() -> void:
	var text := JSON.stringify(data, "\t")
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: não abriu " + TEMP_PATH)
		return
	file.store_string(text)
	file.close()
	var dir := DirAccess.open("user://")
	if FileAccess.file_exists(PATH):
		dir.copy(PATH, BACKUP_PATH)
	dir.rename(TEMP_PATH, PATH)
	saved.emit()


func reset_profile() -> void:
	data = default_profile()
	save_profile()


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# --- Atalhos -----------------------------------------------------------------

func ryo() -> int:
	return int(data["ryo"])


func add_ryo(amount: int) -> void:
	data["ryo"] = maxi(0, ryo() + amount)
	if amount > 0:
		data["ryo_total"] = int(data["ryo_total"]) + amount


func is_unlocked(kind: String, id: StringName) -> bool:
	return (data["unlocked"][kind] as Array).has(String(id))


func unlock(kind: String, id: StringName) -> bool:
	var list: Array = data["unlocked"][kind]
	if list.has(String(id)):
		return false
	list.append(String(id))
	unlocked.emit(kind, id)
	return true


func powerup_level(id: StringName) -> int:
	return int((data["powerups"] as Dictionary).get(String(id), 0))


func stat(key: String) -> Variant:
	return data["stats"][key]


func add_stat(key: String, amount: float) -> void:
	data["stats"][key] = float(data["stats"][key]) + amount


func stage_best(stage_id: StringName) -> Dictionary:
	var all: Dictionary = data["stage_best"]
	if not all.has(String(stage_id)):
		all[String(stage_id)] = {"won": false, "won_brisa": false, "max_moon": -1,
				"best_time": 0.0, "endless_best": 0.0}
	return all[String(stage_id)]
