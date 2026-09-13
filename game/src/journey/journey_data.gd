class_name JourneyData
extends RefCounted
## Reads the compiled journey files under assets/journey/<run>/.
##
## The format is defined and written by C:\temp\_script\journey_format.py; this
## is the other half of it. Both sides must change together, which is why the
## field order is spelled out in the same sequence in both files.
##
## Nothing here decides what happens next - it only makes the graph, the
## conversations and the backdrops available. Choosing a path is the caller's
## job, so that the rule can be tested without a display attached.
##
## Node ids are namespaced by dataset - "goodlife:TRV-143", "iran:VIS-001" -
## because the four datasets collide on bare ids: FIN-001, PSY-001, DIS-001 and
## EDU-001 each exist in more than one of them, and goodlife FAM-001 (a family
## memory) is not iran FAM-001 (parents refused a visa).
##
## [codeblock]
## var data := JourneyData.load_run("res://journey/iran")
## if data.ok:
##     var studying := data.index_of("goodlife:TRV-143")
##     for i in data.successors(studying, JourneyData.EDGE_CONSEQUENCE):
##         print(data.nodes[i].title)
## [/codeblock]

## The 7 magic bytes: "OCJRNY" followed by NUL. Held as bytes rather than as a
## string constant because a NUL inside a GDScript string literal makes the
## parser replace it and report "Unexpected NUL character" - which stops the
## whole script compiling and takes `class_name` down with it.
const MAGIC: PackedByteArray = [0x4F, 0x43, 0x4A, 0x52, 0x4E, 0x59, 0x00]
const VERSION := 1

const KIND_DIRECTION := 1
const KIND_EVENT := 2
const KIND_SCENES := 3

const REC_NODE := 0
const REC_EDGE := 1

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

## Kept in the same order as TRIGGERS in journey_format.py. The index is the bit.
const TRIGGERS: PackedStringArray = [
	"money", "work", "power", "family", "discretion", "documents", "visa",
	"credential", "border", "airport", "land", "platform", "weather",
	"security", "banking", "transport", "police", "care", "school", "health",
	"registry", "gender", "body", "status", "maternity",
]

const LIFE_STAGES: PackedStringArray = [
	"any", "infancy", "childhood", "adolescence", "young_adult", "adult",
	"midlife", "later_life",
]

const REQUIRES: PackedStringArray = [
	"none", "others", "money_small", "money_large", "travel_local",
	"travel_domestic", "travel_intl", "documents", "health", "time", "place",
	"power", "institution",
]

const SOURCES: PackedStringArray = ["goodlife", "iran", "general", "war"]

var ok: bool = false
var errors: PackedStringArray = []

var nodes: Array[Dictionary] = []
var edges: Array[Dictionary] = []
var events: Dictionary = {}   ## event_id -> event dictionary
var scenes: Dictionary = {}   ## scene_id -> scene dictionary

var _by_id: Dictionary = {}   ## node_id -> index into `nodes`
var _out: Dictionary = {}     ## node index -> Array[int] of edge indices


## Loads all three files from a run directory. Missing files are recorded in
## `errors` rather than raised, so a half-built run still shows what it has.
static func load_run(dir_path: String) -> JourneyData:
	var data := JourneyData.new()
	data._load_direction("%s/direction.bin" % dir_path)
	data._load_events("%s/event.bin" % dir_path)
	data._load_scenes("%s/scenes.bin" % dir_path)
	data.ok = data.errors.is_empty()
	return data


func index_of(node_id: String) -> int:
	return int(_by_id.get(node_id, -1))


## Edge indices leaving a node, optionally of one kind. Pass -1 for all.
func successors(node_index: int, kind: int = -1) -> PackedInt32Array:
	var found: PackedInt32Array = []
	for edge_index: int in _out.get(node_index, [] as Array):
		var edge: Dictionary = edges[edge_index]
		if kind == -1 or int(edge["kind"]) == kind:
			found.append(int(edge["dst"]))
	return found


## The trigger names a node exposes you to, decoded from its bitmask.
func trigger_names(node_index: int) -> PackedStringArray:
	var out: PackedStringArray = []
	var mask := int(nodes[node_index].get("triggers", 0))
	for i: int in TRIGGERS.size():
		if mask & (1 << i):
			out.append(TRIGGERS[i])
	return out


func event_for(node_index: int) -> Dictionary:
	var event_id := String(nodes[node_index].get("event_id", ""))
	return events.get(event_id, {})


# --- reading -----------------------------------------------------------------

