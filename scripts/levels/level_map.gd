class_name LevelMap extends Node2D

func _ready() -> void:
	$Deploy.visible = false   


func get_size() -> Vector2i:
	return $Terrain.get_used_rect().end


func get_blocked_cells() -> Array[Vector2i]:
	var terrain: TileMapLayer = $Terrain
	var cells: Array[Vector2i] = []
	for cell in terrain.get_used_cells():
		var data := terrain.get_cell_tile_data(cell)
		if data and data.get_custom_data("blocked"):
			cells.append(cell)
	return cells


func get_deploy_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = $Deploy.get_used_cells()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells


func get_enemy_spawns() -> Array[EnemySpawn]:
	var spawns: Array[EnemySpawn] = []
	for child in $Enemies.get_children():
		if child is EnemySpawn:
			spawns.append(child)
	return spawns


func cell_of(node: Node2D) -> Vector2i:
	return Vector2i((node.position / Grid.CELL_SIZE).floor())
