extends Node

class_name Warehouse

@export var all_quantity: Dictionary[ResourceAgreement, int] = {}
@export var white_list: Array[ResourceAgreement] = []

func add(resource_agreement: ResourceAgreement, value: int) -> bool:
	if not resource_in_warehouse(resource_agreement):
		return false
		
	if value < 0:
		return false
	
	all_quantity[resource_agreement] += value
	return true

func deduction(resource_agreement: ResourceAgreement, value: int) -> bool:
	if value < 0:
		return false
		
	if not inventory_judgment(resource_agreement, value):
		return false
	
	all_quantity[resource_agreement] -= value
	return true
	
func inventory_judgment(resource_agreement: ResourceAgreement, value: int) -> bool:
	if not resource_in_warehouse(resource_agreement):
		return false
	return value < all_quantity[resource_agreement]
	
func resource_in_warehouse(resource_agreement: ResourceAgreement) -> bool:
	if not resource_agreement in white_list:
		return false
	if not resource_agreement in all_quantity.keys():
		all_quantity[resource_agreement] = 0
		
	return true

