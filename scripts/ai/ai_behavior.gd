class_name AIBehavior extends Resource
## Decides what an enemy unit does on its turn by scoring every option.
## Pure: it only reads the board, never changes it.

@export_group("Attack scoring")
@export var damage_weight: float = 1.0     # points per damage dealt
@export var kill_bonus: float = 10.0       # extra points for a kill
@export var counter_weight: float = 1.0    # points lost per damage taken from a counter
@export var death_penalty: float = 20.0    # points lost if the counter would kill us

@export_group("Positioning")
@export var approach_weight: float = 1.0   # how eager to close distance (0 = hold position)

class Decision:
	var cell: Vector2i
	var target: Unit   # null = move and wait
	func _init(p_cell: Vector2i, p_target: Unit) -> void:
		cell = p_cell
		target = p_target


func decide(unit: Unit, grid: Grid, units: Dictionary) -> Decision:
	var enemy_cells: Array[Vector2i] = []
	for other in units.values():
		if other.team != unit.team:
			enemy_cells.append(other.cell)
	var dist_map := grid.distance_map(enemy_cells)

	var best := Decision.new(unit.cell, null)
	var best_score := -INF

	for cell in grid.get_reachable_cells(unit.cell, unit.move_range):
		var wait_score := _score_position(cell, dist_map)

		if wait_score > best_score:
			best_score = wait_score
			best = Decision.new(cell, null)

		for target in Combat.targets_from(unit, cell, grid, units):
			var attack_score := _score_attack(unit, target, cell)
			if attack_score > best_score:
				best_score = attack_score
				best = Decision.new(cell, target)

	return best


func _score_attack(unit: Unit, target: Unit, from_cell: Vector2i) -> float:
	var hits := Combat.resolve_attack(unit, target, from_cell)
	var score := 0.0

	score += hits[0].damage * damage_weight
	if hits[0].lethal:
		score += kill_bonus

	if hits.size() > 1:
		score -= hits[1].damage * counter_weight
		if hits[1].lethal:
			score -= death_penalty

	return score


func _score_position(cell: Vector2i, dist_map: Dictionary) -> float:
	if not dist_map.has(cell):
		return 0.0   # no walking route to any enemy from here
	return -dist_map[cell] * approach_weight
