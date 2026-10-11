# scripts/resources/character_state.gd
class_name CharacterState extends Resource
## One hero's persistent progress in the current campaign.

@export var data: UnitData
@export var alive: bool = true
# Later: xp, level, equipment...
