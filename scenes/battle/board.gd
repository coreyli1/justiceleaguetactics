class_name Board extends Node2D
## Draws the highlight overlays on top of the level's painted map:
## movement range, attack range, and the route being drawn.
## Purely visual: it never decides anything, it only shows what it's told.

const MOVE_COLOR := Color(0.3, 0.6, 1.0, 0.5)
const ATTACK_COLOR := Color(0.842, 0.473, 0.543, 0.5)
const PATH_COLOR := Color(1.0, 0.85, 0.3, 0.75)
const MARK_COLOR := Color(1.0, 0.85, 0.3, 0.75)   # e.g. the hero picked up during deployment

var _grid: Grid
var _move_cells: Array[Vector2i] = []
var _attack_cells: Array[Vector2i] = []
var _path: Array[Vector2i] = []
var _marked: Array[Vector2i] = []


func setup(grid: Grid) -> void:
	_grid = grid
	queue_redraw()


func show_moves(cells: Array[Vector2i]) -> void:
	_move_cells.assign(cells)
	queue_redraw()


func show_attacks(cells: Array[Vector2i]) -> void:
	_attack_cells.assign(cells)
	queue_redraw()


func show_path(cells: Array[Vector2i]) -> void:
	_path.assign(cells)
	queue_redraw()


## Single-cell emphasis, independent of the other highlights.
func show_marked(cells: Array[Vector2i]) -> void:
	_marked.assign(cells)
	queue_redraw()


func clear_highlights() -> void:
	_move_cells.clear()
	_attack_cells.clear()
	_path.clear()
	_marked.clear()
	queue_redraw()


func _draw() -> void:
	if _grid == null:
		return
	for cell in _move_cells:
		_draw_cell(cell, MOVE_COLOR)
	for cell in _attack_cells:
		_draw_cell(cell, ATTACK_COLOR)
	_draw_path()
	for cell in _marked:
		_draw_cell(cell, MARK_COLOR)


func _draw_cell(cell: Vector2i, color: Color) -> void:
	draw_rect(Rect2(_grid.cell_to_world(cell), Vector2.ONE * Grid.CELL_SIZE), color)


## Fills each cell on the route, with the destination drawn a bit stronger.
func _draw_path() -> void:
	if _path.size() < 2:
		return   # standing still: nothing to draw
	for i in range(0, _path.size()):   # skip index 0, the cell the unit stands on
		var color := PATH_COLOR
		if i < _path.size() - 1:
			color.a = 0.45   # route cells: lighter
		_draw_cell(_path[i], color)
