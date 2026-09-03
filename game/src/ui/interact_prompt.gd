extends Control
## The little floating "Examine the desk" label a room parks over whatever the
## player is standing next to.
##
## The room keeps this node's origin on the object; the panel centres itself
## around that origin, so the prompt sits above the object rather than hanging
## off to one side.

@onready var _panel: Control = $Panel
@onready var _label: Label = $Panel/Margin/Label

var _current: String = ""


func set_prompt(text: String) -> void:
	if text == _current:
		return
	_current = text
	_label.text = text
	# The panel only knows its width after the container has laid it out.
	await get_tree().process_frame
	if is_instance_valid(_panel):
		_panel.position = Vector2(-_panel.size.x * 0.5, -_panel.size.y)
