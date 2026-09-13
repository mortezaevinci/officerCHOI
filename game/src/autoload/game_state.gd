extends Node
## Everything the story knows about the player's run.
##
## This is the single source of truth for story variables. Dialogue conditions
## (`if trust >= 2 -> ...`) and effects (`set trust += 1`) read and write here,
## and [SaveGame] serialises the whole thing.
##
## Keep gameplay values in [member vars] rather than in scene nodes, so a save
## made anywhere can be restored anywhere.

## Emitted whenever a story variable changes value.
signal variable_changed(key: String, old_value: Variant, new_value: Variant)
## Emitted when a brand new run is started.
signal run_started()

## Story variables: flags, counters, relationship values.
## Values must be JSON-safe (bool, int, float, String, Array, Dictionary).
var vars: Dictionary = {}

## Dialogue node ids the player has already been through, as a set
## ("file.dlg::node_id" -> true). Used for "seen this before" checks.
var visited: Dictionary = {}

## Seconds of gameplay in this run (excludes time spent in menus).
var playtime: float = 0.0

## Where the player is, so a load can put them back.
var current_scene: String = ""
var current_spawn: String = ""

## Set by the test runner. Scenes check it before doing anything that touches
## the player's files - autosaving, mainly.
var testing: bool = false

## Values a fresh run starts with. Add new story variables here so they always
## have a defined type - dialogue conditions on an undefined variable read as
## `false`, which silently hides content.
const DEFAULTS := {
	"chapter": 1,
	"trust_park": 0,
	"trust_ward": 0,
	"suspicion": 0,
	"has_badge": true,
	"read_case_file": false,
	"told_truth": false,

	# --- the journey -------------------------------------------------------
	# The player types their own name; content refers to them as {player}.
	"player_name": "",
	# The spelling the state wrote down. Diverges from player_name at
	# the registry and never converges again.
	"document_name": "",
	"journey_run": "iran",
	"season": 1,
	# How many missions of this season are finished. Mission n is unlocked when
	# n <= mission, so this is both the progress counter and the unlock gate.
	"mission": 0,
	"journey_ended": false,

	# What the run costs you. Nothing ever spends it, because nothing can -
	# it is a record, not a currency.
	"dignity": 5,

	# Set by the Iranian events. Declared here so a condition on one of them
	# reads as its real type rather than silently as false.
	"alive": false,
	"name_mismatch": false,
	"rest": 0,
	"wants_out": 0,
	"clever": false,
	"has_rank": false,
	"service_pending": false,
	"university": "",
	"degree_flagged": false,
	"earning": false,
	"been_abroad": false,
	"turkey_blocked": false,
	"has_offer": false,
	"term_lost": 0,
	"clearance_refused": false,
	"banked": true,
	"kindness_seen": 0,
	"passport_away": false,
	"medicine_short": false,
	"parents_refused": false,
	"flagged_behaviour": false,
	"ssss": 0,
	"saw_choi_work": false,

	# Set during the Choi encounter.
	"noticed_early": false,
	"saw_the_method": false,
	"told_to_calm_down": false,
	"said_no": false,
}


func _ready() -> void:
	reset()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	playtime += delta


## Wipes all progress and applies [constant DEFAULTS]. Call before a new game.
func reset() -> void:
	vars = DEFAULTS.duplicate(true)
	visited.clear()
	playtime = 0.0
	current_scene = ""
	current_spawn = ""
	run_started.emit()


## Reads a story variable. Unknown keys read as [param default] (false), which
## makes `if some_flag -> node` safe to write before the flag ever gets set.
func get_var(key: String, default: Variant = false) -> Variant:
	return vars.get(key, default)


## Writes a story variable and announces the change.
func set_var(key: String, value: Variant) -> void:
	var old: Variant = vars.get(key, null)
	# Compare types first: `false == "x"` is a hard error in GDScript, and a
	# variable that legitimately changes type must not take the game down.
	if typeof(old) == typeof(value) and old == value:
		return
	vars[key] = value
	variable_changed.emit(key, old, value)


## Adds to a numeric variable (treating a missing key as 0).
func add_var(key: String, amount: float) -> void:
	var current: Variant = vars.get(key, 0)
	if current is bool:
		current = 1 if current else 0
	if not (current is int or current is float):
		push_warning("GameState.add_var on non-numeric '%s' (%s)" % [key, current])
		current = 0
	var result: Variant = current + amount
	# Keep whole numbers as ints so they format cleanly in text.
	if current is int and amount == floor(amount):
		result = int(result)
	set_var(key, result)


## True when the variable exists and is truthy.
func has_flag(key: String) -> bool:
	var v: Variant = vars.get(key, false)
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	if v is String:
		return not v.is_empty()
	return v != null


## Records that a dialogue node has been played.
func mark_visited(script_id: String, node_id: String) -> void:
	visited["%s::%s" % [script_id, node_id]] = true


## True if this dialogue node has been played before in this run.
func was_visited(script_id: String, node_id: String) -> bool:
	return visited.has("%s::%s" % [script_id, node_id])


# --- Serialisation -----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"vars": vars.duplicate(true),
		"visited": visited.duplicate(true),
		"playtime": playtime,
		"current_scene": current_scene,
		"current_spawn": current_spawn,
	}


func from_dict(data: Dictionary) -> void:
	# Start from DEFAULTS so saves made before a new variable existed still load.
	vars = DEFAULTS.duplicate(true)
	vars.merge(data.get("vars", {}), true)
	visited = data.get("visited", {}).duplicate(true)
	playtime = float(data.get("playtime", 0.0))
	current_scene = String(data.get("current_scene", ""))
	current_spawn = String(data.get("current_spawn", ""))
