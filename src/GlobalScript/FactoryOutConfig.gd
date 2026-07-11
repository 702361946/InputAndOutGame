extends Resource
class_name FactoryOutConfig

@export var out_resource: ResourceAgreement
@export_range(1, 999) var out_value: int = 1
@export_range(0.0, 1.0) var out_probability: float = 1.0

func generate() -> int:
	if randf() <= out_probability:
		return out_value
	return 0
