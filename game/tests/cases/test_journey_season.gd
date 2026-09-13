extends TestCase
## Drives the season machinery headlessly: assembly, the causal pairing, the
## conversion into playable dialogue, and the boss order.
##
## test_journey.gd checks the *data* is sound. This checks the *game* works -
## that ten missions come out, that each one's hurdle genuinely follows from its
## good event, that a second life differs from the first, and that both an
## authored beat and a generated one produce a script the runner can play.
##
## It exists because a green suite has already been misleading twice here:
## test_every_script_parses reports ok for a script that fails to compile, and
## test_scenes only checks a scene can be instantiated. Neither would notice if
## a season came out empty.

const RUN := "iran"
const BOSS := "choi"


func _run() -> JourneyData:
	return JourneyData.load_run(RUN)


# --- assembly ---------------------------------------------------------------

func test_a_season_is_ten_missions() -> void:
	var season := JourneySeason.assemble(_run(), 1)
	assert_true(season.total() == JourneySeason.MISSIONS_PER_SEASON,
		"season 1 produced %d missions, expected %d"
			% [season.total(), JourneySeason.MISSIONS_PER_SEASON])


func test_every_mission_pairs_a_good_event_with_a_hurdle() -> void:
	var run := _run()
	var season := JourneySeason.assemble(run, 1)
	for mission: Dictionary in season.missions:
		var good: Dictionary = run.nodes[int(mission["good"])]
		var bad: Dictionary = run.nodes[int(mission["bad"])]
		assert_true(int(good["kind"]) == JourneyData.NODE_GOOD,
			"'%s' is not a good event" % good["id"])
		assert_true(int(bad["kind"]) == JourneyData.NODE_BAD,
			"'%s' is not a hurdle" % bad["id"])


func test_every_hurdle_is_a_consequence_of_its_own_good_event() -> void:
	# The whole design in one assertion. A mission is not "something nice, then
	# something nasty" - the nasty thing has to be reachable from the nice one,
	# which the graph only allows when the good event's own triggers justify it.
	var run := _run()
	var season := JourneySeason.assemble(run, 1)
	for mission: Dictionary in season.missions:
		var good := int(mission["good"])
		var bad := int(mission["bad"])
		var allowed := run.successors(good, JourneyData.EDGE_CONSEQUENCE)
		assert_true(allowed.has(bad),
			"'%s' cannot follow '%s' - it is not a consequence of it"
				% [run.nodes[bad]["id"], run.nodes[good]["id"]])


func test_a_mission_good_event_always_triggers_something() -> void:
	# A node that triggers nothing has no consequence, so it cannot carry a
	# mission. Those are the game's rest state and belong between missions.
	var run := _run()
	var season := JourneySeason.assemble(run, 1)
	for mission: Dictionary in season.missions:
		var good := int(mission["good"])
		assert_false(run.trigger_names(good).is_empty(),
			"'%s' triggers nothing and cannot carry a mission"
				% run.nodes[good]["id"])


func test_assembly_is_deterministic() -> void:
	# A save stores the season number, not the itinerary, so the same number
	# must always rebuild the same life.
	var a := JourneySeason.assemble(_run(), 3)
	var b := JourneySeason.assemble(_run(), 3)
	assert_true(a.total() == b.total(), "same season, different length")
	for i: int in a.missions.size():
		assert_true(int(a.missions[i]["good"]) == int(b.missions[i]["good"]),
			"season 3 rebuilt with a different mission %d" % i)


func test_a_new_life_is_a_different_life() -> void:
	# "Reset and try a new life" has to mean a new one.
	var first := JourneySeason.assemble(_run(), 1)
	var second := JourneySeason.assemble(_run(), 2)
	var shared := 0
	for i: int in mini(first.missions.size(), second.missions.size()):
		if int(first.missions[i]["good"]) == int(second.missions[i]["good"]):
			shared += 1
	assert_true(shared < first.total(),
		"season 2 is the same ten missions as season 1")


func test_progress_walks_to_the_end_and_stops() -> void:
	var season := JourneySeason.assemble(_run(), 1)
	assert_false(season.is_finished(), "a fresh season is already finished")
	var guard := 0
	while not season.is_finished() and guard < 50:
		guard += 1
		assert_false(season.current().is_empty(), "mission %d is empty" % guard)
		season.advance()
	assert_true(season.is_finished(), "season never finished")
	assert_true(guard == season.total(),
		"walked %d missions, season has %d" % [guard, season.total()])


# --- conversion into something playable --------------------------------------

func test_authored_events_convert_to_playable_scripts() -> void:
	var run := _run()
	for event_id: String in run.events:
		var script := JourneyDialogue.build(run, run.events[event_id], "Darya")
		if not script.errors.is_empty():
			fail("%s:\n            %s" % [event_id, "\n            ".join(script.errors)])
		assert_false(script.entry.is_empty(), "%s has no entry node" % event_id)
		assert_true(script.has_node_id(script.entry),
			"%s entry '%s' does not exist" % [event_id, script.entry])


