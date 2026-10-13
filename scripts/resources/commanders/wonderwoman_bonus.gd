class_name WonderWomanBonus extends CommanderBonus
## Once per battle: every hero gains a shield that blocks 1 damage from each
## hit, until the start of your next turn (so it covers the enemy's attacks).

@export var shield_amount: int = 1


func _init() -> void:
	uses_per_battle = 1


func is_activated() -> bool:
	return true


func activate(battle: Battle, _target: Unit) -> void:
	for unit in battle.units.values():
		if unit.team == Unit.Team.PLAYER:
			unit.add_effect(StatusEffect.shielded(shield_amount))
	print("Wonder Woman: heroes shielded")
