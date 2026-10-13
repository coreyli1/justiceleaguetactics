class_name ActionMenu extends VBoxContainer

signal attack_chosen
signal wait_chosen
signal ability_chosen(state: CommanderState)

@onready var _attack_button: Button = $Attack
@onready var _wait_button: Button = $Wait

var _ability_buttons: Array[Button] = []


func _ready() -> void:
	hide()
	_attack_button.pressed.connect(attack_chosen.emit)
	_wait_button.pressed.connect(wait_chosen.emit)


func open(screen_pos: Vector2, can_attack: bool, abilities: Array[CommanderState] = []) -> void:
	position = screen_pos + Vector2(Grid.CELL_SIZE + 2, 0)
	_attack_button.visible = can_attack

	_clear_abilities()
	for state in abilities:
		var button := Button.new()
		button.text = state.bonus.display_name
		button.tooltip_text = state.bonus.description
		button.pressed.connect(ability_chosen.emit.bind(state))
		add_child(button)
		move_child(button, _wait_button.get_index())   
		_ability_buttons.append(button)

	show()
	(_attack_button if can_attack else _wait_button).grab_focus()


func close() -> void:
	hide()


func _clear_abilities() -> void:
	for button in _ability_buttons:
		remove_child(button)   
		button.queue_free()
	_ability_buttons.clear()
