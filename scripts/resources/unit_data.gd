class_name UnitData extends Resource

enum Type {HUMAN, META, ALIEN}

@export var id: StringName              
@export var display_name: String = "Unit"
@export var type: Type = Type.HUMAN
@export var commander_bonus: CommanderBonus
@export var sprite: Texture2D
@export var ai_behavior: AIBehavior

@export_group("Stats")
@export var max_hp: int = 10
@export var attack: int = 3
@export var defense: int = 1
@export var move_range: int = 3

@export_group("Attack Range")
@export var attack_range_min: int = 1   
@export var attack_range_max: int = 1  



# Later: @export var abilities: Array[AbilityData]
