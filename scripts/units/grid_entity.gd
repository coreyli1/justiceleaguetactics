# grid_entity.gd
class_name GridEntity extends Node2D

var entity_id: int
var cell: Vector2i

func snap_to_cell(grid: Grid, p_cell: Vector2i) -> void:
	cell = p_cell
	position = grid.cell_to_world(p_cell)
