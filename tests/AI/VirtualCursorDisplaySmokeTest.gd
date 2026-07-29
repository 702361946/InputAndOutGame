## 在真实窗口 DisplayServer 中验证虚拟光标显示策略。
##
## 该测试不统计输入信号次数，避免测试窗口收到真实鼠标移动时产生干扰。
## 必须以带窗口模式运行：
## [codeblock]
## Godot_v4.7-stable_win64_console.exe --path . \
##     --rendering-method gl_compatibility --audio-driver Dummy \
##     --script res://tests/VirtualCursorDisplaySmokeTest.gd
## [/codeblock]
extends SceneTree

const MAIN_SCENE_PATH := "res://src/Scene/MainMap.tscn"
const TEST_MOUSE_POSITION := Vector2(32.0, 32.0)

var _failures: Array[String] = []


## 将测试主体延迟到窗口和 SceneTree 完成初始化后执行。
func _initialize() -> void:
	call_deferred("_run")


## 验证初始化、设备切换和场景退出三个阶段的光标显隐状态。
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("VirtualCursor display smoke test requires a window DisplayServer.")
		quit(1)
		return

	var main_scene := load(MAIN_SCENE_PATH) as PackedScene
	var main_map := main_scene.instantiate()
	root.add_child(main_map)
	await process_frame

	var virtual_cursor := main_map.get_node("VirtualCursor") as VirtualCursor
	var cursor_sprite := virtual_cursor.get_node("Sprite2D") as Sprite2D
	_expect(
		cursor_sprite.centered
			and cursor_sprite.get_rect().get_center().is_zero_approx(),
		"Virtual cursor texture center must be the logical pointer hotspot."
	)
	_expect_active_display(cursor_sprite, "Initial mouse mode")

	var joypad_event := InputEventJoypadButton.new()
	joypad_event.button_index = JOY_BUTTON_A
	joypad_event.pressed = true
	virtual_cursor._input(joypad_event)
	_expect(
		virtual_cursor.input_mode == VirtualCursor.InputMode.CONTROLLER,
		"Joypad input must activate controller mode."
	)
	_expect_active_display(cursor_sprite, "Controller mode")

	var mouse_event := InputEventMouseMotion.new()
	mouse_event.position = TEST_MOUSE_POSITION
	mouse_event.global_position = TEST_MOUSE_POSITION
	virtual_cursor._input(mouse_event)
	_expect(
		virtual_cursor.input_mode == VirtualCursor.InputMode.KEYBOARD_MOUSE,
		"Mouse input must restore keyboard/mouse mode."
	)
	_expect_active_display(cursor_sprite, "Mouse mode")

	virtual_cursor.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	_expect(
		cursor_sprite.visible,
		"Leaving the client area must keep the virtual cursor rendered."
	)
	_expect(
		Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"Leaving the client area must show the system cursor for window chrome."
	)
	virtual_cursor.notification(Node.NOTIFICATION_WM_MOUSE_ENTER)
	_expect_active_display(cursor_sprite, "Returning to the client area")

	await _verify_title_bar_drag(main_map)

	main_map.queue_free()
	await process_frame
	_expect(
		Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"Leaving the scene must restore the system mouse cursor."
	)

	if _failures.is_empty():
		print("VirtualCursor display smoke test passed.")
		quit()
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


## 通过完整 Viewport 输入传播验证 TitleBlock 能够开始、移动并结束拖拽。
func _verify_title_bar_drag(main_map: Node) -> void:
	var factory := main_map.get_node("AllFactory/FactoryBase") as Control
	var title_block := factory.get_node("L1/Title/TitleBlock") as Control
	var start_position := factory.global_position
	var press_world_position := title_block.get_global_rect().get_center()
	var press_viewport_position := (
		main_map.get_viewport().get_canvas_transform() * press_world_position
	)
	var drag_viewport_position := press_viewport_position + Vector2(32.0, 16.0)

	await _parse_mouse_button(press_viewport_position, true)
	await _parse_mouse_motion(
		drag_viewport_position,
		drag_viewport_position - press_viewport_position
	)
	await _parse_mouse_button(drag_viewport_position, false)
	_expect(
		not factory.global_position.is_equal_approx(start_position),
		"Dragging the factory TitleBlock must move the factory."
	)


## 通过 Input.parse_input_event() 向真实窗口输入队列发送鼠标按钮事件。
func _parse_mouse_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


## 通过完整输入队列发送按住左键时的鼠标移动事件。
func _parse_mouse_motion(position: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	await process_frame


## 验证场景有效期间只显示虚拟光标。
func _expect_active_display(cursor_sprite: Sprite2D, phase: String) -> void:
	_expect(
		cursor_sprite.visible,
		"%s must keep the virtual cursor visible." % phase
	)
	_expect(
		Input.mouse_mode == Input.MOUSE_MODE_HIDDEN,
		"%s must keep the system mouse cursor hidden." % phase
	)


## 记录失败信息而不中断测试，使一次运行能够报告全部显隐阶段。
func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
