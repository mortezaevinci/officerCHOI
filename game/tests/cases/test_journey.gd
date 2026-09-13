extends TestCase
## Checks the compiled journey documents, and the contract between the two
## halves of their format.
##
## content/journey/<run>/journey.json is written by Python
## (C:\temp\_script\journey_build.py) and read by GDScript
## (src/journey/journey_data.gd). Nothing but this file makes the two agree:
## rename a key on one side and every record still parses, into nothing.
##
## These assert the design rules rather than fixed counts, so adding events or
## whole nationalities does not break them.

## A good event that triggers nothing. Nothing may follow it - that is what
## makes it a rest rather than a trap.
const PURE_GOOD := "goodlife:FOO-004"

## A good event that triggers visa, border, airport, documents and credential,
## so refusals may legitimately follow it.
const EXPOSING_GOOD := "goodlife:TRV-143"


func _runs() -> PackedStringArray:
	return JourneyData.available_runs()


func test_at_least_one_run_exists() -> void:
	assert_false(_runs().is_empty(),
		"no journey.json found under %s" % JourneyData.CONTENT_ROOT)


func test_every_run_loads_without_errors() -> void:
	for run: String in _runs():
		var data := JourneyData.load_run(run)
		if not data.ok:
			fail("%s:\n            %s" % [run, "\n            ".join(data.errors)])


func test_every_run_is_self_contained() -> void:
	# Runs must not depend on each other. Each document carries its own cast,
	# scenes and graph, so loading one in isolation has to be enough.
	for run: String in _runs():
		var data := JourneyData.load_run(run)
		assert_false(data.nodes.is_empty(), "%s has no nodes" % run)
		assert_false(data.scenes.is_empty(), "%s has no scenes" % run)
		assert_false(data.cast.is_empty(), "%s has no cast" % run)


func test_node_ids_are_namespaced_and_unique() -> void:
	# The four datasets collide on bare ids - FIN-001, PSY-001, DIS-001 and
	# EDU-001 all exist in more than one - so the namespace is load-bearing.
	for run: String in _runs():
		var data := JourneyData.load_run(run)
		var seen := {}
		for node: Dictionary in data.nodes:
			var id := String(node["id"])
			assert_true(id.contains(":"), "%s: id '%s' is not namespaced" % [run, id])
			assert_false(seen.has(id), "%s: duplicate id '%s'" % [run, id])
			seen[id] = true


func test_edges_point_at_real_nodes() -> void:
	for run: String in _runs():
		var data := JourneyData.load_run(run)
		var count := data.nodes.size()
		for edge: Array in data.edges:
			var src := int(edge[JourneyData.E_SRC])
			var dst := int(edge[JourneyData.E_DST])
			assert_true(src >= 0 and src < count, "%s: src %d out of range" % [run, src])
			assert_true(dst >= 0 and dst < count, "%s: dst %d out of range" % [run, dst])


func test_a_pure_good_has_no_consequences() -> void:
	# The causal rule, stated as a test.
	var data := JourneyData.load_run("iran")
	var i := data.index_of(PURE_GOOD)
	assert_true(i >= 0, "%s is missing" % PURE_GOOD)
	if i < 0:
		return
	assert_true(data.trigger_names(i).is_empty(), "%s should trigger nothing" % PURE_GOOD)
	var after := data.successors(i, JourneyData.EDGE_CONSEQUENCE)
	assert_true(after.is_empty(),
		"%s has %d consequences; a rest must cost nothing" % [PURE_GOOD, after.size()])


func test_an_exposing_good_does_have_consequences() -> void:
	# The other half, so the test above cannot pass by there being no
	# consequence edges at all.
	var data := JourneyData.load_run("iran")
	var i := data.index_of(EXPOSING_GOOD)
	assert_true(i >= 0, "%s is missing" % EXPOSING_GOOD)
	if i < 0:
		return
	assert_true(data.trigger_names(i).has("visa"), "%s should trigger visa" % EXPOSING_GOOD)
	var after := data.successors(i, JourneyData.EDGE_CONSEQUENCE)
	assert_false(after.is_empty(), "%s should expose you to something" % EXPOSING_GOOD)
	for dst: int in after:
		assert_true(int(data.nodes[dst]["kind"]) == JourneyData.NODE_BAD,
			"a consequence of %s is not a hurdle" % EXPOSING_GOOD)


