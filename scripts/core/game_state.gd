extends Node


const MAIN_MENU := "res://scenes/menus/main_menu.tscn"
const LEVEL_SELECT := "res://scenes/menus/level_select.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"
const CATALOG: LevelCatalog = preload("res://data/levels/catalog.tres")
const STARTING_ROSTER: RosterData = preload("res://data/roster/starting_roster.tres")
const UNIT_SELECT := "res://scenes/menus/unit_select.tscn"
const MAX_COMMANDERS := 2

var roster: Array[CharacterState] = []   # every hero the player owns
var squad: Array[CharacterState] = []    # the heroes picked for the next battle
var commanders: Array[CharacterState] = []
var current_level: LevelData

func _ready() -> void:
	new_campaign()


func new_campaign() -> void:
	roster.clear()
	for hero in STARTING_ROSTER.heroes:
		var character := CharacterState.new()
		character.data = hero
		roster.append(character)

func start_level(level: LevelData) -> void:
	current_level = level
	_change_scene(BATTLE)


func restart_level() -> void:
	_change_scene(BATTLE)


func go_to_main_menu() -> void:
	_change_scene(MAIN_MENU)


func go_to_level_select() -> void:
	_change_scene(LEVEL_SELECT)


func _change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	
func select_level(level: LevelData) -> void:
	current_level = level
	squad.clear()
	commanders.clear()
	_change_scene(UNIT_SELECT)


func start_battle() -> void:
	_change_scene(BATTLE)
