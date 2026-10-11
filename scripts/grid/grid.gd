class_name Grid extends RefCounted

const CELL_SIZE := 16
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT
]

var size: Vector2i
var _occupants: Dictionary = {}   # Vector2i -> entity_id (int)
var _astar := AStarGrid2D.new()

func _init(p_size: Vector2i) -> void:
	size = p_size
	_astar.region = Rect2i(Vector2i.ZERO, size)
	_astar.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.update() 

func is_in_bounds(cell: Vector2i) -> bool: 
	return Rect2i(Vector2i.ZERO, size).has_point(cell)
	
func cell_to_world(cell: Vector2i) -> Vector2:
	# Returns the TOP-LEFT corner of the cell. Sprites are not centered.
	return Vector2(cell * CELL_SIZE)
	
func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i((pos / CELL_SIZE).floor())

func is_occupied(cell: Vector2i) -> bool: 
	return _occupants.has(cell)
	
func get_occupant(cell: Vector2i) -> int: 
	return _occupants.get(cell, -1)   # -1 means empty
	
func place(entity_id: int, cell: Vector2i) -> void: 
	_occupants[cell] = entity_id
	
func move(entity_id: int, from: Vector2i, to: Vector2i) -> void: 
	remove(from)
	place(entity_id, to)
	
func remove(cell: Vector2i) -> void: 
	_occupants.erase(cell)

func set_blocked(cell: Vector2i, blocked: bool) -> void:
	_astar.set_point_solid(cell, blocked)   # walls, water, etc. (milestone 5)
	
func _flood_fill(origin: Vector2i, move_range: int) -> Dictionary:
	var distances := {origin: 0}
	var frontier: Array[Vector2i] = [origin]
	var came_from := {origin: origin}

	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for dir in DIRECTIONS:
			var next := current + dir
			if distances.has(next):
				continue
			if not is_in_bounds(next):
				continue
			if _astar.is_point_solid(next) or is_occupied(next):
				continue
			var d: int = distances[current] + 1
			if d > move_range:
				continue
			distances[next] = d
			frontier.append(next)
			came_from[next] = current
	return came_from
	
func get_reachable_cells(origin: Vector2i, move_range: int) -> Array[Vector2i]:
	var came_from = _flood_fill(origin, move_range)
	var ret: Array[Vector2i] = []
	for k in came_from.keys():
		ret.append(k)
	return ret	
	
	
func find_path(from: Vector2i, to: Vector2i, move_range: int) -> Array[Vector2i]:
	var came_from := _flood_fill(from, move_range) 
	var path: Array[Vector2i] = []
	if not came_from.has(to):
		return path
	var current := to
	while current != from:
		path.append(current)
		current = came_from[current]
	path.append(from)
	path.reverse()

	return path
	
	
func is_blocked(cell):
	if not is_in_bounds(cell):
		return true
	return _astar.is_point_solid(cell)
		
func get_cells_in_range(origin: Vector2i, min_range: int, max_range: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dx in range(-max_range, max_range + 1):
		for dy in range(-max_range, max_range + 1):
			var dist := absi(dx) + absi(dy)
			if dist > max_range or dist < min_range:
				continue
			var c := origin + Vector2i(dx, dy)
			if not is_in_bounds(c): 
				continue
			cells.append(c)

	return cells

## Walking distance from the nearest source cell to every cell reachable from it.
## Respects walls, ignores units. Cells that can't be reached are absent.
func distance_map(sources: Array[Vector2i]) -> Dictionary:
	var dist := {}
	var frontier: Array[Vector2i] = []
	for source in sources:
		dist[source] = 0
		frontier.append(source)

	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for dir in DIRECTIONS:
			var next := current + dir
			if dist.has(next) or is_blocked(next):
				continue
			dist[next] = dist[current] + 1
			frontier.append(next)
	return dist
