extends Node
## Banco de dados do jogo: lê os JSON de res://data (plano 10.4).
## Os dados ficam em JSON, e não em .tres, para que diffs e validações automáticas
## sejam simples e o balanceamento possa ser feito sem o editor.

const FILES := ["heroes", "weapons", "passives", "enemies", "bosses", "stages", "kami",
		"powerups", "achievements", "missions", "items", "shop", "story"]

var heroes: Dictionary = {}
var weapons: Dictionary = {}
var passives: Dictionary = {}
var enemies: Dictionary = {}
var bosses: Dictionary = {}
var stages: Dictionary = {}
var kami: Dictionary = {}
var powerups: Dictionary = {}
var achievements: Dictionary = {}
## Missões do Santuário além das conquistas (data/missions.json; ver MissionBook).
var missions: Dictionary = {}
var items: Dictionary = {}
var shop: Dictionary = {}
var story: Dictionary = {}
## Diálogos antes dos chefes (data/dialogues.json, um bloco por id de chefe; ver DialogueScript).
## Sem o arquivo, nenhum chefe tem diálogo.
var dialogues: Dictionary = {}
## Listas na ordem do arquivo (a ordem importa para menus e sorteios determinísticos).
var order: Dictionary = {}
var errors: PackedStringArray = []


func _ready() -> void:
	load_all()


func load_all() -> void:
	errors.clear()
	for name: String in FILES:
		var path := "res://data/%s.json" % name
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			errors.append("arquivo vazio ou ausente: " + path)
			continue
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_ARRAY:
			errors.append("não é uma lista JSON: " + path)
			continue
		var table: Dictionary = {}
		var ids: Array[StringName] = []
		for entry: Variant in parsed:
			var row: Dictionary = entry
			var id := StringName(String(row.get("id", "")))
			if id == &"":
				errors.append("%s: entrada sem id" % name)
				continue
			if table.has(id):
				errors.append("%s: id repetido %s" % [name, id])
			row["id"] = id
			table[id] = row
			ids.append(id)
		set(name, table)
		order[name] = ids
	dialogues = _load_dialogues()
	for message: String in errors:
		push_error("DB: " + message)


## data/dialogues.json é um objeto {id do chefe: {"lines": [...]}} e é opcional.
func _load_dialogues() -> Dictionary:
	var path := "res://data/dialogues.json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("não é um objeto JSON: " + path)
		return {}
	return parsed


func ids(table: String) -> Array[StringName]:
	var list: Array[StringName] = []
	list.assign(order.get(table, []))
	return list


func weapon(id: StringName) -> Dictionary:
	return weapons.get(id, {})


func enemy(id: StringName) -> Dictionary:
	return enemies.get(id, {})


func stage(id: StringName) -> Dictionary:
	return stages.get(id, {})
