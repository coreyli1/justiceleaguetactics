class_name LevelMap extends Node2D
## The root of a painted level scene. It is the only script that knows how a
## level is drawn (tile layers, spawn nodes); the battle just asks it questions.
## Uses $ paths inside functions (not @onready) so it also works on a map
## that was instantiated but never added to the tree, e.g. to count deploy slots.

func _ready() -> void:
	$Deploy.visible = false   # deploy markers are an editing aid, not part of the look


## Grid size in cells. Paint the level starting at cell (0, 0).
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


## Deploy slots in reading order (top-to-bottom, then left-to-right).
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
