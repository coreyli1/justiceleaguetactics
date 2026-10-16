class_name BatmanBonus extends CommanderBonus

func _init() -> void:
	uses_per_battle = 1


func is_activated() -> bool:
	return true


func activate(battle: Battle, _target: Unit) -> void:
	battle.turn_manager.extra_player_phases += 1
	print("Batman: you'll take another turn after this one")
