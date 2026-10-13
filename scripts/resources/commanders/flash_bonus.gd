class_name FlashBonus extends CommanderBonus
## Once per battle: every hero gets +3 movement for this turn.

@export var move_amount: int = 3


func _init() -> void:
	uses_per_battle = 1


func is_activated() -> bool:
	return true


func activate(battle: Battle, _target: Unit) -> void:
	for unit in battle.units.values():
		if unit.team == Unit.Team.PLAYER:
			unit.add_effect(StatusEffect.speed(move_amount))
	print("Flash: heroes +%d movement" % move_amount)
