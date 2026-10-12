class_name DeploymentPanel extends PanelContainer
## Side panel shown during deployment: lists the squad, shows who is picked up
## and who is already on the map, and has the Start Battle button.
## It knows nothing about battle rules; it only displays things and reports clicks.

signal hero_picked(character: CharacterState)
signal start_pressed

const WIDTH := 84
const PLACED_TINT := Color(1, 1, 1, 0.45)   # heroes already on the map look faded

@onready var _hero_list: VBoxContainer = $VBox/HeroList
@onready var _commanders_label: Label = $VBox/Commanders
@onready var _start_button: Button = $VBox/Start

var _buttons: Dictionary = {}   # CharacterState -> Button


func _ready() -> void:
	hide()
	_start_button.focus_mode = Control.FOCUS_NONE
	_start_button.pressed.connect(start_pressed.emit)


## Shows the panel on the side of the screen away from the deploy tiles.
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
		# No keyboard focus: arrow keys keep moving the map cursor instead.
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


## Redraws every button's state. `placed` is a set: CharacterState -> true.
func refresh(placed: Dictionary, picked: CharacterState, can_start: bool) -> void:
	for character in _buttons:
		var button: Button = _buttons[character]
		button.set_pressed_no_signal(character == picked)
		button.modulate = PLACED_TINT if placed.has(character) else Color.WHITE
	_start_button.disabled = not can_start


func close() -> void:
	hide()
