extends Node2D

const MOVABLE_FACTORY_GROUP: StringName = &"movable_factory"

@export var snap_to_grid: bool = true
@export var keep_inside_viewport: bool = true

var _dragged_factory: Control
var _drag_offset: Vector2
var _drag_start_position: Vector2


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventKey:
		_handle_key(event)


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	var mouse_world_position := _viewport_to_world(event.position)
	if event.pressed:
		_start_drag(mouse_world_position)
	else:
		_finish_drag(mouse_world_position)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var mouse_world_position := _viewport_to_world(event.position)
	if is_instance_valid(_dragged_factory):
		_move_dragged_factory(mouse_world_position)
		get_viewport().set_input_as_handled()
	else:
		_update_cursor(mouse_world_position)


func _handle_key(event: InputEventKey) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel_drag()


func _start_drag(mouse_world_position: Vector2) -> void:
	var factory := _find_factory_at(mouse_world_position)
	if factory == null:
		return

	_dragged_factory = factory
	_drag_offset = mouse_world_position - factory.global_position
	_drag_start_position = factory.global_position
	factory.move_to_front()
	Input.set_default_cursor_shape(Input.CURSOR_MOVE)
	get_viewport().set_input_as_handled()


func _finish_drag(mouse_world_position: Vector2) -> void:
	if not is_instance_valid(_dragged_factory):
		return

	_move_dragged_factory(mouse_world_position)
	_dragged_factory = null
	_update_cursor(mouse_world_position)
	get_viewport().set_input_as_handled()


func _cancel_drag() -> void:
	if not is_instance_valid(_dragged_factory):
		return

	_dragged_factory.global_position = _drag_start_position
	_dragged_factory = null
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	get_viewport().set_input_as_handled()


func _move_dragged_factory(mouse_world_position: Vector2) -> void:
	var target_position := mouse_world_position - _drag_offset
	if snap_to_grid:
		target_position = GlobalValue.to_approximate_coordinates(target_position)
	if keep_inside_viewport:
		target_position = _clamp_factory_position(_dragged_factory, target_position)

	_dragged_factory.global_position = target_position


func _find_factory_at(mouse_world_position: Vector2) -> Control:
	var factories := get_tree().get_nodes_in_group(MOVABLE_FACTORY_GROUP)
	for index in range(factories.size() - 1, -1, -1):
		var factory := factories[index] as Control
		if factory != null and factory.is_visible_in_tree():
			if factory.get_global_rect().has_point(mouse_world_position):
				return factory

	return null


func _clamp_factory_position(factory: Control, target_position: Vector2) -> Vector2:
	var visible_rect := _get_visible_world_rect()
	var factory_size := factory.get_global_rect().size
	var minimum_position := visible_rect.position
	var maximum_position := visible_rect.end - factory_size

	if snap_to_grid:
		var grid_size := Vector2(GlobalValue.grid_size)
		minimum_position = Vector2(
			ceilf(minimum_position.x / grid_size.x) * grid_size.x,
			ceilf(minimum_position.y / grid_size.y) * grid_size.y
		)
		maximum_position = Vector2(
			floorf(maximum_position.x / grid_size.x) * grid_size.x,
			floorf(maximum_position.y / grid_size.y) * grid_size.y
		)

	maximum_position.x = maxf(minimum_position.x, maximum_position.x)
	maximum_position.y = maxf(minimum_position.y, maximum_position.y)
	return target_position.clamp(minimum_position, maximum_position)


func _get_visible_world_rect() -> Rect2:
	var inverse_canvas_transform := get_viewport().get_canvas_transform().affine_inverse()
	var top_left := inverse_canvas_transform * Vector2.ZERO
	var bottom_right := inverse_canvas_transform * get_viewport_rect().size
	return Rect2(top_left, bottom_right - top_left).abs()


func _viewport_to_world(viewport_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * viewport_position


func _update_cursor(mouse_world_position: Vector2) -> void:
	var cursor_shape := Input.CURSOR_MOVE \
		if _find_factory_at(mouse_world_position) != null \
		else Input.CURSOR_ARROW
	Input.set_default_cursor_shape(cursor_shape)
