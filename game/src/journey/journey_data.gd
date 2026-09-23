class_name JourneyData
extends RefCounted
## Reads one journey run from content/journey/<run>/journey.json.
##
## The document is written by C:\temp\_script\officerchoi\journey_build.py against the schema
## in journey_schema.py. Both sides must change together, and
## tests/cases/test_journey.gd is what makes them agree.
##
## Nothing here decides what happens next. It exposes the graph, the
## conversations and the backdrops, and leaves choosing a path to the caller, so
## the rule can be tested with no display attached.
##
## RUNS ARE INDEPENDENT. Loading "iran" does not read, need or touch "mexico".
## Each document carries its own cast, scenes and graph. Two runs may describe
## the same experience - and where they do, the event UUIDs match on purpose -
## but nothing is shared at load time and no run can break another.
##
## THE PLAYER TYPES THEIR OWN NAME. Text may contain the token "{player}"; call
## [method render] before showing any line. Everyone else is invented and named
## in the run's own cast.
##
## [codeblock]
## var run := JourneyData.load_run("iran")
## if run.ok:
##     var studying := run.index_of("goodlife:TRV-143")
##     for i in run.successors(studying, JourneyData.EDGE_CONSEQUENCE):
##         print(run.nodes[i]["title"])
## [/codeblock]

const CONTENT_ROOT := "res://content/journey"
const ART_ROOT := "res://assets/art/backgrounds/journey"
const SUPPORTED_VERSION := 2
const DOCUMENT_TOKEN := "{document}"

const NODE_GOOD := 0
const NODE_BAD := 1

const EDGE_CONSEQUENCE := 0
const EDGE_CASCADE := 1
const EDGE_SEQUEL := 2
const EDGE_RECOVERY := 3

const STEP_LINE := 0
const STEP_NARRATION := 1
const STEP_CHOICES := 2
const STEP_SET := 3
const STEP_JUMP := 4
const STEP_BRANCH := 5
const STEP_COMMAND := 6
const STEP_END := 7

## Edges are flat arrays in this order. There are tens of thousands of them and
## object keys would otherwise be most of the file.
const E_SRC := 0
const E_DST := 1
const E_KIND := 2
const E_WEIGHT := 3
const E_VIA := 4

var run_id: String = ""
var ok: bool = false
var errors: PackedStringArray = []

var nodes: Array = []
var edges: Array = []
var events: Dictionary = {}
var scenes: Dictionary = {}
var cast: Dictionary = {}
var triggers: Array = []
var stages: Array = []
## Event ids in authored order. The boss encounter is a written sequence, and
## this is what preserves it - the edges cannot be trusted to recover it.
var sequence: Array = []

var _player_token: String = "{player}"
var _by_id: Dictionary = {}
var _out: Dictionary = {}


## Loads a run by name. Problems land in `errors` rather than being raised, so a
## half-built run still reports what it has.
static func load_run(run: String) -> JourneyData:
	var data := JourneyData.new()
	data.run_id = run
	data._load("%s/%s/journey.json" % [CONTENT_ROOT, run])
	data.ok = data.errors.is_empty()
	return data


## Which runs are present. Each is self-contained; there is no shared index.
static func available_runs() -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(CONTENT_ROOT)
	if dir == null:
		return found
	for sub: String in dir.get_directories():
		if FileAccess.file_exists("%s/%s/journey.json" % [CONTENT_ROOT, sub]):
			found.append(sub)
	found.sort()
	return found


func index_of(node_id: String) -> int:
	return int(_by_id.get(node_id, -1))


## Node indices reachable from a node, optionally of one edge kind (-1 for all).
func successors(node_index: int, kind: int = -1) -> PackedInt32Array:
	var found: PackedInt32Array = []
	for edge_index: int in _out.get(node_index, [] as Array):
		var edge: Array = edges[edge_index]
		if kind == -1 or int(edge[E_KIND]) == kind:
			found.append(int(edge[E_DST]))
	return found


## The trigger names a node exposes you to, decoded from its bitmask. A node
## that triggers nothing cannot be followed by a hurdle - that is what makes a
## pomegranate a rest rather than a trap.
func trigger_names(node_index: int) -> PackedStringArray:
	var out: PackedStringArray = []
	var mask := int(nodes[node_index].get("trig", 0))
	for i: int in triggers.size():
		if mask & (1 << i):
			out.append(String(triggers[i]))
	return out


func event_for(node_index: int) -> Dictionary:
	return events.get(String(nodes[node_index].get("event", "")), {})


## Life stages in the order a life happens, "any" first. Used to lay a season
## out from birth to adult rather than shuffling the whole graph.
func stage_order() -> PackedStringArray:
	var out: PackedStringArray = []
	for stage: Variant in stages:
		out.append(String(stage))
	if out.is_empty():
		out = ["any", "infancy", "childhood", "adolescence", "young_adult",
			"adult", "midlife", "later_life"]
	return out


