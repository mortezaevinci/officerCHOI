extends TestCase
## Loads every GDScript in the project.
##
## Godot reports a parse error at the moment a script is first loaded, which
## can be deep into a play session - or in a build that is already on Steam.
## Loading them all here turns that into a failed test instead.

const ROOTS := ["res://src", "res://tests", "res://tools"]


func test_every_script_parses() -> void:
	var scripts := _all_scripts()
	assert_false(scripts.is_empty(), "no scripts found")
	for path: String in scripts:
		# load() returns null when the script fails to parse.
		var script: Resource = load(path)
		assert_true(script != null, "%s failed to parse - see the error above" % path)


func _all_scripts() -> PackedStringArray:
	var found: PackedStringArray = []
	for root: String in ROOTS:
		_collect(root, found)
	found.sort()
	return found


func _collect(dir_path: String, into: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file: String in dir.get_files():
		var name := file.trim_suffix(".remap")
		if name.ends_with(".gd"):
			into.append("%s/%s" % [dir_path, name])
	for sub: String in dir.get_directories():
		_collect("%s/%s" % [dir_path, sub], into)
