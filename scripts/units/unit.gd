class_name Unit extends GridEntity

enum Team { PLAYER, ENEMY }

var data: UnitData
var team: Team
var hp: int
var has_acted: bool

var move_range: int:
	get:
		return data.move_range   # TODO: later, buffs/terrain modify this

func setup(p_data: UnitData, p_team: Team) -> void:
	data = p_data
	
	team = p_team
	hp = data.max_hp
	
	update_visual()

func update_visual():
	match team: 
		Team.PLAYER: modulate = Color(0.649, 0.826, 0.491, 1.0)
		Team.ENEMY: modulate = Color(0.578, 0.095, 0.063, 1.0)
	
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
