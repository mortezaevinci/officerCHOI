class_name Room
extends Node2D
## Base script for every explorable room.
##
## A room owns the walking-around layer: it places the player, works out which
## [Interactable] the prompt should point at, runs in-room conversations through
## its own dialogue box, and opens the pause menu. Anything story-shaped lives
## in `.dlg` files, not here.
##
## Scene layout a room is expected to have (see scenes/rooms/precinct.tscn):
##
##     Room (this script)
##     +-- Background
##     +-- Walls              (StaticBody2D collision)
##     +-- Spawns             (Marker2D children, named)
##     +-- Interactables      (Interactable nodes)
##     +-- Player
##     +-- InteractPrompt       (world space, follows the focused object)
##     +-- UI (CanvasLayer)
##         +-- DialogueBox

## Short id used in save files and analytics.
@export var room_id: String = ""
## Shown briefly when the room is entered. Leave empty for no title card.
@export var display_name: String = ""
## Track name from [constant AudioDirector.MUSIC], or a res:// path.
@export var music: String = ""
## Marker2D to use when nobody said where to arrive.
@export var default_spawn: String = "default"
## Write an autosave when the player walks in. Rooms are good checkpoints.
@export var autosave_on_enter: bool = true
## The floor the camera is allowed to show. Make it at least as large as the
## viewport (1920x1080) or the player will see past the walls.
@export var camera_bounds: Rect2 = Rect2(0, 0, 2560, 1440)

@onready var player: Player = get_node_or_null("Player")
@onready var dialogue_box: DialogueBox = get_node_or_null("UI/DialogueBox")
# Lives in world space (a child of the room, not the CanvasLayer) so it can be
# parked directly over the object it describes.
@onready var interact_prompt: Control = get_node_or_null("InteractPrompt")

var _focused: Interactable = null


func _ready() -> void:
	add_to_group("rooms")

	if not music.is_empty():
		AudioDirector.play_music(music)

	Dialogue.started.connect(_on_dialogue_started)
	Dialogue.finished.connect(_on_dialogue_ended)
	Dialogue.cancelled.connect(_on_dialogue_ended)
	Dialogue.command_issued.connect(_on_dialogue_command)

	if interact_prompt:
		interact_prompt.visible = false

	_place_player(String(SceneFlow.payload.get("spawn", "")))

	GameState.current_scene = scene_file_path
	if autosave_on_enter and not GameState.testing:
		SaveGame.save_to_slot(SaveGame.AUTOSAVE_SLOT, scene_file_path, default_spawn)


func _exit_tree() -> void:
	# The room can be detached while a desk scene is pushed; do not leave stale
	# connections behind when it is finally freed.
	for connection: Dictionary in [
		{"sig": Dialogue.started, "fn": _on_dialogue_started},
		{"sig": Dialogue.finished, "fn": _on_dialogue_ended},
		{"sig": Dialogue.cancelled, "fn": _on_dialogue_ended},
		{"sig": Dialogue.command_issued, "fn": _on_dialogue_command},
	]:
		var sig: Signal = connection["sig"]
		if sig.is_connected(connection["fn"]):
			sig.disconnect(connection["fn"])


## Called by [SceneFlow] when this room becomes the running scene.
func scene_entered(payload: Dictionary) -> void:
	_place_player(String(payload.get("spawn", "")))


## Called by [SceneFlow] when a pushed scene (a desk) has closed.
func scene_resumed(_payload: Dictionary) -> void:
	if player:
		player.movement_locked = false
	if not music.is_empty():
		AudioDirector.play_music(music)


func _process(_delta: float) -> void:
	_update_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		open_pause_menu()
		get_viewport().set_input_as_handled()
		return

	if Dialogue.is_active or SceneFlow.is_busy():
		return

	if event.is_action_pressed("interact") and _focused:
		_activate(_focused)
		get_viewport().set_input_as_handled()


## Picks the nearest available interactable the player is standing in, and
## keeps the floating prompt on it.
func _update_focus() -> void:
	if not player or Dialogue.is_active or SceneFlow.is_busy():
		_set_focus(null)
		return

	var best: Interactable = null
	var best_distance := INF
	for node: Node in get_tree().get_nodes_in_group("interactables"):
		var candidate := node as Interactable
		if candidate == null or not is_ancestor_of(candidate):
			continue
		if not candidate.player_in_range or not candidate.is_available():
			continue
		var distance := candidate.distance_to_point(player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	_set_focus(best)


func _set_focus(target: Interactable) -> void:
	_focused = target
	if not interact_prompt:
		return
	interact_prompt.visible = target != null
	if target:
		interact_prompt.global_position = target.global_position + target.prompt_offset
		if interact_prompt.has_method("set_prompt"):
			interact_prompt.call("set_prompt", target.prompt)


func _activate(target: Interactable) -> void:
	_set_focus(null)
	if player:
		player.stop()
	target.activate()


func open_pause_menu() -> void:
	if get_tree().paused:
		return
	var packed: PackedScene = load("res://scenes/menus/pause_menu.tscn")
	var menu := packed.instantiate()
	get_tree().root.add_child(menu)
	get_tree().paused = true


func _on_dialogue_started(_script_id: String) -> void:
	if player:
		player.movement_locked = true


func _on_dialogue_ended(_script_id: String) -> void:
	if player:
		player.movement_locked = false


## Stage directions from `.dlg` files. Add cases here as the writing needs them;
## anything unhandled is reported rather than silently ignored.
func _on_dialogue_command(command: String, args: PackedStringArray) -> void:
	match command:
		"music":
			AudioDirector.play_music(args[0] if args.size() > 0 else "none")
		"sfx":
			if args.size() > 0:
				AudioDirector.play_sfx(args[0])
		"goto":
			if args.size() > 0:
				SceneFlow.goto(args[0], args[1] if args.size() > 1 else "")
		"walk_to":
			# @walk_to NpcName MarkerName
			if args.size() >= 2:
				var who := get_node_or_null(NodePath(args[0]))
				var marker := get_node_or_null(NodePath("Spawns/%s" % args[1]))
				if who and marker and who.has_method("walk_to"):
					who.call("walk_to", (marker as Node2D).global_position)
		_:
			push_warning("room '%s': unhandled dialogue command '@%s'" % [room_id, command])


func _place_player(spawn_name: String) -> void:
	if not player:
		return
	var wanted := spawn_name if not spawn_name.is_empty() else default_spawn
	var marker := get_node_or_null(NodePath("Spawns/%s" % wanted)) as Node2D
	if marker == null:
		marker = get_node_or_null(NodePath("Spawns/%s" % default_spawn)) as Node2D
	if marker:
		player.global_position = marker.global_position
	player.stop()
	player.set_camera_limits(camera_bounds)
