class_name BattleCamera extends Camera2D
## Keeps whatever we focus on (usually the cursor) on screen, scrolling only
## when it gets close to an edge. Clamped to the map, so you never see past it;
## maps smaller than the screen are centred instead.

const EDGE_MARGIN := 2   # cells kept between the focus and the screen edge
const PAN_SPEED := 160.0
var _map_px := Vector2.ZERO


func _process(delta: float) -> void:
	var direction := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if direction != Vector2.ZERO:
		position = _clamp(position + direction * PAN_SPEED * delta)

func _ready() -> void:
	# With a top-left anchor, `position` is the top-left corner of what you see,
	# which keeps all the math in the same convention as the grid.
	anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	position_smoothing_enabled = true
	position_smoothing_speed = 10.0
	make_current()


## Call once the level is loaded, with its size in cells.
func setup(map_cells: Vector2i) -> void:
	_map_px = Vector2(map_cells * Grid.CELL_SIZE)
	position = _clamp(Vector2.ZERO)
	reset_smoothing()   # jump straight there on load instead of gliding in


## Scrolls just enough to keep `cell` (plus a margin) on screen.
func follow(cell: Vector2i) -> void:
	var view := get_viewport_rect().size
	var margin := float(EDGE_MARGIN * Grid.CELL_SIZE)
	var cell_pos := Vector2(cell * Grid.CELL_SIZE)
	var target := position

	# Cell too close to the left/top edge: scroll back.
	target.x = minf(target.x, cell_pos.x - margin)
	target.y = minf(target.y, cell_pos.y - margin)
	# Cell too close to the right/bottom edge: scroll forward.
	target.x = maxf(target.x, cell_pos.x + Grid.CELL_SIZE + margin - view.x)
	target.y = maxf(target.y, cell_pos.y + Grid.CELL_SIZE + margin - view.y)

	position = _clamp(target)


## Keeps the view inside the map on each axis (or centres a map that's smaller than the screen).
func _clamp(pos: Vector2) -> Vector2:
	var view := get_viewport_rect().size
	var result := pos
	for axis in 2:
		if _map_px[axis] <= view[axis]:
			result[axis] = (_map_px[axis] - view[axis]) / 2.0
		else:
			result[axis] = clampf(pos[axis], 0.0, _map_px[axis] - view[axis])
	return result
