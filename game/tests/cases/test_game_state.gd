extends TestCase
## Story variables, and the save round-trip that has to survive them.


func before_each() -> void:
	GameState.reset()


func test_unknown_variables_read_as_false() -> void:
	assert_eq(GameState.get_var("never_set"), false)
	assert_false(GameState.has_flag("never_set"))


func test_add_var_keeps_whole_numbers_whole() -> void:
	GameState.add_var("trust_ward", 1)
	GameState.add_var("trust_ward", 2)
	assert_eq(GameState.get_var("trust_ward"), 3)
	assert_true(typeof(GameState.get_var("trust_ward")) == TYPE_INT)


func test_reset_restores_the_defaults() -> void:
	GameState.set_var("chapter", 4)
	GameState.reset()
	assert_eq(GameState.get_var("chapter"), GameState.DEFAULTS["chapter"])


func test_round_trip_through_a_dictionary() -> void:
	GameState.set_var("trust_ward", 2)
	GameState.mark_visited("desk_ward", "confrontation")
	GameState.current_scene = "res://scenes/rooms/precinct.tscn"
	var snapshot := GameState.to_dict()

	GameState.reset()
	assert_eq(GameState.get_var("trust_ward"), 0)

	GameState.from_dict(snapshot)
	assert_eq(GameState.get_var("trust_ward"), 2)
	assert_true(GameState.was_visited("desk_ward", "confrontation"))
	assert_eq(GameState.current_scene, "res://scenes/rooms/precinct.tscn")


func test_loading_an_old_save_still_gets_new_defaults() -> void:
	# A save written before a variable existed must not leave it undefined.
	GameState.from_dict({"vars": {"trust_ward": 1}})
	assert_eq(GameState.get_var("trust_ward"), 1)
	assert_eq(GameState.get_var("chapter"), GameState.DEFAULTS["chapter"],
		"variables missing from the save fall back to their default")


func test_save_and_load_a_slot() -> void:
	var slot := SaveGame.MANUAL_SLOTS  # last slot, kept for tests
	GameState.set_var("trust_ward", 2)
	assert_true(SaveGame.save_to_slot(slot, "res://scenes/rooms/precinct.tscn", "desk"))

	GameState.reset()
	assert_true(SaveGame.load_from_slot(slot))
	assert_eq(GameState.get_var("trust_ward"), 2)
	assert_eq(GameState.current_spawn, "desk")

	SaveGame.delete_slot(slot)
	assert_false(SaveGame.has_save(slot))


func test_expression_truthiness_matches_has_flag() -> void:
	for value: Variant in [true, false, 0, 1, "", "x", null]:
		GameState.set_var("probe", value)
		assert_eq(DialogueExpression.truthy(value), GameState.has_flag("probe"),
			"truthiness of %s must agree between conditions and has_flag" % [value])
