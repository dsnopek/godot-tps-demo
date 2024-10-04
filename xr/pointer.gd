extends Node3D

@export var composition_layer: OpenXRCompositionLayer
@export var button_action : String = "select"

const NO_INTERSECTION = Vector2(-1.0, -1.0)

var was_pressed : bool = false
var was_intersect : Vector2 = NO_INTERSECTION

# Convert the intersect point reurned by intersects_ray to local coords in the viewport.
func _intersect_to_viewport_pos(intersect : Vector2) -> Vector2i:
	if composition_layer and composition_layer.layer_viewport and intersect != NO_INTERSECTION:
		var pos : Vector2 = intersect * Vector2(composition_layer.layer_viewport.size)
		return Vector2i(pos)
	else:
		return Vector2i(-1, -1)

func _process(_delta):
	var controller = get_parent()
	if not controller or not controller is XRController3D:
		return
	if not composition_layer or not composition_layer.layer_viewport:
		return
	var layer_viewport: SubViewport = composition_layer.layer_viewport

	var controller_t : Transform3D = controller.global_transform
	var intersect : Vector2 = composition_layer.intersects_ray(controller_t.origin, -controller_t.basis.z)

	if intersect != NO_INTERSECTION:
		var is_pressed : bool = controller.is_button_pressed(button_action)

		if was_intersect != NO_INTERSECTION and intersect != was_intersect:
			# Pointer moved
			var event : InputEventMouseMotion = InputEventMouseMotion.new()
			var from : Vector2 = _intersect_to_viewport_pos(was_intersect)
			var to : Vector2 = _intersect_to_viewport_pos(intersect)
			if was_pressed:
				event.button_mask = MOUSE_BUTTON_MASK_LEFT
			event.relative = to - from
			event.position = to
			layer_viewport.push_input(event)

		if not is_pressed and was_pressed:
			# Button was let go?
			var event : InputEventMouseButton = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = false
			event.position = _intersect_to_viewport_pos(intersect)
			layer_viewport.push_input(event)

		elif is_pressed and not was_pressed:
			# Button was pressed?
			var event : InputEventMouseButton = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.button_mask = MOUSE_BUTTON_MASK_LEFT
			event.pressed = true
			event.position = _intersect_to_viewport_pos(intersect)
			layer_viewport.push_input(event)

		was_pressed = is_pressed
		was_intersect = intersect
		visible = true

	else:
		was_pressed = false
		was_intersect = NO_INTERSECTION
		visible = false
