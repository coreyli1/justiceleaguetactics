# scripts/resources/commander_bonus.gd
class_name CommanderBonus extends Resource
## A squad-wide stat boost a hero provides while commanding.

@export var display_name: String = "Bonus"
@export_multiline var description: String

@export_group("Squad stat bonuses")
@export var attack: int = 0
@export var defense: int = 0
@export var move_range: int = 0
