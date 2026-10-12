@tool
class_name EnemySpawn extends Node2D

@export var unit: UnitData:
	set(value):
		unit = value
		queue_redraw()

const CELL := 16   


func _draw() -> void:
	if not Engine.is_editor_hint():
		return   

	var label := unit.display_name.left(3) if unit else "?"
	draw_string(ThemeDB.fallback_font, Vector2(1, 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
