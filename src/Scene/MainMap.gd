## 负责主地图中的工厂命中、拖拽、网格吸附和可见区域约束。
##
## 鼠标与手柄输入均由 [VirtualCursor] 转换为逻辑视口坐标。本脚本只消费
## 统一指针信号，并在交互边界处将坐标转换为当前 Camera2D 对应的世界坐标。
extends Node2D

## 主地图中可由统一指针拖拽的节点分组。
const MOVABLE_FACTORY_GROUP: StringName = &"movable_factory"

## 是否在拖拽时把工厂左上角吸附到全局网格。
@export var snap_to_grid: bool = true
## 是否限制工厂完整处于当前可见世界区域内。
@export var keep_inside_viewport: bool = true

## 当前正在拖拽的工厂；没有拖拽时为 null。
var _dragged_factory: Control
## 指针按下位置相对工厂左上角的偏移，防止拖拽开始时节点跳动。
var _drag_offset: Vector2
## 拖拽开始前的位置，用于 Escape 取消操作。
var _drag_start_position: Vector2

## 当前场景中的统一指针输入节点。
@onready var _virtual_cursor: VirtualCursor = $VirtualCursor


## 连接统一指针信号，建立唯一的地图指针输入入口。
func _ready() -> void:
	# 鼠标和手柄都只通过 VirtualCursor 的统一指针信号进入地图逻辑。
	_virtual_cursor.pointer_moved.connect(_handle_pointer_motion)
	_virtual_cursor.pointer_pressed.connect(_handle_pointer_pressed)
	_virtual_cursor.pointer_released.connect(_handle_pointer_released)


## 在 UI 和快捷键均未消费 Escape 时取消当前拖拽。
##
## 忽略按键回显，确保一次物理按下只执行一次取消操作。
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_cancel_drag()


## 节点退出场景时恢复默认系统光标形状。
func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## 将视口坐标下的按下事件转换到世界空间并尝试开始拖拽。
func _handle_pointer_pressed(viewport_position: Vector2) -> void:
	var world_position := _viewport_to_world(viewport_position)
	_start_drag(world_position)


## 将视口坐标下的释放事件转换到世界空间并结束当前拖拽。
func _handle_pointer_released(viewport_position: Vector2) -> void:
	var world_position := _viewport_to_world(viewport_position)
	_finish_drag(world_position)


## 处理统一指针移动。
##
## 拖拽期间更新工厂位置并消费当前鼠标移动事件；未拖拽时仅更新系统光标
## 形状。手柄按帧移动不对应原始事件，此时标记处理状态不会影响其他事件。
func _handle_pointer_motion(viewport_position: Vector2) -> void:
	var world_position := _viewport_to_world(viewport_position)
	if is_instance_valid(_dragged_factory):
		_move_dragged_factory(world_position)
		# 鼠标拖拽期间阻止同一移动事件继续传递给下层交互。
		get_viewport().set_input_as_handled()
	else:
		_update_cursor(world_position)


## 在指定世界坐标命中最上层可移动工厂并建立拖拽状态。
##
## 已有有效拖拽或当前位置未命中工厂时不执行任何操作。开始拖拽时会保存
## 指针相对工厂左上角的偏移和原始位置，并把工厂移动到同级节点最前方。
func _start_drag(mouse_world_position: Vector2) -> void:
	# 忽略重复按下，保留首次按下时记录的偏移和取消位置。
	if is_instance_valid(_dragged_factory):
		return

	var factory := _find_factory_at(mouse_world_position)
	if factory == null:
		return

	_dragged_factory = factory
	_drag_offset = mouse_world_position - factory.global_position
	_drag_start_position = factory.global_position
	factory.move_to_front()
	Input.set_default_cursor_shape(Input.CURSOR_MOVE)
	get_viewport().set_input_as_handled()


## 将工厂移动到最终指针位置，然后清空拖拽状态。
##
## 没有有效拖拽时释放事件不产生副作用。
func _finish_drag(mouse_world_position: Vector2) -> void:
	if not is_instance_valid(_dragged_factory):
		return

	_move_dragged_factory(mouse_world_position)
	_dragged_factory = null
	_update_cursor(mouse_world_position)
	get_viewport().set_input_as_handled()


## 放弃当前拖拽并将工厂恢复到按下前的位置。
func _cancel_drag() -> void:
	if not is_instance_valid(_dragged_factory):
		return

	_dragged_factory.global_position = _drag_start_position
	_dragged_factory = null
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	get_viewport().set_input_as_handled()


## 根据当前世界空间指针位置更新被拖拽工厂的左上角坐标。
##
## 先减去按下偏移，再按配置执行网格吸附，最后限制在可见世界区域内。
func _move_dragged_factory(mouse_world_position: Vector2) -> void:
	var target_position := mouse_world_position - _drag_offset
	if snap_to_grid:
		target_position = GlobalValue.to_approximate_coordinates(target_position)
	if keep_inside_viewport:
		target_position = _clamp_factory_position(_dragged_factory, target_position)

	_dragged_factory.global_position = target_position


## 返回指定世界坐标下最上层、可见且属于可移动分组的工厂。
##
## 没有命中时返回 [code]null[/code]。
func _find_factory_at(mouse_world_position: Vector2) -> Control:
	var factories := get_tree().get_nodes_in_group(MOVABLE_FACTORY_GROUP)
	# move_to_front() 会调整场景树顺序，因此从后向前搜索可优先命中顶层工厂。
	for index in range(factories.size() - 1, -1, -1):
		var factory := factories[index] as Control
		if factory != null and factory.is_visible_in_tree():
			if factory.get_global_rect().has_point(mouse_world_position):
				return factory

	return null


## 约束工厂左上角坐标，使工厂完整位于当前可见世界区域内。
##
## 开启网格吸附时，边界本身也会向内对齐到网格，避免最终约束破坏吸附结果。
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


## 返回当前逻辑视口经画布反变换后覆盖的世界空间矩形。
func _get_visible_world_rect() -> Rect2:
	# 可见矩形需要反变换到世界空间，才能兼容 Camera2D 平移和缩放。
	var inverse_canvas_transform := get_viewport().get_canvas_transform().affine_inverse()
	var top_left := inverse_canvas_transform * Vector2.ZERO
	var bottom_right := inverse_canvas_transform * get_viewport_rect().size
	return Rect2(top_left, bottom_right - top_left).abs()


## 将 [VirtualCursor] 提供的逻辑视口坐标转换为世界坐标。
func _viewport_to_world(viewport_position: Vector2) -> Vector2:
	# VirtualCursor 对外统一使用视口坐标；地图只在交互边界处转换一次。
	return get_viewport().get_canvas_transform().affine_inverse() * viewport_position


## 根据世界坐标下是否存在可移动工厂更新系统光标形状。
func _update_cursor(mouse_world_position: Vector2) -> void:
	var cursor_shape := Input.CURSOR_MOVE \
		if _find_factory_at(mouse_world_position) != null \
		else Input.CURSOR_ARROW
	Input.set_default_cursor_shape(cursor_shape)
