extends TestCase
## Officer Choi's escalation, played through the real runner.
##
## The encounter's cruelty is a mechanic, not just prose: `choi_strikes` counts
## every answer that is not submission, and for the men the second one is the
## door. All of that is expressed as conditions on choice options
## (`choi_strikes < 1` / `choi_strikes >= 1`), which nothing else in the suite
## covers for journey content - test_dialogue_runner.gd proves the mechanism
## for hand-written .dlg files only.
##
## THE FAILURE THIS EXISTS TO CATCH. A condition naming a variable that is not
## declared in GameState.DEFAULTS cannot be parsed, so it evaluates to the
## `false` fallback - and a false condition HIDES an option rather than showing
## it. Delete "choi_strikes" from DEFAULTS and the escalation does not error, it
## silently disappears, and the scenes still play as though nothing were wrong.
## A build stays green while the content quietly stops existing. Hence
## test_the_gated_option_is_actually_offered, which asserts the visible symptom
## rather than the cause.

var _choices: Array = []


func before_each() -> void:
	GameState.reset()
	Dialogue.stop()
	_choices = []
	Dialogue.choices_offered.connect(_on_choices)


func after_each() -> void:
	Dialogue.stop()
	if Dialogue.choices_offered.is_connected(_on_choices):
		Dialogue.choices_offered.disconnect(_on_choices)


func _on_choices(options: Array) -> void:
	_choices = options


func _script_for(run_id: String, slug: String) -> DialogueScript:
	var run := JourneyData.load_run(run_id)
	assert_true(run.ok, "%s failed to load" % run_id)
	assert_has(run.events, slug, "%s has no event '%s'" % [run_id, slug])
	var script := JourneyDialogue.build(run, run.events[slug], "Kaveh", "Kaveh")
	assert_empty(script.errors, "%s/%s should build cleanly" % [run_id, slug])
	return script


## Plays a scene from [param entry], taking the first option whose text contains
## [param want], then answering with the last option every time after that. The
## last option is always the submissive one ("I say nothing, and sit down"), so
## the scene terminates instead of circling the menu.
func _play_from(script: DialogueScript, entry: String, want: String) -> void:
	Dialogue.start_script(script, entry)
	var taken := false
	var guard := 300
	while Dialogue.is_active and guard > 0:
		guard -= 1
		if _choices.is_empty():
			Dialogue.advance()
			continue

		var pick := -1
		if not taken:
			for option: Dictionary in _choices:
				if String(option["text"]).contains(want):
					pick = int(option["index"])
					break
			assert_true(pick >= 0, "no option matching '%s' was offered" % want)
			taken = true
		if pick < 0:
			pick = int(_choices[_choices.size() - 1]["index"])

		_choices = []
		Dialogue.choose(pick)

	assert_true(guard > 0, "the scene never finished")
	assert_true(taken, "the option matching '%s' was never reached" % want)


# --- the variables the whole mechanic rests on -------------------------------

func test_strike_variables_are_declared_in_defaults() -> void:
	# Not pedantry: see the note at the top. Undeclared means invisible.
	assert_has(GameState.DEFAULTS, "choi_strikes",
		"choi_strikes must be declared or every gated option vanishes")
	assert_has(GameState.DEFAULTS, "choi_ejected",
		"choi_ejected must be declared")


func test_the_gated_option_is_actually_offered() -> void:
	var script := _script_for("choi_iran", "choi-iran-the-second-room")
	Dialogue.start_script(script, "menu")
	assert_false(_choices.is_empty(), "no options were offered at all")

	var texts := ""
	for option: Dictionary in _choices:
		texts += String(option["text"]) + " | "
	assert_true(texts.contains("I ask how long"),
		"the gated option did not survive condition evaluation: %s" % texts)


# --- the men: two strikes and the door ---------------------------------------

func test_a_first_question_warns_but_does_not_eject() -> void:
	var script := _script_for("choi_iran", "choi-iran-the-second-room")
	_play_from(script, "menu", "I ask how long")
	assert_false(bool(GameState.get_var("choi_ejected", false)),
		"a first question must not end the encounter")
	assert_eq(int(GameState.get_var("choi_strikes", 0)), 1,
		"the warning must cost exactly one strike")


func test_a_second_question_reaches_the_door() -> void:
	GameState.set_var("choi_strikes", 2)
	var script := _script_for("choi_iran", "choi-iran-the-second-room")
	_play_from(script, "menu", "I ask how long")
	assert_true(bool(GameState.get_var("choi_ejected", false)),
		"asking again after a warning must eject")
	assert_true(bool(GameState.get_var("journey_ended", false)),
		"an ejection must end the life, not just the scene")


