class_name PlayerController extends Node

enum State { INACTIVE, IDLE, UNIT_SELECTED, BUSY, CHOOSING_ACTION, TARGETING, COMMAND_TARGETING, DISABLED }

var _battle: Battle
var _menu: ActionMenu
var _cursor: GridCursor
var _end_turn_button: Button

var _state: State = State.INACTIVE:
	set(value):
		_state = value
		_refresh_end_turn_button()
		_refresh_cursor()

var _selected: Unit = null
var _move_origin: Vector2i
var _reachable: Array[Vector2i] = []
var _path: Array[Vector2i] = []   
var _attack_cells: Array[Vector2i] = []
var _pending_command: CommanderState = null   # the ability waiting for a target
var _command_cells: Array[Vector2i] = []      # cells holding valid targets

func setup(battle: Battle, menu: ActionMenu, cursor: GridCursor, end_turn_button: Button) -> void:
	_battle = battle
	_menu = menu
	_cursor = cursor
	_end_turn_button = end_turn_button

	_cursor.moved.connect(_on_cursor_moved)
	_cursor.confirmed.connect(_on_confirmed)
	_cursor.cancelled.connect(_on_cancelled)
	_menu.attack_chosen.connect(_on_attack_chosen)
	_menu.wait_chosen.connect(_on_wait_chosen)
	_menu.ability_chosen.connect(_on_ability_chosen)
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.turn_manager.phase_started.connect(_on_phase_started)

	_end_turn_button.focus_mode = Control.FOCUS_NONE
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_refresh_end_turn_button()


func activate() -> void:
	_state = State.IDLE


# --- Input ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("end_turn"):
		_on_end_turn_pressed()


func _on_cursor_moved(cell: Vector2i) -> void:
	if _state == State.UNIT_SELECTED:
		_update_path(cell)

func _on_confirmed(cell: Vector2i) -> void:
	match _state:
		State.IDLE: _confirm_idle(cell)
		State.UNIT_SELECTED: _confirm_selected(cell)
		State.TARGETING: _confirm_targeting(cell)
		State.COMMAND_TARGETING: _confirm_command_target(cell)


func _on_cancelled(_cell: Vector2i) -> void:
	match _state:
		State.UNIT_SELECTED: _deselect()
		State.CHOOSING_ACTION: _undo_move()
		State.TARGETING: _cancel_targeting()
		State.COMMAND_TARGETING: _end_command_targeting()

# --- Confirming, one function per state -------------------------------------------

func _confirm_idle(cell: Vector2i) -> void:
	var unit := _battle.get_unit_at(cell)
	if unit and _battle.turn_manager.can_act(unit):
		_select(unit)


func _confirm_selected(cell: Vector2i) -> void:
	if not (cell in _reachable):  
		_deselect()
		return
	if _path.is_empty() or _path.back() != cell:
		_update_path(cell)   
	_move_selected_along(_path.duplicate())


func _confirm_targeting(cell: Vector2i) -> void:
	if not (cell in _attack_cells):
		return
	var target := _battle.get_unit_at(cell)
	if target and target in _battle.get_targets(_selected):
		if not _battle.resolve_attack(_selected, target):
			_finish_unit()


# --- Selection --------------------------------------------------------------------

func _select(unit: Unit) -> void:
	_selected = unit
	_reachable = _battle.grid.get_reachable_cells(unit.cell, unit.move_range, unit.can_fly, unit.can_pass_units)
	_attack_cells.clear()
	_battle.board.show_moves(_reachable)
	_cursor.move_to(unit.cell)
	_path = [unit.cell]
	_battle.board.show_path(_path)
	_state = State.UNIT_SELECTED


func _deselect() -> void:
	_selected = null
	_reachable.clear()
	_path.clear()
	_attack_cells.clear()
	_battle.board.clear_highlights()
	_state = State.IDLE


# --- Moving and the action menu ------------------------------------------------------
func _update_path(cell: Vector2i) -> void:
	if not (cell in _reachable):
		return   
		
	var index := _path.find(cell)
	if index != -1:
		_path.resize(index + 1)   
	elif _is_neighbor(_path.back(), cell) and _path.size() - 1 < _selected.move_range:
		_path.append(cell)       
	else:
				_path = _battle.grid.find_path(_selected.cell, cell, _selected.move_range, _selected.can_fly, _selected.can_pass_units)

	_battle.board.show_path(_path)


