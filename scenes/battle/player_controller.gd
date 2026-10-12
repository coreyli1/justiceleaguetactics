class_name PlayerController extends Node
## Turns mouse/keyboard input into actions for the player's units.
## Owns the input state machine, and asks Battle to actually do things.
##
## Everything goes through the cursor: the mouse moves it by hovering, the
## arrow keys move it one cell at a time, and "select" confirms the cell it's on.
##
## While a unit is selected, moving the cursor draws its route (Fire Emblem style):
## stepping to a neighbouring cell extends the path, stepping back onto it trims it,
## and jumping (or running out of movement) falls back to the shortest route.
##
## Before turn 1 there is a deployment phase: heroes start off the map. Pick one
## (from the panel or the map), then confirm a deploy tile to place or move them.
## Cancel on a placed hero sends them back to the panel.

enum State { DEPLOYING, DEPLOY_PICKED, IDLE, UNIT_SELECTED, BUSY, CHOOSING_ACTION, TARGETING, DISABLED }

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
var _deploy_panel: DeploymentPanel   # optional: deployment still works without it

## Every state change also refreshes the End Turn button, so it can never be
## clickable at the wrong moment.
var _state: State = State.IDLE:
	set(value):
		_state = value
		_refresh_end_turn_button()
		_refresh_cursor()

var _selected: Unit = null
var _move_origin: Vector2i
var _reachable: Array[Vector2i] = []
var _path: Array[Vector2i] = []   # the route being drawn, starting at the unit's cell
var _attack_cells: Array[Vector2i] = []

var _deploy_cells: Array[Vector2i] = []
var _picked: CharacterState = null   # hero picked up during deployment (placed or not)


func setup(battle: Battle, menu: ActionMenu, cursor: GridCursor, end_turn_button: Button, deploy_panel: DeploymentPanel = null) -> void:
	_battle = battle
	_menu = menu
	_cursor = cursor
	_end_turn_button = end_turn_button
	_deploy_panel = deploy_panel
	if _deploy_panel:
		_deploy_panel.hero_picked.connect(_pick_up)
		_deploy_panel.start_pressed.connect(_finish_deployment)

	_menu.attack_chosen.connect(_on_attack_chosen)
	_menu.wait_chosen.connect(_on_wait_chosen)
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.turn_manager.phase_started.connect(_on_phase_started)

	# FOCUS_NONE: clicking the button must not steal keyboard focus, or the
	# arrow keys would start navigating UI instead of moving the cursor.
	_end_turn_button.focus_mode = Control.FOCUS_NONE
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_refresh_end_turn_button()

	_place_cursor_on_first_hero()


# --- Input ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _battle == null:
		return

	# Hovering the mouse over the grid always moves the cursor, in any state.
	if event is InputEventMouseMotion:
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
			State.DEPLOYING: _send_back(_cursor.cell)
			State.DEPLOY_PICKED: _put_down()
			State.UNIT_SELECTED: _deselect()
			State.CHOOSING_ACTION: _undo_move()
			State.TARGETING: _cancel_targeting()

	elif event.is_action_pressed("end_turn"):
		_on_end_turn_pressed()


## What "select" does on a cell depends on the state.
func _confirm(cell: Vector2i) -> void:
	match _state:
		State.DEPLOYING: _confirm_deploying(cell)
		State.DEPLOY_PICKED: _confirm_deploy_picked(cell)
		State.IDLE: _confirm_idle(cell)
		State.UNIT_SELECTED: _confirm_selected(cell)
		State.TARGETING: _confirm_targeting(cell)


# --- Cursor -----------------------------------------------------------------------

func _cursor_active() -> bool:
	return _state in [State.DEPLOYING, State.DEPLOY_PICKED, State.IDLE, State.UNIT_SELECTED, State.TARGETING]


func _set_cursor(cell: Vector2i) -> void:
	if not _battle.grid.is_in_bounds(cell):
		return
	_cursor.move_to(cell)
	if _state == State.UNIT_SELECTED:
		_update_path(cell)


func _mouse_cell() -> Vector2i:
	return _battle.grid.world_to_cell(_battle.get_global_mouse_position())


func _place_cursor_on_first_hero() -> void:
	for unit in _battle.units.values():
		if unit.team == Unit.Team.PLAYER:
			_cursor.move_to(unit.cell)
			return


# --- Deployment ----------------------------------------------------------------------

