extends CanvasLayer
## Self-contained pause menu. Drop an instance into any scene that can be paused.
## Toggled with the "pause" input action (Escape).

@onready var _resume_button: Button = $Root/VBox/Resume
@onready var _restart_button: Button = $Root/VBox/Restart
@onready var _quit_button: Button = $Root/VBox/Quit


func _ready() -> void:
	# Keep running while the rest of the game is paused, or we could never unpause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	_resume_button.pressed.connect(_resume)
	_restart_button.pressed.connect(GameState.restart_level)
	_quit_button.pressed.connect(GameState.go_to_level_select)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()


func _pause() -> void:
	get_tree().paused = true
	show()
	_resume_button.grab_focus()


func _resume() -> void:
	get_tree().paused = false
	hide()