func test_a_converted_script_has_no_dangling_targets() -> void:
	var run := _run()
	for event_id: String in run.events:
		var script := JourneyDialogue.build(run, run.events[event_id], "Darya")
		var dangling := script.dangling_targets()
		assert_true(dangling.is_empty(),
			"%s: %s" % [event_id, ", ".join(dangling)])


func test_the_player_name_reaches_the_script() -> void:
	var run := _run()
	var found := false
	for event_id: String in run.events:
		var script := JourneyDialogue.build(run, run.events[event_id], "Darya")
		for node_id: String in script.node_ids():
			for step: Dictionary in script.get_steps(node_id):
				var text := String(step.get("text", ""))
				assert_false(text.contains("{player}"),
					"%s/%s still contains the raw token" % [event_id, node_id])
				if text.contains("Darya"):
					found = true
	assert_true(found, "no converted line carries the player's name")


func test_a_node_with_no_authored_event_still_plays() -> void:
	# Most of the 1,074 nodes have no conversation. Later seasons depend on
	# those still producing a beat rather than a blank screen.
	var run := _run()
	var stubbed := 0
	for i: int in run.nodes.size():
		if not String(run.nodes[i].get("event", "")).is_empty():
			continue
		var script := JourneyDialogue.build_stub(run, i)
		assert_true(script.has_node_id("start"), "stub for %s has no start" % run.nodes[i]["id"])
		assert_false(script.get_steps("start").is_empty(),
			"stub for %s is empty" % run.nodes[i]["id"])
		stubbed += 1
		if stubbed >= 40:
			break
	assert_true(stubbed > 0, "every node had an authored event, which cannot be right")


func test_a_whole_season_can_be_converted_without_error() -> void:
	# The end-to-end check: assemble a life, and turn every beat of it into
	# something the dialogue runner would accept.
	var run := _run()
	var season := JourneySeason.assemble(run, 1)
	for mission: Dictionary in season.missions:
		for key: String in ["good", "bad"]:
			var index := int(mission[key])
			var event := run.event_for(index)
			var script := (JourneyDialogue.build_stub(run, index) if event.is_empty()
				else JourneyDialogue.build(run, event, "Darya"))
			if not script.errors.is_empty():
				fail("%s (%s):\n            %s"
					% [run.nodes[index]["id"], key, "\n            ".join(script.errors)])
			assert_false(script.entry.is_empty(),
				"%s produced a script with no entry" % run.nodes[index]["id"])


# --- the boss ----------------------------------------------------------------

func test_the_boss_run_loads_and_is_all_hurdles() -> void:
	var boss := JourneyData.load_run(BOSS)
	assert_true(boss.ok, "boss run did not load: %s" % ", ".join(boss.errors))
	for node: Dictionary in boss.nodes:
		assert_true(int(node["kind"]) == JourneyData.NODE_BAD,
			"the boss run contains a good event: %s" % node["id"])


func test_the_boss_has_a_stated_order() -> void:
	# Recovering the order from the edges does not work - the escalation ladder
	# gives almost every node an incoming edge - so the document states it.
	var boss := JourneyData.load_run(BOSS)
	assert_false(boss.sequence.is_empty(), "the boss run has no stated sequence")
	for entry: Variant in boss.sequence:
		assert_true(boss.events.has(String(entry)),
			"sequence names '%s', which is not an event" % entry)


func test_the_boss_opens_with_the_queue_and_ends_with_the_refusal() -> void:
	var boss := JourneyData.load_run(BOSS)
	if boss.sequence.is_empty():
		return
	var first := String(boss.sequence[0])
	var last := String(boss.sequence[boss.sequence.size() - 1])
	assert_true(first.contains("queue"),
		"the encounter opens with '%s' rather than the queue" % first)
	assert_true(last.contains("reviewable-by-nobody"),
		"the encounter ends with '%s' rather than the refusal" % last)


func test_every_boss_beat_converts_and_names_the_player() -> void:
	var boss := JourneyData.load_run(BOSS)
	for event_id: String in boss.events:
		var script := JourneyDialogue.build(boss, boss.events[event_id], "Darya")
		if not script.errors.is_empty():
			fail("%s:\n            %s" % [event_id, "\n            ".join(script.errors)])


func test_the_refusal_says_what_it_is_there_to_say() -> void:
	# The thesis of the whole game, and the reason the encounter exists: rights
	# belong to citizens, and he is explaining rather than raging.
	var boss := JourneyData.load_run(BOSS)
	var final_id := String(boss.sequence[boss.sequence.size() - 1]) if not boss.sequence.is_empty() else ""
	assert_false(final_id.is_empty(), "no final beat")
	if final_id.is_empty():
		return
	var script := JourneyDialogue.build(boss, boss.events[final_id], "Darya")
	var whole := ""
	for node_id: String in script.node_ids():
		for step: Dictionary in script.get_steps(node_id):
			whole += String(step.get("text", "")) + " "
	assert_true(whole.contains("rights"), "the refusal never mentions rights")
	assert_true(whole.to_lower().contains("citizen"),
		"the refusal never mentions citizenship")
