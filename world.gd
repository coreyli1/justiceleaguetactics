extends Node2D
@onready var actors: Node2D = $TileMapLayer/Actors
@onready var arrow_path: TileMapLayer = $TileMapLayer/ArrowPath


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for actor: Actor in actors.get_children():
		actor.moved.connect(arrow_path.set_cells)
	
	actors.get_child(0).active = true
