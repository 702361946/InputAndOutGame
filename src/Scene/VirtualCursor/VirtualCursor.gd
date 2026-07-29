extends CanvasLayer

## 将鼠标和手柄输入统一转换为视口坐标下的指针事件。
##
## 对外只暴露一套位置、按下和释放信号。所有信号坐标均使用逻辑视口坐标，
## 世界场景应在消费信号时自行完成视口坐标到世界坐标的转换。
class_name VirtualCursor

## InputMap 中表示指针主按钮的动作名称。
const CLICK_ACTION: StringName = &"VCClick"

## 当前负责控制指针的输入设备类型。
##
## 输入模式只描述设备来源，不控制系统鼠标或虚拟光标的可见性。
enum InputMode {
	KEYBOARD_MOUSE,
	CONTROLLER,
}

## 指针位置发生变化时发出，参数使用逻辑视口坐标。
signal pointer_moved(viewport_position: Vector2)
## 点击动作由未按下切换为按下时发出。
signal pointer_pressed(viewport_position: Vector2)
## 点击动作由按下切换为释放时发出。
signal pointer_released(viewport_position: Vector2)
## 键鼠和手柄输入模式发生切换时发出。
signal input_mode_changed(mode: InputMode)

## 手柄控制虚拟光标时的移动速度，单位为逻辑视口像素/秒。
@export_range(1.0, 4000.0, 1.0) var controller_speed: float = 640.0

## 当前指针在逻辑视口中的坐标。
var viewport_position: Vector2 = Vector2.ZERO
## 当前负责控制指针的输入模式。
var input_mode: InputMode = InputMode.KEYBOARD_MOUSE

## 键鼠和手柄模式下始终显示的虚拟光标贴图。
##
## 贴图中心圆点是逻辑热点，必须与 [member viewport_position] 保持重合。
@onready var _cursor_sprite: Sprite2D = $Sprite2D


## 初始化指针位置、视口尺寸监听和固定的虚拟光标显示策略。
func _ready() -> void:
	get_viewport().size_changed.connect(_handle_viewport_size_changed)
	_set_viewport_position(get_viewport().get_mouse_position(), false)
	_apply_cursor_display()


## 节点退出场景时恢复系统光标，避免隐藏状态泄漏到后续场景。
func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## 根据鼠标是否位于游戏客户区内切换系统鼠标。
##
## 虚拟光标被限制在逻辑视口内，无法进入系统窗口标题栏。鼠标离开客户区时
## 临时显示系统鼠标，使窗口标题栏和边框仍可拖动；重新进入后再次隐藏。
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_MOUSE_EXIT:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		NOTIFICATION_WM_MOUSE_ENTER:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


## 将原始输入事件转换为统一指针状态和信号。
##
## 鼠标按钮必须先同步事件携带的坐标，再判断 [constant CLICK_ACTION]。
## 这样从手柄模式直接点击鼠标时，无需先产生移动事件也能恢复键鼠模式。
## 非点击鼠标按钮只更新输入模式和位置，不会发出按下或释放信号。
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_use_mouse_position(event.position)
		return

	if event is InputEventMouseButton:
		_use_mouse_position(event.position)

	var click_pressed := event.is_action_pressed(CLICK_ACTION)
	var click_released := event.is_action_released(CLICK_ACTION)
	if not click_pressed and not click_released:
		return

	# 鼠标分支已在上方同步模式；手柄点击没有位置事件，需要在此切换。
	if event is InputEventJoypadButton:
		_set_input_mode(InputMode.CONTROLLER)

	if click_pressed:
		pointer_pressed.emit(viewport_position)
	else:
		pointer_released.emit(viewport_position)


## 按帧轮询虚拟光标方向动作，并按秒速度累计手柄位移。
##
## [param delta] 为上一帧经过的秒数。摇杆回中时保留当前位置和输入模式。
func _process(delta: float) -> void:
	# 连续轮询摇杆轴，保证按住方向时按帧持续移动。
	var input_vector := Input.get_vector(
		"VCTo_left",
		"VCTo_right",
		"VCTo_up",
		"VCTo_down"
	)
	if input_vector.is_zero_approx():
		return

	_set_input_mode(InputMode.CONTROLLER)
	var next_position := viewport_position + input_vector * controller_speed * delta
	_set_viewport_position(next_position, true)


## 切换到键鼠模式，并使用鼠标事件中的逻辑视口坐标更新指针。
##
## 仅当约束后的位置实际变化时才会发出 [signal pointer_moved]。
func _use_mouse_position(mouse_position: Vector2) -> void:
	_set_input_mode(InputMode.KEYBOARD_MOUSE)
	# 按钮事件也携带坐标；即使没有先移动鼠标，也必须先同步位置。
	_set_viewport_position(mouse_position, true)


## 约束并保存指针位置，同时把虚拟光标中心热点移动到该坐标。
##
## [param emit_moved] 为 [code]true[/code] 时，位置实际变化后发出
## [signal pointer_moved]；初始化时可传入 [code]false[/code] 避免无意义通知。
func _set_viewport_position(new_position: Vector2, emit_moved: bool) -> void:
	# 所有输入源都在这里完成边界约束，避免信号携带越界坐标。
	var clamped_position := _clamp_to_viewport(new_position)
	if clamped_position.is_equal_approx(viewport_position):
		return

	viewport_position = clamped_position
	_cursor_sprite.position = viewport_position
	if emit_moved:
		pointer_moved.emit(viewport_position)


## 幂等地切换输入模式并发出模式变化信号。
##
## 模式变化不会改变光标显隐；鼠标和手柄始终共用虚拟光标贴图。
func _set_input_mode(new_mode: InputMode) -> void:
	if input_mode == new_mode:
		return

	input_mode = new_mode
	input_mode_changed.emit(input_mode)


## 在游戏客户区内隐藏系统鼠标并显示虚拟光标贴图。
##
## 键鼠模式下仍使用鼠标事件更新 [member viewport_position]，但只渲染虚拟光标。
func _apply_cursor_display() -> void:
	_cursor_sprite.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


## 将目标位置限制在逻辑视口有效像素范围内。
##
## 返回范围为 [code](0, 0)[/code] 到
## [code](viewport_width - 1, viewport_height - 1)[/code]。
func _clamp_to_viewport(target_position: Vector2) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var maximum_position := Vector2(
		maxf(viewport_size.x - 1.0, 0.0),
		maxf(viewport_size.y - 1.0, 0.0)
	)
	return target_position.clamp(Vector2.ZERO, maximum_position)


## 视口尺寸变化后重新约束当前位置。
##
## 仅手柄模式需要在位置因约束发生变化时通知场景消费者。
func _handle_viewport_size_changed() -> void:
	_set_viewport_position(viewport_position, input_mode == InputMode.CONTROLLER)
