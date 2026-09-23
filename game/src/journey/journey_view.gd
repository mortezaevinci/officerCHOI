class_name JourneyView
extends Control
## Plays one life: ten missions, then Officer Choi.
##
## A mission is two beats - **you choose something good, and the consequence of
## having chosen it arrives.** The pairing is not arbitrary: the only hurdles
## reachable from a good event are the ones its own triggers justify, so the bad
## thing always follows from the good thing rather than merely after it.
##
## This scene owns the order of events and nothing else. The conversation is
## played by the `Dialogue` autoload, the box draws itself, and the graph decides
## what can follow what. All that happens here is: pick, play, wait, pick again.
##
## The season number is the only progress worth saving. A season's itinerary is
## derived from it, so a save is a couple of integers rather than a list of
## every node visited.

## Phases of a single mission, in order.
enum Phase { GOOD, BAD, BOSS, DONE }

@onready var _background: TextureRect = $Background
@onready var _progress: Label = $Progress
@onready var _speaker: PortraitSlot = $UI/Speaker
@onready var _player_slot: PortraitSlot = $UI/Player

var _run: JourneyData
var _boss: JourneyData
var _season: JourneySeason
var _phase: Phase = Phase.GOOD
var _boss_step: int = 0
var _boss_order: Array[String] = []
var _started: bool = false
## Which mission of the season this scene was opened to play, and whether it was
## opened for the boss instead. Set from the payload by [method scene_configure].
var _mission_index: int = -1
var _is_boss: bool = false


func _ready() -> void:
	var run_id := String(GameState.get_var("journey_run", GamePaths.DEFAULT_RUN))
	_run = JourneyData.load_run(run_id)
	if not _run.ok:
		push_error("journey '%s' failed to load:\n  %s"
			% [run_id, "\n  ".join(_run.errors)])
		if not GameState.testing:
			SceneFlow.goto(GamePaths.MAIN_MENU)
		return

	# The run's people are named inside its own document rather than in
	# characters.json, so that the nationalities stay independent. Announce them
	# so the dialogue box prints "Farideh" rather than "farideh".
	CharacterDb.register_cast(_run.cast)

	# The player's own face, for the whole run. Five were built per
	# nationality and nothing displayed them: this slot only ever showed the
	# current speaker, and narration cleared even that.
	if _player_slot != null:
		_player_slot.set_character("player_%s" % run_id)
		_player_slot.set_speaking(false)

	_season = JourneySeason.assemble(_run, int(GameState.get_var("season", 1)))
	_season.restore({"index": int(GameState.get_var("mission", 0))})

	Dialogue.line_shown.connect(_on_line_shown)
	Dialogue.command_issued.connect(_on_command)
	Dialogue.finished.connect(_on_finished)
	Dialogue.cancelled.connect(_on_finished)

	# A frame, so the fade has begun before the first line lands.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	# test_scenes.gd instantiates every scene with no setup. This one would
	# otherwise start a whole life, and a failed load would change the scene out
	# from under the running test.
	if GameState.testing:
		return
	_started = true

	if _is_boss:
		_begin_boss()
		return
	# Opened for one mission. Anything else is a bug in whoever pushed us here,
	# but resuming at the player's progress is better than a blank screen.
	if _mission_index < 0:
		_mission_index = clampi(int(GameState.get_var("mission", 0)),
			0, maxi(0, _season.total() - 1))
	_season.index = _mission_index
	_advance_to_next_beat()


## Arguments from [method SceneFlow.goto], delivered before this enters the tree.
## The mission select opens this scene for one mission at a time, or for the
## boss once the whole season is behind the player.
func scene_configure(payload: Dictionary) -> void:
	if payload.has("run"):
		GameState.set_var("journey_run", String(payload["run"]))
	if payload.has("mission"):
		_mission_index = int(payload["mission"])
	_is_boss = bool(payload.get("boss", false))


# --- the spine ---------------------------------------------------------------

func _advance_to_next_beat() -> void:
	if _season.is_finished():
		_begin_boss()
		return

	var mission := _season.current()
	if mission.is_empty():
		_begin_boss()
		return

	match _phase:
		Phase.GOOD:
			_show_progress("Mission %d of %d" % [_season.mission_number(), _season.total()])
			_play_node(_run, int(mission["good"]))
		Phase.BAD:
			_play_node(_run, int(mission["bad"]))
		_:
			_begin_boss()


func _on_finished(_script_id: String) -> void:
	if not _started:
		return
	match _phase:
		Phase.GOOD:
			# The good thing happened. Now the price of it.
			_phase = Phase.BAD
			_advance_to_next_beat()
		Phase.BAD:
			# The mission is over. Unlock the next one and go back to the list
			# rather than running ten missions together - the brief asks for
			# short missions that each unlock the next, and returning somewhere
			# is what makes finishing one feel like finishing something.
			_phase = Phase.GOOD
			var done := int(GameState.get_var("mission", 0))
			GameState.set_var("mission", maxi(done, _mission_index + 1))
			SceneFlow.goto(GamePaths.MISSION_SELECT)
		Phase.BOSS:
			# Choi can end the encounter early. Asking him a second question as
			# though you were entitled to an answer gets you ejected, and an
			# ejection ends the life then and there. Without this the remaining
			# beats would play anyway - "THE DOOR IS THAT WAY. GOODBYE." and
			# then, cheerfully, two more scenes with the man who just said it.
			if bool(GameState.get_var("choi_ejected", false)):
				_finish_life()
				return
			_boss_step += 1
			if _boss_step < _boss_order.size():
				_play_event(_boss, _boss_order[_boss_step])
			else:
				_finish_life()
		Phase.DONE:
			pass


