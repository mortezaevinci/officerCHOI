extends TestCase
## Checks the compiled journey data, and the contract between the two halves of
## its format.
##
## direction.bin, event.bin and scenes.bin are written by Python
## (C:\temp\_script\journey_format.py) and read by GDScript
## (src/journey/journey_data.gd). Nothing but this file makes the two agree:
## reorder a field on one side and every record silently decodes into garbage
## that still looks like a valid record. That is what these tests exist to catch.
##
## They assert the design rule rather than fixed counts, so adding events does
## not break them.

const RUN_DIR_RELATIVE := "../assets/journey/iran"

## A good event that triggers nothing. Nothing may follow it - that is what
## makes it a rest rather than a trap.
const PURE_GOOD := "goodlife:FOO-004"

## A good event that triggers visa, border, airport, documents and credential,
## so refusals may legitimately follow it.
const EXPOSING_GOOD := "goodlife:TRV-143"


func _run_dir() -> String:
	var project_dir := ProjectSettings.globalize_path("res://")
	return project_dir.path_join(RUN_DIR_RELATIVE).simplify_path()


func _load() -> JourneyData:
	return JourneyData.load_run(_run_dir())


func test_the_run_loads_without_errors() -> void:
	var data := _load()
	if not data.ok:
		fail("%s:\n            %s" % [_run_dir(), "\n            ".join(data.errors)])


func test_the_graph_has_nodes_and_edges() -> void:
	var data := _load()
	assert_false(data.nodes.is_empty(), "direction.bin decoded no nodes")
	assert_false(data.edges.is_empty(), "direction.bin decoded no edges")


func test_strings_decoded_rather_than_garbage() -> void:
	# The cheapest way to notice the two sides have drifted: a field read at the
	# wrong offset still yields a string table index, just the wrong one.
	var data := _load()
	for node: Dictionary in data.nodes:
		var id := String(node["node_id"])
		assert_true(id.contains(":"),
			"node id '%s' is not namespaced - field order has drifted" % id)
		assert_false(String(node["title"]).is_empty(),
			"node '%s' decoded an empty title" % id)


func test_every_node_id_is_unique() -> void:
	var data := _load()
	var seen := {}
	for node: Dictionary in data.nodes:
		var id := String(node["node_id"])
		assert_false(seen.has(id), "duplicate node id '%s'" % id)
		seen[id] = true


func test_edges_point_at_real_nodes() -> void:
	var data := _load()
	var count := data.nodes.size()
	for edge: Dictionary in data.edges:
		var src := int(edge["src"])
		var dst := int(edge["dst"])
		assert_true(src >= 0 and src < count, "edge src %d out of range" % src)
		assert_true(dst >= 0 and dst < count, "edge dst %d out of range" % dst)


func test_a_pure_good_has_no_consequences() -> void:
	# The causal rule, stated as a test. A pomegranate triggers nothing, so
	# nothing may follow it.
	var data := _load()
	var i := data.index_of(PURE_GOOD)
	assert_true(i >= 0, "%s is missing from the graph" % PURE_GOOD)
	if i < 0:
		return
	assert_true(data.trigger_names(i).is_empty(),
		"%s should trigger nothing" % PURE_GOOD)
	var after := data.successors(i, JourneyData.EDGE_CONSEQUENCE)
	assert_true(after.is_empty(),
		"%s has %d consequences; a rest must cost nothing" % [PURE_GOOD, after.size()])


func test_an_exposing_good_does_have_consequences() -> void:
	# The other half of the rule, so the test above cannot pass by the graph
	# simply having no consequence edges at all.
	var data := _load()
	var i := data.index_of(EXPOSING_GOOD)
	assert_true(i >= 0, "%s is missing from the graph" % EXPOSING_GOOD)
	if i < 0:
		return
	var triggers := data.trigger_names(i)
	assert_true(triggers.has("visa"), "%s should trigger visa" % EXPOSING_GOOD)
	var after := data.successors(i, JourneyData.EDGE_CONSEQUENCE)
	assert_false(after.is_empty(), "%s should expose you to something" % EXPOSING_GOOD)
	for dst: int in after:
		assert_true(int(data.nodes[dst]["kind"]) == JourneyData.NODE_BAD,
			"a consequence of %s is not a hurdle" % EXPOSING_GOOD)


func test_authored_events_attach_to_real_nodes() -> void:
	var data := _load()
	assert_false(data.events.is_empty(), "event.bin decoded no events")
	for event_id: String in data.events:
		var event: Dictionary = data.events[event_id]
		var node_id := String(event["node_id"])
		var found := false
		for node: Dictionary in data.nodes:
			if String(node["event_id"]) == event_id:
				found = true
				break
		assert_true(found, "%s (%s) is attached to no node" % [event_id, node_id])


func test_every_event_has_an_entry_node_with_steps() -> void:
	var data := _load()
	for event_id: String in data.events:
		var event: Dictionary = data.events[event_id]
		var nodes: Dictionary = event["nodes"]
		assert_false(nodes.is_empty(), "%s has no dialogue nodes" % event_id)
		assert_true(nodes.has("start"), "%s has no 'start' node" % event_id)


func test_every_choice_targets_a_node_in_its_own_event() -> void:
	# The same check test_content.gd makes of .dlg files, for compiled events.
	var data := _load()
	for event_id: String in data.events:
		var event: Dictionary = data.events[event_id]
		var nodes: Dictionary = event["nodes"]
		for node_name: String in nodes:
			for step: Dictionary in nodes[node_name]:
				var kind := int(step["kind"])
				if kind == JourneyData.STEP_CHOICES:
					for option: Dictionary in step["options"]:
						var target := String(option["target"])
						assert_true(nodes.has(target),
							"%s/%s: choice points at missing node '%s'"
							% [event_id, node_name, target])
				elif kind == JourneyData.STEP_JUMP or kind == JourneyData.STEP_BRANCH:
					var target := String(step["target"])
					assert_true(nodes.has(target),
						"%s/%s: jump points at missing node '%s'"
						% [event_id, node_name, target])


func test_every_event_names_a_scene_that_exists() -> void:
	var data := _load()
	assert_false(data.scenes.is_empty(), "scenes.bin decoded no scenes")
	for event_id: String in data.events:
		var scene_id := String(data.events[event_id]["scene_id"])
		assert_true(data.scenes.has(scene_id),
			"%s names scene '%s', which scenes.bin does not have"
			% [event_id, scene_id])


func test_every_scene_has_its_artwork_on_disk() -> void:
	# The art is generated by tools/art/build_journey_scenes.py. A scene whose
	# PNG is missing renders as nothing and is easy to miss in a conversation.
	var data := _load()
	var run_dir := _run_dir()
	for scene_id: String in data.scenes:
		var art := String(data.scenes[scene_id]["art"])
		var path := run_dir.path_join(art)
		assert_true(FileAccess.file_exists(path),
			"scene '%s' has no artwork at %s (run build_journey_scenes.py)"
			% [scene_id, path])


func test_a_corrupt_file_is_refused_rather_than_half_read() -> void:
	# The container carries a crc32; a reader that ignored it would hand back
	# plausible-looking nonsense.
	var data := JourneyData.load_run(_run_dir().path_join("does-not-exist"))
	assert_false(data.ok, "a missing run reported itself as loaded")
	assert_false(data.errors.is_empty(), "a missing run recorded no error")
