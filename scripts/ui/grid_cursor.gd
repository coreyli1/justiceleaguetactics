class_name GridCursor extends Node2D

signal moved(cell: Vector2i)
signal confirmed(cell: Vector2i)
signal cancelled(cell: Vector2i)

const COLOR := Color(1, 1, 1, 0.95)
const MOVE_ACTIONS := {
	"cursor_up": Vector2i.UP,
	"cursor_down": Vector2i.DOWN,
	"cursor_left": Vector2i.LEFT,
	"cursor_right": Vector2i.RIGHT,
}

var enabled := false:
	set(value):
		enabled = value
		_refresh_visibility()

var cell := Vector2i.ZERO

var _grid: Grid
var _mouse_over_ui := false  


func setup(grid: Grid) -> void:
	_grid = grid


func move_to(p_cell: Vector2i) -> void:
	cell = p_cell
	position = Vector2(cell * Grid.CELL_SIZE)   # top-left of the cell, like everything else
	moved.emit(cell)


# --- Input ------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_over_ui = true
		_refresh_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if _grid == null:
		return

	if event is InputEventMouseMotion:
		_mouse_over_ui = false   
		_refresh_visibility()
		var hovered := _mouse_cell()
		if hovered != cell and _grid.is_in_bounds(hovered):
			move_to(hovered)
		return

	for action in MOVE_ACTIONS:
		if event.is_action_pressed(action, true):
			_mouse_over_ui = false   
			_refresh_visibility()
			if enabled and _grid.is_in_bounds(cell + MOVE_ACTIONS[action]):
				move_to(cell + MOVE_ACTIONS[action])
			return

	if not enabled:
		return

	if event.is_action_pressed("select"):
		if event is InputEventMouseButton:
			var clicked := _mouse_cell()
			if not _grid.is_in_bounds(clicked):
				return   
			if clicked != cell:
				move_to(clicked)
		confirmed.emit(cell)
	elif event.is_action_pressed("cancel"):
		cancelled.emit(cell)


func _mouse_cell() -> Vector2i:
	return _grid.world_to_cell(get_global_mouse_position())


# --- Drawing ----------------------------------------------------------------------

func _refresh_visibility() -> void:
	visible = enabled and not _mouse_over_ui


func _draw() -> void:
	var size := Vector2.ONE * (Grid.CELL_SIZE - 1)
	draw_rect(Rect2(Vector2.ONE * 0.5, size), COLOR, false, 1.0)
