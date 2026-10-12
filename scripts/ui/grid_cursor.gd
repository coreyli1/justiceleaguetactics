class_name GridCursor extends Node2D
## The selection cursor: a pulsing outline on one cell.
## Purely visual; PlayerController decides where it goes and what confirming means.

const COLOR := Color(1, 1, 1, 0.95)

var cell := Vector2i.ZERO


func _ready() -> void:
	# Gentle pulse so the cursor is easy to spot.
	var tween := create_tween().set_loops()
	tween.tween_property(self, "modulate:a", 0.45, 0.4)
	tween.tween_property(self, "modulate:a", 1.0, 0.4)


func move_to(p_cell: Vector2i) -> void:
	cell = p_cell
	position = Vector2(cell * Grid.CELL_SIZE)   # top-left of the cell, like everything else


func _draw() -> void:
	# Half-pixel inset keeps a 1px outline crisp instead of blurred across two pixels.
	var size := Vector2.ONE * (Grid.CELL_SIZE - 1)
	draw_rect(Rect2(Vector2.ONE * 0.5, size), COLOR, false, 1.0)
