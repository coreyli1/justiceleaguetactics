class_name LevelData extends Resource
## Everything that defines one battle: the map, who's on it, and what it's called.

@export var id: StringName              # stable ID for saves, e.g. &"level_01"
@export var display_name: String = "Untitled"
@export var map: PackedScene






	

## Unit select needs the squad limit before the battle exists,
## so build the map briefly, count its slots, and throw it away.
func get_deploy_count() -> int:
	var level_map: LevelMap = map.instantiate()
	var count := level_map.get_deploy_cells().size()
	level_map.free()
	return count
