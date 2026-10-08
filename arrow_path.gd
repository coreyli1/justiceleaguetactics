extends TileMapLayer


func set_cells(cells: Array[Vector2]) -> void:
	clear()
	
	for cell: Vector2 in cells:
		set_cell(cell,0, Vector2.ZERO)
