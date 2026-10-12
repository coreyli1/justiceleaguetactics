class_name DeploymentController extends Node


signal finished

var _battle: Battle
var _cursor: GridCursor
var _panel: DeploymentPanel   
var _active := false
var _cells: Array[Vector2i] = []
var _picked: CharacterState = null   


func setup(battle: Battle, cursor: GridCursor, panel: DeploymentPanel = null) -> void:
	_battle = battle
	_cursor = cursor
	_panel = panel
	_cursor.confirmed.connect(_on_confirmed)
	_cursor.cancelled.connect(_on_cancelled)
	if _panel:
		_panel.hero_picked.connect(_pick_up)
		_panel.start_pressed.connect(_finish)


func begin(cells: Array[Vector2i]) -> void:
	_cells = cells
	var squad := _battle.get_squad()

	if _panel == null:
		for i in mini(squad.size(), cells.size()):
			_battle.deploy_character(squad[i], cells[i])
		finished.emit()
		return

	_battle.board.show_moves(_cells)  

	var total_x := 0
	for cell in cells:
		total_x += cell.x
	var on_right := cells.is_empty() or total_x / float(cells.size()) < _battle.grid.size.x / 2.0
	_panel.open(squad, on_right)

	if not cells.is_empty():
		_cursor.move_to(cells[0])   
	_active = true
	_cursor.enabled = true
	_refresh()


# --- Input ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _active and event.is_action_pressed("end_turn"):
		_finish()

		get_viewport().set_input_as_handled()


func _on_confirmed(cell: Vector2i) -> void:
	if not _active:
		return
	if _picked == null:
		var unit := _battle.get_unit_at(cell)
		if unit and unit.team == Unit.Team.PLAYER:
			_pick_up(unit.character)
	else:
		_place_picked(cell)


func _on_cancelled(cell: Vector2i) -> void:
	if not _active:
		return
	if _picked:
		_put_down()
	else:
		_send_back(cell)


# --- Actions ----------------------------------------------------------------------
func _pick_up(character: CharacterState) -> void:
	if not _active:
		return
	_picked = character
	var unit := _battle.get_unit_for(character)
	if unit:
		_battle.board.show_marked([unit.cell])
		_cursor.move_to(unit.cell)
	else:
		_battle.board.show_marked([])
	_refresh()


func _place_picked(cell: Vector2i) -> void:
	if cell in _cells:
		var unit := _battle.get_unit_for(_picked)
		if unit:
			_battle.reposition(unit, cell)   
		else:
			var occupant := _battle.get_unit_at(cell)
			if occupant:
				_battle.undeploy(occupant)   
			_battle.deploy_character(_picked, cell)
	_put_down()


func _put_down() -> void:
	_picked = null
	_battle.board.show_marked([])
	_refresh()


## Sends a placed hero back to the panel.
func _send_back(cell: Vector2i) -> void:
	var unit := _battle.get_unit_at(cell)
	if unit and unit.team == Unit.Team.PLAYER:
		_battle.undeploy(unit)
		_refresh()


func _finish() -> void:
	if not _can_start():
		return   
	_active = false
	_picked = null
	_cursor.enabled = false   
	_panel.close()
	_battle.board.clear_highlights()
	finished.emit()


# --- Helpers ----------------------------------------------------------------------

func _can_start() -> bool:
	for unit in _battle.units.values():
		if unit.team == Unit.Team.PLAYER:
			return true
	return false


func _refresh() -> void:
	var placed := {}
	for unit in _battle.units.values():
		if unit.character:
			placed[unit.character] = true
	_panel.refresh(placed, _picked, _can_start())
