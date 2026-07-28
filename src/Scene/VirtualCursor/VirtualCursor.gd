extends Node2D

class_name VirtualCursor

var VC_x: float = 0.0
var VC_y: float = 0.0

signal VC_click(x: float, y: float)
signal VC_to(x:float, y: float)

func update_self():
	self.position = Vector2(VC_x, VC_y)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("VCClick") and event.is_pressed():
		print_debug("--VCClick--" + str(event))
		VC_click.emit(VC_x, VC_y)
		
func _process(_delta: float) -> void:
	var input_vector := Input.get_vector("VCTo_left", "VCTo_right", "VCTo_up", "VCTo_down")
	
	if input_vector.x > 0 or input_vector.y > 0:
		VC_x += input_vector.x
		VC_y += input_vector.y
		VC_to.emit(VC_x, VC_y)
	else:
		var viewport := get_viewport()
		if viewport != null:
			var mouse_pos := viewport.get_mouse_position()
			VC_x = mouse_pos.x
			VC_y = mouse_pos.y
	
	update_self()
	