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

	# Read before the headless check: setting state is useful without a display,
	# capturing a screenshot is not.
	var args := _user_args()
	if args.has("set"):
		_state_spec = String(args["set"])
		_apply_state(_state_spec)
		# GameState.reset() restores DEFAULTS, and DEFAULTS contains
		# journey_run. boot.gd calls reset() on the --scene path a frame after
		# this runs, so setting the value once is not enough: it gets wiped and
		# the default run plays instead, which looks exactly like the flag being
		# ignored. Re-apply on every reset rather than trying to win the race.
		GameState.run_started.connect(_reapply_state)

	if _is_headless():
		return

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


## What --set asked for, kept so it can be re-applied after a reset. Empty
## unless the flag was passed, which is what keeps all of this inert in a
## normal build.
var _state_spec: String = ""


func _reapply_state() -> void:
	if not _state_spec.is_empty():
		_apply_state(_state_spec)


## Writes `key:value` pairs straight into GameState, before the first scene
## loads. This exists so a specific run can be started from the command line:
##
##     OfficerChoi.exe -- --set=journey_run:mexico --scene=res://... \
##         --screenshot=C:\path\shot.png
##
## Development only, and inert unless --set is passed: with the flag absent
## nothing here executes, so a shipped build behaves exactly as before. It runs
## in DevTools rather than in GameState because this is a debugging affordance,
## not a save-game feature, and it should be deletable without touching state.
##
## Integer-looking values are stored as integers, because `season` and `mission`
## are compared numerically and a string "3" would silently fail those checks.
func _apply_state(spec: String) -> void:
	for pair: String in spec.split(";", false):
		var key := pair.get_slice(":", 0).strip_edges()
		var value := pair.get_slice(":", 1).strip_edges()
		if key.is_empty():
			continue
		GameState.set_var(key, int(value) if value.is_valid_int() else value)
		print("devtools: %s = %s" % [key, value])


func _user_args() -> Dictionary:
	var args := {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			args[arg.substr(2).get_slice("=", 0)] = arg.get_slice("=", 1)
	return args


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"
