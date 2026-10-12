class_name PlayerController extends Node
## Turns mouse/keyboard input into actions for the player's units.
## Owns the input state machine, and asks Battle to actually do things.
##
## Everything goes through the cursor: the mouse moves it by hovering, the
## arrow keys move it one cell at a time, and "select" confirms the cell it's on.

enum State { IDLE, UNIT_SELECTED, BUSY, CHOOSING_ACTION, TARGETING, DISABLED }

const CURSOR_ACTIONS := {
	"cursor_up": Vector2i.UP,
	"cursor_down": Vector2i.DOWN,
	"cursor_left": Vector2i.LEFT,
	"cursor_right": Vector2i.RIGHT,
}

var _battle: Battle
var _menu: ActionMenu
var _cursor: GridCursor
var _end_turn_button: Button

## Every state change also refreshes the End Turn button, so it can never be
## clickable at the wrong moment.
var _state: State = State.IDLE:
	set(value):
		_state = value
		_refresh_end_turn_button()

var _selected: Unit = null
var _move_origin: Vector2i
var _reachable: Array[Vector2i] = []
var _attack_cells: Array[Vector2i] = []


func setup(battle: Battle, menu: ActionMenu, cursor: GridCursor, end_turn_button: Button) -> void:
	_battle = battle
	_menu = menu
	_cursor = cursor
	_end_turn_button = end_turn_button

	_menu.attack_chosen.connect(_on_attack_chosen)
	_menu.wait_chosen.connect(_on_wait_chosen)
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.turn_manager.phase_started.connect(func(_team): _refresh_end_turn_button())

	# FOCUS_NONE: clicking the button must not steal keyboard focus, or the
	# arrow keys would start navigating UI instead of moving the cursor.
	_end_turn_button.focus_mode = Control.FOCUS_NONE
	_end_turn_button.pressed.connect(_try_end_turn)
	_refresh_end_turn_button()

	_place_cursor_on_first_hero()


# --- Input ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _battle == null:
		return

	# Hovering the mouse moves the cursor.
	if event is InputEventMouseMotion:
		if _cursor_active():
			_set_cursor(_mouse_cell())
		return

	# Arrow keys / WASD move it one cell (true = keep repeating while held).
	for action in CURSOR_ACTIONS:
		if event.is_action_pressed(action, true):
			if _cursor_active():
				_set_cursor(_cursor.cell + CURSOR_ACTIONS[action])
			return

	if event.is_action_pressed("select"):
		if event is InputEventMouseButton:
			var cell := _mouse_cell()
			if not _battle.grid.is_in_bounds(cell):
				return   # clicked off the map: ignore rather than act on the old cursor cell
			_set_cursor(cell)
		_confirm(_cursor.cell)

	elif event.is_action_pressed("cancel"):
		match _state:
			State.UNIT_SELECTED: _deselect()
			State.CHOOSING_ACTION: _undo_move()
			State.TARGETING: _cancel_targeting()

	elif event.is_action_pressed("end_turn"):
		_try_end_turn()


## What "select" does on a cell depends on the state.
func _confirm(cell: Vector2i) -> void:
	match _state:
		State.IDLE: _confirm_idle(cell)
		State.UNIT_SELECTED: _confirm_selected(cell)
		State.TARGETING: _confirm_targeting(cell)


# --- Cursor -----------------------------------------------------------------------

func _cursor_active() -> bool:
	return _state in [State.IDLE, State.UNIT_SELECTED, State.TARGETING]


func _set_cursor(cell: Vector2i) -> void:
	if _battle.grid.is_in_bounds(cell):
		_cursor.move_to(cell)


func _mouse_cell() -> Vector2i:
	return _battle.grid.world_to_cell(_battle.get_global_mouse_position())


func _place_cursor_on_first_hero() -> void:
	for unit in _battle.units.values():
		if unit.team == Unit.Team.PLAYER:
			_cursor.move_to(unit.cell)
			return


# --- Confirming, one function per state -------------------------------------------

func _confirm_idle(cell: Vector2i) -> void:
	var unit := _battle.get_unit_at(cell)
	if unit and _battle.turn_manager.can_act(unit):
		_select(unit)


func _confirm_selected(cell: Vector2i) -> void:
	if cell in _reachable:   # includes the unit's own cell (act in place)
		_move_selected_to(cell)
	else:
		_deselect()


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
	_state = State.UNIT_SELECTED


func _deselect() -> void:
	_selected = null
	_reachable.clear()
	_attack_cells.clear()
	_battle.board.clear_highlights()
	_state = State.IDLE


# --- Moving and the action menu ------------------------------------------------------

func _move_selected_to(cell: Vector2i) -> void:
	_move_origin = _selected.cell
	_state = State.BUSY
	_battle.board.clear_highlights()
	await _battle.move_unit(_selected, cell)
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


# --- End turn -------------------------------------------------------------------------

func _can_end_turn() -> bool:
	return _state == State.IDLE and _battle.turn_manager.current_team == Unit.Team.PLAYER


func _try_end_turn() -> void:
	if _can_end_turn():
		_battle.turn_manager.end_phase()


func _refresh_end_turn_button() -> void:
	if _end_turn_button and _battle:   # the setter can run before setup() finishes
		_end_turn_button.disabled = not _can_end_turn()
