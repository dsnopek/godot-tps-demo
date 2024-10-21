@tool
extends EditorPlugin

const MeshDeduplicator = preload("mesh_deduplicator.gd")

var mesh_deduplicator: MeshDeduplicator

func _enter_tree() -> void:
	mesh_deduplicator = MeshDeduplicator.new()
	add_scene_post_import_plugin(mesh_deduplicator)

func _exit_tree() -> void:
	remove_scene_post_import_plugin(mesh_deduplicator)
