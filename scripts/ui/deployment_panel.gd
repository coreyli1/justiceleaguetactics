class_name DeploymentPanel extends PanelContainer

signal hero_picked(character: CharacterState)
signal start_pressed

const WIDTH := 84
const PLACED_TINT := Color(1, 1, 1, 0.45)   

@onready var _hero_list: VBoxContainer = $VBox/HeroList
@onready var _commanders_label: Label = $VBox/Commanders
@onready var _start_button: Button = $VBox/Start

var _buttons: Dictionary = {}   


func _ready() -> void:
	hide()
	_start_button.focus_mode = Control.FOCUS_NONE
	_start_button.pressed.connect(start_pressed.emit)



func open(squad: Array[CharacterState], on_right: bool) -> void:
	for child in _hero_list.get_children():
		child.queue_free()
	_buttons.clear()

	for character in squad:
		var button := Button.new()
		button.toggle_mode = true
		button.text = character.data.display_name
		button.icon = character.data.sprite
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(hero_picked.emit.bind(character))
		_hero_list.add_child(button)
		_buttons[character] = button

	var names: Array[String] = []
	for character in GameState.commanders:
		names.append(character.data.display_name)
	_commanders_label.text = "Commanders:\n" + (", ".join(names) if not names.is_empty() else "none")

	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE if on_right else Control.PRESET_LEFT_WIDE)
	custom_minimum_size.x = WIDTH
	show()


func refresh(placed: Dictionary, picked: CharacterState, can_start: bool) -> void:
	for character in _buttons:
		var button: Button = _buttons[character]
		button.set_pressed_no_signal(character == picked)
		button.modulate = PLACED_TINT if placed.has(character) else Color.WHITE
	_start_button.disabled = not can_start


func close() -> void:
	hide()