# --- playing one beat --------------------------------------------------------

## Plays whatever is attached to a node: the authored conversation if it has
## one, and a generated beat from the dataset's own summary if it does not.
## Most of the 1,074 nodes have no authored event, which is what lets a second
## season be a different life rather than the same one again.
func _play_node(source: JourneyData, node_index: int) -> void:
	var event := source.event_for(node_index)
	var script: DialogueScript
	if event.is_empty():
		script = JourneyDialogue.build_stub(source, node_index)
		_set_backdrop(source, _fallback_scene(source, node_index))
	else:
		script = JourneyDialogue.build(source, event, _player_name(), _document_name())
		_set_backdrop(source, String(event.get("scene", "")))

	if not script.errors.is_empty():
		push_error("journey beat %s:\n  %s" % [script.id, "\n  ".join(script.errors)])
		_on_finished(script.id)
		return
	Dialogue.start_script(script)


func _play_event(source: JourneyData, event_id: String) -> void:
	var event: Dictionary = source.events.get(event_id, {})
	if event.is_empty():
		_on_finished(event_id)
		return
	_set_backdrop(source, String(event.get("scene", "")))
	Dialogue.start_script(JourneyDialogue.build(source, event, _player_name(), _document_name()))


# --- the boss ----------------------------------------------------------------

func _begin_boss() -> void:
	if _phase == Phase.BOSS:
		return
	_phase = Phase.BOSS
	_boss_step = 0

	# Every encounter starts you at zero with him, and must: these persist in
	# GameState, and _finish_life() does not clear them. Without this an
	# ejection in one life would still be set at the start of the next, and the
	# check in _on_finished would end that encounter after its first scene.
	GameState.set_var("choi_strikes", 0)
	GameState.set_var("choi_ejected", false)

	var boss_id := JourneySeason.boss_run_for(
		String(GameState.get_var("journey_run", GamePaths.DEFAULT_RUN)))
	_boss = JourneyData.load_run(boss_id)
	if not _boss.ok:
		push_error("boss run failed to load:\n  %s" % "\n  ".join(_boss.errors))
		_finish_life()
		return
	CharacterDb.register_cast(_boss.cast)

	# The encounter is a written sequence, not a shuffle. Authored order is the
	# order of the chain edges in the boss document.
	_boss_order = _boss_sequence()
	if _boss_order.is_empty():
		_finish_life()
		return

	_show_progress("Toronto Pearson")
	_play_event(_boss, _boss_order[0])


## The boss beats in authored order, which the document states outright.
##
## An earlier version tried to recover the order by walking the cascade edges
## from "the node nothing leads to". That does not work: the escalation ladder
## gives almost every abuse node an incoming edge, so there is no head to find,
## and it silently fell through to dictionary iteration order - right only by
## accident. The document carries `sequence` for exactly this reason.
func _boss_sequence() -> Array[String]:
	var ordered: Array[String] = []
	for entry: Variant in _boss.sequence:
		var event_id := String(entry)
		if _boss.events.has(event_id):
			ordered.append(event_id)
	if not ordered.is_empty():
		return ordered

	# No stated sequence (an older document): take what is there rather than
	# playing nothing at all.
	for event_id: String in _boss.events:
		ordered.append(event_id)
	return ordered


func _finish_life() -> void:
	_phase = Phase.DONE
	GameState.set_var("journey_ended", true)
	# A new life is a new season, with missions drawn from parts of the graph
	# this one did not touch.
	GameState.set_var("season", int(GameState.get_var("season", 1)) + 1)
	GameState.set_var("mission", 0)
	_show_progress("")
	SceneFlow.goto(GamePaths.MAIN_MENU)


## Shows whoever is speaking. Narration has no speaker, so the slot empties
## rather than leaving the last face staring through an unrelated line.
func _on_line_shown(speaker: String, mood: String, _text: String) -> void:
	if _speaker == null:
		return
	if speaker.is_empty():
		_speaker.set_character("")
		if _player_slot != null:
			_player_slot.set_speaking(true)
		return
	_speaker.set_character(speaker, mood)
	_speaker.set_speaking(true)
	if _player_slot != null:
		_player_slot.set_speaking(false)


# --- presentation ------------------------------------------------------------

func _on_command(command: String, args: PackedStringArray) -> void:
	match command:
		"scene":
			if args.size() > 0:
				var source := _boss if _phase == Phase.BOSS else _run
				_set_backdrop(source, args[0])
		"music":
			AudioDirector.play_music(args[0] if args.size() > 0 else "none")
		"sfx":
			if args.size() > 0:
				AudioDirector.play_sfx(args[0])


func _set_backdrop(source: JourneyData, scene_id: String) -> void:
	if scene_id.is_empty() or _background == null:
		return
	var path := source.art_path(scene_id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	_background.texture = load(path)


## A node with no authored event still needs somewhere to stand. Reuse whatever
## backdrop is already up rather than cutting to black.
func _fallback_scene(_source: JourneyData, _node_index: int) -> String:
	return ""


func _show_progress(text: String) -> void:
	if _progress == null:
		return
	_progress.text = text
	_progress.visible = not text.is_empty()


func _player_name() -> String:
	return String(GameState.get_var("player_name", ""))


## The spelling the paperwork has. Set when the registry clerk gets it wrong,
## and used by every official from then on.
func _document_name() -> String:
	return String(GameState.get_var("document_name", ""))