func _open(path: String, expect_kind: int) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("missing: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("cannot open: %s" % path)
		return {}
	var raw := file.get_buffer(file.get_length())
	file.close()
	if raw.size() < 32:
		errors.append("%s: shorter than a header" % path)
		return {}

	for i: int in MAGIC.size():
		if raw[i] != MAGIC[i]:
			errors.append("%s: not a journey file" % path)
			return {}

	var kind := raw[7]
	if kind != expect_kind:
		errors.append("%s: expected kind %d, found %d" % [path, expect_kind, kind])
		return {}
	var version := raw.decode_u16(8)
	if version > VERSION:
		errors.append("%s: version %d, this reader knows %d" % [path, version, VERSION])
		return {}

	var count := raw.decode_u32(12)
	var records_at := raw.decode_u32(16)
	var strtab_at := raw.decode_u32(20)

	var strings: PackedStringArray = []
	var p := strtab_at
	var string_count := raw.decode_u32(p)
	p += 4
	for _i: int in string_count:
		var length := raw.decode_u16(p)
		p += 2
		strings.append(raw.slice(p, p + length).get_string_from_utf8())
		p += length

	var records: Array[PackedByteArray] = []
	p = records_at
	for _i: int in count:
		var length := raw.decode_u32(p)
		p += 4
		records.append(raw.slice(p, p + length))
		p += length

	return {"strings": strings, "records": records}


func _load_direction(path: String) -> void:
	var opened := _open(path, KIND_DIRECTION)
	if opened.is_empty():
		return
	var strings: PackedStringArray = opened["strings"]
	for record: PackedByteArray in opened["records"]:
		var c := _Cursor.new(record, strings)
		if c.u8() == REC_NODE:
			var node := {
				"node_id": c.text(), "kind": c.u8(), "source": SOURCES[c.u8()],
				"category": c.text(), "title": c.text(),
				"stage": LIFE_STAGES[c.u8()], "weight": c.u8(),
				"triggers": c.u32(), "requires": REQUIRES[c.u8()],
				"event_id": c.text(),
			}
			_by_id[node["node_id"]] = nodes.size()
			nodes.append(node)
		else:
			var edge := {
				"src": c.u32(), "dst": c.u32(), "kind": c.u8(),
				"weight": c.u16(), "via": c.u32(),
				"min_stage": LIFE_STAGES[c.u8()], "note": c.text(),
			}
			var src := int(edge["src"])
			if not _out.has(src):
				_out[src] = [] as Array
			_out[src].append(edges.size())
			edges.append(edge)


func _load_events(path: String) -> void:
	var opened := _open(path, KIND_EVENT)
	if opened.is_empty():
		return
	var strings: PackedStringArray = opened["strings"]
	for record: PackedByteArray in opened["records"]:
		var c := _Cursor.new(record, strings)
		var event := {
			"event_id": c.text(), "node_id": c.text(), "scene_id": c.text(),
			"title": c.text(), "stage": LIFE_STAGES[c.u8()],
			"source_detail": c.text(), "nodes": {},
		}
		var node_count := c.u16()
		for _n: int in node_count:
			var name := c.text()
			var steps: Array[Dictionary] = []
			var step_count := c.u16()
			for _s: int in step_count:
				steps.append(_read_step(c))
			event["nodes"][name] = steps
		events[event["event_id"]] = event


func _read_step(c: _Cursor) -> Dictionary:
	var kind := c.u8()
	match kind:
		STEP_LINE, STEP_NARRATION:
			return {"kind": kind, "speaker": c.text(), "mood": c.text(), "text": c.text()}
		STEP_CHOICES:
			var options: Array[Dictionary] = []
			var n := c.u16()
			for _i: int in n:
				options.append({"text": c.text(), "condition": c.text(),
					"target": c.text(), "note": c.text()})
			return {"kind": kind, "options": options}
		STEP_SET:
			return {"kind": kind, "name": c.text(), "op": c.text(), "expr": c.text()}
		STEP_JUMP, STEP_BRANCH:
			return {"kind": kind, "condition": c.text(), "target": c.text()}
		STEP_COMMAND:
			return {"kind": kind, "name": c.text(), "args": c.text()}
		_:
			return {"kind": STEP_END}


func _load_scenes(path: String) -> void:
	var opened := _open(path, KIND_SCENES)
	if opened.is_empty():
		return
	var strings: PackedStringArray = opened["strings"]
	for record: PackedByteArray in opened["records"]:
		var c := _Cursor.new(record, strings)
		var scene := {
			"scene_id": c.text(), "art": c.text(), "location": c.text(),
			"time_of_day": c.text(), "mood": c.text(), "palette": c.text(),
			"tags": c.text(), "note": c.text(),
		}
		scenes[scene["scene_id"]] = scene


## Walks one record. Field order must match Packer in journey_format.py.
class _Cursor extends RefCounted:
	var _d: PackedByteArray
	var _p: int = 0
	var _s: PackedStringArray

	func _init(data: PackedByteArray, strings: PackedStringArray) -> void:
		_d = data
		_s = strings

	func u8() -> int:
		var v := _d[_p]
		_p += 1
		return v

	func u16() -> int:
		var v := _d.decode_u16(_p)
		_p += 2
		return v

	func u32() -> int:
		var v := _d.decode_u32(_p)
		_p += 4
		return v

	func text() -> String:
		var i := u32()
		return _s[i] if i < _s.size() else ""
