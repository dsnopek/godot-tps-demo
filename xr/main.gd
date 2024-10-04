extends Node3D

func _ready() -> void:
	randomize()


func _on_menu_replace_main_scene(resource) -> void:
	call_deferred("change_scene_to_file", resource)


func change_scene_to_file(resource : Resource):
	var node = resource.instantiate()

	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_child(node)

