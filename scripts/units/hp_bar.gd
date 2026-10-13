class_name HpBar extends Node2D

const HEIGHT := 2
const MARGIN := 1
const BACK_COLOR := Color(0.08, 0.08, 0.1, 0.85)
const FULL_COLOR := Color(0.35, 0.85, 0.35)
const EMPTY_COLOR := Color(0.9, 0.25, 0.2)
const SHIELD_COLOR := Color(0.45, 0.85, 1.0)

const TYPE_COLORS := {
	UnitData.Type.HUMAN: Color(0.35, 0.55, 1.0),
	UnitData.Type.META: Color(1.0, 0.85, 0.25),
	UnitData.Type.ALIEN: Color(0.4, 0.9, 0.45),
}


func _ready() -> void:
	hide()


func _draw() -> void:
	var unit := get_parent() as Unit
	if unit == null or unit.data == null:
		return
	var ratio := clampf(float(unit.hp) / unit.max_hp, 0.0, 1.0)
	var width := Grid.CELL_SIZE - MARGIN * 2
	var top := Grid.CELL_SIZE - HEIGHT - MARGIN
	draw_rect(Rect2(MARGIN, top, width, HEIGHT), BACK_COLOR)
	draw_rect(Rect2(MARGIN, top, width * ratio, HEIGHT), EMPTY_COLOR.lerp(FULL_COLOR, ratio))
	if unit.shield > 0:
		draw_rect(Rect2(MARGIN, top - 1, width, 1), SHIELD_COLOR)   # thin line above the bar
	draw_rect(Rect2(MARGIN, MARGIN, 3, 3), TYPE_COLORS[unit.type])
