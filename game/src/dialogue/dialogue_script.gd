class_name DialogueScript
extends RefCounted
## A parsed `.dlg` file: a bag of named nodes, each a list of steps.
##
## Produced by [DialogueParser] and played back by the `Dialogue` autoload.
## Pure data - it has no idea how it will be displayed.

## Step kinds a node can contain. Stored as `kind` in each step dictionary.
const LINE := "line"        ## {speaker, mood, text}
const CHOICES := "choices"  ## {options: [{text, condition, target}]}
const SET := "set"          ## {name, op, expr}
const JUMP := "jump"        ## {target}
const BRANCH := "branch"    ## {condition, target}
const COMMAND := "command"  ## {name, args: PackedStringArray}
const END := "end"          ## {}

## Target name that ends the conversation instead of jumping.
const END_TARGET := "end"

## Short id, normally the file name without extension ("precinct_intro").
var id: String = ""
## Path the script was loaded from, for error messages.
var source_path: String = ""
## node id -> Array[Dictionary] of steps.
var nodes: Dictionary = {}
## Node the conversation starts at when no entry point is given.
var entry: String = ""
## Human-readable parse problems, "line 12: ..." style. Empty means clean.
var errors: PackedStringArray = []


func has_node_id(node_id: String) -> bool:
	return nodes.has(node_id)


func get_steps(node_id: String) -> Array:
	return nodes.get(node_id, [])


func node_ids() -> Array:
	return nodes.keys()


## Every node id referenced by a jump, branch or choice that does not exist.
## Used by the validator and the parser tests to catch typos in targets.
func dangling_targets() -> PackedStringArray:
	var missing: PackedStringArray = []
	for node_id: String in nodes:
		for step: Dictionary in nodes[node_id]:
			var targets: PackedStringArray = []
			match step.get("kind", ""):
				JUMP, BRANCH:
					targets.append(String(step.get("target", "")))
				CHOICES:
					for option: Dictionary in step.get("options", []):
						targets.append(String(option.get("target", "")))
			for target: String in targets:
				if target == END_TARGET or target.is_empty():
					continue
				if not nodes.has(target) and not missing.has(target):
					missing.append("%s -> %s" % [node_id, target])
	return missing
