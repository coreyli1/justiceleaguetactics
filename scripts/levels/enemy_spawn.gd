@tool
class_name EnemySpawn extends Node2D
## Marks where an enemy starts. Drag into a level's Enemies node, snap to the
## 16px grid, and pick its UnitData. Draws a marker in the editor only.

@export var unit: UnitData:
	set(value):
		unit = value
		queue_redraw()

const CELL := 16   # matches Grid.CELL_SIZE (kept literal so this @tool script stays standalone)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return   # invisible in-game; the real Unit is spawned here instead

	var label := unit.display_name.left(3) if unit else "?"
	draw_string(ThemeDB.fallback_font, Vector2(1, 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
