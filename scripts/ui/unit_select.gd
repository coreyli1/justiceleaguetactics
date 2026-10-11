extends Control
## Pick which heroes go into the next battle, and which of their commander
## bonuses are active. Each row is [hero toggle] [commander bonus toggle].
## A bonus can only be chosen for a hero who is in the squad.

@onready var _hero_list: GridContainer = $VBox/HeroList   # Columns = 2
@onready var _count_label: Label = $VBox/Count
@onready var _start_button: Button = $VBox/Buttons/Start
@onready var _back_button: Button = $VBox/Buttons/Back

var _max_squad := 0
var _command_buttons: Dictionary = {}   # CharacterState -> its bonus Button


func _ready() -> void:
	# Running this scene alone with F6? Fall back to the first level.
	if GameState.current_level == null and not GameState.CATALOG.levels.is_empty():
		GameState.current_level = GameState.CATALOG.levels.front()

	_max_squad = GameState.current_level.get_deploy_cells().size()

	for character in GameState.roster:
		if not character.alive:
			continue
		_add_hero_row(character)

	_start_button.pressed.connect(GameState.start_battle)
	_back_button.pressed.connect(GameState.go_to_level_select)
	_refresh()

	if _hero_list.get_child_count() > 0:
		_hero_list.get_child(0).grab_focus()


func _add_hero_row(character: CharacterState) -> void:
	var hero_button := Button.new()
	hero_button.toggle_mode = true
	hero_button.text = character.data.display_name
	hero_button.toggled.connect(_on_hero_toggled.bind(character, hero_button))
	hero_button.custom_minimum_size.x = 70
	hero_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hero_list.add_child(hero_button)

	var bonus := character.data.commander_bonus
	var command_button := Button.new()
	command_button.toggle_mode = true
	command_button.text = bonus.display_name if bonus else "-"
	command_button.tooltip_text = bonus.description if bonus else ""
	command_button.toggled.connect(_on_command_toggled.bind(character, command_button))
	_hero_list.add_child(command_button)
	_command_buttons[character] = command_button


func _on_hero_toggled(pressed: bool, character: CharacterState, button: Button) -> void:
	if pressed:
		if GameState.squad.size() >= _max_squad:
			button.set_pressed_no_signal(false)   # squad full: undo the click
			return
		GameState.squad.append(character)
	else:
		GameState.squad.erase(character)
		# A hero who leaves the squad can't keep commanding.
		GameState.commanders.erase(character)
		_command_buttons[character].set_pressed_no_signal(false)
	_refresh()


func _on_command_toggled(pressed: bool, character: CharacterState, button: Button) -> void:
	if pressed:
		if GameState.commanders.size() >= GameState.MAX_COMMANDERS:
			button.set_pressed_no_signal(false)   # already have 2: undo the click
			return
		GameState.commanders.append(character)
	else:
		GameState.commanders.erase(character)
	_refresh()


func _refresh() -> void:
	_count_label.text = "Squad: %d/%d\nCommanders: %d/%d" % [
		GameState.squad.size(), _max_squad,
		GameState.commanders.size(), GameState.MAX_COMMANDERS,
	]
	# A bonus button only works for heroes in the squad who have a bonus.
	for character in _command_buttons:
		var in_squad: bool = character in GameState.squad
		var has_bonus: bool = character.data.commander_bonus != null
		_command_buttons[character].disabled = not (in_squad and has_bonus)
	_start_button.disabled = GameState.squad.is_empty()
