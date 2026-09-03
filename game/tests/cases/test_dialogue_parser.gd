extends TestCase
## The parser is the piece every conversation depends on, so it gets the most
## attention. Each test is a small `.dlg` snippet parsed in memory.


func test_speaker_lines_split_name_mood_and_text() -> void:
	var script := DialogueParser.parse_text("""
:: start
Ward: Choi. You're on tonight.
Choi @tired: Every night.
""")
	assert_empty(script.errors, "clean source should not produce errors")
	var steps: Array = script.get_steps("start")
	assert_eq(steps.size(), 2)
	assert_eq(steps[0]["speaker"], "Ward")
	assert_eq(steps[0]["text"], "Choi. You're on tonight.")
	assert_eq(steps[1]["speaker"], "Choi")
	assert_eq(steps[1]["mood"], "tired")


func test_narration_has_no_speaker() -> void:
	var script := DialogueParser.parse_text("""
:: start
> The chair is new. The file is not.
The lamp buzzes.
""")
	var steps: Array = script.get_steps("start")
	assert_eq(steps.size(), 2)
	assert_eq(steps[0]["speaker"], "", "a '>' line is narration")
	assert_eq(steps[0]["text"], "The chair is new. The file is not.")
	assert_eq(steps[1]["speaker"], "", "a bare line is narration too")


func test_a_colon_inside_a_sentence_is_not_a_speaker() -> void:
	var script := DialogueParser.parse_text("""
:: start
It was late: later than the log admitted.
""")
	var steps: Array = script.get_steps("start")
	assert_eq(steps[0]["speaker"], "")
	assert_eq(steps[0]["text"], "It was late: later than the log admitted.")


func test_consecutive_options_become_one_choice_step() -> void:
	var script := DialogueParser.parse_text("""
:: start
+ [Open the file] -> open_file
+ [Leave it] if has_badge -> leave_it

:: open_file
end

:: leave_it
end
""")
	assert_empty(script.errors)
	var steps: Array = script.get_steps("start")
	assert_eq(steps.size(), 1, "two '+' lines are a single choice step")
	assert_eq(steps[0]["kind"], DialogueScript.CHOICES)
	var options: Array = steps[0]["options"]
	assert_eq(options.size(), 2)
	assert_eq(options[0]["text"], "Open the file")
	assert_eq(options[0]["condition"], "")
	assert_eq(options[1]["condition"], "has_badge")
	assert_eq(options[1]["target"], "leave_it")


func test_set_branch_command_and_end() -> void:
	var script := DialogueParser.parse_text("""
:: start
set trust_ward += 1
set told_truth = true
if trust_ward >= 2 -> trusted
@music tense
@portrait right ward "very angry"
end

:: trusted
end
""")
	assert_empty(script.errors)
	var steps: Array = script.get_steps("start")
	assert_eq(steps[0]["kind"], DialogueScript.SET)
	assert_eq(steps[0]["name"], "trust_ward")
	assert_eq(steps[0]["op"], "+=")
	assert_eq(steps[0]["expr"], "1")
	assert_eq(steps[1]["expr"], "true")
	assert_eq(steps[2]["kind"], DialogueScript.BRANCH)
	assert_eq(steps[2]["condition"], "trust_ward >= 2")
	assert_eq(steps[3]["kind"], DialogueScript.COMMAND)
	assert_eq(steps[3]["name"], "music")
	assert_eq(Array(steps[4]["args"]), ["right", "ward", "very angry"],
		"quoted argument stays one argument")
	assert_eq(steps[5]["kind"], DialogueScript.END)


func test_first_node_becomes_the_entry_point() -> void:
	var script := DialogueParser.parse_text("""
:: opening
-> second

:: second
end
""")
	assert_eq(script.entry, "opening")


func test_a_jump_to_a_missing_node_is_an_error() -> void:
	var script := DialogueParser.parse_text("""
:: start
-> typo_here
""")
	assert_false(script.errors.is_empty(), "dangling targets must be reported")
	assert_eq(script.dangling_targets().size(), 1)


func test_end_is_a_legal_jump_target() -> void:
	var script := DialogueParser.parse_text("""
:: start
+ [Walk away] -> end
""")
	assert_empty(script.errors, "'end' is reserved, not a missing node")


func test_content_before_a_node_label_is_reported() -> void:
	var script := DialogueParser.parse_text("Ward: floating line\n:: start\nend\n")
	assert_false(script.errors.is_empty())


func test_comments_and_blank_lines_are_ignored() -> void:
	var script := DialogueParser.parse_text("""
# a note to the writer

:: start
# another note
Ward: Only this survives.
""")
	assert_eq(script.get_steps("start").size(), 1)
