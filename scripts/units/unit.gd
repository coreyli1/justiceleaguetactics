class_name Unit extends GridEntity

enum Team { PLAYER, ENEMY }

var data: UnitData
var team: Team
var hp: int
var has_acted: bool
var character: CharacterState

var bonus_attack := 0
var bonus_defense := 0
var bonus_move := 0

var attack: int:
	get:
		return data.attack + bonus_attack

var defense: int:
	get:
		return data.defense + bonus_defense

var move_range: int:
	get:
		return data.move_range + bonus_move



func setup(p_data: UnitData, p_team: Team) -> void:
	data = p_data
	if data.sprite:
		$Sprite2D.texture = data.sprite
	team = p_team
	hp = data.max_hp
	
	update_visual()

func update_visual():

	if has_acted:
		modulate = modulate.darkened(0.5)
	

func move_along(path: Array[Vector2i], grid: Grid) -> Tween:
	if path.is_empty():
		return null
	cell = path[-1]
	if path.size() < 2:
		return null
	var tween := create_tween()
	for step in path.slice(1):
		tween.tween_property(self, "position", grid.cell_to_world(step), 0.12)
	return tween
