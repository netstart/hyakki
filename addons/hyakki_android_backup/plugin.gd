@tool
extends EditorPlugin
## Registra o export plugin que liga o Auto Backup do Android (veja backup_rules.gd).

const ExportPlugin := preload("res://addons/hyakki_android_backup/export_plugin.gd")

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = ExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null
