class_name JourneySeason
extends RefCounted
## Assembles one life: ten missions, then Officer Choi.
##
## A mission is the shape the whole game is built on - **you choose something
## good, and the consequence of having chosen it arrives**. So each mission is a
## pair of nodes: a good event, and one hurdle that the good event's own triggers
## justify. The graph already guarantees the pairing is causal, because the only
## hurdles reachable from a good node are the ones its triggers allow.
##
## Missions are assembled, not authored. There are 1,074 nodes and a few dozen
## hand-written conversations, so season one plays the authored spine and later
## seasons draw on the rest of the graph with generated beats. That is what makes
## "reset and try a new life" produce a different life rather than the same one.
##
## Assembly is deterministic in the season number: season 3 is always season 3,
## on every machine and after every reload, which means a save can store the
## number rather than the whole itinerary.
##
## [codeblock]
## var season := JourneySeason.assemble(run, 1)
## var mission := season.current()
## # ... play mission.good, then mission.bad ...
## season.advance()
## if season.is_finished(): # -> the boss
## [/codeblock]

const MISSIONS_PER_SEASON := 10

## The run that ends every season, whichever life was lived.
const BOSS_RUN := "choi"

var run: JourneyData
var season_number: int = 1
## Each entry is {good: int, bad: int} - indices into `run.nodes`.
var missions: Array[Dictionary] = []
var index: int = 0


## Builds a season. Later seasons prefer material the earlier ones did not use,
## so a second life is genuinely a second life.
static func assemble(source: JourneyData, number: int) -> JourneySeason:
	var season := JourneySeason.new()
	season.run = source
	season.season_number = maxi(1, number)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("officerchoi/season/%d" % season.season_number)

	var candidates := season._candidates()
	# Authored conversations first in season one, so the hand-written spine is
	# what a new player meets. Later seasons rotate past them.
	var offset := (season.season_number - 1) * MISSIONS_PER_SEASON

	var chosen: Array[Dictionary] = []
	var used_bad := {}
	var i := 0
	while chosen.size() < MISSIONS_PER_SEASON and i < candidates.size():
		var good: int = candidates[(i + offset) % candidates.size()]
		i += 1
		var bad := season._consequence_for(good, rng, used_bad)
		if bad < 0:
			continue
		used_bad[bad] = true
		chosen.append({"good": good, "bad": bad})

	season.missions = chosen
	return season


## Good nodes that can actually carry a mission, in the order a life happens.
## A node that triggers nothing is excluded: it has no consequence, and a
## mission with no consequence is not a mission. Those nodes are the game's
## rest state and belong between missions, not as one.
func _candidates() -> Array[int]:
	var stages := run.stage_order()
	var buckets: Dictionary = {}
	for name: String in stages:
		buckets[name] = [] as Array[int]

	for i: int in run.nodes.size():
		var node: Dictionary = run.nodes[i]
		if int(node.get("kind", JourneyData.NODE_BAD)) != JourneyData.NODE_GOOD:
			continue
		if int(node.get("trig", 0)) == 0:
			continue
		if run.successors(i, JourneyData.EDGE_CONSEQUENCE).is_empty():
			continue
		var stage := String(node.get("stage", "any"))
		if not buckets.has(stage):
			stage = "any"
		buckets[stage].append(i)

	# Authored events first within each stage, then by id so assembly is stable.
	var ordered: Array[int] = []
	for name: String in stages:
		var bucket: Array = buckets[name]
		bucket.sort_custom(func(a: int, b: int) -> bool:
			var a_authored := not String(run.nodes[a].get("event", "")).is_empty()
			var b_authored := not String(run.nodes[b].get("event", "")).is_empty()
			if a_authored != b_authored:
				return a_authored
			return String(run.nodes[a]["id"]) < String(run.nodes[b]["id"]))
		ordered.append_array(bucket)
	return ordered


## Picks the hurdle that follows a good event. Prefers one with an authored
## conversation, then one not already used this season, so a life does not hand
## you the same refusal twice.
func _consequence_for(good: int, rng: RandomNumberGenerator, used: Dictionary) -> int:
	var options := run.successors(good, JourneyData.EDGE_CONSEQUENCE)
	if options.is_empty():
		return -1

	var authored: Array[int] = []
	var fresh: Array[int] = []
	for candidate: int in options:
		if used.has(candidate):
			continue
		if not String(run.nodes[candidate].get("event", "")).is_empty():
			authored.append(candidate)
		else:
			fresh.append(candidate)

	if not authored.is_empty():
		return authored[rng.randi() % authored.size()]
	if not fresh.is_empty():
		return fresh[rng.randi() % fresh.size()]
	return options[rng.randi() % options.size()]


func current() -> Dictionary:
	return missions[index] if index < missions.size() else {}


func advance() -> void:
	index += 1


func is_finished() -> bool:
	return index >= missions.size()


func mission_number() -> int:
	return index + 1


func total() -> int:
	return missions.size()


## A one-line description for a progress display, without spoiling the hurdle.
func headline(mission: Dictionary) -> String:
	if mission.is_empty():
		return ""
	return String(run.nodes[int(mission["good"])].get("title", ""))


## Serialisable progress. The itinerary is not stored because it is derived
## from the season number, so a save is three integers.
func to_dict() -> Dictionary:
	return {"season": season_number, "index": index, "run": run.run_id}


func restore(state: Dictionary) -> void:
	index = clampi(int(state.get("index", 0)), 0, missions.size())
