extends Control
## The ten missions of a season, unlocking one at a time, and then Choi.
##
## This is the spine of the game the player actually touches: a short list of
## short missions, where finishing one opens the next. A mission is a good event
## and the consequence of having chosen it, so the titles here name the good
## half only - what it costs is the part you find out by playing it.
##
## Progress is `mission` in [GameState]: the number finished. Mission n is
## unlocked when n <= mission, which makes the counter and the gate the same
## number and means there is nothing separate to keep in step.

@onready var _rows: VBoxContainer = $Center/Rows
@onready var _title: Label = $Center/Rows/Title
@onready var _subtitle: Label = $Center/Rows/Subtitle
@onready var _list: VBoxContainer = $Center/Rows/Scroll/List
@onready var _back: Button = $Center/Rows/Back

var _run: JourneyData
var _season: JourneySeason


func _ready() -> void:
	var run_id := String(GameState.get_var("journey_run", GamePaths.DEFAULT_RUN))
	_run = JourneyData.load_run(run_id)
	if not _run.ok:
		push_error("journey '%s' failed to load:\n  %s"
			% [run_id, "\n  ".join(_run.errors)])
		if not GameState.testing:
			SceneFlow.goto(GamePaths.DIFFICULTY_SELECT)
		return

	var season_number := int(GameState.get_var("season", 1))
	_season = JourneySeason.assemble(_run, season_number)

	var done := clampi(int(GameState.get_var("mission", 0)), 0, _season.total())
	_title.text = "Season %d" % season_number
	var who := String(GameState.get_var("player_name", ""))
	var counted := "%d of %d" % [done, _season.total()]
	_subtitle.text = "%s - %s" % [who, counted] if not who.is_empty() else counted

	var focus_me: Button = null
	for i: int in _season.missions.size():
		var unlocked := i <= done
		var finished := i < done

		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 64)
		button.focus_mode = Control.FOCUS_ALL
		button.disabled = not unlocked
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		var headline := _season.headline(_season.missions[i])
		if finished:
			button.text = "%d. %s  (done)" % [i + 1, headline]
		elif unlocked:
			button.text = "%d. %s" % [i + 1, headline]
		else:
			button.text = "%d. locked" % [i + 1]

		if unlocked:
			button.pressed.connect(_on_mission.bind(i))
			if focus_me == null and not finished:
				focus_me = button
		_list.add_child(button)

	# The boss opens only when the whole season is behind you. It sits outside
	# the scrolling list, because inside it the tenth mission pushed it below
	# the fold and the thing the whole season leads to was invisible.
	var boss := Button.new()
	boss.custom_minimum_size = Vector2(0, 72)
	boss.focus_mode = Control.FOCUS_ALL
	boss.disabled = done < _season.total()
	boss.text = "Toronto Pearson - locked" if boss.disabled else "Toronto Pearson"
	if not boss.disabled:
		boss.pressed.connect(_on_boss)
		focus_me = boss
	_rows.add_child(boss)
	_rows.move_child(boss, _back.get_index())

	_back.pressed.connect(_on_back)
	(focus_me if focus_me != null else _back).grab_focus()


func _on_mission(index: int) -> void:
	SceneFlow.goto(GamePaths.JOURNEY_VIEW, "", {"mission": index})


func _on_boss() -> void:
	SceneFlow.goto(GamePaths.JOURNEY_VIEW, "", {"boss": true})


func _on_back() -> void:
	SceneFlow.goto(GamePaths.MAIN_MENU)
