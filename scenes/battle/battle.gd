extends Node2D

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const GRID_SIZE := Vector2i(20, 11)

const SOLDIER := preload("res://data/units/soldier.tres")
const ARCHER := preload("res://data/units/archer.tres")
const BRUTE := preload("res://data/units/brute.tres")

var grid: Grid
var _next_entity_id := 0
var _units: Dictionary = {}   # entity_id -> Unit
var _selected: Unit = null
var _reachable: Array[Vector2i] = []
var _attack_cells: Array[Vector2i] = []
var turn_manager: TurnManager

@onready var entities: Node2D = $Entities
@onready var action_menu: VBoxContainer = $UI/ActionMenu
@onready var wait_button: Button = $UI/ActionMenu/Wait
@onready var attack_button: Button = $UI/ActionMenu/Attack
@onready var result_label: Label = $UI/ResultLabel


enum State { IDLE, UNIT_SELECTED, BUSY, CHOOSING_ACTION, TARGETING, GAME_OVER }
var _state: State = State.IDLE
var _move_origin: Vector2i

enum Outcome { NONE, VICTORY, DEFEAT }

func _ready() -> void:
	#set up UI
	action_menu.hide()
	wait_button.pressed.connect(_end_unit_action)
	attack_button.pressed.connect(_on_attack_pressed)
	
	# set up grid
	grid = Grid.new(GRID_SIZE)
	grid.set_blocked(Vector2i(3,4)	, true)
	grid.set_blocked(Vector2i(4,4)	, true)
	grid.set_blocked(Vector2i(5,4)	, true)
	
	#spawn units
	spawn_unit(SOLDIER, Vector2i(3, 3), Unit.Team.PLAYER)
	
	spawn_unit(ARCHER, Vector2i(2, 3), Unit.Team.PLAYER)
	spawn_unit(BRUTE, Vector2i(1, 3), Unit.Team.ENEMY)
	
	turn_manager = TurnManager.new(_units)
	turn_manager.phase_started.connect(_on_phase_started)
	turn_manager.start_phase(Unit.Team.PLAYER)
	
	queue_redraw()

func _get_outcome() -> Outcome:
	var players := 0
	var enemies := 0
	for unit in _units.values():
		match unit.team:
			Unit.Team.PLAYER: players += 1
			Unit.Team.ENEMY: enemies += 1

	if enemies == 0:
		return Outcome.VICTORY
	if players == 0:
		return Outcome.DEFEAT
	return Outcome.NONE

func _end_battle(outcome: Outcome) -> void:
	_hide_action_menu()
	_deselect()
	_state = State.GAME_OVER
	result_label.text = "Victory!" if outcome == Outcome.VICTORY else "Defeat..."
	result_label.text += "\nPress R to restart"
	result_label.show()

func spawn_unit(data: UnitData, cell: Vector2i, team: Unit.Team) -> Unit:
	var unit: Unit = UNIT_SCENE.instantiate()
	unit.entity_id = _next_entity_id
	_next_entity_id += 1
	
	unit.setup(data, team)
	entities.add_child(unit)
	unit.snap_to_cell(grid, cell)
	grid.place(unit.entity_id, cell)
	_units[unit.entity_id] = unit
	return unit

func _draw() -> void:
	var cell_px := Vector2(Grid.CELL_SIZE, Grid.CELL_SIZE)
	for x in grid.size.x:
		for y in grid.size.y:
			var cell := Vector2i(x, y)
			var color := Color("3a3f5c") if (x + y) % 2 == 0 else Color("2f3350")
			if grid.is_blocked(cell):
				color = Color("cdefa2ff")
			draw_rect(Rect2(grid.cell_to_world(cell), cell_px), color)
	for cell in _reachable:
		draw_rect(Rect2(grid.cell_to_world(cell), cell_px), Color(0.3, 0.6, 1.0, 0.5))
	for cell in _attack_cells:
		draw_rect(Rect2(grid.cell_to_world(cell), cell_px), Color(0.842, 0.473, 0.543, 0.5))		
	

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("select"):
		var cell := grid.world_to_cell(get_global_mouse_position())
		match _state:
			State.IDLE: _idle_click(cell)
			State.UNIT_SELECTED: _selected_click(cell)
			State.TARGETING: _targeting_click(cell)
	elif event.is_action_pressed("cancel"):
		match _state:
			State.UNIT_SELECTED: _deselect()
			State.CHOOSING_ACTION: _undo_move()
			State.TARGETING: _cancel_targeting()
	elif event.is_action_pressed("end_turn"):
		if _state == State.IDLE and turn_manager.current_team == Unit.Team.PLAYER:
			turn_manager.end_phase()
	elif event.is_action_pressed("restart") and _state == State.GAME_OVER:
		get_tree().reload_current_scene()

