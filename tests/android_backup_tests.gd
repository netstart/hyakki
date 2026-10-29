extends RefCounted
## Auto Backup do Android (addons/hyakki_android_backup/backup_rules.gd):
##   - os arquivos do backup são exatamente os caminhos reais do SaveManager e do Settings;
##   - as regras (fullBackupContent e dataExtractionRules) são XML bem formado, só com includes de
##     domain="file" exatos, com <cloud-backup> e <device-transfer>, sem shared_prefs nem bancos;
##   - o manifesto das variantes liga allowBackup="true" e aponta para as duas regras;
##   - o plugin está ligado no project.godot e todo preset Android usa o build Gradle;
##   - write_all escreve os arquivos onde o Gradle os lê.
## run_unit() roda sem autoloads (tests/run_tests.gd).

const Rules := preload("res://addons/hyakki_android_backup/backup_rules.gd")
const PLUGIN_CFG := "res://addons/hyakki_android_backup/plugin.cfg"
const EXPECTED := ["save.json", "save.bak", "settings.cfg"]
const TEMP_DIR := "user://test_android_backup"

var _check: Callable


func run_unit(check: Callable) -> void:
	_check = check
	_test_files_match_game_paths()
	_test_full_backup_content()
	_test_data_extraction_rules()
	_test_variant_manifest()
	_test_outputs_and_build_dir()
	_test_project_config()
	_test_write_all()


func _ok(condition: bool, label: String) -> void:
	_check.call(condition, "backup Android: " + label)


func _constant(path: String, constant: String) -> String:
	var script := load(path) as Script
	return str(script.get_script_constant_map().get(constant, "")) if script != null else ""


func _test_files_match_game_paths() -> void:
	var files := Rules.backup_files()
	_ok(Array(files) == EXPECTED, "arquivos = save.json, save.bak, settings.cfg (%s)" % [files])
	var real := [_constant(Rules.SAVE_SCRIPT, "PATH"), _constant(Rules.SAVE_SCRIPT, "BACKUP_PATH"),
			_constant(Rules.SETTINGS_SCRIPT, "PATH")]
	_ok(real == ["user://save.json", "user://save.bak", "user://settings.cfg"],
			"constantes do SaveManager e do Settings continuam em user:// (%s)" % [real])
	for i: int in real.size():
		_ok("user://" + files[i] == real[i], "%s vem da constante do jogo" % real[i])
	var temp := _constant(Rules.SAVE_SCRIPT, "TEMP_PATH").trim_prefix("user://")
	_ok(not temp.is_empty() and not files.has(temp), "save.tmp fica fora do backup")


## Elementos do XML em ordem: {name, parent, attrs}. Vazio se o XML for mal formado.
func _parse(xml: String) -> Array[Dictionary]:
	var parser := XMLParser.new()
	var nodes: Array[Dictionary] = []
	if parser.open_buffer(xml.to_utf8_buffer()) != OK:
		return nodes
	var stack: PackedStringArray = []
	var error := parser.read()
	while error == OK:
		var type := parser.get_node_type()
		if type == XMLParser.NODE_ELEMENT:
			var attrs := {}
			for i: int in parser.get_attribute_count():
				attrs[parser.get_attribute_name(i)] = parser.get_attribute_value(i)
			var name := parser.get_node_name()
			nodes.append({"name": name, "parent": stack[-1] if not stack.is_empty() else "", "attrs": attrs})
			if not parser.is_empty():
				stack.append(name)
		elif type == XMLParser.NODE_ELEMENT_END:
			if stack.is_empty() or stack[-1] != parser.get_node_name():
				return [] as Array[Dictionary]
			stack.remove_at(stack.size() - 1)
		error = parser.read()
	if error != ERR_FILE_EOF or not stack.is_empty():
		return [] as Array[Dictionary]
	return nodes


func _includes(nodes: Array[Dictionary], parent: String) -> Array:
	var paths := []
	for node: Dictionary in nodes:
		if node["parent"] == parent and node["name"] == "include" and node["attrs"].get("domain") == "file":
			paths.append(node["attrs"].get("path"))
	return paths


## Nada além de include domain="file" com os arquivos do jogo (sem sharedpref, database, root...).
func _only_file_includes(nodes: Array[Dictionary], containers: Array, label: String) -> void:
	var clean := true
	for node: Dictionary in nodes:
		if containers.has(node["name"]):
			continue
		var attrs: Dictionary = node["attrs"]
		if node["name"] != "include" or attrs.get("domain") != "file" or not EXPECTED.has(attrs.get("path")):
			clean = false
	_ok(clean, label + ": só includes domain=\"file\" dos arquivos do jogo")
	var text := str(nodes)
	_ok(not text.contains("sharedpref") and not text.contains("database"),
			label + ": sem sharedpref nem database")