## Substitutes the name the player typed. Call this on every line before showing
## it; text containing no token comes back unchanged.
func render(text: String, player_name: String, document_name: String = "") -> String:
	var out := text
	if not player_name.is_empty():
		out = out.replace(_player_token, player_name)
	# The paperwork spelling. Falls back to the real name so a run started
	# before the registry scene still reads correctly.
	var on_paper := document_name if not document_name.is_empty() else player_name
	if not on_paper.is_empty():
		out = out.replace(DOCUMENT_TOKEN, on_paper)
	return out


## Where the authored misspellings live. Compiled from
## assets/text/names/misspellings.csv by tools-side names_build.py, because the
## export filter ships *.json and would silently drop a .csv.
const NAMES_PATH := "res://content/names/misspellings.json"

## Loaded once and kept. Static, because misspell() is called from the name
## entry screen before any run is loaded.
static var _names: Dictionary = {}
static var _names_loaded: bool = false


static func _load_names() -> void:
	if _names_loaded:
		return
	_names_loaded = true
	if not FileAccess.file_exists(NAMES_PATH):
		push_warning("JourneyData: no name list at %s; names pass through" % NAMES_PATH)
		return
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(NAMES_PATH))
	if parsed is Dictionary:
		_names = parsed
	else:
		push_warning("JourneyData: name list at %s is not an object" % NAMES_PATH)


## How the state writes a name down, which is not always how it was given.
##
## A lookup rather than a rule. The old version swapped the first letter by
## table, which made every name wrong in the same mechanical way; the authored
## list makes each one wrong in its own specific, humiliating way - Kaveh
## becomes Gaveh because gav is a cow, Ramón becomes Ramen, Refugio becomes
## Refugee, and Oluwaseun is not misspelled at all, it is truncated because the
## field is eight characters wide.
##
## `run_id` matters: US citizens keep their names. Nobody mishears Kyle, no
## field truncates it, and no officer asks him to spell it. That asymmetry is
## the whole point of the mechanic, so it is enforced here rather than left to
## each run's author to remember.
##
## Deterministic: the same name and run always produce the same result, so a
## save can store only the typed name.
static func misspell(name: String, run_id: String = "") -> String:
	if name.is_empty():
		return name
	_load_names()

	var unchanged: Array = _names.get("unchanged_runs", [] as Array)
	if unchanged.has(run_id):
		return name

	var entry: Dictionary = _names.get("by_name", {}).get(name.to_lower(), {})
	if entry.is_empty() or not bool(entry.get("changed", true)):
		return name
	return String(entry.get("to", name))


## The `why` behind each misspelling is carried in content/names/misspellings.json
## and is deliberately NOT exposed here. A helper to read it was written and then
## removed: authored events are data, they cannot call GDScript, and the runtime
## only handles the `scene` and `music` commands - so nothing could ever have
## reached it. The data is in the document if a future screen wants it.


## What a player reads for a speaker id. Falls back to the id, so an unlisted
## speaker still shows something rather than an empty name.
func display_name(speaker_id: String) -> String:
	var entry: Dictionary = cast.get(speaker_id, {})
	var shown := String(entry.get("display", ""))
	return shown if not shown.is_empty() else speaker_id


func speaker_color(speaker_id: String, fallback: Color = Color.WHITE) -> Color:
	var entry: Dictionary = cast.get(speaker_id, {})
	var value := String(entry.get("color", ""))
	return Color(value) if value.begins_with("#") else fallback


## Path to a scene's backdrop, or "" when the scene is unknown.
func art_path(scene_id: String) -> String:
	var scene: Dictionary = scenes.get(scene_id, {})
	var art := String(scene.get("art", ""))
	return "" if art.is_empty() else "%s/%s" % [ART_ROOT, art]


func _load(path: String) -> void:
	if not FileAccess.file_exists(path):
		errors.append("missing: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("cannot open: %s" % path)
		return
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		errors.append("%s: not a JSON object" % path)
		return
	var doc: Dictionary = parsed

	var version := int(doc.get("version", 0))
	if version != SUPPORTED_VERSION:
		errors.append("%s: version %d, this reader knows %d"
			% [path, version, SUPPORTED_VERSION])
		return

	run_id = String(doc.get("run", run_id))
	_player_token = String(doc.get("player_token", _player_token))
	triggers = doc.get("triggers", [])
	stages = doc.get("stages", [])
	sequence = doc.get("sequence", [])
	nodes = doc.get("nodes", [])
	edges = doc.get("edges", [])
	events = doc.get("events", {})
	scenes = doc.get("scenes", {})
	cast = doc.get("cast", {})

	if nodes.is_empty():
		errors.append("%s: no nodes" % path)
		return

	for i: int in nodes.size():
		_by_id[String(nodes[i]["id"])] = i

	for i: int in edges.size():
		var edge: Array = edges[i]
		var src := int(edge[E_SRC])
		if not _out.has(src):
			_out[src] = [] as Array
		_out[src].append(i)
