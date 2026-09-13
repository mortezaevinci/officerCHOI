extends Control
## Where the player types their own name, before a life starts.
##
## Nothing else in the game knows a name for the player. Content refers to them
## as `{player}` and the journey substitutes it at display time, which is why
## this screen is the first thing a new game opens.
##
## Who then uses the name is an authorial decision made in the content: the
## people who love you say it, and the institutions do not.

const MAX_NAME_LENGTH := 24

@onready var _field: LineEdit = $Center/Rows/NameField
@onready var _begin: Button = $Center/Rows/Begin
@onready var _hint: Label = $Center/Rows/Hint


## Used when the player presses Begin without typing anything. A disabled
## button that looks broken is worse than a name the player can overwrite.
const SUGGESTED := "Kaveh"


func _ready() -> void:
	_field.max_length = MAX_NAME_LENGTH
	var existing := String(GameState.get_var("player_name", ""))
	_field.text = existing if not existing.is_empty() else SUGGESTED
	_field.select_all()
	_field.text_submitted.connect(_on_submitted)
	_field.text_changed.connect(_on_changed)
	_begin.pressed.connect(_on_begin)

	_refresh()
	_field.grab_focus()


func _on_changed(_text: String) -> void:
	_refresh()


func _on_submitted(_text: String) -> void:
	if _is_valid():
		_start()


func _on_begin() -> void:
	_start()


func _is_valid() -> bool:
	return not _field.text.strip_edges().is_empty()


func _refresh() -> void:
	# Begin is never disabled. An unresponsive button reads as a broken game
	# rather than as a prompt, so an empty field falls back to the suggestion.
	_hint.visible = not _is_valid()


func _start() -> void:
	var chosen := _field.text.strip_edges()
	GameState.set_var("player_name", chosen if not chosen.is_empty() else SUGGESTED)
	GameState.set_var("season", maxi(1, int(GameState.get_var("season", 1))))
	GameState.set_var("mission", 0)
	SceneFlow.goto(GamePaths.MISSION_SELECT)
