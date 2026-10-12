class_name DeploymentController extends Node
## The pre-battle phase: heroes start off the map, and the player places them on
## the level's deploy tiles. Pick a hero (from the panel or the map), then confirm
## a deploy tile to place, move or swap them. Cancel on a placed hero sends them
## back to the panel. Emits `finished` when the player starts the battle.

signal finished

var _battle: Battle
var _cursor: GridCursor
var _panel: DeploymentPanel   # optional: without it, everyone is auto-placed

var _active := false
var _cells: Array[Vector2i] = []
var _picked: CharacterState = null   # hero picked up (placed or not), or null


func setup(battle: Battle, cursor: GridCursor, panel: DeploymentPanel = null) -> void:
	_battle = battle
	_cursor = cursor
	_panel = panel
	_cursor.confirmed.connect(_on_confirmed)
	_cursor.cancelled.connect(_on_cancelled)
	if _panel:
		_panel.hero_picked.connect(_pick_up)
		_panel.start_pressed.connect(_finish)


## Called by Battle once the level is loaded.
func begin(cells: Array[Vector2i]) -> void:
	_cells = cells
	var squad := _battle.get_squad()

	if _panel == null:
		# Nothing to place heroes from: auto-place everyone and go straight to turn 1.
		for i in mini(squad.size(), cells.size()):
			_battle.deploy_character(squad[i], cells[i])
		finished.emit()
		return

	_battle.board.show_moves(_cells)   # highlight where heroes may stand

	# Deploy tiles mostly on the left half? Put the panel on the right, and vice versa.
	var total_x := 0
	for cell in cells:
		total_x += cell.x
	var on_right := cells.is_empty() or total_x / float(cells.size()) < _battle.grid.size.x / 2.0
	_panel.open(squad, on_right)

	if not cells.is_empty():
		_cursor.move_to(cells[0])   # no heroes on the map yet, so start on a deploy tile
	_active = true
	_cursor.enabled = true
	_refresh()


# --- Input ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _active and event.is_action_pressed("end_turn"):
		_finish()
		# Stop this key press here, or PlayerController (now active) would also
		# see it and immediately end turn 1.
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

## Picks a hero up, from the map or from the panel's list.
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
	_refresh()


## Sends a placed hero back to the panel.
func _send_back(cell: Vector2i) -> void:
	var unit := _battle.get_unit_at(cell)
	if unit and unit.team == Unit.Team.PLAYER:
		_battle.undeploy(unit)
		_refresh()


func _finish() -> void:
	if not _can_start():
		return   # need at least one hero on the map
	_active = false
	_picked = null
	_cursor.enabled = false   # the player controller takes over the cursor from here
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
