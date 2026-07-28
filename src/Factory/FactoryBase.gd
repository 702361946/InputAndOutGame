extends PanelContainer

@export var display_grid_size: Vector2i = Vector2i(12, 6)
@export var rectangle_size: Vector2

@export var f_warehouse: Warehouse = null

@export var IO: Dictionary[String, FactoryConfig] = {}

func _ready():
	rectangle_size = Vector2(
		GlobalValue.grid_size.x * display_grid_size.x,
		GlobalValue.grid_size.y * display_grid_size.y
	)
	# 锁死大小
	size = rectangle_size
	custom_minimum_size = rectangle_size
	
	# 禁止自动拉伸/收缩
	size_flags_horizontal = SIZE_SHRINK_CENTER
	size_flags_vertical = SIZE_SHRINK_CENTER

	self.global_position = GlobalValue.to_approximate_coordinates(self.global_position)
