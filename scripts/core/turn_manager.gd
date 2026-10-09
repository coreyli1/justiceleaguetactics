class_name TurnManager extends RefCounted

signal phase_started(team: Unit.Team)
signal phase_ended(team: Unit.Team)

var current_team: Unit.Team = Unit.Team.PLAYER
var turn_number: int = 1
var _units: Dictionary   # same dictionary battle uses: entity_id -> Unit
var auto_end_phase: bool = false

func _init(units: Dictionary) -> void:
	_units = units

func start_phase(team: Unit.Team) -> void:
	current_team = team
	for unit in _units.values():
		if unit.team == team:
			unit.has_acted = false
			unit.update_visual()
	phase_started.emit(team)
	pass   # TODO: set current_team, reset has_acted for that team's units, emit phase_started

func can_act(unit: Unit) -> bool:
	return unit.team == current_team and not unit.has_acted


func mark_acted(unit: Unit) -> void:
	unit.has_acted = true
	unit.update_visual()
	if not auto_end_phase:
		return
	for u in _units.values():
		if can_act(u):
			return
	end_phase()

func end_phase() -> void:
	phase_ended.emit(current_team)
	if current_team == Unit.Team.PLAYER:
		current_team = Unit.Team.ENEMY
	else:
		turn_number += 1
		current_team = Unit.Team.PLAYER
	start_phase(current_team)
	
	pass   # TODO: emit phase_ended, switch teams, bump turn_number when it's the player's turn again
