extends TestCase
## Instantiates every scene and puts it in the tree, so `_ready` and every
## `@onready` node path actually run.
##
## Renaming a node in the editor and forgetting the script that looks it up is
## the single most common way to break a Godot project. This is the cheapest
## possible guard against it.

const SCENE_ROOT := "res://scenes"

## boot.tscn immediately navigates somewhere else, and the test runner scene is
## this file's own harness - neither belongs in a smoke test.
const SKIP := ["res://scenes/boot/boot.tscn"]


func test_every_scene_instantiates_and_enters_the_tree() -> void:
	var scenes := _all_scenes()
	assert_false(scenes.is_empty(), "no scenes found under %s" % SCENE_ROOT)

	for path: String in scenes:
		if SKIP.has(path):
			continue
		var packed: PackedScene = load(path)
		if packed == null:
			fail("%s did not load" % path)
			continue
		var node: Node = packed.instantiate()
		if node == null:
			fail("%s did not instantiate" % path)
			continue
		# Any bad @onready path or missing signal target throws here.
		tree.root.add_child(node)
		assert_true(node.is_inside_tree(), "%s did not enter the tree" % path)
		tree.root.remove_child(node)
		node.free()


func test_scenes_referenced_from_code_exist() -> void:
	for path: String in [
		GamePaths.MAIN_MENU,
		GamePaths.PAUSE_MENU,
		GamePaths.SETTINGS_MENU,
		GamePaths.NEW_GAME_SCENE,
		GamePaths.CONVERSATION,
	]:
		assert_true(ResourceLoader.exists(path), "GamePaths points at a missing scene: %s" % path)


func test_interactables_point_at_content_that_exists() -> void:
	# A desk whose target scene was renamed looks fine until someone walks up
	# to it, which might be weeks later.
	for path: String in _all_scenes():
		if SKIP.has(path):
			continue
		var packed: PackedScene = load(path)
		if packed == null:
			continue
		var node: Node = packed.instantiate()
		tree.root.add_child(node)
		for child: Node in node.find_children("*", "Interactable", true, false):
			var target := child as Interactable
			match target.action:
				Interactable.Action.DIALOGUE:
					assert_true(FileAccess.file_exists(target.dialogue_file),
						"%s: '%s' has no dialogue file at '%s'"
							% [path, target.name, target.dialogue_file])
				Interactable.Action.PUSH_SCENE, Interactable.Action.GOTO_SCENE:
					assert_true(ResourceLoader.exists(target.target_scene),
						"%s: '%s' points at a missing scene '%s'"
							% [path, target.name, target.target_scene])
		tree.root.remove_child(node)
		node.free()


func _all_scenes() -> PackedStringArray:
	var found: PackedStringArray = []
	_collect(SCENE_ROOT, found)
	found.sort()
	return found


func _collect(dir_path: String, into: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file: String in dir.get_files():
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tscn"):
			into.append("%s/%s" % [dir_path, name])
	for sub: String in dir.get_directories():
		_collect("%s/%s" % [dir_path, sub], into)
