extends Node

static var grid_size: Vector2i = Vector2i(16, 16)
	
## 用于顶点对齐至格子坐标
static func to_approximate_coordinates(coordinates: Vector2) -> Vector2:
	return coordinates.snapped(grid_size)

