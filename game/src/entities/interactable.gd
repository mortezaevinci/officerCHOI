class_name Interactable
extends Area2D
## Anything in a room the player can walk up to and act on.
##
## Drop one under a desk, a door, a filing cabinet or an NPC, set what it should
## do in the inspector, and the room takes care of the prompt and the input.
## A desk that opens a close-up conversation is [constant PUSH_SCENE] with the
## desk scene; a quick exchange in the room itself is [constant DIALOGUE].

signal triggered(interactable: Interactable)
signal availability_changed(available: bool)

enum Action {
	DIALOGUE,     ## Play a `.dlg` file in the room's dialogue box.
	PUSH_SCENE,   ## Enter a scene and come back here afterwards (a desk).
	GOTO_SCENE,   ## Leave for another scene for good (a door to another room).
	CUSTOM,       ## Emit [signal triggered] and let the room decide.
}

@export_group("Prompt")
## Shown when the player is close enough, e.g. "Examine the desk".
@export var prompt: String = "Examine"
## Where the prompt floats, relative to this node.
@export var prompt_offset: Vector2 = Vector2(0, -48)

@export_group("Action")
@export var action: Action = Action.DIALOGUE
## `.dlg` file for [constant DIALOGUE].
@export_file("*.dlg") var dialogue_file: String = ""
## Node inside that file to start at. Empty means the file's first node.
@export var dialogue_entry: String = ""
## Scene for [constant PUSH_SCENE] / [constant GOTO_SCENE].
@export_file("*.tscn") var target_scene: String = ""
## For [constant GOTO_SCENE]: the Marker2D name to arrive at in the new room.
@export var target_spawn: String = ""

@export_group("Availability")
## Story condition, in the same syntax as `.dlg` conditions, e.g.
## `chapter >= 2 and not read_case_file`. Empty means always available.
@export var condition: String = ""
## After being triggered once, stop offering it.
@export var once: bool = false
## Story variable set to true when triggered. Handy with [member once].
@export var sets_flag: String = ""

var player_in_range: bool = false
var used: bool = false

var _was_available: bool = false


func _ready() -> void:
	add_to_group("interactables")
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	GameState.variable_changed.connect(_on_variable_changed)
	_was_available = is_available()


## True when the prompt should be offered: player nearby, condition met, and
## not already used up.
func is_available() -> bool:
	if used and once:
		return false
	return DialogueExpression.is_true(condition, GameState.vars)


## Runs the action. The room calls this; nothing else needs to.
func activate() -> void:
	used = true
	if not sets_flag.is_empty():
		GameState.set_var(sets_flag, true)

	match action:
		Action.DIALOGUE:
			if dialogue_file.is_empty():
				push_warning("Interactable '%s' has no dialogue file" % name)
			else:
				Dialogue.start(dialogue_file, dialogue_entry)
		Action.PUSH_SCENE:
			SceneFlow.push(target_scene, {"from": get_path()})
		Action.GOTO_SCENE:
			SceneFlow.goto(target_scene, target_spawn)
		Action.CUSTOM:
			pass

	triggered.emit(self)


## Distance from a point, used by the room to pick the nearest prompt.
func distance_to_point(point: Vector2) -> float:
	return global_position.distance_to(point)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false


func _on_variable_changed(_key: String, _old: Variant, _new: Variant) -> void:
	# Conditions are cheap, and this only fires when the story actually moves.
	var now := is_available()
	if now != _was_available:
		_was_available = now
		availability_changed.emit(now)
