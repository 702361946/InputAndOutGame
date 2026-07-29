## 在真实 MainMap 场景中验证 VirtualCursor 输入分发和工厂拖拽。
##
## 无头模式不保证模拟鼠标事件进入窗口队列，因此测试会构造 InputEvent 并
## 直接调用 VirtualCursor._input()。场景中的真实信号连接和拖拽逻辑仍会执行。
##
## 运行命令：
## [codeblock]
## Godot_v4.7-stable_win64_console.exe --headless --path . \
##     --script res://tests/VirtualCursorInputSmokeTest.gd
## [/codeblock]
## Headless DisplayServer 不提供真实系统鼠标模式，因此相关断言仅在带窗口运行时执行。
extends SceneTree

## 被测主场景资源路径。延迟到运行阶段加载，以等待项目自动加载单例注册完成。
const MAIN_SCENE_PATH := "res://src/Scene/MainMap.tscn"
## 基础鼠标移动和点击测试使用的视口坐标。
const TEST_MOUSE_POSITION := Vector2(32.0, 32.0)
## 验证从手柄模式直接点击鼠标时使用的视口坐标。
const MODE_SWITCH_MOUSE_POSITION := Vector2(64.0, 48.0)

## 当前测试收集的失败信息；数组为空表示所有断言通过。
var _failures: Array[String] = []
## 真实主场景中的虚拟光标实例，由输入构造辅助函数共用。
var _virtual_cursor: VirtualCursor


## 将异步测试主体延迟到 SceneTree 完成初始化后执行。
func _initialize() -> void:
	call_deferred("_run")


## 实例化真实场景并依次验证信号、输入模式、移动和拖拽。
func _run() -> void:
	var main_scene := load(MAIN_SCENE_PATH) as PackedScene
	var main_map := main_scene.instantiate()
	root.add_child(main_map)
	await process_frame

	_virtual_cursor = main_map.get_node("VirtualCursor") as VirtualCursor
	var cursor_sprite := _virtual_cursor.get_node("Sprite2D") as Sprite2D
	var moved_positions: Array[Vector2] = []
	var pressed_positions: Array[Vector2] = []
	var released_positions: Array[Vector2] = []
	_virtual_cursor.pointer_moved.connect(
		func(position: Vector2) -> void: moved_positions.append(position)
	)
	_virtual_cursor.pointer_pressed.connect(
		func(position: Vector2) -> void: pressed_positions.append(position)
	)
	_virtual_cursor.pointer_released.connect(
		func(position: Vector2) -> void: released_positions.append(position)
	)
	_expect(
		cursor_sprite.visible,
		"Virtual cursor must be visible when the scene starts in mouse mode."
	)
	_expect(
		cursor_sprite.centered
			and cursor_sprite.get_rect().get_center().is_zero_approx(),
		"Virtual cursor texture center must be the logical pointer hotspot."
	)
	_expect_system_cursor_mode(
		Input.MOUSE_MODE_HIDDEN,
		"System mouse cursor must be hidden while VirtualCursor is active."
	)

	await _send_mouse_motion(TEST_MOUSE_POSITION)
	_expect(
		moved_positions.size() == 1
			and moved_positions[0].is_equal_approx(TEST_MOUSE_POSITION),
		"Mouse motion must emit one pointer_moved signal."
	)

	await _send_mouse_button(TEST_MOUSE_POSITION, MOUSE_BUTTON_RIGHT, true)
	await _send_mouse_button(TEST_MOUSE_POSITION, MOUSE_BUTTON_RIGHT, false)
	_expect(
		pressed_positions.is_empty() and released_positions.is_empty(),
		"Non-VCClick mouse buttons must not emit pointer button signals."
	)

	await _send_mouse_button(TEST_MOUSE_POSITION, MOUSE_BUTTON_LEFT, true)
	await _send_mouse_button(TEST_MOUSE_POSITION, MOUSE_BUTTON_LEFT, false)
	_expect(
		pressed_positions.size() == 1
			and pressed_positions[0].is_equal_approx(TEST_MOUSE_POSITION),
		"Mouse VCClick press must emit exactly one pointer_pressed signal."
	)
	_expect(
		released_positions.size() == 1
			and released_positions[0].is_equal_approx(TEST_MOUSE_POSITION),
		"Mouse VCClick release must emit exactly one pointer_released signal."
	)

	await _send_joypad_button(JOY_BUTTON_A, true)
	await _send_joypad_button(JOY_BUTTON_A, false)
	_expect(
		pressed_positions.size() == 2,
		"Joypad VCClick press must share the pointer_pressed signal path."
	)
	_expect(
		released_positions.size() == 2,
		"Joypad VCClick release must share the pointer_released signal path."
	)
	_expect(
		_virtual_cursor.input_mode == VirtualCursor.InputMode.CONTROLLER,
		"Joypad VCClick must activate controller mode."
	)
	_expect(
		cursor_sprite.visible,
		"Controller mode must keep the virtual cursor visible."
	)
	_expect_system_cursor_mode(
		Input.MOUSE_MODE_HIDDEN,
		"Controller mode must keep the system mouse cursor hidden."
	)

	await _send_mouse_button(MODE_SWITCH_MOUSE_POSITION, MOUSE_BUTTON_LEFT, true)
	await _send_mouse_button(MODE_SWITCH_MOUSE_POSITION, MOUSE_BUTTON_LEFT, false)
	_expect(
		_virtual_cursor.input_mode == VirtualCursor.InputMode.KEYBOARD_MOUSE,
		"Mouse click without prior motion must restore keyboard/mouse mode."
	)
	_expect(
		cursor_sprite.visible,
		"Mouse mode must keep the virtual cursor visible."
	)
	_expect_system_cursor_mode(
		Input.MOUSE_MODE_HIDDEN,
		"Mouse mode must keep the system mouse cursor hidden."
	)
	_expect(
		_virtual_cursor.viewport_position.is_equal_approx(
			MODE_SWITCH_MOUSE_POSITION
		),
		"Mouse click without prior motion must synchronize the pointer position."
	)
	_expect(
		pressed_positions.size() == 3
			and pressed_positions[-1].is_equal_approx(
				MODE_SWITCH_MOUSE_POSITION
			),
		"Mode-switching mouse press must emit exactly one pointer_pressed signal."
	)
	_expect(
		released_positions.size() == 3
			and released_positions[-1].is_equal_approx(
				MODE_SWITCH_MOUSE_POSITION
			),
		"Mode-switching mouse release must emit exactly one pointer_released signal."
	)

	await _verify_controller_movement()
	await _verify_controller_title_block_drag(main_map)
	await _verify_mouse_title_block_drag(main_map)

	main_map.queue_free()
	await process_frame
	_expect_system_cursor_mode(
		Input.MOUSE_MODE_VISIBLE,
		"Leaving the scene must restore the system mouse cursor."
	)
	if _failures.is_empty():
		print("VirtualCursor input smoke test passed.")
		quit()
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


