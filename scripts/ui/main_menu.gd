extends Control

func _ready() -> void:
	$VBox/Play.pressed.connect(GameState.go_to_level_select)
	$VBox/Quit.pressed.connect(get_tree().quit)
	$VBox/Play.grab_focus()
