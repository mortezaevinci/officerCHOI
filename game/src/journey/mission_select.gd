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

## Typed on this screen to unlock every mission. A word rather than a button:
## a visible "unlock all" would read as the game shipping with its own
## difficulty switch, and could be pressed by somebody who did not mean to.
const CHEAT_CODE := "papers"

var _run: JourneyData
var _season: JourneySeason
## What has been typed so far, trimmed to the length of the code.
var _typed: String = ""


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

	# Set by typing CHEAT_CODE on this screen. Deliberately a separate flag
	# rather than raising `mission`: progress stays exactly where it was, so
	# turning the cheat off leaves the season honest, and the counter above
	# still reports what was actually played.
	var cheat := bool(GameState.get_var("cheat_unlock_all", false))
	if cheat:
		_subtitle.text += "    [all unlocked]"

	var focus_me: Button = null
	for i: int in _season.missions.size():
		var unlocked := cheat or i <= done
		var finished := i < done

		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 64)
		button.focus_mode = Control.FOCUS_ALL
		button.disabled = not unlocked
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		# The name is always shown, locked or not. Hiding it made the season a
		# column of "locked" with nothing to look forward to; the disabled state
		# already says you cannot play it yet.
		var headline := _season.headline(_season.missions[i])
		button.text = "%d. %s%s" % [i + 1, headline, "  (done)" if finished else ""]

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
	boss.disabled = not cheat and done < _season.total()
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


## Watches for the cheat word being typed. Letters only, so the buffer cannot
## be filled by arrow keys or Enter while moving around the list.
##
## `_unhandled_input` rather than `_input`: the buttons see their own keys
## first, so typing here never steals a press from the focused control.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	var typed := String.chr(key.unicode).to_lower()
	if typed.length() != 1 or typed < "a" or typed > "z":
		return

	_typed += typed
	if _typed.length() > CHEAT_CODE.length():
		_typed = _typed.substr(_typed.length() - CHEAT_CODE.length())
	if _typed == CHEAT_CODE:
		_typed = ""
		_toggle_cheat()


## Flips the unlock flag and rebuilds the screen, because the buttons were
## built in [method _ready] against the previous value. A toggle rather than a
## one-way switch, so the season can be put back the way it was.
func _toggle_cheat() -> void:
	var on := not bool(GameState.get_var("cheat_unlock_all", false))
	GameState.set_var("cheat_unlock_all", on)
	print("cheat: missions %s" % ("all unlocked" if on else "locked again"))
	SceneFlow.goto(GamePaths.MISSION_SELECT)
