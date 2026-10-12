class_name CommanderBonus extends Resource

@export var display_name: String = "Bonus"
@export_multiline var description: String

@export_group("Squad stat bonuses")
@export var attack: int = 0
@export var defense: int = 0
@export var move_range: int = 0
