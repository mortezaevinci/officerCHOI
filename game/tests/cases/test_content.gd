extends TestCase
## Checks the actual game content, not the engine: every conversation in
## content/dialogue must parse cleanly and point only at nodes that exist.
##
## This is the test that catches a typo in a writer's file before anyone plays
## it, so it is worth running on every commit.

const DIALOGUE_ROOT := "res://content/dialogue"
const CHARACTERS := "res://content/characters/characters.json"


func test_every_dialogue_file_parses() -> void:
	var files := _all_dialogue_files()
	assert_false(files.is_empty(), "no .dlg files found under %s" % DIALOGUE_ROOT)
	for path: String in files:
		var script := DialogueParser.parse_file(path)
		if not script.errors.is_empty():
			fail("%s:\n            %s" % [path, "\n            ".join(script.errors)])


func test_every_dialogue_file_has_an_entry_node() -> void:
	for path: String in _all_dialogue_files():
		var script := DialogueParser.parse_file(path)
		assert_false(script.entry.is_empty(), "%s has no nodes" % path)


func test_no_unreachable_nodes() -> void:
	# A node nobody jumps to is usually a rename that was only half finished.
	for path: String in _all_dialogue_files():
		var script := DialogueParser.parse_file(path)
		var reached := {script.entry: true}
		for node_id: String in script.node_ids():
			for step: Dictionary in script.get_steps(node_id):
				match step.get("kind", ""):
					DialogueScript.JUMP, DialogueScript.BRANCH:
						reached[String(step["target"])] = true
					DialogueScript.CHOICES:
						for option: Dictionary in step["options"]:
							reached[String(option["target"])] = true
		for node_id: String in script.node_ids():
			assert_true(reached.has(node_id),
				"%s: nothing leads to node '%s'" % [path, node_id])


func test_characters_file_is_valid_json() -> void:
	assert_true(FileAccess.file_exists(CHARACTERS), "characters.json is missing")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHARACTERS))
	assert_true(parsed is Dictionary, "characters.json must be a JSON object")


func test_every_speaker_is_a_known_character() -> void:
	# Not fatal in game - an unknown speaker still prints - but it is almost
	# always a typo, and a typo means the wrong portrait and the wrong colour.
	CharacterDb.reload()
	for path: String in _all_dialogue_files():
		var script := DialogueParser.parse_file(path)
		for node_id: String in script.node_ids():
			for step: Dictionary in script.get_steps(node_id):
				if step.get("kind", "") != DialogueScript.LINE:
					continue
				var speaker := String(step["speaker"])
				if speaker.is_empty() or CharacterDb.is_known(speaker):
					continue
				fail("%s: '%s' is not in characters.json" % [path, speaker])


func _all_dialogue_files() -> PackedStringArray:
	var found: PackedStringArray = []
	_collect(DIALOGUE_ROOT, found)
	found.sort()
	return found


func _collect(dir_path: String, into: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file: String in dir.get_files():
		var name := file.trim_suffix(".remap")
		if name.ends_with(".dlg"):
			into.append("%s/%s" % [dir_path, name])
	for sub: String in dir.get_directories():
		_collect("%s/%s" % [dir_path, sub], into)
