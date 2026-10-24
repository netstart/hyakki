extends Node
## Progresso do jogador (plano 10.10): JSON em user://save.json, com backup e migração
## por versão. A gravação escreve primeiro num arquivo temporário e só então troca,
## para um app morto no meio da gravação não corromper o save (teste 14.2).

signal saved
signal unlocked(kind: String, id: StringName)

const PATH := "user://save.json"
const BACKUP_PATH := "user://save.bak"
const TEMP_PATH := "user://save.tmp"
## Arquivos dos testes de integração (use_test_files): o save do jogador nunca é tocado.
const TEST_PATHS := ["user://test_save.json", "user://test_save.bak", "user://test_save.tmp"]
const VERSION := 1

var data: Dictionary = {}
## Arquivos em uso: os do jogo (PATH, BACKUP_PATH, TEMP_PATH) ou os dos testes.
var path: String = PATH
var backup_path: String = BACKUP_PATH
var temp_path: String = TEMP_PATH
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
		"unlocked": {
			"heroes": ["aki", "kenta", "hana", "goro", "rin", "tora", "yuki"],
			"weapons": [], "passives": [], "stages": ["village"], "cosmetics": [], "kami": [],
		},
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


## Testes: passa a ler e gravar nos TEST_PATHS, começando de um perfil novo. Mesmo um
## teste interrompido no meio não mexe no save do jogador.
func use_test_files() -> void:
	path = TEST_PATHS[0]
	backup_path = TEST_PATHS[1]
	temp_path = TEST_PATHS[2]
	for file: String in TEST_PATHS:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	load_profile()


func load_profile() -> void:
	recovered_from_backup = false
	var loaded := _read(path)
	if loaded.is_empty() and FileAccess.file_exists(path):
		loaded = _read(backup_path)
		recovered_from_backup = not loaded.is_empty()
	data = migrate(loaded) if not loaded.is_empty() else default_profile()
	_reapply_achievement_unlocks()


## Recompensas de conquista que ganharam desbloqueios novos chegam a saves antigos. Não
## grava: a correção é refeita a cada carga (idempotente) e vai para o disco na próxima
## gravação normal. No início do jogo o DB (autoload seguinte) ainda não leu os JSON.
func _reapply_achievement_unlocks() -> void:
	if DB.is_node_ready():
		MetaProgress.reapply_achievement_unlocks()
	elif not DB.ready.is_connected(MetaProgress.reapply_achievement_unlocks):
		DB.ready.connect(MetaProgress.reapply_achievement_unlocks, CONNECT_ONE_SHOT)


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
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: não abriu " + temp_path)
		return
	file.store_string(text)
	file.close()
	var dir := DirAccess.open("user://")
	if FileAccess.file_exists(path):
		dir.copy(path, backup_path)
	dir.rename(temp_path, path)
	saved.emit()


func reset_profile() -> void:
	data = default_profile()
	save_profile()


func _read(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
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


## Libera todos os heróis no perfil atual. Chamado apenas pela inicialização de debug.
func unlock_all_heroes() -> bool:
	var changed := false
	for id: StringName in DB.ids("heroes"):
		if unlock("heroes", id):
			changed = true
	return changed


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
