@tool
extends EditorScenePostImportPlugin

const DEDUPLICATE_MESHES_OPTION = "3d_mesh_deduplicator/deduplicate_meshes"
const CONVERT_TO_MULTIMESH_OPTION = "3d_mesh_deduplicator/convert_to_multimesh"
const MAXIMUM_MULTIMESH_DISTANCE_OPTION = "3d_mesh_deduplicator/maximum_multimesh_distance"


func _get_import_options(path: String) -> void:
	add_import_option_advanced(Variant.Type.TYPE_BOOL, DEDUPLICATE_MESHES_OPTION, true)
	add_import_option_advanced(Variant.Type.TYPE_BOOL, CONVERT_TO_MULTIMESH_OPTION, false)
	add_import_option_advanced(Variant.Type.TYPE_FLOAT, MAXIMUM_MULTIMESH_DISTANCE_OPTION, 0.0)


func _post_process(scene: Node) -> void:
	if get_option_value(DEDUPLICATE_MESHES_OPTION):
		_deduplicate_meshes(scene)

	if get_option_value(CONVERT_TO_MULTIMESH_OPTION):
		_convert_duplicates_to_multimesh(scene, get_option_value(MAXIMUM_MULTIMESH_DISTANCE_OPTION))


func _generate_mesh_uid(mesh: ArrayMesh) -> int:
	var surface_count = mesh.get_surface_count()
	var surfaces := []
	for i in surface_count:
		surfaces.append_array(mesh.surface_get_arrays(i))
	return surfaces.hash()


func _deduplicate_meshes(scene: Node) -> void:
	var start_time := Time.get_ticks_msec()
	var duplicate_count := 0

	var instances: Array[Node] = scene.find_children("*", "MeshInstance3D")
	var mesh_library := {}

	for instance: MeshInstance3D in instances:
		var mesh: ArrayMesh = (instance as MeshInstance3D).mesh as ArrayMesh
		var mesh_uid := _generate_mesh_uid(mesh)
		var replacement_mesh: ArrayMesh = mesh_library.get(mesh_uid)
		if replacement_mesh:
			duplicate_count += 1
			instance.mesh = replacement_mesh
		else:
			mesh_library[mesh_uid] = mesh

	var total_time_sec: float = (Time.get_ticks_msec() - start_time) / 1000.0
	print("Scanned %s meshes and removed %s duplicates in %s seconds" % [instances.size(), duplicate_count, total_time_sec])


func _convert_duplicates_to_multimesh(scene: Node, maximum_distance: float) -> void:
	var start_time := Time.get_ticks_msec()
	var conversion_count: int = 0
	var multimesh_count: int = 0

	var instances: Array[Node] = scene.find_children("*", "MeshInstance3D")
	var instances_by_mesh := {}

	for instance in instances:
		if !instances_by_mesh.has(instance.mesh):
			instances_by_mesh[instance.mesh] = []
		instances_by_mesh[instance.mesh].push_back(instance)

	for dups in instances_by_mesh.values():
		var groups = group_mesh_instances_by_distance(dups, maximum_distance)
		for group in groups:
			if group.size() <= 1:
				continue

			var group_center: Vector3
			for instance in group:
				group_center += _get_global_position(instance)
			group_center = group_center / float(group.size())

			var multimesh_instance := MultiMeshInstance3D.new()
			multimesh_instance.position = group_center
			scene.add_child(multimesh_instance)
			multimesh_instance.owner = scene

			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = group[0].mesh
			multimesh.instance_count = group.size()

			for i in range(group.size()):
				var instance = group[i]

				var transform := _get_global_transform(instance)
				transform.origin -= group_center

				multimesh.set_instance_transform(i, transform)

				for child in instance.get_children():
					var child_transform = _get_global_transform(child)
					child_transform.origin -= group_center

					child.owner = null
					instance.remove_child(child)
					multimesh_instance.add_child(child)
					child.owner = scene

					child.transform = child_transform

				var parent = instance.get_parent()
				if parent != null:
					parent.remove_child(instance)
				instance.queue_free()

			multimesh_instance.multimesh = multimesh

			conversion_count += group.size()
			multimesh_count += 1

	var total_time_sec: float = (Time.get_ticks_msec() - start_time) / 1000.0
	print("Converted %s MeshInstance3D's into %s MultiMeshInstance3Ds in %s seconds" % [conversion_count, multimesh_count, total_time_sec])


func _get_global_transform(node: Node3D) -> Transform3D:
	var transform := node.transform

	var parent: Node3D = node.get_parent() as Node3D
	if parent:
		transform = _get_global_transform(parent) * transform

	return transform


func _get_global_position(node: Node3D) -> Vector3:
	var transform: Transform3D = _get_global_transform(node)
	return transform.origin


func group_mesh_instances_by_distance(instances: Array, maximum_distance: float) -> Array:
	if is_zero_approx(maximum_distance):
		return [instances]

	var groups := []

	for instance in instances:
		var added := false

		for group in groups:
			if is_within_distance(group, _get_global_position(instance), maximum_distance):
				group.append(instance)
				added = true
				break

		if not added:
			groups.push_back([instance])

	return groups


func is_within_distance(group: Array, position: Vector3, max_distance: float) -> bool:
	for instance in group:
		if _get_global_position(instance).distance_to(position) <= max_distance:
			return true
	return false
