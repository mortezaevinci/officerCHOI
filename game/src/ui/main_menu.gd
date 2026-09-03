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
	var scene := GameState.current_scene
	if scene.is_empty():
		scene = GamePaths.NEW_GAME_SCENE
	SceneFlow.goto(scene, GameState.current_spawn)


func _on_new_game() -> void:
	GameState.reset()
	SceneFlow.goto(GamePaths.NEW_GAME_SCENE, GamePaths.NEW_GAME_SPAWN)


func _on_settings() -> void:
	var menu: Control = load(GamePaths.SETTINGS_MENU).instantiate()
	add_child(menu)


func _on_quit() -> void:
	get_tree().quit()
