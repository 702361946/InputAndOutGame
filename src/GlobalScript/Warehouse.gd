extends Node

class_name Warehouse

@export var all_quantity: Dictionary[String, int] = {}
@export var white_list: Array[String] = []

func add(resource_name: String, value: int) -> void:
	if resource_name not in white_list:
		return
	all_quantity.get_or_add(resource_name, 0)
	all_quantity[resource_name] += value
	

