extends Control
## Pause overlay. Instantiated on top of whatever is running, pauses the tree,
## and frees itself on resume - so it never has to be part of a room's scene.

@onready var _resume: Button = $Center/Rows/Resume
@onready var _save: Button = $Center/Rows/SaveButton
@onready var _settings: Button = $Center/Rows/SettingsButton
@onready var _quit: Button = $Center/Rows/QuitToMenu
@onready var _status: Label = $Center/Rows/Status


func _ready() -> void:
	# Must keep running while the rest of the tree is frozen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_status.text = ""

	_resume.pressed.connect(close)
	_save.pressed.connect(_on_save)
	_settings.pressed.connect(_on_settings)
	_quit.pressed.connect(_on_quit_to_menu)

	# Saving mid-conversation would restore into a room with no dialogue up.
	_save.disabled = Dialogue.is_active
	_resume.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	get_tree().paused = false
	queue_free()


func _on_save() -> void:
	var scene := get_tree().current_scene
	var path := scene.scene_file_path if scene else GameState.current_scene
	var spawn := GameState.current_spawn
	if scene is Room:
		spawn = (scene as Room).default_spawn
	if SaveGame.save_to_slot(1, path, spawn):
		_status.text = "Saved to slot 1."
	else:
		_status.text = "Could not save."


func _on_settings() -> void:
	var menu: Control = load(GamePaths.SETTINGS_MENU).instantiate()
	add_child(menu)


func _on_quit_to_menu() -> void:
	Dialogue.stop()
	get_tree().paused = false
	AudioDirector.stop_music()
	SceneFlow.goto(GamePaths.MAIN_MENU)
	queue_free()
