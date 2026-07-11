extends Node

class_name FactoryConfig

@export var input: Array[FactoryInputConfig] = []
@export var out: Array[FactoryOutConfig] = []
@export_range(0.001, 9999999) var production_time: float = 1.0
@export var WarehouseNode: Warehouse

signal production_start
signal production_end
var _in_production: bool = false
var _temp_timer: SceneTreeTimer = null

func _process(_delta) -> void:
	production()

func production_inspection() -> bool:
	for i in input:
		if not i.inventory_check(WarehouseNode):
			return false
			
	return true
	
func production() -> void:
	if not production_inspection():
		return
	if _in_production or _temp_timer != null:
		return
	
	_in_production = true
	production_start.emit()
	_temp_timer = get_tree().create_timer(production_time)
	await _temp_timer.timeout
	_temp_timer = null
	production_settlement()
	
	_in_production = false
	production_end.emit()
	return
	
func production_settlement() -> void:
	for o in out:
		var o_v: int = o.generate()
		WarehouseNode.add(o.out_resource, o_v)
	
	for i in input:
		WarehouseNode.deduction(i.input_resource, i.input_value)
	
