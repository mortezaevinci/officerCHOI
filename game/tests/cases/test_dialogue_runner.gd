extends TestCase
## Plays whole conversations through the `Dialogue` autoload and checks where
## they end up - the branching, the counters, the flags.

var _lines: Array = []
var _choices: Array = []


func before_each() -> void:
	GameState.reset()
	Dialogue.stop()
	_lines = []
	_choices = []
	Dialogue.line_shown.connect(_on_line)
	Dialogue.choices_offered.connect(_on_choices)


func after_each() -> void:
	Dialogue.stop()
	if Dialogue.line_shown.is_connected(_on_line):
		Dialogue.line_shown.disconnect(_on_line)
	if Dialogue.choices_offered.is_connected(_on_choices):
		Dialogue.choices_offered.disconnect(_on_choices)


func _on_line(speaker: String, _mood: String, text: String) -> void:
	_lines.append({"speaker": speaker, "text": text})


func _on_choices(options: Array) -> void:
	_choices = options


## Plays a script to the end, taking [param picks] in order whenever a choice
## comes up (and the first option once the list runs out).
func _play(source: String, picks: Array = []) -> void:
	var script := DialogueParser.parse_text(source, "test")
	assert_empty(script.errors, "test fixture should parse cleanly")
	Dialogue.start_script(script)

	var pick_index := 0
	var guard := 200
	while Dialogue.is_active and guard > 0:
		guard -= 1
		if not _choices.is_empty():
			var pick: int = picks[pick_index] if pick_index < picks.size() else 0
			pick_index += 1
			_choices = []
			Dialogue.choose(pick)
		else:
			Dialogue.advance()
	assert_true(guard > 0, "conversation did not finish")


func test_lines_arrive_in_order() -> void:
	_play("""
:: start
Ward: One.
Choi: Two.
> Three.
""")
	assert_eq(_lines.size(), 3)
	assert_eq(_lines[0]["text"], "One.")
	assert_eq(_lines[2]["speaker"], "")


func test_choosing_follows_the_option_target() -> void:
	_play("""
:: start
+ [Left] -> left
+ [Right] -> right

:: left
Choi: Went left.
end

:: right
Choi: Went right.
end
""", [1])
	assert_eq(_lines.size(), 1)
	assert_eq(_lines[0]["text"], "Went right.")


func test_options_are_hidden_when_their_condition_is_false() -> void:
	GameState.set_var("has_badge", false)
	_play("""
:: start
+ [Show the badge] if has_badge -> badge
+ [Say nothing] -> quiet

:: badge
Choi: Badge.
end

:: quiet
Choi: Nothing.
end
""")
	assert_eq(_lines[0]["text"], "Nothing.", "the badge option should not be offered")


func test_set_writes_through_to_game_state() -> void:
	_play("""
:: start
set trust_ward += 2
set told_truth = true
set suspicion = 1 + 2
end
""")
	assert_eq(GameState.get_var("trust_ward"), 2)
	assert_eq(GameState.get_var("told_truth"), true)
	assert_eq(GameState.get_var("suspicion"), 3, "right-hand side is a full expression")


func test_branch_takes_the_jump_only_when_true() -> void:
	GameState.set_var("trust_ward", 3)
	_play("""
:: start
if trust_ward >= 2 -> trusted
Choi: Not trusted.
end

:: trusted
Choi: Trusted.
end
""")
	assert_eq(_lines[0]["text"], "Trusted.")


func test_accumulated_state_decides_the_ending() -> void:
	# The pattern the real scripts use: several choices nudge a counter, and a
	# single branch at the end reads it.
	_play("""
:: start
+ [Press him] -> press
+ [Let it go] -> soft

:: press
set suspicion += 2
-> weigh

:: soft
set trust_ward += 2
-> weigh

:: weigh
if suspicion >= 2 -> cold
if trust_ward >= 2 -> warm
Choi: Neither.
end

:: cold
Choi: Cold ending.
end

:: warm
Choi: Warm ending.
end
""", [1])
	assert_eq(_lines[0]["text"], "Warm ending.")


func test_text_interpolates_story_variables() -> void:
	GameState.set_var("trust_ward", 2)
	_play("""
:: start
Ward: You are at {trust_ward}.
""")
	assert_eq(_lines[0]["text"], "You are at 2.")


func test_visited_nodes_are_recorded() -> void:
	_play("""
:: start
Choi: Here.
end
""")
	assert_true(GameState.was_visited("test", "start"))


func test_a_loop_with_no_lines_does_not_hang() -> void:
	var script := DialogueParser.parse_text("""
:: start
-> start
""", "loop")
	Dialogue.start_script(script)
	assert_false(Dialogue.is_active, "the runner must bail out of a dialogue-free loop")
