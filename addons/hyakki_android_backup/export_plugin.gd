@tool
extends EditorExportPlugin
## No export Android com Gradle, antes do Gradle rodar, escreve em android/build as regras do Auto
## Backup e os manifestos das variantes standardDebug/standardRelease (backup_rules.gd). A pasta
## android/ não é versionada: tudo é recriado a cada export a partir deste addon.

const Rules := preload("res://addons/hyakki_android_backup/backup_rules.gd")


func _get_name() -> String:
	return "HyakkiAndroidBackup"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	if not bool(get_option("gradle_build/use_gradle_build")):
		return
	var build_dir := Rules.build_dir(str(get_option("gradle_build/gradle_build_directory")))
	var error := Rules.write_all(ProjectSettings.globalize_path(build_dir))
	if error != OK:
		push_error("Hyakki Android Backup: falha ao escrever as regras em %s (%s)" % [build_dir,
				error_string(error)])
