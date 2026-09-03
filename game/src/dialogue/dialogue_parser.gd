class_name DialogueParser
extends RefCounted
## Turns a `.dlg` text file into a [DialogueScript].
##
## The format is documented for writers in docs/writing/dialogue-format.md.
## Everything here is line-based and order-independent, so a writer can move
## whole nodes around without breaking anything but their own targets.
##
## Parsing never throws: unrecognised lines become errors on the script and the
## rest of the file still parses, so one typo does not blank a conversation.

const _PATTERNS := {
	"node": r"^::\s*([A-Za-z_][A-Za-z0-9_]*)\s*$",
	"jump": r"^->\s*([A-Za-z_][A-Za-z0-9_]*)\s*$",
	"choice": r"^\+\s*\[(.+?)\]\s*(?:if\s+(.+?)\s*)?->\s*([A-Za-z_][A-Za-z0-9_]*)\s*$",
	"set": r"^set\s+([A-Za-z_][A-Za-z0-9_]*)\s*(=|\+=|-=)\s*(.+?)\s*$",
	"branch": r"^if\s+(.+?)\s*->\s*([A-Za-z_][A-Za-z0-9_]*)\s*$",
	"command": r"^@([A-Za-z_][A-Za-z0-9_]*)\s*(.*?)\s*$",
	"end": r"^end\s*$",
	"narration": r"^>\s?(.*)$",
	# A speaker is deliberately a single word, so that a colon inside ordinary
	# prose ("It was late: later than the log admitted") stays narration.
	# Multi-word names like "Det. Ward" live in characters.json as display names.
	"line": r"^([A-Za-z_][A-Za-z0-9_]{0,23})(?:\s+@([A-Za-z_][A-Za-z0-9_]*))?\s*:\s+(.+)$",
}

static var _regex_cache: Dictionary = {}


## Loads and parses a `.dlg` file. Returns a script whose `errors` array is
## non-empty if anything went wrong (including the file not existing).
static func parse_file(path: String) -> DialogueScript:
	if not FileAccess.file_exists(path):
		var missing := DialogueScript.new()
		missing.source_path = path
		missing.errors.append("file not found: %s" % path)
		return missing
	var text := FileAccess.get_file_as_string(path)
	var script := parse_text(text, path.get_file().get_basename())
	script.source_path = path
	return script


## Parses `.dlg` source text. [param id] names the script in errors and in
## visited-node bookkeeping.
static func parse_text(text: String, id: String = "inline") -> DialogueScript:
	var script := DialogueScript.new()
	script.id = id

	var current_node := ""
	var pending_choices: Array = []  # collected `+` lines, flushed as one step

	var lines := text.replace("\r\n", "\n").split("\n")
	for i: int in lines.size():
		var raw: String = lines[i]
		var line := raw.strip_edges()
		var where := "line %d" % (i + 1)

		if line.is_empty() or line.begins_with("#"):
			continue

		# A run of `+` options forms a single choice step; anything else ends it.
		var is_choice := line.begins_with("+")
		if not is_choice and not pending_choices.is_empty():
			_flush_choices(script, current_node, pending_choices)

		var m: RegExMatch = _match("node", line)
		if m:
			current_node = m.get_string(1)
			if script.nodes.has(current_node):
				script.errors.append("%s: duplicate node '%s'" % [where, current_node])
			else:
				script.nodes[current_node] = []
			if script.entry.is_empty():
				script.entry = current_node
			continue

		if current_node.is_empty():
			script.errors.append("%s: content before the first ':: node' label" % where)
			continue

		if is_choice:
			m = _match("choice", line)
			if m:
				pending_choices.append({
					"text": m.get_string(1).strip_edges(),
					"condition": m.get_string(2).strip_edges(),
					"target": m.get_string(3),
				})
			else:
				script.errors.append("%s: malformed choice, expected '+ [text] -> node'" % where)
			continue

		m = _match("jump", line)
		if m:
			_add(script, current_node, {"kind": DialogueScript.JUMP, "target": m.get_string(1)})
			continue

		m = _match("branch", line)
		if m:
			_add(script, current_node, {
				"kind": DialogueScript.BRANCH,
				"condition": m.get_string(1).strip_edges(),
				"target": m.get_string(2),
			})
			continue

		m = _match("set", line)
		if m:
			_add(script, current_node, {
				"kind": DialogueScript.SET,
				"name": m.get_string(1),
				"op": m.get_string(2),
				"expr": m.get_string(3),
			})
			continue

		m = _match("command", line)
		if m:
			var args := m.get_string(2)
			_add(script, current_node, {
				"kind": DialogueScript.COMMAND,
				"name": m.get_string(1),
				"args": _split_args(args),
			})
			continue

		if _match("end", line):
			_add(script, current_node, {"kind": DialogueScript.END})
			continue

		m = _match("narration", line)
		if m:
			_add(script, current_node, _line_step("", "", m.get_string(1).strip_edges()))
			continue

		m = _match("line", line)
		if m:
			_add(script, current_node, _line_step(
				m.get_string(1).strip_edges(), m.get_string(2), m.get_string(3).strip_edges()))
			continue

		# Anything left is narration without the leading '>'. Common enough in
		# drafts that treating it as prose beats rejecting it.
		_add(script, current_node, _line_step("", "", line))

	if not pending_choices.is_empty():
		_flush_choices(script, current_node, pending_choices)

	if script.nodes.is_empty():
		script.errors.append("no nodes found - a script needs at least one ':: node' label")

	for dangling: String in script.dangling_targets():
		script.errors.append("jump to a node that does not exist: %s" % dangling)

	return script


static func _line_step(speaker: String, mood: String, text: String) -> Dictionary:
	return {
		"kind": DialogueScript.LINE,
		"speaker": speaker,
		"mood": mood,
		"text": text,
	}


static func _add(script: DialogueScript, node_id: String, step: Dictionary) -> void:
	script.nodes[node_id].append(step)


static func _flush_choices(script: DialogueScript, node_id: String, pending: Array) -> void:
	if node_id.is_empty() or not script.nodes.has(node_id):
		pending.clear()
		return
	script.nodes[node_id].append({
		"kind": DialogueScript.CHOICES,
		"options": pending.duplicate(true),
	})
	pending.clear()


## Splits command arguments on whitespace, keeping "quoted phrases" together.
static func _split_args(text: String) -> PackedStringArray:
	var args: PackedStringArray = []
	var current := ""
	var in_quotes := false
	for c: String in text:
		if c == '"':
			in_quotes = not in_quotes
			continue
		if c == " " and not in_quotes:
			if not current.is_empty():
				args.append(current)
				current = ""
			continue
		current += c
	if not current.is_empty():
		args.append(current)
	return args


static func _match(key: String, line: String) -> RegExMatch:
	if not _regex_cache.has(key):
		var re := RegEx.new()
		var err := re.compile(_PATTERNS[key])
		assert(err == OK, "bad dialogue regex for '%s'" % key)
		_regex_cache[key] = re
	return (_regex_cache[key] as RegEx).search(line)