func _test_full_backup_content() -> void:
	var nodes := _parse(Rules.full_backup_content_xml(Rules.backup_files()))
	_ok(not nodes.is_empty() and nodes[0]["name"] == "full-backup-content",
			"fullBackupContent bem formado com raiz full-backup-content")
	_ok(_includes(nodes, "full-backup-content") == EXPECTED, "fullBackupContent: includes exatos")
	_only_file_includes(nodes, ["full-backup-content"], "fullBackupContent")


func _test_data_extraction_rules() -> void:
	var nodes := _parse(Rules.data_extraction_rules_xml(Rules.backup_files()))
	_ok(not nodes.is_empty() and nodes[0]["name"] == "data-extraction-rules",
			"dataExtractionRules bem formado com raiz data-extraction-rules")
	var sections := nodes.filter(func(n: Dictionary) -> bool: return n["parent"] == "data-extraction-rules")
	_ok(sections.map(func(n: Dictionary) -> String: return n["name"]) == ["cloud-backup", "device-transfer"],
			"dataExtractionRules: cloud-backup e device-transfer")
	_ok(_includes(nodes, "cloud-backup") == EXPECTED, "cloud-backup: includes exatos")
	_ok(_includes(nodes, "device-transfer") == EXPECTED, "device-transfer: includes exatos")
	_only_file_includes(nodes, ["data-extraction-rules", "cloud-backup", "device-transfer"], "dataExtractionRules")


func _test_variant_manifest() -> void:
	var nodes := _parse(Rules.variant_manifest_xml())
	var apps := nodes.filter(func(n: Dictionary) -> bool: return n["name"] == "application")
	_ok(not nodes.is_empty() and nodes[0]["name"] == "manifest" and apps.size() == 1,
			"manifesto da variante bem formado com um <application>")
	if apps.size() != 1:
		return
	var attrs: Dictionary = apps[0]["attrs"]
	_ok(attrs.get("android:allowBackup") == "true", "manifesto: allowBackup=\"true\"")
	_ok(attrs.get("android:fullBackupContent") == "@xml/" + Rules.BACKUP_RULES, "manifesto: fullBackupContent")
	_ok(attrs.get("android:dataExtractionRules") == "@xml/" + Rules.EXTRACTION_RULES,
			"manifesto: dataExtractionRules")
	var replaced := str(attrs.get("tools:replace", "")).split(",")
	_ok(replaced.has("android:allowBackup") and replaced.has("android:fullBackupContent")
			and replaced.has("android:dataExtractionRules"), "manifesto: tools:replace dos três atributos")
	_ok(nodes[0]["attrs"].get("xmlns:tools") == "http://schemas.android.com/tools", "manifesto: namespace tools")


func _test_outputs_and_build_dir() -> void:
	var outputs := Rules.outputs(Rules.backup_files())
	var keys := outputs.keys()
	keys.sort()
	_ok(keys == ["res/xml/hyakki_backup_rules.xml", "res/xml/hyakki_data_extraction_rules.xml",
			"src/standardDebug/AndroidManifest.xml", "src/standardRelease/AndroidManifest.xml"],
			"saídas: duas regras em res/xml e o manifesto das duas variantes (%s)" % [keys])
	_ok(Rules.outputs(PackedStringArray()).is_empty(), "sem arquivos: não liga o backup")
	_ok(Rules.build_dir("") == "res://android/build", "pasta Gradle padrão")
	_ok(Rules.build_dir("res://custom") == "res://custom/build", "pasta Gradle do preset")


func _test_project_config() -> void:
	var enabled: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	_ok(enabled.has(PLUGIN_CFG), "plugin ligado no project.godot")
	var presets := ConfigFile.new()
	_ok(presets.load("res://export_presets.cfg") == OK, "export_presets.cfg carregado")
	var android := 0
	for section: String in presets.get_sections():
		if section.ends_with(".options") or presets.get_value(section, "platform", "") != "Android":
			continue
		android += 1
		var options := section + ".options"
		_ok(presets.get_value(options, "gradle_build/use_gradle_build", false) == true,
				"%s usa o build Gradle (o plugin só age nele)" % presets.get_value(section, "name"))
	_ok(android > 0, "há presets Android")


func _test_write_all() -> void:
	var base := ProjectSettings.globalize_path(TEMP_DIR)
	_ok(Rules.write_all(base.path_join("nao_existe")) == ERR_FILE_NOT_FOUND, "sem android/build: não escreve")
	DirAccess.make_dir_recursive_absolute(base)
	_ok(Rules.write_all(base) == OK, "write_all escreve sem erro")
	var outputs := Rules.outputs(Rules.backup_files())
	for relative: String in outputs:
		var path := base.path_join(relative)
		_ok(FileAccess.get_file_as_string(path) == outputs[relative], "escrito: " + relative)
	_remove_tree(base)
	_ok(not DirAccess.dir_exists_absolute(base), "pasta temporária removida")


func _remove_tree(path: String) -> void:
	for dir: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(dir))
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