func test_event_uuids_are_present_and_unique_within_a_run() -> void:
	for run: String in _runs():
		var data := JourneyData.load_run(run)
		var seen := {}
		for event_id: String in data.events:
			var uid := String(data.events[event_id].get("uuid", ""))
			assert_true(uid.length() == 36, "%s/%s: '%s' is not a uuid" % [run, event_id, uid])
			assert_false(seen.has(uid), "%s: uuid reused by %s" % [run, event_id])
			seen[uid] = event_id


func test_authored_events_attach_to_real_nodes() -> void:
	for run: String in _runs():
		var data := JourneyData.load_run(run)
		assert_false(data.events.is_empty(), "%s has no events" % run)
		for event_id: String in data.events:
			var node_id := String(data.events[event_id]["node"])
			assert_true(data.index_of(node_id) >= 0,
				"%s/%s attaches to missing node '%s'" % [run, event_id, node_id])


func test_every_choice_targets_a_node_in_its_own_event() -> void:
	for run: String in _runs():
		var data := JourneyData.load_run(run)
		for event_id: String in data.events:
			var event_nodes: Dictionary = data.events[event_id]["nodes"]
			assert_true(event_nodes.has("start"), "%s/%s has no start" % [run, event_id])
			for node_name: String in event_nodes:
				for step: Dictionary in event_nodes[node_name]:
					var kind := int(step["k"])
					if kind == JourneyData.STEP_CHOICES:
						for option: Dictionary in step["options"]:
							assert_true(event_nodes.has(String(option["to"])),
								"%s/%s/%s: choice -> missing '%s'"
								% [run, event_id, node_name, option["to"]])
					elif kind == JourneyData.STEP_JUMP or kind == JourneyData.STEP_BRANCH:
						assert_true(event_nodes.has(String(step["to"])),
							"%s/%s/%s: jump -> missing '%s'"
							% [run, event_id, node_name, step["to"]])


func test_every_speaker_is_in_the_runs_own_cast() -> void:
	# Not fatal in game, but an unlisted speaker means the wrong name and the
	# wrong colour, and the cast is per-run precisely so runs stay independent.
	for run: String in _runs():
		var data := JourneyData.load_run(run)
		for event_id: String in data.events:
			var event_nodes: Dictionary = data.events[event_id]["nodes"]
			for node_name: String in event_nodes:
				for step: Dictionary in event_nodes[node_name]:
					if int(step["k"]) != JourneyData.STEP_LINE:
						continue
					var who := String(step.get("who", ""))
					assert_true(data.cast.has(who),
						"%s/%s: speaker '%s' is not in the cast" % [run, event_id, who])


func test_every_event_names_a_scene_with_artwork_on_disk() -> void:
	for run: String in _runs():
		var data := JourneyData.load_run(run)
		for event_id: String in data.events:
			var scene_id := String(data.events[event_id]["scene"])
			assert_true(data.scenes.has(scene_id),
				"%s/%s names unknown scene '%s'" % [run, event_id, scene_id])
			var art := data.art_path(scene_id)
			assert_true(FileAccess.file_exists(art),
				"%s: scene '%s' has no artwork at %s" % [run, scene_id, art])


func test_the_player_token_is_substituted() -> void:
	# The player types their own name; no name for them is written in content.
	var data := JourneyData.load_run("iran")
	var found := false
	for event_id: String in data.events:
		var event_nodes: Dictionary = data.events[event_id]["nodes"]
		for node_name: String in event_nodes:
			for step: Dictionary in event_nodes[node_name]:
				var text := String(step.get("text", ""))
				if text.contains("{player}"):
					found = true
					var shown := data.render(text, "Darya")
					assert_false(shown.contains("{player}"),
						"%s/%s: token survived rendering" % [event_id, node_name])
					assert_true(shown.contains("Darya"),
						"%s/%s: name did not appear" % [event_id, node_name])
	assert_true(found, "no line anywhere uses the player token")


func test_rendering_without_a_name_leaves_text_intact() -> void:
	var data := JourneyData.load_run("iran")
	var text := "Hold your hands out, {player}."
	assert_true(data.render(text, "") == text, "empty name should not alter the text")


func test_a_missing_run_is_refused_rather_than_half_loaded() -> void:
	var data := JourneyData.load_run("no-such-run")
	assert_false(data.ok, "a missing run reported itself as loaded")
	assert_false(data.errors.is_empty(), "a missing run recorded no error")
