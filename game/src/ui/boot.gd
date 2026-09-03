extends Control
## First scene the game runs. Sets things up, then hands over to the menu.
##
## It also reads a couple of development command-line switches, which is the
## fastest way to iterate on one room or one conversation:
##
##     godot --path game -- --scene=res://scenes/rooms/precinct.tscn --spawn=desk
##     godot --path game -- --dialogue=desk_ward.dlg --left=choi --right=ward
##
## Those switches are ignored in exported release builds.

func _ready() -> void:
	Settings.apply_all()

	# Give the autoloads a frame to finish their own _ready work.
	await get_tree().process_frame

	if OS.is_debug_build() and _handle_dev_switches():
		return

	SceneFlow.goto(GamePaths.MAIN_MENU)


## Returns true if a switch took over and the menu should be skipped.
func _handle_dev_switches() -> bool:
	var args := {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			args[arg.substr(2).get_slice("=", 0)] = arg.get_slice("=", 1)

	# --auto reads a conversation to you, hands free. Session-only, so it never
	# ends up in the player's settings file.
	if args.has("auto") or OS.get_cmdline_user_args().has("--auto"):
		Settings.override("gameplay/auto_advance", true)

	if args.has("scene"):
		GameState.reset()
		SceneFlow.goto(String(args["scene"]), String(args.get("spawn", "")))
		return true

	if args.has("dialogue"):
		GameState.reset()
		SceneFlow.goto(GamePaths.CONVERSATION, "", {
			"dialogue": GamePaths.dialogue(String(args["dialogue"])),
			"entry": String(args.get("entry", "")),
			"left": String(args.get("left", "")),
			"right": String(args.get("right", "")),
		})
		return true

	return false
