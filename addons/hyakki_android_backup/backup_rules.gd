@tool
extends RefCounted
## Auto Backup do Android (Google Drive do jogador, até 25 MB, e troca de aparelho): só o progresso
## (SaveManager.PATH e BACKUP_PATH) e as opções (Settings.PATH) entram. Com includes explícitos, todo o
## resto do app fica de fora (shared_prefs do consentimento UMP/AdMob, bancos, caches, save.tmp, etc.).
##   - res/xml/hyakki_backup_rules.xml: android:fullBackupContent (Android 6 a 11);
##   - res/xml/hyakki_data_extraction_rules.xml: android:dataExtractionRules (Android 12+), com
##     <cloud-backup> e <device-transfer>;
##   - src/standardDebug|standardRelease/AndroidManifest.xml: o manifesto da variante tem prioridade
##     sobre o do build type (src/debug|release, regerado pelo Godot com allowBackup="false") no merge
##     do Gradle, e o tools:replace troca os atributos.
## user:// no Android é Context.getFilesDir() (GodotIO.getDataDir), que é o domain="file" das regras.
## Funções puras (sem autoloads), testadas por tests/android_backup_tests.gd.

const SAVE_SCRIPT := "res://scripts/autoload/save_manager.gd"
const SETTINGS_SCRIPT := "res://scripts/autoload/settings.gd"
## [script, constante]: os caminhos reais do jogo, lidos das constantes (fonte única).
const SOURCES := [[SAVE_SCRIPT, "PATH"], [SAVE_SCRIPT, "BACKUP_PATH"], [SETTINGS_SCRIPT, "PATH"]]
const BACKUP_RULES := "hyakki_backup_rules"
const EXTRACTION_RULES := "hyakki_data_extraction_rules"
## Flavor "standard" do template Godot + build types debug e release.
const VARIANTS := ["standardDebug", "standardRelease"]
const DEFAULT_BUILD_DIR := "res://android/build"
const HEADER := "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" \
		+ "<!-- Gerado pelo addon hyakki_android_backup a cada export Android. Não edite. -->\n"


## Nomes relativos a user:// (= getFilesDir() no Android) dos arquivos do backup. Vazio se alguma
## constante sumiu ou não está em user:// (aí o export não liga o backup).
static func backup_files() -> PackedStringArray:
	var files := PackedStringArray()
	for source: Array in SOURCES:
		var script := load(str(source[0])) as Script
		if script == null:
			return PackedStringArray()
		var path := str(script.get_script_constant_map().get(source[1], ""))
		var name := path.trim_prefix("user://")
		if not path.begins_with("user://") or name.is_empty() or name.contains("/"):
			return PackedStringArray()
		files.append(name)
	return files


static func includes_xml(files: PackedStringArray, indent: String) -> String:
	var lines := ""
	for file: String in files:
		lines += "%s<include domain=\"file\" path=\"%s\" />\n" % [indent, file.xml_escape(true)]
	return lines


## android:fullBackupContent (Android 11 ou anterior).
static func full_backup_content_xml(files: PackedStringArray) -> String:
	return HEADER + "<full-backup-content>\n" + includes_xml(files, "    ") + "</full-backup-content>\n"


## android:dataExtractionRules (Android 12+): nuvem e troca de aparelho com os mesmos arquivos.
static func data_extraction_rules_xml(files: PackedStringArray) -> String:
	var body := includes_xml(files, "        ")
	return HEADER + "<data-extraction-rules>\n" \
			+ "    <cloud-backup>\n" + body + "    </cloud-backup>\n" \
			+ "    <device-transfer>\n" + body + "    </device-transfer>\n" \
			+ "</data-extraction-rules>\n"


## Manifesto das variantes: só o <application> com o backup ligado.
static func variant_manifest_xml() -> String:
	return HEADER + "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\"\n" \
			+ "    xmlns:tools=\"http://schemas.android.com/tools\">\n" \
			+ "    <application\n" \
			+ "        android:allowBackup=\"true\"\n" \
			+ "        android:fullBackupContent=\"@xml/%s\"\n" % BACKUP_RULES \
			+ "        android:dataExtractionRules=\"@xml/%s\"\n" % EXTRACTION_RULES \
			+ "        tools:replace=\"android:allowBackup,android:fullBackupContent,"\
			+ "android:dataExtractionRules\" />\n" \
			+ "</manifest>\n"


## Arquivos a escrever, relativos a android/build. Vazio se a lista de arquivos estiver vazia.
static func outputs(files: PackedStringArray) -> Dictionary:
	if files.is_empty():
		return {}
	var result := {
		"res/xml/%s.xml" % BACKUP_RULES: full_backup_content_xml(files),
		"res/xml/%s.xml" % EXTRACTION_RULES: data_extraction_rules_xml(files),
	}
	for variant: String in VARIANTS:
		result["src/%s/AndroidManifest.xml" % variant] = variant_manifest_xml()
	return result


## Pasta do projeto Gradle: a opção gradle_build/gradle_build_directory do preset ou res://android.
static func build_dir(gradle_build_directory: String) -> String:
	if gradle_build_directory.strip_edges().is_empty():
		return DEFAULT_BUILD_DIR
	return gradle_build_directory.strip_edges().path_join("build")


## Escreve tudo em build_path (caminho absoluto). Sem a lista de arquivos, apaga os manifestos das
## variantes, e o app fica com o padrão do Godot (allowBackup="false").
static func write_all(build_path: String) -> Error:
	if not DirAccess.dir_exists_absolute(build_path):
		return ERR_FILE_NOT_FOUND
	var files := backup_files()
	if files.is_empty():
		for variant: String in VARIANTS:
			var manifest := build_path.path_join("src/%s/AndroidManifest.xml" % variant)
			if FileAccess.file_exists(manifest):
				DirAccess.remove_absolute(manifest)
		return ERR_INVALID_DATA
	var contents := outputs(files)
	for relative: String in contents:
		var target := build_path.path_join(relative)
		var error := DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		if error != OK:
			return error
		var file := FileAccess.open(target, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		file.store_string(str(contents[relative]))
		file.close()
	return OK
