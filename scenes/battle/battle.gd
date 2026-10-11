class_name Battle extends Node2D
## Owns the battle's state (grid, units, turns) and the shared actions that
## both the player and the AI use: moving, attacking, killing, ending.
## It does NOT handle player input or drawing; see PlayerController and Board.

signal battle_ended(outcome: Outcome)

enum Outcome { NONE, VICTORY, DEFEAT }

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const GRID_SIZE := Vector2i(20, 11)

const SOLDIER := preload("res://data/units/soldier.tres")
const ARCHER := preload("res://data/units/archer.tres")
const BRUTE := preload("res://data/units/brute.tres")

var grid: Grid
var units: Dictionary = {}   # entity_id -> Unit (living units only)
var turn_manager: TurnManager
var is_over := false

var _next_entity_id := 0

@onready var board: Board = $Board
@onready var entities: Node2D = $Entities
@onready var player: PlayerController = $PlayerController
@onready var action_menu: ActionMenu = $UI/ActionMenu
@onready var result_label: Label = $UI/ResultLabel

@export var level: LevelData


func _ready() -> void:
	if GameState.current_level:
		level = GameState.current_level
	
	result_label.hide()
	print(level)
	_load_level()

	turn_manager = TurnManager.new(units)
	turn_manager.phase_started.connect(_on_phase_started)

	board.setup(grid)
	player.setup(self, action_menu)
	turn_manager.start_phase(Unit.Team.PLAYER)
	


func _unhandled_input(event: InputEvent) -> void:
	if not is_over:
		return
	if event.is_action_pressed("restart"):
		GameState.restart_level()
	elif event.is_action_pressed("ui_accept"):
		GameState.go_to_level_select()

func _load_level() -> void:
	grid = Grid.new(level.get_size())
	for cell in level.get_blocked_cells():
		grid.set_blocked(cell, true)
	for spawn in level.spawns:
		spawn_unit(spawn.unit, spawn.cell, spawn.team)


# --- Queries ------------------------------------------------------------------

func get_unit_at(cell: Vector2i) -> Unit:
	return units.get(grid.get_occupant(cell))   # null if empty


func get_targets(unit: Unit) -> Array[Unit]:
	return Combat.targets_from(unit, unit.cell, grid, units)


# --- Shared actions (used by the player now, and the AI next) -----------------

func spawn_unit(data: UnitData, cell: Vector2i, team: Unit.Team) -> Unit:
	var unit: Unit = UNIT_SCENE.instantiate()
	unit.entity_id = _next_entity_id
	_next_entity_id += 1

	unit.setup(data, team)
	entities.add_child(unit)
	unit.snap_to_cell(grid, cell)
	grid.place(unit.entity_id, cell)
	units[unit.entity_id] = unit
	return unit


## Moves a unit along its path and waits for the animation. Call with await.
func move_unit(unit: Unit, cell: Vector2i) -> void:
	var path := grid.find_path(unit.cell, cell, unit.move_range)
	if path.is_empty():
		return
	grid.move(unit.entity_id, unit.cell, cell)   # logic first...
	var tween := unit.move_along(path, grid)      # ...then visuals
	if tween:
		await tween.finished


## Instantly puts a unit back where it was (used by the player's undo).
func undo_move(unit: Unit, origin: Vector2i) -> void:
	grid.move(unit.entity_id, unit.cell, origin)
	unit.snap_to_cell(grid, origin)


## Applies a full attack exchange (hit + possible counter).
## Returns true if this ended the battle.
func resolve_attack(attacker: Unit, target: Unit) -> bool:
	var hits := Combat.resolve_attack(attacker, target, attacker.cell)
	for hit in hits:
		hit.defender.hp -= hit.damage
		print("%s hits %s for %d (%d HP left)" % [hit.attacker.data.display_name, hit.defender.data.display_name, hit.damage, hit.defender.hp])
		if hit.defender.hp <= 0:
			_kill_unit(hit.defender)

	var outcome := _get_outcome()
	if outcome != Outcome.NONE:
		_end_battle(outcome)
		return true
	return false


# --- Internals ------------------------------------------------------------------

func _kill_unit(unit: Unit) -> void:
	print("%s is defeated" % unit.data.display_name)
	grid.remove(unit.cell)
	units.erase(unit.entity_id)
	unit.queue_free()


func _get_outcome() -> Outcome:
	var players := 0
	var enemies := 0
	for unit in units.values():
		match unit.team:
			Unit.Team.PLAYER: players += 1
			Unit.Team.ENEMY: enemies += 1
	if enemies == 0:
		return Outcome.VICTORY
	if players == 0:
		return Outcome.DEFEAT
	return Outcome.NONE


func _end_battle(outcome: Outcome) -> void:
	print("battle ended: ", Outcome.keys()[outcome])
	is_over = true
	var headline := "Victory!" if outcome == Outcome.VICTORY else "Defeat..."
	result_label.text = headline + "\nR: retry   Enter: continue"
	result_label.show()
	battle_ended.emit(outcome)


func _on_phase_started(team: Unit.Team) -> void:
	if team == Unit.Team.ENEMY:
		_run_enemy_phase()


func _run_enemy_phase() -> void:
	await get_tree().create_timer(0.4).timeout

	var enemies := units.values().filter(func(u): return u.team == Unit.Team.ENEMY)
	for unit in enemies:
		if not units.has(unit.entity_id):
			continue   # died earlier this phase
		if unit.data.ai_behavior:
			var decision: AIBehavior.Decision = unit.data.ai_behavior.decide(unit, grid, units)
			if decision.cell != unit.cell:
				await move_unit(unit, decision.cell)
			if decision.target:
				if resolve_attack(unit, decision.target):
					return   # battle over, so don't start another turn
		turn_manager.mark_acted(unit)
		await get_tree().create_timer(0.25).timeout

	turn_manager.end_phase()
