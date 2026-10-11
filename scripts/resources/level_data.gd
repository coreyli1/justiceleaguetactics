class_name LevelData extends Resource
## Everything that defines one battle: the map, who's on it, and what it's called.

@export var id: StringName              # stable ID for saves, e.g. &"level_01"
@export var display_name: String = "Untitled"

@export_multiline var layout: String    # '#' = wall, '.' = floor
@export var spawns: Array[UnitSpawn] = []


func get_rows() -> PackedStringArray:
	print(spawns)
	print(id)
	print(display_name)
	return layout.strip_edges().split("\n")


func get_size() -> Vector2i:
	var rows := get_rows()
	return Vector2i(rows[0].length(), rows.size())


func get_blocked_cells() -> Array[Vector2i]:
	var blocked: Array[Vector2i] = []
	var rows := get_rows()
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "#":
				blocked.append(Vector2i(x, y))
	return blocked
