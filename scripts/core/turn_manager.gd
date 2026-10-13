class_name TurnManager extends RefCounted

signal phase_started(team: Unit.Team)
signal phase_ended(team: Unit.Team)
## A new turn number begins (not emitted for Batman's extra phases).
## Status effects and cooldowns count down here.
signal turn_started(turn_number: int)

var current_team: Unit.Team = Unit.Team.PLAYER
var turn_number: int = 1
var _units: Dictionary   
var auto_end_phase: bool = false
## Extra player phases queued (Batman). Each one replays the player phase before the enemy moves.
var extra_player_phases := 0

func _init(units: Dictionary) -> void:
	_units = units

func start_phase(team: Unit.Team) -> void:
	current_team = team
	for unit in _units.values():
		if unit.team == team:
			unit.has_acted = false
			unit.update_visual()
	phase_started.emit(team)

func can_act(unit: Unit) -> bool:
	return unit.team == current_team and not unit.has_acted


func mark_acted(unit: Unit) -> void:
	unit.has_acted = true
	unit.update_visual()
	if not auto_end_phase or current_team != Unit.Team.PLAYER:
		return
	for u in _units.values():
		if can_act(u):
			return
	end_phase()

func end_phase() -> void:
	phase_ended.emit(current_team)
	if current_team == Unit.Team.PLAYER and extra_player_phases > 0:
		extra_player_phases -= 1
		start_phase(Unit.Team.PLAYER)   # another player phase, same turn number
		return
	var next_team := Unit.Team.ENEMY if current_team == Unit.Team.PLAYER else Unit.Team.PLAYER
	if next_team == Unit.Team.PLAYER:
		turn_number += 1
		turn_started.emit(turn_number)
	start_phase(next_team)
