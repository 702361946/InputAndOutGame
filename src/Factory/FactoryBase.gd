extends PanelContainer

@export var display_size: Vector2 = Vector2(64, 64)

@export var f_warehouse: Warehouse = null

@export var IO: Dictionary[String, FactoryConfig] = {}

func _ready():
	# 锁死大小
	custom_minimum_size = display_size
	size = display_size
	
	# 禁止自动拉伸/收缩
	size_flags_horizontal = SIZE_SHRINK_CENTER
	size_flags_vertical = SIZE_SHRINK_CENTER

