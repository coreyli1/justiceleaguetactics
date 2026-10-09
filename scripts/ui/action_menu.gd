class_name ActionMenu extends VBoxContainer
## The post-move action menu. It knows nothing about battles: it shows
## buttons and reports which one was pressed.

signal attack_chosen
signal wait_chosen

@onready var _attack_button: Button = $Attack
@onready var _wait_button: Button = $Wait


func _ready() -> void:
	hide()
	_attack_button.pressed.connect(attack_chosen.emit)
	_wait_button.pressed.connect(wait_chosen.emit)


func open(screen_pos: Vector2, can_attack: bool) -> void:
	position = screen_pos + Vector2(Grid.CELL_SIZE + 2, 0)
	_attack_button.visible = can_attack
	show()
	(_attack_button if can_attack else _wait_button).grab_focus()


func close() -> void:
	hide()
