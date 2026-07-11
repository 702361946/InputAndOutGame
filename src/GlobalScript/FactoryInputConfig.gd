extends Resource

class_name FactoryInputConfig

@export var input_resource: ResourceAgreement
@export_range(1, 999) var input_value: int = 1

func inventory_check(warehouse: Warehouse) -> bool:
	return warehouse.inventory_judgment(input_resource, input_value)
