class_name PlayerController extends Node
## Plays the player's turns: select a hero, draw their route, move, then attack or wait.
## Owns the turn state machine and asks Battle to actually do things.
## Input arrives through the cursor's signals (moved / confirmed / cancelled);
## deployment before turn 1 is handled by DeploymentController.
##
## While a unit is selected, moving the cursor draws its route (Fire Emblem style):
## stepping to a neighbouring cell extends the path, stepping back onto it trims it,
## and jumping (or running out of movement) falls back to the shortest route.

enum State { INACTIVE, IDLE, UNIT_SELECTED, BUSY, CHOOSING_ACTION, TARGETING, DISABLED }

var _battle: Battle
var _menu: ActionMenu
var _cursor: GridCursor
var _end_turn_button: Button

## Every state change refreshes the End Turn button and the cursor, so neither
## can be usable at the wrong moment.
var _state: State = State.INACTIVE:
	set(value):
		_state = value
		_refresh_end_turn_button()
		_refresh_cursor()

var _selected: Unit = null
var _move_origin: Vector2i
var _reachable: Array[Vector2i] = []
var _path: Array[Vector2i] = []   # the route being drawn, starting at the unit's cell
var _attack_cells: Array[Vector2i] = []


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
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.turn_manager.phase_started.connect(_on_phase_started)

	# FOCUS_NONE: clicking the button must not steal keyboard focus, or the
	# arrow keys would start navigating UI instead of moving the cursor.
	_end_turn_button.focus_mode = Control.FOCUS_NONE
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_refresh_end_turn_button()


## Called by Battle when deployment is done and turn 1 begins.
func activate() -> void:
	_state = State.IDLE


# --- Input ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("end_turn"):
		_on_end_turn_pressed()


func _on_cursor_moved(cell: Vector2i) -> void:
	if _state == State.UNIT_SELECTED:
		_update_path(cell)


## What "select" does on a cell depends on the state.
func _on_confirmed(cell: Vector2i) -> void:
	match _state:
		State.IDLE: _confirm_idle(cell)
		State.UNIT_SELECTED: _confirm_selected(cell)
		State.TARGETING: _confirm_targeting(cell)


func _on_cancelled(_cell: Vector2i) -> void:
	match _state:
		State.UNIT_SELECTED: _deselect()
		State.CHOOSING_ACTION: _undo_move()
		State.TARGETING: _cancel_targeting()


# --- Confirming, one function per state -------------------------------------------

func _confirm_idle(cell: Vector2i) -> void:
	var unit := _battle.get_unit_at(cell)
	if unit and _battle.turn_manager.can_act(unit):
		_select(unit)


func _confirm_selected(cell: Vector2i) -> void:
	if not (cell in _reachable):   # includes the unit's own cell (act in place)
		_deselect()
		return
	if _path.is_empty() or _path.back() != cell:
		_update_path(cell)   # safety net: make sure the path really ends here
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
	_reachable = _battle.grid.get_reachable_cells(unit.cell, unit.move_range)
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

## Rebuilds the drawn route so it ends at `cell`.
func _update_path(cell: Vector2i) -> void:
	if not (cell in _reachable):
		return   # out of range: keep the last valid path on screen

	var index := _path.find(cell)
	if index != -1:
		_path.resize(index + 1)   # stepped back onto the path: trim everything after
	elif _is_neighbor(_path.back(), cell) and _path.size() - 1 < _selected.move_range:
		_path.append(cell)        # one step further, still within movement: extend
	else:
		# Jumped (mouse) or out of movement: fall back to the shortest route.
		_path = _battle.grid.find_path(_selected.cell, cell, _selected.move_range)

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
	_menu.open(screen_pos, not _battle.get_targets(_selected).is_empty())


func _undo_move() -> void:
	var unit := _selected
	_menu.close()
	_battle.undo_move(unit, _move_origin)
	_select(unit)   # also puts the cursor back on the unit


# --- Actions ---------------------------------------------------------------------------

func _on_attack_chosen() -> void:
	_menu.close()
	_attack_cells = _battle.grid.get_cells_in_range(_selected.cell, _selected.data.attack_range_min, _selected.data.attack_range_max)
	_battle.board.show_attacks(_attack_cells)
	# Jump the cursor onto the first valid target, so keyboard players can confirm right away.
	var targets := _battle.get_targets(_selected)
	if not targets.is_empty():
		_cursor.move_to(targets[0].cell)
	_state = State.TARGETING


func _cancel_targeting() -> void:
	_attack_cells.clear()
	_battle.board.clear_highlights()
	_cursor.move_to(_selected.cell)
	_open_menu()


func _on_wait_chosen() -> void:
	_menu.close()
	_finish_unit()


## The single exit path for "this unit is done for the turn".
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
		return   # the setter can run before setup() finishes
	_end_turn_button.visible = _state != State.INACTIVE   # hidden during deployment
	_end_turn_button.disabled = not _can_end_turn()


func _refresh_cursor() -> void:
	if _cursor == null or _battle == null or _state == State.INACTIVE:
		return   # during deployment, DeploymentController owns the cursor
	var players_turn := _battle.turn_manager.current_team == Unit.Team.PLAYER
	var usable := _state in [State.IDLE, State.UNIT_SELECTED, State.TARGETING]
	_cursor.enabled = usable and players_turn
