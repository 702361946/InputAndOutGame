extends HBoxContainer

@export var NodeImage: TextureRect

var midpoint: Vector2
var global_midpoint: Vector2

func _ready():
	NodeImage.resized.connect(_on_image_resized)
	_on_image_resized()

func _on_image_resized():
	_update_global_midpoint()

func _update_midpoint():
	midpoint = NodeImage.size * 0.5
	
func _update_global_midpoint():
	_update_midpoint()
	global_midpoint = midpoint + NodeImage.global_position
