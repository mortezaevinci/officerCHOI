extends Node
## Autoload `Dialogue`: plays a [DialogueScript] and tells the UI what to show.
##
## The runner owns *what* is said and *what happens to the story*; it knows
## nothing about boxes, portraits or fonts. Any UI that connects to the signals
## below and calls [method advance] / [method choose] can present a conversation
## - the dialogue box in a room and the desk close-up both do exactly that.
##
##     Dialogue.start("res://content/dialogue/en/precinct_intro.dlg")
##     await Dialogue.finished

## A conversation began.
signal started(script_id: String)
## Show this line, then call [method advance] when the player is ready.
signal line_shown(speaker: String, mood: String, text: String)
## Offer these options, then call [method choose] with the index picked.
## Each option is `{"text": String, "index": int}`; hidden options are already
## filtered out, and `index` is the index to pass back.
signal choices_offered(options: Array)
## A `@command` line the scene should act on (music, camera, animation...).
signal command_issued(name: String, args: PackedStringArray)
## The conversation ran to its end.
signal finished(script_id: String)
## The conversation was stopped early by [method stop].
signal cancelled(script_id: String)

## Guards against a writer accidentally creating a loop with no dialogue in it.
const MAX_STEPS_PER_RESUME := 2000

## True while a conversation is running (used to lock out player movement).
var is_active: bool = false
## The script currently playing, or null.
var current: DialogueScript = null
## Every line shown this conversation, for a backlog / history view.
var history: Array[Dictionary] = []

var _node_id: String = ""
var _step: int = 0
var _options: Array = []      # options as offered, so `choose` can map indices
var _waiting: bool = false    # blocked on the player (a line or a choice)
var _cache: Dictionary = {}   # path -> DialogueScript


## Starts a conversation. [param path] is a `res://` path to a `.dlg` file;
## [param entry] defaults to the script's first node.
## Returns false if the script could not be played (and pushes the reason).
func start(path: String, entry: String = "") -> bool:
	var script := load_script(path)
	if script == null:
		return false
	return start_script(script, entry)


## Starts an already-parsed script. Useful for tests and for generated content.
func start_script(script: DialogueScript, entry: String = "") -> bool:
	if is_active:
		push_warning("Dialogue.start while '%s' is still running - stopping it first"
			% current.id)
		stop()

	var first := entry if not entry.is_empty() else script.entry
	if not script.has_node_id(first):
		push_error("dialogue '%s' has no node '%s'" % [script.id, first])
		return false

	current = script
	is_active = true
	history.clear()
	_goto(first)
	started.emit(script.id)
	_resume()
	return true


## Parses (and caches) a `.dlg` file. Returns null and logs if it has errors.
func load_script(path: String) -> DialogueScript:
	if _cache.has(path):
		return _cache[path]
	var script := DialogueParser.parse_file(path)
	if not script.errors.is_empty():
		push_error("dialogue '%s' has %d error(s):\n  %s"
			% [path, script.errors.size(), "\n  ".join(script.errors)])
		# Errors are recoverable unless there is nothing to play at all.
		if script.nodes.is_empty():
			return null
	_cache[path] = script
	return script


## Drops parsed scripts so edited `.dlg` files are picked up. Called by the
## editor's file-changed hook in debug builds; harmless to call any time.
func clear_cache() -> void:
	_cache.clear()


## Called by the UI once the player has read the current line.
func advance() -> void:
	if not is_active or not _waiting:
		return
	_waiting = false
	_resume()


## Called by the UI with the index of the chosen option (as offered).
func choose(index: int) -> void:
	if not is_active or _options.is_empty():
		return
	if index < 0 or index >= _options.size():
		push_error("Dialogue.choose(%d) out of range (%d options)" % [index, _options.size()])
		return
	var option: Dictionary = _options[index]
	_options = []
	_waiting = false
	_goto(String(option["target"]))
	_resume()


## Stops a conversation early (quitting to menu, skipping a cutscene).
func stop() -> void:
	if not is_active:
		return
	var id := current.id if current else ""
	_reset()
	cancelled.emit(id)


func _reset() -> void:
	is_active = false
	_waiting = false
	_options = []
	current = null
	_node_id = ""
	_step = 0


func _goto(node_id: String) -> void:
	if node_id == DialogueScript.END_TARGET:
		_node_id = ""
		_step = 0
		return
	_node_id = node_id
	_step = 0
	if current:
		GameState.mark_visited(current.id, node_id)


## Walks steps until the player has something to do, or the script ends.
func _resume() -> void:
	var budget := MAX_STEPS_PER_RESUME
	while is_active and not _waiting:
		budget -= 1
		if budget <= 0:
			push_error("dialogue '%s' looped without reaching a line - check node '%s'"
				% [current.id, _node_id])
			_finish()
			return

		if _node_id.is_empty():
			_finish()
			return

		var steps := current.get_steps(_node_id)
		if _step >= steps.size():
			# Falling off the end of a node ends the conversation. Writers who
			# want to continue say so with an explicit `-> next_node`.
			_finish()
			return

		var step: Dictionary = steps[_step]
		_step += 1
		_execute(step)


func _execute(step: Dictionary) -> void:
	match String(step.get("kind", "")):
		DialogueScript.LINE:
			var text := DialogueExpression.interpolate(String(step["text"]), GameState.vars)
			var speaker := String(step["speaker"])
			var mood := String(step["mood"])
			history.append({"speaker": speaker, "text": text})
			_waiting = true
			line_shown.emit(speaker, mood, text)

		DialogueScript.CHOICES:
			_options = []
			for option: Dictionary in step["options"]:
				if DialogueExpression.is_true(String(option.get("condition", "")), GameState.vars):
					_options.append(option)
			if _options.is_empty():
				# Every option was filtered out. Better to walk on than to hang.
				push_warning("dialogue '%s' node '%s': no choice was available"
					% [current.id, _node_id])
				return
			var offered: Array = []
			for i: int in _options.size():
				offered.append({
					"text": DialogueExpression.interpolate(
						String(_options[i]["text"]), GameState.vars),
					"index": i,
				})
			_waiting = true
			choices_offered.emit(offered)

		DialogueScript.SET:
			_apply_set(step)

		DialogueScript.JUMP:
			_goto(String(step["target"]))

		DialogueScript.BRANCH:
			if DialogueExpression.is_true(String(step["condition"]), GameState.vars):
				_goto(String(step["target"]))

		DialogueScript.COMMAND:
			var name := String(step["name"])
			var args: PackedStringArray = step["args"]
			if name == "wait":
				_wait_seconds(float(args[0]) if args.size() > 0 else 0.5)
			else:
				command_issued.emit(name, args)

		DialogueScript.END:
			_finish()

		_:
			push_error("unknown dialogue step: %s" % step)


func _apply_set(step: Dictionary) -> void:
	var name := String(step["name"])
	var value: Variant = DialogueExpression.evaluate(String(step["expr"]), GameState.vars, null)
	if value == null:
		return  # evaluate() already reported why
	match String(step["op"]):
		"=":
			GameState.set_var(name, value)
		"+=":
			GameState.add_var(name, float(value))
		"-=":
			GameState.add_var(name, -float(value))


## `@wait 0.5` - hold the conversation without asking the player for anything.
func _wait_seconds(seconds: float) -> void:
	_waiting = true
	var timer := get_tree().create_timer(maxf(seconds, 0.0), false)
	timer.timeout.connect(func() -> void:
		if is_active:
			_waiting = false
			_resume()
	)


func _finish() -> void:
	var id := current.id if current else ""
	_reset()
	finished.emit(id)
