class_name GreenLanternBonus extends CommanderBonus
@export_range(0.1, 1.0) var revive_hp_fraction: float = 0.5

func _init() -> void:
	uses_per_battle = 1

func on_unit_died(_battle: Battle, unit: Unit, state: CommanderState) -> bool:
	if unit.team != Unit.Team.PLAYER:
		return false
	state.spend()
	unit.hp = maxi(1, ceili(unit.max_hp * revive_hp_fraction))
	print("Green Lantern: %s is revived with %d HP" % [unit.data.display_name, unit.hp])
	return true
