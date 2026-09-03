class_name PortraitSlot
extends Control
## One character's portrait in a close-up conversation.
##
## Falls back to a labelled placeholder card when the art does not exist yet,
## which is most of the time early on. That keeps conversations fully playable
## and reviewable long before anyone draws anything.

const DIM := Color(0.45, 0.45, 0.5, 1.0)
const LIT := Color(1, 1, 1, 1)

@onready var _texture: TextureRect = $Texture
@onready var _placeholder: Control = $Placeholder
@onready var _placeholder_label: Label = $Placeholder/Label

var character_id: String = ""


## Shows [param id] with an optional mood. Passing "" empties the slot.
func set_character(id: String, mood: String = "") -> void:
	character_id = id
	if id.is_empty():
		visible = false
		return

	visible = true
	var path := CharacterDb.portrait_path(id, mood)
	if path.is_empty():
		_texture.visible = false
		_placeholder.visible = true
		_placeholder_label.text = CharacterDb.display_name(id)
		_placeholder.modulate = CharacterDb.color(id)
	else:
		_texture.texture = load(path)
		_texture.visible = true
		_placeholder.visible = false


## Lights this portrait when its character is talking and dims it otherwise.
func set_speaking(speaking: bool) -> void:
	var target := LIT if speaking else DIM
	create_tween().tween_property(self, "modulate", target, 0.15)
