class_name EnemyController extends Node
## Plays the enemy team's turn: asks each enemy's AIBehavior what to do, then
## carries it out with the same Battle actions the player uses.
## The thinking lives in AIBehavior; this is just the hands.

const START_DELAY := 0.4     # pause before the first enemy acts
const BETWEEN_UNITS := 0.25  # pause between enemies, so the player can follow along

var _battle: Battle


func setup(battle: Battle) -> void:
	_battle = battle
	_battle.turn_manager.phase_started.connect(_on_phase_started)


func _on_phase_started(team: Unit.Team) -> void:
	if team == Unit.Team.ENEMY:
		_run_phase()


func _run_phase() -> void:
	# false = timers respect pause, so enemies don't act while the game is paused.
	await get_tree().create_timer(START_DELAY, false).timeout

	var enemies := _battle.units.values().filter(func(u): return u.team == Unit.Team.ENEMY)
	for unit in enemies:
		if not _battle.units.has(unit.entity_id):
			continue   # died earlier this phase
		if unit.data.ai_behavior:
			var decision: AIBehavior.Decision = unit.data.ai_behavior.decide(unit, _battle.grid, _battle.units)
			if decision.cell != unit.cell:
				_battle.camera.follow(unit.cell)
				await _battle.move_unit(unit, decision.cell)
			if decision.target:
				if _battle.resolve_attack(unit, decision.target):
					return   # battle over, so don't start another turn
		_battle.turn_manager.mark_acted(unit)
		await get_tree().create_timer(BETWEEN_UNITS, false).timeout

	_battle.turn_manager.end_phase()
