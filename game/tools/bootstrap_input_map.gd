extends SceneTree
## Writes the game's input actions into project.godot.
##
##     tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game \
##         --script res://tools/bootstrap_input_map.gd
##
## Run it once when setting up, and again whenever the bindings below change.
## Editing the actions here rather than by hand in the Input Map panel keeps
## them reviewable in a diff and identical on every machine.
##
## Keyboard, gamepad and touch all end up mapped to the same small set of
## actions, which is what lets one build serve Steam and Android.

const ACTIONS := {
	"move_left": {
		"keys": [KEY_A, KEY_LEFT],
		"axes": [[JOY_AXIS_LEFT_X, -1.0]],
	},
	"move_right": {
		"keys": [KEY_D, KEY_RIGHT],
		"axes": [[JOY_AXIS_LEFT_X, 1.0]],
	},
	"move_up": {
		"keys": [KEY_W, KEY_UP],
		"axes": [[JOY_AXIS_LEFT_Y, -1.0]],
	},
	"move_down": {
		"keys": [KEY_S, KEY_DOWN],
		"axes": [[JOY_AXIS_LEFT_Y, 1.0]],
	},
	# Walk up to something and act on it.
	"interact": {
		"keys": [KEY_E, KEY_F],
		"buttons": [JOY_BUTTON_A],
	},
	# Move a conversation along. Separate from `interact` so that a line can be
	# advanced without also re-triggering whatever started the conversation.
	"advance": {
		"keys": [KEY_SPACE, KEY_ENTER],
		"buttons": [JOY_BUTTON_A],
	},
	"pause": {
		"keys": [KEY_ESCAPE],
		"buttons": [JOY_BUTTON_START],
	},
	# Hold to fast-forward text the player has already read.
	"skip": {
		"keys": [KEY_CTRL, KEY_TAB],
		"buttons": [JOY_BUTTON_RIGHT_SHOULDER],
	},
}


func _initialize() -> void:
	for action_name: String in ACTIONS:
		var setting := "input/%s" % action_name
		var events: Array = []
		var spec: Dictionary = ACTIONS[action_name]

		for keycode: int in spec.get("keys", []):
			var key := InputEventKey.new()
			key.physical_keycode = keycode
			events.append(key)

		for button: int in spec.get("buttons", []):
			var pad := InputEventJoypadButton.new()
			pad.button_index = button
			events.append(pad)

		for axis: Array in spec.get("axes", []):
			var motion := InputEventJoypadMotion.new()
			motion.axis = axis[0]
			motion.axis_value = axis[1]
			events.append(motion)

		ProjectSettings.set_setting(setting, {"deadzone": 0.35, "events": events})

	var err := ProjectSettings.save()
	if err != OK:
		printerr("could not write project.godot: %s" % error_string(err))
		quit(1)
		return

	print("wrote %d input actions to project.godot" % ACTIONS.size())
	quit(0)
