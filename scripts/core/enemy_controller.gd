class_name EnemyController extends Node

const START_DELAY := 0.4     
const BETWEEN_UNITS := 0.25  

var _battle: Battle


func setup(battle: Battle) -> void:
	_battle = battle
	_battle.turn_manager.phase_started.connect(_on_phase_started)


func _on_phase_started(team: Unit.Team) -> void:
	if team == Unit.Team.ENEMY:
		_run_phase()


func _run_phase() -> void:
	await get_tree().create_timer(START_DELAY, false).timeout

	var enemies := _battle.units.values().filter(func(u): return u.team == Unit.Team.ENEMY)
	for unit in enemies:
		if not _battle.units.has(unit.entity_id):
			continue   
		if unit.data.ai_behavior:
			var decision: AIBehavior.Decision = unit.data.ai_behavior.decide(unit, _battle.grid, _battle.units)
			if decision.cell != unit.cell:
				_battle.camera.follow(unit.cell)
				await _battle.move_unit(unit, decision.cell)
			if decision.target:
				if _battle.resolve_attack(unit, decision.target):
					return   
		_battle.turn_manager.mark_acted(unit)
		await get_tree().create_timer(BETWEEN_UNITS, false).timeout

	_battle.turn_manager.end_phase()
