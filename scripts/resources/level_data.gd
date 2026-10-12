class_name LevelData extends Resource

@export var id: StringName              
@export var display_name: String = "Untitled"
@export var map: PackedScene

func get_deploy_count() -> int:
	var level_map: LevelMap = map.instantiate()
	var count := level_map.get_deploy_cells().size()
	level_map.free()
	return count
