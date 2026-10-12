class_name GridCursor extends Node2D
## The selection cursor, and the one place that turns raw input into "pointing".
## It moves with the mouse (hover) and the arrow keys, hides itself while the mouse
## is over UI, and reports what the player did through signals:
##   moved(cell)      - the cursor is on a new cell
##   confirmed(cell)  - "select" was pressed on a cell
##   cancelled(cell)  - "cancel" was pressed
## It never decides what those mean; the controllers listen and decide.

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

## Controllers switch this on when the cursor should respond to keys and clicks,
## and off when it shouldn't (menus open, animations, enemy turn, game over).
var enabled := false:
	set(value):
		enabled = value
		_refresh_visibility()

var cell := Vector2i.ZERO

var _grid: Grid
var _mouse_over_ui := false   # true while the mouse is over a button or panel


func setup(grid: Grid) -> void:
	_grid = grid


func move_to(p_cell: Vector2i) -> void:
	cell = p_cell
	position = Vector2(cell * Grid.CELL_SIZE)   # top-left of the cell, like everything else
	moved.emit(cell)


# --- Input ------------------------------------------------------------------------

## Runs BEFORE the GUI sees the event. Assume the mouse is over UI for now;
## if no button/panel consumes the movement, _unhandled_input corrects it.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_over_ui = true
		_refresh_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if _grid == null:
		return

	# Hovering the map always moves the cursor (even while disabled, so it's already
	# in the right place when it reappears).
	if event is InputEventMouseMotion:
		_mouse_over_ui = false   # the event reached us, so no Control is under the mouse
		_refresh_visibility()
		var hovered := _mouse_cell()
		if hovered != cell and _grid.is_in_bounds(hovered):
			move_to(hovered)
		return

	# Arrow keys move one cell (true = keep repeating while held).
	for action in MOVE_ACTIONS:
		if event.is_action_pressed(action, true):
			_mouse_over_ui = false   # keyboard players get the cursor back
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
				return   # clicked off the map: ignore rather than act on the old cell
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
	# Half-pixel inset keeps a 1px outline crisp instead of blurred across two pixels.
	var size := Vector2.ONE * (Grid.CELL_SIZE - 1)
	draw_rect(Rect2(Vector2.ONE * 0.5, size), COLOR, false, 1.0)
