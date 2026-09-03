class_name ConversationView
extends Control
## The close-up scene: two people, a background, and one conversation.
##
## This is what a desk (or an interrogation table, or a phone call) opens into.
## It is pushed on top of the room by [Interactable], so when the conversation
## ends and it pops, the room is exactly as the player left it.
##
## Everything about *which* conversation is either set in the inspector on a
## per-desk scene, or passed in through [SceneFlow]'s payload:
##
##     SceneFlow.push("res://scenes/conversations/desk.tscn", {
##         "dialogue": "res://content/dialogue/en/desk_ward.dlg",
##         "left": "choi", "right": "ward",
##     })

signal conversation_finished(script_id: String)

@export_group("Content")
@export_file("*.dlg") var dialogue_file: String = ""
@export var dialogue_entry: String = ""
@export var left_character: String = ""
@export var right_character: String = ""

@export_group("Presentation")
@export var background: Texture2D
@export var music: String = ""
## Pop back to the scene underneath when the conversation ends. Turn off for a
## conversation that is its own top-level scene (an intro, a phone call).
@export var return_on_finish: bool = true

@onready var _background: TextureRect = $Background
@onready var _left: PortraitSlot = $Portraits/Left
@onready var _right: PortraitSlot = $Portraits/Right

var _finishing: bool = false


func _ready() -> void:
	if background:
		_background.texture = background

	Dialogue.line_shown.connect(_on_line_shown)
	Dialogue.command_issued.connect(_on_command)
	Dialogue.finished.connect(_on_finished)
	Dialogue.cancelled.connect(_on_finished)

	_left.set_character(left_character)
	_right.set_character(right_character)

	if not music.is_empty():
		AudioDirector.play_music(music)

	# Wait a frame so the fade-in has started before the first line lands.
	await get_tree().process_frame
	if not is_inside_tree():
		return  # closed again before it ever opened
	if not dialogue_file.is_empty():
		Dialogue.start(dialogue_file, dialogue_entry)
	else:
		push_warning("ConversationView has no dialogue file")


## Arguments from [method SceneFlow.push], delivered before this scene enters
## the tree so that [method _ready] below already knows them. Anything not
## passed keeps whatever the scene was authored with in the inspector.
func scene_configure(payload: Dictionary) -> void:
	dialogue_file = String(payload.get("dialogue", dialogue_file))
	dialogue_entry = String(payload.get("entry", dialogue_entry))
	left_character = String(payload.get("left", left_character))
	right_character = String(payload.get("right", right_character))
	music = String(payload.get("music", music))


func _on_line_shown(speaker: String, mood: String, _text: String) -> void:
	# Light whoever is talking, dim the other, and swap in the right expression.
	var talking := CharacterDb.canonical_id(speaker)
	var speaking_left := not talking.is_empty() \
		and talking == CharacterDb.canonical_id(_left.character_id)
	var speaking_right := not talking.is_empty() \
		and talking == CharacterDb.canonical_id(_right.character_id)
	if speaking_left and not mood.is_empty():
		_left.set_character(left_character, mood)
	if speaking_right and not mood.is_empty():
		_right.set_character(right_character, mood)
	# Narration (no speaker) leaves both lit rather than dimming the whole cast.
	_left.set_speaking(speaking_left or speaker.is_empty())
	_right.set_speaking(speaking_right or speaker.is_empty())


func _on_command(command: String, args: PackedStringArray) -> void:
	match command:
		"portrait":
			# @portrait left ward angry
			if args.size() >= 2:
				var slot := _left if args[0] == "left" else _right
				var mood := args[2] if args.size() > 2 else ""
				slot.set_character(args[1], mood)
				if args[0] == "left":
					left_character = args[1]
				else:
					right_character = args[1]
		"music":
			AudioDirector.play_music(args[0] if args.size() > 0 else "none")
		"sfx":
			if args.size() > 0:
				AudioDirector.play_sfx(args[0])


func _on_finished(script_id: String) -> void:
	if _finishing:
		return
	_finishing = true
	conversation_finished.emit(script_id)
	if not return_on_finish:
		return
	if SceneFlow.can_pop():
		SceneFlow.pop()
	else:
		# Opened directly (a dev switch, or a conversation that opens the game)
		# with no room underneath to go back to.
		SceneFlow.goto(GamePaths.MAIN_MENU)
