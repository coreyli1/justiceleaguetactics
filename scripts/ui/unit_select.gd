extends Control
## Pick the squad for the next battle, and up to MAX_COMMANDERS commanders from it.
##
## Each hero is a "card" button (sprite icon, hero name, and commander bonus name)
## plus a small "Lead" toggle that makes them a commander. Cards are laid out two
## per row (HeroList is a GridContainer with 4 columns: card, Lead, card, Lead),
## so all 7 heroes fit on screen. Hovering or focusing a hero shows their bonus
## description in the Details line.

const CARD_WIDTH := 104

@onready var _hero_list: GridContainer = $VBox/HeroList   # Columns = 4
@onready var _details_label: Label = $VBox/Details
@onready var _count_label: Label = $VBox/Count
@onready var _start_button: Button = $VBox/Buttons/Start
@onready var _back_button: Button = $VBox/Buttons/Back

var _max_squad := 0
var _lead_buttons: Dictionary = {}   # CharacterState -> its "Lead" Button


func _ready() -> void:
	if GameState.current_level == null and not GameState.CATALOG.levels.is_empty():
		GameState.current_level = GameState.CATALOG.levels.front()

	_max_squad = GameState.current_level.get_deploy_count()

	var first_card: Button = null
	for character in GameState.roster:
		if not character.alive:
			continue
		var card := _add_hero(character)
		if first_card == null:
			first_card = card

	_start_button.pressed.connect(GameState.start_battle)
	_back_button.pressed.connect(GameState.go_to_level_select)
	_details_label.text = "Pick up to %d heroes, then up to %d to Lead." % [_max_squad, GameState.MAX_COMMANDERS]
	_refresh()

	if first_card:
		first_card.grab_focus()


## Adds one hero: a card button (toggles squad membership) and a Lead button
## (toggles commander). Returns the card.
func _add_hero(character: CharacterState) -> Button:
	var bonus := character.data.commander_bonus

	var card := Button.new()
	card.toggle_mode = true
	card.icon = character.data.sprite
	card.text = "%s\n%s" % [character.data.display_name, bonus.display_name if bonus else "-"]
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.custom_minimum_size.x = CARD_WIDTH
	card.toggled.connect(_on_hero_toggled.bind(character, card))
	_hero_list.add_child(card)

	var lead := Button.new()
	lead.toggle_mode = true
	lead.text = "Lead"
	lead.toggled.connect(_on_lead_toggled.bind(character, lead))
	_hero_list.add_child(lead)
	_lead_buttons[character] = lead

	# Hovering (mouse) or focusing (keyboard) either button describes this hero's bonus.
	for button in [card, lead]:
		button.mouse_entered.connect(_show_details.bind(character))
		button.focus_entered.connect(_show_details.bind(character))

	return card


func _show_details(character: CharacterState) -> void:
	var bonus := character.data.commander_bonus
	if bonus == null:
		_details_label.text = "%s has no commander bonus." % character.data.display_name
	else:
		_details_label.text = "%s - %s: %s" % [character.data.display_name, bonus.display_name, bonus.description]


func _on_hero_toggled(pressed: bool, character: CharacterState, button: Button) -> void:
	if pressed:
		if GameState.squad.size() >= _max_squad:
			button.set_pressed_no_signal(false)   # squad full: undo the click
			return
		GameState.squad.append(character)
	else:
		GameState.squad.erase(character)
		# A hero who leaves the squad can't keep leading.
		GameState.commanders.erase(character)
		_lead_buttons[character].set_pressed_no_signal(false)
	_refresh()


func _on_lead_toggled(pressed: bool, character: CharacterState, button: Button) -> void:
	if pressed:
		if GameState.commanders.size() >= GameState.MAX_COMMANDERS:
			button.set_pressed_no_signal(false)   # already have enough commanders: undo
			return
		GameState.commanders.append(character)
	else:
		GameState.commanders.erase(character)
	_refresh()


func _refresh() -> void:
	_count_label.text = "Squad %d/%d   Commanders %d/%d" % [
		GameState.squad.size(), _max_squad,
		GameState.commanders.size(), GameState.MAX_COMMANDERS,
	]
	# Lead only works for heroes in the squad who have a bonus.
	for character in _lead_buttons:
		var in_squad: bool = character in GameState.squad
		var has_bonus: bool = character.data.commander_bonus != null
		_lead_buttons[character].disabled = not (in_squad and has_bonus)
	_start_button.disabled = GameState.squad.is_empty()
