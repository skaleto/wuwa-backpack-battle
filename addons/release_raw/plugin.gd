@tool
extends EditorPlugin
var exporter
func _enter_tree():
 exporter=preload("res://addons/release_raw/raw_export.gd").new()
 add_export_plugin(exporter)
func _exit_tree():remove_export_plugin(exporter)
