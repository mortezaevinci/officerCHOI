class_name PortraitSlot
extends Control
## One character's portrait in a close-up conversation.
##
## Falls back to a labelled placeholder card when the art does not exist yet,
## which is most of the time early on. That keeps conversations fully playable
## and reviewable long before anyone draws anything.

const DIM := Color(0.62, 0.62, 0.68, 1.0)
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

	# The card stays either way - it is the character's colour, and the portrait
	# art reads against it. Only the name label is a stand-in for missing art.
	_placeholder.visible = true
	_placeholder.modulate = CharacterDb.color(id)

	# A mood sheet is one image holding all nine faces; this hands back the right
	# cell as an AtlasTexture, and falls back to the single-file portrait for a
	# character who has no sheet yet.
	var art := CharacterDb.portrait_texture(id, mood)
	if art == null:
		_texture.visible = false
		_placeholder_label.text = CharacterDb.display_name(id)
		_placeholder_label.visible = true
	else:
		_texture.texture = art
		_texture.visible = true
		_placeholder_label.visible = false


## Lights this portrait when its character is talking and dims it otherwise.
func set_speaking(speaking: bool) -> void:
	var target := LIT if speaking else DIM
	create_tween().tween_property(self, "modulate", target, 0.15)
