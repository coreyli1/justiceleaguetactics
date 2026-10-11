class_name UnitSpawn extends Resource
## One unit placed in a level.

@export var unit: UnitData
@export var cell: Vector2i
@export var team: Unit.Team = Unit.Team.ENEMY
