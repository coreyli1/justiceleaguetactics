class_name MartianManhunterBonus extends CommanderBonus
## Twice per battle: pick any unit (hero or enemy) and shift its type to the
## next one in the cycle: Human -> Meta -> Alien -> Human. Lasts the whole battle.

func _init() -> void:
	uses_per_battle = 2


func is_activated() -> bool:
	return true


func needs_target() -> bool:
	return true


func can_target(_battle: Battle, _unit: Unit) -> bool:
	return true


func activate(_battle: Battle, target: Unit) -> void:
	var next_type := ((target.type + 1) % UnitData.Type.size()) as UnitData.Type
	target.set_type(next_type)
	print("Martian Manhunter: %s is now %s" % [target.data.display_name, UnitData.Type.keys()[target.type]])
