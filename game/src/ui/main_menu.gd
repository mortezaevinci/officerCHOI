extends Control
## Title screen: continue, start over, settings, quit.

@onready var _continue_button: Button = $Center/Rows/Continue
@onready var _new_game_button: Button = $Center/Rows/NewGame
@onready var _settings_button: Button = $Center/Rows/SettingsButton
@onready var _quit_button: Button = $Center/Rows/Quit
@onready var _version: Label = $Version


func _ready() -> void:
	_version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")

	var latest := SaveGame.latest_slot()
	_continue_button.disabled = latest == -1
	_continue_button.visible = latest != -1

	_continue_button.pressed.connect(_on_continue)
	_new_game_button.pressed.connect(_on_new_game)
	_settings_button.pressed.connect(_on_settings)
	_quit_button.pressed.connect(_on_quit)

	# Consoles and phones have no window to close.
	_quit_button.visible = not OS.has_feature("mobile") and not OS.has_feature("web")

	(_continue_button if latest != -1 else _new_game_button).grab_focus()


func _on_continue() -> void:
	var slot := SaveGame.latest_slot()
	if slot == -1:
		return
	if not SaveGame.load_from_slot(slot):
		return

	# Continue used to fall back to NEW_GAME_SCENE when the save had no scene
	# recorded, which dropped the player into the abandoned prototype room: a
	# backdrop, no conversation, and nothing that responded. A save from before
	# the journey existed has no name and no run, so it resumes at the start of
	# the journey rather than at a room that is no longer part of the game.
	if String(GameState.get_var("player_name", "")).is_empty():
		SceneFlow.goto(GamePaths.DIFFICULTY_SELECT)
		return
	SceneFlow.goto(GamePaths.MISSION_SELECT)


func _on_new_game() -> void:
	# A new game is a new life: difficulty, name, ten missions, then Choi.
	GameState.reset()
	SceneFlow.goto(GamePaths.DIFFICULTY_SELECT)


func _on_settings() -> void:
	var menu: Control = load(GamePaths.SETTINGS_MENU).instantiate()
	add_child(menu)


func _on_quit() -> void:
	get_tree().quit()
