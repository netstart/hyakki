class_name LicenseIndex
extends RefCounted
## Lê licenses/index.json (gerado por tools/build_license_index.py a partir do registro)
## e lista também os componentes de terceiros do motor via Engine (plano 12.6.5).

const PATH := "res://licenses/index.json"

static var _entries: Array[Dictionary] = []


static func entries() -> Array[Dictionary]:
	if not _entries.is_empty():
		return _entries
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) == TYPE_ARRAY:
		for item: Variant in parsed:
			_entries.append(item as Dictionary)
	return _entries


## Componentes de terceiros do Godot da versão exportada (FreeType, HarfBuzz, ...).
static func engine_components() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for info: Dictionary in Engine.get_copyright_info():
		var parts: PackedStringArray = []
		var licenses: PackedStringArray = []
		for part: Dictionary in info.get("parts", []):
			for holder: Variant in part.get("copyright", []):
				parts.append(String(holder))
			licenses.append(String(part.get("license", "")))
		list.append({"name": String(info.get("name", "")), "author": "; ".join(parts),
				"license_id": " / ".join(licenses)})
	return list


static func license_text(id: String) -> String:
	var texts := Engine.get_license_info()
	if texts.has(id):
		return String(texts[id])
	return ""


static func read_file(path: String) -> String:
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)
