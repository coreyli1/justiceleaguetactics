extends Control

@onready var _list: VBoxContainer = $VBox/LevelList


func _ready() -> void:
	for level in GameState.CATALOG.levels:
		var button := Button.new()
		button.text = level.display_name
		button.pressed.connect(GameState.select_level.bind(level))
		_list.add_child(button)

	$VBox/Back.pressed.connect(GameState.go_to_main_menu)
	if _list.get_child_count() > 0:
		_list.get_child(0).grab_focus()
