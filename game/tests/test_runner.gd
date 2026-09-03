extends Node
## Finds and runs every `test_*.gd` under res://tests/cases, then quits with a
## non-zero exit code if anything failed - so CI and tools/build/run-tests can
## just look at the exit status.
##
##     godot --headless --path game res://tests/test_runner.tscn

const CASES_DIR := "res://tests/cases"


func _ready() -> void:
	# Tests add nodes to the tree, which the root refuses while it is still
	# setting up its own children. Let the first frames go by first.
	await get_tree().process_frame
	await get_tree().process_frame
	_run()


func _run() -> void:
	var total := 0
	var failed := 0
	var assertions := 0
	var report: PackedStringArray = []

	print_rich("[b]Officer Choi - test run[/b]")
	# Lets scenes skip side effects that would trample the player's own files.
	GameState.testing = true

	for path: String in _find_cases():
		var script: GDScript = load(path)
		if script == null:
			report.append("could not load %s" % path)
			failed += 1
			continue

		var instance: TestCase = script.new()
		instance.tree = get_tree()
		var case_name := path.get_file().get_basename()

		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			instance.failures = []
			instance.before_each()
			instance.call(method_name)
			instance.after_each()
			assertions += instance.assertions
			instance.assertions = 0
			if instance.failures.is_empty():
				print("  ok    %s.%s" % [case_name, method_name])
			else:
				failed += 1
				print("  FAIL  %s.%s" % [case_name, method_name])
				for failure: String in instance.failures:
					print("          %s" % failure)
					report.append("%s.%s: %s" % [case_name, method_name, failure])

	print("")
	print("%d test(s), %d assertion(s), %d failure(s)" % [total, assertions, failed])
	if failed > 0:
		for line: String in report:
			printerr(line)

	get_tree().quit(1 if failed > 0 else 0)


func _find_cases() -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(CASES_DIR)
	if dir == null:
		printerr("no test directory at %s" % CASES_DIR)
		return found
	for file: String in dir.get_files():
		# Exported builds rename .gd to .gdc/.remap; source runs see plain .gd.
		var name := file.trim_suffix(".remap")
		if name.begins_with("test_") and name.ends_with(".gd"):
			found.append("%s/%s" % [CASES_DIR, name])
	found.sort()
	return found