func _is_neighbor(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func _move_selected_along(path: Array[Vector2i]) -> void:
	_move_origin = _selected.cell
	_state = State.BUSY
	_battle.board.clear_highlights()
	await _battle.move_unit_along(_selected, path)
	_open_menu()


func _open_menu() -> void:
	_state = State.CHOOSING_ACTION
	var screen_pos := get_viewport().get_canvas_transform() * _selected.position
	var can_attack := not _battle.get_targets(_selected).is_empty()
	_menu.open(screen_pos, can_attack, _battle.commanders.usable())




func _undo_move() -> void:
	var unit := _selected
	_menu.close()
	_battle.undo_move(unit, _move_origin)
	_select(unit)  


# --- Actions ---------------------------------------------------------------------------

func _on_attack_chosen() -> void:
	_menu.close()
	_attack_cells = _battle.grid.get_cells_in_range(_selected.cell, _selected.data.attack_range_min, _selected.data.attack_range_max)
	_battle.board.show_attacks(_attack_cells)
	var targets := _battle.get_targets(_selected)
	if not targets.is_empty():
		_cursor.move_to(targets[0].cell)
	_state = State.TARGETING

## Commander abilities are free actions: use it, then the menu reopens,
## and the hero can still attack, wait, or undo their move.
func _on_ability_chosen(command: CommanderState) -> void:
	_menu.close()
	if not command.bonus.needs_target():
		_battle.commanders.activate(command)
		_open_menu()
		return

	# Targeted ability: mark every valid unit, and let the cursor pick one.
	_pending_command = command
	_command_cells.clear()
	for unit in _battle.units.values():
		if command.bonus.can_target(_battle, unit):
			_command_cells.append(unit.cell)
	_battle.board.show_marked(_command_cells)
	_state = State.COMMAND_TARGETING


func _confirm_command_target(cell: Vector2i) -> void:
	if not (cell in _command_cells):
		return   # not a valid target: ignore the click, like attack targeting does
	_battle.commanders.activate(_pending_command, _battle.get_unit_at(cell))
	_end_command_targeting()


## Leaves command targeting (after using the ability, or cancelling) and
## returns to the action menu.
func _end_command_targeting() -> void:
	_pending_command = null
	_command_cells.clear()
	_battle.board.show_marked([])
	_cursor.move_to(_selected.cell)
	_open_menu()

func _cancel_targeting() -> void:
	_attack_cells.clear()
	_battle.board.clear_highlights()
	_cursor.move_to(_selected.cell)
	_open_menu()


func _on_wait_chosen() -> void:
	_menu.close()
	_finish_unit()

func _finish_unit() -> void:
	var unit := _selected
	_deselect()
	_battle.turn_manager.mark_acted(unit)


func _on_battle_ended(_outcome: Battle.Outcome) -> void:
	_menu.close()
	_deselect()
	_state = State.DISABLED


# --- End turn and cursor --------------------------------------------------------------

func _can_end_turn() -> bool:
	return _state == State.IDLE and _battle.turn_manager.current_team == Unit.Team.PLAYER


func _on_end_turn_pressed() -> void:
	if _can_end_turn():
		_battle.turn_manager.end_phase()


func _on_phase_started(_team: Unit.Team) -> void:
	_refresh_end_turn_button()
	_refresh_cursor()


func _refresh_end_turn_button() -> void:
	if _end_turn_button == null or _battle == null:
		return   
	_end_turn_button.visible = _state != State.INACTIVE   # hidden during deployment
	_end_turn_button.disabled = not _can_end_turn()


func _refresh_cursor() -> void:
	if _cursor == null or _battle == null or _state == State.INACTIVE:
		return   # during deployment, DeploymentController owns the cursor
	var players_turn := _battle.turn_manager.current_team == Unit.Team.PLAYER
	var usable := _state in [State.IDLE, State.UNIT_SELECTED, State.TARGETING, State.COMMAND_TARGETING]
	_cursor.enabled = usable and players_turn