func _idle_click(cell: Vector2i) -> void:
	var id := grid.get_occupant(cell)
	if id == -1:
		return
	var unit: Unit = _units[id]
	if turn_manager.can_act(unit):
		_select(unit)

func _selected_click(cell: Vector2i) -> void:
	if cell in _reachable:
		_move_selected_to(cell)
	else:
		_deselect()

func _end_unit_action() -> void:
	_hide_action_menu()
	var unit := _selected
	_deselect()
	turn_manager.mark_acted(unit)

func _select(unit: Unit) -> void:
	_selected = unit
	_reachable = grid.get_reachable_cells(unit.cell, unit.move_range)
	_state = State.UNIT_SELECTED
	queue_redraw()

func _deselect() -> void:
	_selected = null
	_reachable.clear()
	_state = State.IDLE
	_attack_cells.clear()
	queue_redraw()
	
func _move_selected_to(cell: Vector2i) -> void:
	var unit := _selected
	var path := grid.find_path(unit.cell, cell, unit.move_range)
	if path.is_empty():
		return

	_move_origin = unit.cell
	_state = State.BUSY
	_reachable.clear()
	queue_redraw()

	grid.move(unit.entity_id, unit.cell, cell)
	var tween := unit.move_along(path, grid)
	if tween:
		await tween.finished

	_state = State.CHOOSING_ACTION
	_show_action_menu()
	
func _on_phase_started(team: Unit.Team) -> void:
	if team == Unit.Team.ENEMY:
		turn_manager.end_phase.call_deferred()



func _show_action_menu() -> void:
	var screen_pos := get_viewport().get_canvas_transform() * _selected.position
	action_menu.position = screen_pos + Vector2(Grid.CELL_SIZE + 2, 0)
	attack_button.visible = not _get_targets(_selected).is_empty()
	action_menu.show()
	if attack_button.visible:
		attack_button.grab_focus()
	else:
		wait_button.grab_focus()
func _hide_action_menu() -> void:
	action_menu.hide()


func _undo_move() -> void:
	var unit := _selected
	_hide_action_menu()
	grid.move(unit.entity_id, unit.cell, _move_origin)
	unit.snap_to_cell(grid, _move_origin)
	_select(unit)
	
	

	
func _get_targets(unit: Unit) -> Array[Unit]:
	var targets: Array[Unit] = []
	for cell in grid.get_cells_in_range(unit.cell, unit.data.attack_range_min, unit.data.attack_range_max):
		var id := grid.get_occupant(cell)
		if id == -1:
			continue
		var other: Unit = _units[id]
		if other.team != unit.team:
			targets.append(other)
	return targets

func _attack(target: Unit) -> void:
	var hits := Combat.resolve_attack(_selected, target)
	for hit in hits:
		hit.defender.hp -= hit.damage
		print("%s hits %s for %d (%d HP left)" % [hit.attacker.data.display_name, hit.defender.data.display_name, hit.damage, hit.defender.hp])
		if hit.defender.hp <= 0:
			_kill_unit(hit.defender)
	var outcome := _get_outcome()
	if outcome != Outcome.NONE:
		_end_battle(outcome)
		return
	_end_unit_action()

func _kill_unit(unit: Unit) -> void:
	print("%s is defeated" % unit.data.display_name)
	grid.remove(unit.cell)
	_units.erase(unit.entity_id)
	unit.queue_free()

func _on_attack_pressed() -> void:
	_hide_action_menu()
	_attack_cells = grid.get_cells_in_range(_selected.cell, _selected.data.attack_range_min, _selected.data.attack_range_max)
	_state = State.TARGETING
	queue_redraw()

func _targeting_click(cell: Vector2i) -> void:
	if not (cell in _attack_cells):
		return
	var id := grid.get_occupant(cell)
	if id == -1:
		return
	var target: Unit = _units[id]
	if target in _get_targets(_selected):
		_attack(target)

func _cancel_targeting() -> void:
	_attack_cells.clear()
	_state = State.CHOOSING_ACTION
	queue_redraw()
	_show_action_menu()
