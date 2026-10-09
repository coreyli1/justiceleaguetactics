class_name PlayerController extends Node
## Turns mouse/keyboard input into actions for the player's units.
## Owns the input state machine, and asks Battle to actually do things.

enum State { IDLE, UNIT_SELECTED, BUSY, CHOOSING_ACTION, TARGETING, DISABLED }

var _battle: Battle
var _menu: ActionMenu
var _state: State = State.IDLE

var _selected: Unit = null
var _move_origin: Vector2i
var _reachable: Array[Vector2i] = []
var _attack_cells: Array[Vector2i] = []


func setup(battle: Battle, menu: ActionMenu) -> void:
	_battle = battle
	_menu = menu
	_menu.attack_chosen.connect(_on_attack_chosen)
	_menu.wait_chosen.connect(_on_wait_chosen)
	_battle.battle_ended.connect(_on_battle_ended)


func _unhandled_input(event: InputEvent) -> void:
	if _battle == null:
		return

	if event.is_action_pressed("select"):
		var cell := _battle.grid.world_to_cell(_battle.get_global_mouse_position())
		match _state:
			State.IDLE: _click_idle(cell)
			State.UNIT_SELECTED: _click_selected(cell)
			State.TARGETING: _click_targeting(cell)

	elif event.is_action_pressed("cancel"):
		match _state:
			State.UNIT_SELECTED: _deselect()
			State.CHOOSING_ACTION: _undo_move()
			State.TARGETING: _cancel_targeting()

	elif event.is_action_pressed("end_turn"):
		if _state == State.IDLE and _battle.turn_manager.current_team == Unit.Team.PLAYER:
			_battle.turn_manager.end_phase()


# --- Clicks, one function per state -------------------------------------------

func _click_idle(cell: Vector2i) -> void:
	var unit := _battle.get_unit_at(cell)
	if unit and _battle.turn_manager.can_act(unit):
		_select(unit)


func _click_selected(cell: Vector2i) -> void:
	if cell in _reachable:   # includes the unit's own cell (act in place)
		_move_selected_to(cell)
	else:
		_deselect()


func _click_targeting(cell: Vector2i) -> void:
	if not (cell in _attack_cells):
		return
	var target := _battle.get_unit_at(cell)
	if target and target in _battle.get_targets(_selected):
		if not _battle.resolve_attack(_selected, target):
			_finish_unit()


# --- Selection ------------------------------------------------------------------

func _select(unit: Unit) -> void:
	_selected = unit
	_reachable = _battle.grid.get_reachable_cells(unit.cell, unit.move_range)
	_attack_cells.clear()
	_battle.board.show_moves(_reachable)
	_state = State.UNIT_SELECTED


func _deselect() -> void:
	_selected = null
	_reachable.clear()
	_attack_cells.clear()
	_battle.board.clear_highlights()
	_state = State.IDLE


# --- Moving and the action menu ------------------------------------------------

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
	_select(unit)


# --- Actions ---------------------------------------------------------------------

func _on_attack_chosen() -> void:
	_menu.close()
	_attack_cells = _battle.grid.get_cells_in_range(_selected.cell, _selected.data.attack_range_min, _selected.data.attack_range_max)
	_battle.board.show_attacks(_attack_cells)
	_state = State.TARGETING


func _cancel_targeting() -> void:
	_attack_cells.clear()
	_battle.board.clear_highlights()
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