func test_asking_for_your_documents_back_ejects_without_warning() -> void:
	var script := _script_for("choi_palestine", "choi-palestine-the-second-room")
	_play_from(script, "menu", "document back")
	assert_true(bool(GameState.get_var("choi_ejected", false)),
		"asking for the document back is ejection on the first offence")


# --- the woman: the same questions, and no door ------------------------------

func test_she_is_never_ejected() -> void:
	var script := _script_for("choi_nigeria", "choi-nigeria-the-second-room")
	_play_from(script, "menu", "I ask how long")
	assert_false(bool(GameState.get_var("choi_ejected", false)),
		"the Nigerian encounter has no door - she is kept, not thrown out")


func test_her_scene_still_terminates() -> void:
	# It used to loop for ever, losing a dignity point per lap, because she
	# cannot be ejected and nothing else stopped the menu re-offering itself.
	var script := _script_for("choi_nigeria", "choi-nigeria-the-second-room")
	_play_from(script, "menu", "call the hospital")
	assert_false(Dialogue.is_active, "the scene should have ended")


# --- the control case --------------------------------------------------------

func test_the_us_citizen_is_never_given_a_strike() -> void:
	# The whole point of that run is that none of this applies to him.
	var run := JourneyData.load_run("choi_usa")
	assert_true(run.ok, "choi_usa failed to load")
	for slug: String in run.events:
		var event: Dictionary = run.events[slug]
		var nodes: Dictionary = event.get("nodes", {})
		for node_name: String in nodes:
			for step: Dictionary in nodes[node_name]:
				assert_ne(String(step.get("name", "")), "choi_strikes",
					"%s sets a strike; the citizen run must not" % slug)


# --- every way out of the encounter says so -----------------------------------

func test_every_terminal_path_carries_an_ending_card() -> void:
	# A run can end at the refusal or at any ejection, and all of them must say
	# so. Nothing else enforces this: add an ending later and it would ship
	# silent, dropping the player back to the menu with no word at all - which
	# is exactly what it looked like before these were added.
	var runs := ["choi", "choi_iran", "choi_palestine",
		"choi_nigeria", "choi_mexico", "choi_usa"]
	for run_id: String in runs:
		var run := JourneyData.load_run(run_id)
		assert_true(run.ok, "%s failed to load" % run_id)

		# The citizen's run is the exception, and the difference between the two
		# strings is the whole argument of the game.
		var want := "MISSION ACCOMPLISHED." if run_id == "choi_usa" \
			else "THE END. GAME OVER. YOU FAILED."

		var endings := 0
		for slug: String in run.events:
			var nodes: Dictionary = run.events[slug].get("nodes", {})
			for node_name: String in nodes:
				var steps: Array = nodes[node_name]
				var terminal := false
				for step: Dictionary in steps:
					if int(step.get("k", -1)) == JourneyData.STEP_SET \
							and String(step.get("name", "")) == "journey_ended":
						terminal = true
				if not terminal:
					continue
				endings += 1
				var carded := false
				for step: Dictionary in steps:
					if String(step.get("text", "")).contains(want):
						carded = true
				assert_true(carded, "%s/%s/%s ends the run without saying so"
					% [run_id, slug, node_name])
		assert_true(endings > 0, "%s has no terminal node at all" % run_id)


# --- the cheat word, which has to show what it claims to show ----------------

func test_the_cheat_reveals_options_the_condition_would_hide() -> void:
	# `papers` is meant to open everything, which has to include branches you
	# have not earned - otherwise whole scenes can only be read by replaying
	# the encounter with different answers.
	GameState.set_var("cheat_unlock_all", true)
	var script := _script_for("choi_iran", "choi-iran-the-second-room")
	Dialogue.start_script(script, "menu")

	var texts := ""
	for option: Dictionary in _choices:
		texts += String(option["text"]) + " | "
	assert_true(texts.contains("[locked]"),
		"with the cheat on, an option whose condition is false must still be "
		+ "offered and marked: %s" % texts)


func test_a_shipped_game_never_shows_a_locked_option() -> void:
	# The other half, and the one that matters: the reveal must be inert
	# whenever the flag is off, or every player sees the scaffolding.
	var script := _script_for("choi_iran", "choi-iran-the-second-room")
	Dialogue.start_script(script, "menu")
	for option: Dictionary in _choices:
		assert_false(String(option["text"]).begins_with("[locked]"),
			"a locked option leaked into normal play: %s" % String(option["text"]))
		assert_false(bool(option.get("locked", false)),
			"an option was flagged locked with the cheat off")
