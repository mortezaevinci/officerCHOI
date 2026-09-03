extends Node
## Autoload `DevTools`: screenshots, and somewhere to put the next small
## development convenience.
##
## Press F12 at any time to drop a PNG in `user://screenshots`. From the command
## line, capture a specific screen without touching the keyboard - which is how
## the Steam store shots get taken, and how a scene can be eyeballed from a
## script:
##
##     godot --path game -- --scene=res://scenes/rooms/precinct.tscn \
##         --screenshot=C:\temp\_samples\precinct.png --shot-after=120

const DIR := "user://screenshots"

## Frames to wait before an automatic capture, so fades and layout have settled.
const DEFAULT_DELAY_FRAMES := 90


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(DIR)

	if _is_headless():
		return

	var args := _user_args()
	if args.has("screenshot"):
		_auto_capture(String(args["screenshot"]), int(args.get("shot-after", DEFAULT_DELAY_FRAMES)))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_F12:
		capture()


## Saves a PNG. With no path, writes a timestamped file into `user://screenshots`
## and returns where it went.
func capture(path: String = "") -> String:
	if _is_headless():
		push_warning("DevTools: cannot screenshot without a display")
		return ""

	if path.is_empty():
		path = "%s/%s.png" % [DIR, Time.get_datetime_string_from_system(false, true)
			.replace(":", "-").replace(" ", "_")]

	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	if err != OK:
		push_error("DevTools: could not write %s (%s)" % [path, error_string(err)])
		return ""
	print("screenshot: %s" % ProjectSettings.globalize_path(path))
	return path


func _auto_capture(path: String, delay_frames: int) -> void:
	for i: int in maxi(delay_frames, 1):
		await get_tree().process_frame
	await capture(path)
	get_tree().quit(0)


func _user_args() -> Dictionary:
	var args := {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			args[arg.substr(2).get_slice("=", 0)] = arg.get_slice("=", 1)
	return args


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"
