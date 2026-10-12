class_name Battle extends Node2D
## Owns the battle's state (grid, units, turns) and the shared actions that
## both the player and the AI use: moving, attacking, killing, ending.
## It does NOT handle player input or drawing; see PlayerController and Board.
##
## Expected scene tree (UI, PlayerController and PauseMenu directly under Battle):
##   Battle
##    ├ Board
##    ├ Entities            (empty in the editor; units are added here at runtime)
##    ├ Cursor
##    ├ PlayerController
##    ├ UI
##    │   ├ ActionMenu (Attack, Wait)
##    │   ├ ResultLabel
##    │   ├ EndTurnButton
##    │   └ DeploymentPanel
##    └ PauseMenu
## The level's map scene is added as the first child at runtime.

signal battle_ended(outcome: Outcome)

enum Outcome { NONE, VICTORY, DEFEAT }

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")

## Used when the battle is run directly (F6) without picking a level first.
@export var level: LevelData

var grid: Grid
var level_map: LevelMap
var units: Dictionary = {}   # entity_id -> Unit (living units only)
var turn_manager: TurnManager
var is_over := false

var _next_entity_id := 0

@onready var camera: BattleCamera = $Camera
@onready var board: Board = $Board
@onready var entities: Node2D = $Entities
@onready var cursor: GridCursor = $Cursor
@onready var player: PlayerController = $PlayerController
@onready var action_menu: ActionMenu = $UI/ActionMenu
@onready var result_label: Label = $UI/ResultLabel
@onready var end_turn_button: Button = $UI/EndTurnButton
## Optional: if the scene has no DeploymentPanel instance, deployment still works
## (the End Turn button doubles as "Start Battle").
@onready var deploy_panel: DeploymentPanel = get_node_or_null("UI/DeploymentPanel")


func _ready() -> void:
	if GameState.current_level:
		level = GameState.current_level

	result_label.hide()
	_load_level()
	camera.setup(level_map.get_size())

	turn_manager = TurnManager.new(units)
	turn_manager.phase_started.connect(_on_phase_started)

	board.setup(grid)
	#cursor.moved.connect(camera.follow) allows camera to folow cursor
	player.setup(self, action_menu, cursor, end_turn_button, deploy_panel)
	player.begin_deployment(level_map.get_deploy_cells())   # turn 1 waits for start_battle()


## Called when the player confirms their formation. Starts turn 1.
func start_battle() -> void:
	_apply_commander_bonuses()   # heroes exist now, so they can receive the bonuses
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
	move_child(level_map, 0)   # first child = drawn first, under highlights and units

	grid = Grid.new(level_map.get_size())
	for cell in level_map.get_blocked_cells():
		grid.set_blocked(cell, true)

	for spawn in level_map.get_enemy_spawns():
		spawn_unit(spawn.unit, level_map.cell_of(spawn), Unit.Team.ENEMY)
	# Heroes are NOT spawned here: the player places them during deployment.


## The heroes available for this battle.
## F6 testing with no squad picked: borrow the first few heroes from the roster.
func get_squad() -> Array[CharacterState]:
	if not GameState.squad.is_empty():
		return GameState.squad
	return GameState.roster.slice(0, level_map.get_deploy_cells().size())


## Sums every chosen commander's bonus and gives it to the whole squad.
## Passive: applied once at the start, unaffected by deaths.
func _apply_commander_bonuses() -> void:
	var atk := 0
	var def := 0
	var mov := 0
	for character in GameState.commanders:
		var bonus := character.data.commander_bonus
		if bonus:
			atk += bonus.attack
			def += bonus.defense
			mov += bonus.move_range

	for unit in units.values():
		if unit.team == Unit.Team.PLAYER:
			unit.bonus_attack = atk
			unit.bonus_defense = def
			unit.bonus_move = mov
	print("Commander bonuses: +%d ATK, +%d DEF, +%d MOV" % [atk, def, mov])


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


## Moves a unit along the shortest path to a cell (used by the AI). Call with await.
func move_unit(unit: Unit, cell: Vector2i) -> void:
	await move_unit_along(unit, grid.find_path(unit.cell, cell, unit.move_range))


## Moves a unit along a specific path; the first cell is where it stands
## (used by the player's drawn route). Call with await.
func move_unit_along(unit: Unit, path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	grid.move(unit.entity_id, unit.cell, path.back())   # logic first...
	var tween := unit.move_along(path, grid)             # ...then visuals
	if tween:
		await tween.finished


## Deployment: puts a hero from the squad onto the map.
func deploy_character(character: CharacterState, cell: Vector2i) -> Unit:
	var unit := spawn_unit(character.data, cell, Unit.Team.PLAYER)
	unit.character = character
	return unit


## Deployment: takes a hero off the map, back to the squad list.
func undeploy(unit: Unit) -> void:
	_remove_unit(unit)


## Deployment: moves a hero to another cell, swapping with whoever stands there.
func reposition(unit: Unit, cell: Vector2i) -> void:
	var other := get_unit_at(cell)
	if other == unit:
		return
	var from := unit.cell

	# Clear both cells from the grid BEFORE placing anyone, or placing the first
	# unit would overwrite the second one's occupancy.
	grid.remove(from)
	if other:
		grid.remove(cell)
		grid.place(other.entity_id, from)
		other.snap_to_cell(grid, from)
	grid.place(unit.entity_id, cell)
	unit.snap_to_cell(grid, cell)


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


# --- Enemy phase ------------------------------------------------------------------

func _on_phase_started(team: Unit.Team) -> void:
	if team == Unit.Team.ENEMY:
		_run_enemy_phase()


func _run_enemy_phase() -> void:
	# false = the timer respects pause, so enemies don't act while the game is paused.
	await get_tree().create_timer(0.4, false).timeout

	var enemies := units.values().filter(func(u): return u.team == Unit.Team.ENEMY)
	for unit in enemies:
		if not units.has(unit.entity_id):
			continue   # died earlier this phase
		if unit.data.ai_behavior:
			var decision: AIBehavior.Decision = unit.data.ai_behavior.decide(unit, grid, units)
			if decision.cell != unit.cell:
				camera.follow(unit.cell)
				await move_unit(unit, decision.cell)
			if decision.target:
				if resolve_attack(unit, decision.target):
					return   # battle over, so don't start another turn
		turn_manager.mark_acted(unit)
		await get_tree().create_timer(0.25, false).timeout

	turn_manager.end_phase()


# --- Internals --------------------------------------------------------------------

func _kill_unit(unit: Unit) -> void:
	print("%s is defeated" % unit.data.display_name)
	_remove_unit(unit)


## Removes a unit from all three places it's registered: grid, dictionary, scene.
func _remove_unit(unit: Unit) -> void:
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
	is_over = true
	var headline := "Victory!" if outcome == Outcome.VICTORY else "Defeat..."
	result_label.text = headline + "\nR: retry   Enter: continue"
	result_label.show()
	battle_ended.emit(outcome)
