class_name UnitData extends Resource

@export var id: StringName              # stable ID for saves, e.g. &"soldier"
@export var display_name: String = "Unit"

@export_group("Stats")
@export var max_hp: int = 10
@export var attack: int = 3
@export var defense: int = 1
@export var move_range: int = 3

@export_group("Attack Range")
@export var attack_range_min: int = 1   # 1 = adjacent
@export var attack_range_max: int = 1   # archers might be 2–3

# Later: @export var abilities: Array[AbilityData]
# Later: @export var sprite: Texture2D