## Called by Battle once the level is loaded. Turn 1 waits for _finish_deployment().
func begin_deployment(cells: Array[Vector2i]) -> void:
	_deploy_cells = cells
	_battle.board.show_moves(_deploy_cells)   # highlight where heroes may stand
	var squad := _battle.get_squad()

	if _deploy_panel == null:
		# No panel to place heroes from: auto-place everyone so the battle is still playable.
		for i in mini(squad.size(), cells.size()):
			_battle.deploy_character(squad[i], cells[i])
	else:
		# Deploy tiles mostly on the left half? Put the panel on the right, and vice versa.
		var total_x := 0
		for cell in cells:
			total_x += cell.x
		var on_right := cells.is_empty() or total_x / float(cells.size()) < _battle.grid.size.x / 2.0
		_deploy_panel.open(squad, on_right)

	if not cells.is_empty():
		_cursor.move_to(cells[0])   # no heroes on the map yet, so start on a deploy tile
	_state = State.DEPLOYING
	_refresh_deploy_ui()


func _is_deploying() -> bool:
	return _state in [State.DEPLOYING, State.DEPLOY_PICKED]


func _confirm_deploying(cell: Vector2i) -> void:
	var unit := _battle.get_unit_at(cell)
	if unit and unit.team == Unit.Team.PLAYER:
		_pick_up(unit.character)


## Picks a hero up, from the map or from the panel's list.
func _pick_up(character: CharacterState) -> void:
	if not _is_deploying():
		return
	_picked = character
	var unit := _battle.get_unit_for(character)
	if unit:
		_battle.board.show_marked([unit.cell])
		_cursor.move_to(unit.cell)
	else:
		_battle.board.show_marked([])
	_state = State.DEPLOY_PICKED
	_refresh_deploy_ui()


func _confirm_deploy_picked(cell: Vector2i) -> void:
	if cell in _deploy_cells:
		var unit := _battle.get_unit_for(_picked)
		if unit:
			_battle.reposition(unit, cell)   # already on the map: move, or swap
		else:
			var occupant := _battle.get_unit_at(cell)
			if occupant:
				_battle.undeploy(occupant)   # coming from the panel: bench whoever stood here
			_battle.deploy_character(_picked, cell)
	_put_down()


func _put_down() -> void:
	_picked = null
	_battle.board.show_marked([])
	_state = State.DEPLOYING
	_refresh_deploy_ui()


## Cancel on a placed hero (with nobody picked up) sends them back to the panel.
func _send_back(cell: Vector2i) -> void:
	var unit := _battle.get_unit_at(cell)
	if unit and unit.team == Unit.Team.PLAYER:
		_battle.undeploy(unit)
		_refresh_deploy_ui()


func _deployed_count() -> int:
	var count := 0
	for unit in _battle.units.values():
		if unit.team == Unit.Team.PLAYER:
			count += 1
	return count


func _can_start_battle() -> bool:
	return _is_deploying() and _deployed_count() > 0


func _refresh_deploy_ui() -> void:
	if _deploy_panel:
		var placed := {}
		for unit in _battle.units.values():
			if unit.character:
				placed[unit.character] = true
		_deploy_panel.refresh(placed, _picked, _can_start_battle())
	_refresh_end_turn_button()


func _finish_deployment() -> void:
	if not _can_start_battle():
		return   # need at least one hero on the map
	_picked = null
	_deploy_cells.clear()
	if _deploy_panel:
		_deploy_panel.close()
	_battle.board.clear_highlights()
	_state = State.IDLE
	_battle.start_battle()


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


# --- End turn -------------------------------------------------------------------------

func _can_end_turn() -> bool:
	return _state == State.IDLE and _battle.turn_manager.current_team == Unit.Team.PLAYER


## The end-turn key starts the battle during deployment, then ends turns.
func _on_end_turn_pressed() -> void:
	if _is_deploying():
		_finish_deployment()
	elif _can_end_turn():
		_battle.turn_manager.end_phase()


func _refresh_end_turn_button() -> void:
	if _end_turn_button == null or _battle == null:
		return   # the setter can run before setup() finishes
	var deploying := _is_deploying()
	# With a panel, its own Start button takes over during deployment, so hide End Turn.
	# Without one, End Turn doubles as "Start Battle".
	_end_turn_button.visible = not (deploying and _deploy_panel)
	_end_turn_button.text = "Start Battle" if deploying else "End Turn"
	_end_turn_button.disabled = not (_can_start_battle() or _can_end_turn())


func _refresh_cursor() -> void:
	if _cursor == null or _battle == null:
		return   # the setter can run before setup() finishes
	var players_turn := _is_deploying() or _battle.turn_manager.current_team == Unit.Team.PLAYER
	_cursor.visible = _cursor_active() and players_turn
	
	print("cursor visible: ", _cursor.visible, "  team: ", _battle.turn_manager.current_team)

func _on_phase_started(_team: Unit.Team) -> void:
	_refresh_end_turn_button()
	_refresh_cursor()
