class_name Battle extends Node2D

signal battle_ended(outcome: Outcome)

enum Outcome { NONE, VICTORY, DEFEAT }

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")

@export var level: LevelData

var grid: Grid
var level_map: LevelMap
var units: Dictionary = {}  
var turn_manager: TurnManager
var is_over := false

var _next_entity_id := 0
var _hovered: Unit = null   # the unit whose health bar is showing

@onready var camera: BattleCamera = $Camera
@onready var board: Board = $Board
@onready var entities: Node2D = $Entities
@onready var cursor: GridCursor = $Cursor
@onready var deployment: DeploymentController = $DeploymentController
@onready var player: PlayerController = $PlayerController
@onready var enemies: EnemyController = $EnemyController
@onready var action_menu: ActionMenu = $UI/ActionMenu
@onready var result_label: Label = $UI/ResultLabel
@onready var end_turn_button: Button = $UI/EndTurnButton
@onready var deploy_panel: DeploymentPanel = get_node_or_null("UI/DeploymentPanel")


func _ready() -> void:
	if GameState.current_level:
		level = GameState.current_level

	result_label.hide()
	_load_level()
	camera.setup(level_map.get_size())

	turn_manager = TurnManager.new(units)

	board.setup(grid)
	cursor.setup(grid)
	cursor.moved.connect(_on_cursor_moved)
	player.setup(self, action_menu, cursor, end_turn_button)
	enemies.setup(self)
	deployment.setup(self, cursor, deploy_panel)
	deployment.finished.connect(start_battle)
	deployment.begin(level_map.get_deploy_cells())   


func start_battle() -> void:
	_apply_commander_bonuses()   
	player.activate()
	turn_manager.start_phase(Unit.Team.PLAYER)


func _unhandled_input(event: InputEvent) -> void:
	if not is_over:
		return
	if event.is_action_pressed("restart"):
		GameState.restart_level()
	elif event.is_action_pressed("ui_accept"):
		GameState.go_to_level_select()


# --- Setup ------------------------------------------------------------------------

func _load_level() -> void:
	level_map = level.map.instantiate()
	add_child(level_map)
	move_child(level_map, 0)   

	grid = Grid.new(level_map.get_size())
	for cell in level_map.get_blocked_cells():
		grid.set_blocked(cell, true)

	for spawn in level_map.get_enemy_spawns():
		spawn_unit(spawn.unit, level_map.cell_of(spawn), Unit.Team.ENEMY)


func get_squad() -> Array[CharacterState]:
	if not GameState.squad.is_empty():
		return GameState.squad
	return GameState.roster.slice(0, level_map.get_deploy_cells().size())


func _apply_commander_bonuses() -> void:
	var atk := 0
	var mov := 0
	for character in GameState.commanders:
		var bonus := character.data.commander_bonus
		if bonus:
			atk += bonus.attack
			mov += bonus.move_range

	for unit in units.values():
		if unit.team == Unit.Team.PLAYER:
			unit.bonus_attack = atk
			unit.bonus_move = mov
	print("Commander bonuses: +%d ATK, +%d MOV" % [atk, mov])


# --- Queries ----------------------------------------------------------------------

func get_unit_at(cell: Vector2i) -> Unit:
	return units.get(grid.get_occupant(cell))   # null if empty


func get_targets(unit: Unit) -> Array[Unit]:
	return Combat.targets_from(unit, unit.cell, grid, units)


## The unit on the map for a hero, or null if they haven't been placed.
func get_unit_for(character: CharacterState) -> Unit:
	for unit in units.values():
		if unit.character == character:
			return unit
	return null


# --- Shared actions (used by both the player and the AI) --------------------------

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



func move_unit(unit: Unit, cell: Vector2i) -> void:
	await move_unit_along(unit, grid.find_path(unit.cell, cell, unit.move_range, unit.can_fly))



func move_unit_along(unit: Unit, path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	grid.move(unit.entity_id, unit.cell, path.back())   
	var tween := unit.move_along(path, grid)            
	if tween:
		await tween.finished


func deploy_character(character: CharacterState, cell: Vector2i) -> Unit:
	var unit := spawn_unit(character.data, cell, Unit.Team.PLAYER)
	unit.character = character
	return unit


func undeploy(unit: Unit) -> void:
	_remove_unit(unit)


func reposition(unit: Unit, cell: Vector2i) -> void:
	var other := get_unit_at(cell)
	if other == unit:
		return
	var from := unit.cell

	grid.remove(from)
	if other:
		grid.remove(cell)
		grid.place(other.entity_id, from)
		other.snap_to_cell(grid, from)
	grid.place(unit.entity_id, cell)
	unit.snap_to_cell(grid, cell)

func undo_move(unit: Unit, origin: Vector2i) -> void:
	grid.move(unit.entity_id, unit.cell, origin)
	unit.snap_to_cell(grid, origin)

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


# --- Internals --------------------------------------------------------------------

func _kill_unit(unit: Unit) -> void:
	print("%s is defeated" % unit.data.display_name)
	_remove_unit(unit)

func _remove_unit(unit: Unit) -> void:
	grid.remove(unit.cell)
	units.erase(unit.entity_id)
	unit.queue_free()


func _get_outcome() -> Outcome:
	var players := 0
	var enemyunits := 0
	for unit in units.values():
		match unit.team:
			Unit.Team.PLAYER: players += 1
			Unit.Team.ENEMY: enemyunits += 1
	if enemyunits == 0:
		return Outcome.VICTORY
	if players == 0:
		return Outcome.DEFEAT
	return Outcome.NONE


func _end_battle(outcome: Outcome) -> void:
	is_over = true
	var headline := "Victory!" if outcome == Outcome.VICTORY else "Defeat..."
	result_label.text = headline + "\nR: retry   Enter: continue"
	result_label.show()
	battle_ended.emit(outcome)


# --- Hover ------------------------------------------------------------------------

## Shows the health bar of whichever unit the cursor is on, and hides the last one.
func _on_cursor_moved(cell: Vector2i) -> void:
	var unit := get_unit_at(cell)
	if unit == _hovered:
		return
	if is_instance_valid(_hovered):   # it may have died since we last hovered it
		_hovered.show_hp(false)
	_hovered = unit
	if _hovered:
		_hovered.show_hp(true)