## 验证鼠标在 TitleBlock 中心按下时能够完成工厂的选择、移动和释放。
##
## 测试位置来自实际 TitleBlock 矩形，避免使用较大的工厂矩形掩盖热点偏移。
func _verify_mouse_title_block_drag(main_map: Node) -> void:
	var factory := get_first_node_in_group("movable_factory") as Control
	_expect(factory != null, "MainMap must contain a movable factory.")
	if factory == null:
		return

	var title_block := factory.get_node("L1/Title/TitleBlock") as Control
	var start_position := factory.global_position
	var pointer_world_position := title_block.get_global_rect().get_center()
	var pointer_viewport_position := (
		main_map.get_viewport().get_canvas_transform() * pointer_world_position
	)
	await _send_mouse_motion(pointer_viewport_position)
	await _send_mouse_button(pointer_viewport_position, MOUSE_BUTTON_LEFT, true)
	await _send_mouse_motion(pointer_viewport_position + Vector2(32.0, 16.0))
	await _send_mouse_button(
		pointer_viewport_position + Vector2(32.0, 16.0),
		MOUSE_BUTTON_LEFT,
		false
	)
	_expect(
		not factory.global_position.is_equal_approx(start_position),
		"Mouse pointer signals must drive MainMap dragging."
	)


## 验证手柄虚拟光标以 TitleBlock 中心热点开始并完成拖拽。
func _verify_controller_title_block_drag(main_map: Node) -> void:
	var factory := get_first_node_in_group("movable_factory") as Control
	_expect(factory != null, "MainMap must contain a movable factory.")
	if factory == null:
		return

	var title_block := factory.get_node("L1/Title/TitleBlock") as Control
	var start_position := factory.global_position
	var pointer_world_position := title_block.get_global_rect().get_center()
	var pointer_viewport_position := (
		main_map.get_viewport().get_canvas_transform() * pointer_world_position
	)
	await _send_mouse_motion(pointer_viewport_position)
	await _send_joypad_button(JOY_BUTTON_A, true)
	Input.action_press(&"VCTo_right")
	_virtual_cursor._process(0.05)
	Input.action_release(&"VCTo_right")
	await process_frame
	await _send_joypad_button(JOY_BUTTON_A, false)
	_expect(
		not factory.global_position.is_equal_approx(start_position),
		"Controller pointer on TitleBlock must drive MainMap dragging."
	)


## 分别按下四个方向动作，验证正负轴都按速度和时间正确累计。
func _verify_controller_movement() -> void:
	var center := Vector2(640.0, 360.0)
	var expected_directions: Dictionary[StringName, Vector2] = {
		&"VCTo_left": Vector2.LEFT,
		&"VCTo_right": Vector2.RIGHT,
		&"VCTo_up": Vector2.UP,
		&"VCTo_down": Vector2.DOWN,
	}
	for action in expected_directions:
		await _send_mouse_motion(center)
		Input.action_press(action)
		_virtual_cursor._process(0.1)
		Input.action_release(action)

		var expected_position := (
			center
			+ expected_directions[action]
			* _virtual_cursor.controller_speed
			* 0.1
		)
		_expect(
			_virtual_cursor.viewport_position.is_equal_approx(expected_position),
			"Controller direction %s must move in the expected direction." % action
		)


## 构造鼠标移动事件并直接送入被测输入回调。
func _send_mouse_motion(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	_virtual_cursor._input(event)
	await process_frame


## 构造指定鼠标按钮的按下或释放事件并送入被测输入回调。
func _send_mouse_button(
	position: Vector2,
	button_index: MouseButton,
	pressed: bool
) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button_index
	event.pressed = pressed
	_virtual_cursor._input(event)
	await process_frame


## 构造指定手柄按钮的按下或释放事件并送入被测输入回调。
func _send_joypad_button(button_index: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = pressed
	_virtual_cursor._input(event)
	await process_frame


## 记录失败信息而不中断测试，使一次运行能够报告全部回归项。
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## 在支持窗口鼠标模式的 DisplayServer 中验证系统鼠标显隐。
##
## Headless DisplayServer 不管理真实系统鼠标，因此无头运行时跳过此断言。
func _expect_system_cursor_mode(expected_mode: int, message: String) -> void:
	if DisplayServer.get_name() == "headless":
		return

	_expect(Input.mouse_mode == expected_mode, message)
