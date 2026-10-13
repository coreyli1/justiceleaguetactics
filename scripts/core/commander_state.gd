class_name CommanderState extends RefCounted


var character: CharacterState
var bonus: CommanderBonus
var uses_left: int      # -1 = unlimited
var cooldown_left := 0

var deployed := false


func _init(p_character: CharacterState) -> void:
	character = p_character
	bonus = character.data.commander_bonus
	uses_left = bonus.uses_per_battle if bonus.uses_per_battle > 0 else -1


func is_ready() -> bool:
	return uses_left != 0 and cooldown_left == 0


func spend() -> void:
	if uses_left > 0:
		uses_left -= 1
	cooldown_left = bonus.cooldown_turns


func tick() -> void:
	cooldown_left = maxi(0, cooldown_left - 1)


func status_text() -> String:
	if uses_left == 0:
		return "used"
	if cooldown_left > 0:
		return "%dT" % cooldown_left
	if uses_left > 0:
		return "x%d" % uses_left
	return "ready"
