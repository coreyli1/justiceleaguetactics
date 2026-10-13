class_name CommanderBonus extends Resource

@export var display_name: String = "Bonus"
@export_multiline var description: String

@export_group("Passive squad bonus")
@export var attack: int = 0
@export var move_range: int = 0
@export var max_hp: int = 0

@export_group("Uses")
@export var uses_per_battle: int = 0
@export var cooldown_turns: int = 0


# --- Hooks (override in subclasses) ------------------------------------------------
func is_activated() -> bool:
	return false


func needs_target() -> bool:
	return false


func can_target(_battle: Battle, _unit: Unit) -> bool:
	return false


func on_battle_start(battle: Battle) -> void:
	if attack == 0 and move_range == 0 and max_hp == 0:
		return
	for unit in battle.units.values():
		if unit.team == Unit.Team.PLAYER:
			unit.bonus_attack += attack
			unit.bonus_move += move_range
			unit.bonus_max_hp += max_hp
			unit.hp += max_hp


func activate(_battle: Battle, _target: Unit) -> void:
	pass


func on_unit_died(_battle: Battle, _unit: Unit, _state: CommanderState) -> bool:
	return false
