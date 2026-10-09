class_name Board extends Node2D
## Draws the grid and the highlight overlays. Purely visual: it never decides
## anything, it only shows what it's told.

const TILE_A := Color("3a3f5c")
const TILE_B := Color("2f3350")
const WALL_COLOR := Color("cdefa2ff")
const MOVE_COLOR := Color(0.3, 0.6, 1.0, 0.5)
const ATTACK_COLOR := Color(0.842, 0.473, 0.543, 0.5)

var _grid: Grid
var _move_cells: Array[Vector2i] = []
var _attack_cells: Array[Vector2i] = []


func setup(grid: Grid) -> void:
	_grid = grid
	queue_redraw()


func show_moves(cells: Array[Vector2i]) -> void:
	_move_cells.assign(cells)
	queue_redraw()


func show_attacks(cells: Array[Vector2i]) -> void:
	_attack_cells.assign(cells)
	queue_redraw()


func clear_highlights() -> void:
	_move_cells.clear()
	_attack_cells.clear()
	queue_redraw()


func _draw() -> void:
	if _grid == null:
		return
	for x in _grid.size.x:
		for y in _grid.size.y:
			var cell := Vector2i(x, y)
			var color := TILE_A if (x + y) % 2 == 0 else TILE_B
			if _grid.is_blocked(cell):
				color = WALL_COLOR
			_draw_cell(cell, color)
	for cell in _move_cells:
		_draw_cell(cell, MOVE_COLOR)
	for cell in _attack_cells:
		_draw_cell(cell, ATTACK_COLOR)


func _draw_cell(cell: Vector2i, color: Color) -> void:
	draw_rect(Rect2(_grid.cell_to_world(cell), Vector2.ONE * Grid.CELL_SIZE), color)
