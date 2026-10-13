class_name HawkgirlBonus extends CommanderBonus
## Pick a hero who hasn't acted: this turn they move through walls and units
## (but can't stop on them). Unlimited uses, 3-turn cooldown.

func _init() -> void:
	uses_per_battle = 0
	cooldown_turns = 3


func is_activated() -> bool:
	return true


func needs_target() -> bool:
	return true


func can_target(battle: Battle, unit: Unit) -> bool:
	return unit.team == Unit.Team.PLAYER and battle.turn_manager.can_act(unit)


func activate(_battle: Battle, target: Unit) -> void:
	target.add_effect(StatusEffect.phase())
	print("Hawkgirl: %s can pass through anything this turn" % target.data.display_name)
