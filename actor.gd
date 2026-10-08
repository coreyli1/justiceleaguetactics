@tool
class_name Actor extends CharacterBody2D

signal moved(cells: Array[Vector2])


const FRIENDLY_COLOR: Color = Color("83ffab")
const ENEMY_COLOR: Color = Color.CRIMSON
const MOVE_PIXELS_PER_FRAME: int = 4





@export var is_friendly: bool = false: 
	set(value):
		is_friendly = value
		$Sprite.self_modulate = FRIENDLY_COLOR if is_friendly else ENEMY_COLOR
		name = "ActorPlayer" if is_friendly else "ActorEnemy"
		
const CELL_SIZE: Vector2 = Vector2(16,16)

@export var movement_range: int = 8
@onready var position_target: Vector2 = position
@onready var cells_traveled: Array[Vector2] = []
@onready var input_delay: Timer = $InputDelay

var active: bool = false

func _ready() -> void:
	is_friendly = is_friendly
	cells_traveled.append(position / CELL_SIZE)
	
func _process(delta: float) -> void:
	if not active:
		return
		
	position = position.move_toward(position_target, MOVE_PIXELS_PER_FRAME)
	
	if not input_delay.is_stopped() or not position.is_equal_approx(position_target):
		return
		
	var movement: Vector2 = Vectors.get_four_direction_vector(false)
	if movement.is_zero_approx():
		return
		
	movement *= CELL_SIZE
	if move_and_collide(movement, true):
		return

	var pixel_target: Vector2 = position + movement
	var cell_target: Vector2 = pixel_target / CELL_SIZE
	var cell_index: int = cells_traveled.find(cell_target)
	if cell_index == -1: 
		if cells_traveled.size() == movement_range:
			return
			
			
		cells_traveled.append(cell_target)
		input_delay.start()
	else:
		cells_traveled.resize(cell_index + 1)
	
	position_target = pixel_target
	moved.emit(cells_traveled)
	queue_redraw()
	
func _draw() -> void:
	if not active:
		return
	draw_string(ThemeDB.fallback_font, Vector2(32,32), "Cells Traveled: " + str(cells_traveled.size()))
	
	#path drawing not working
	#for cell: Vector2 in cells_traveled:
		#var cell_pos: Vector2 = to_global(cell*CELL_SIZE) 
		#draw_rect(Rect2(cell_pos,CELL_SIZE), Color.AQUA)
