class_name JourneyDialogue
extends RefCounted
## Turns one journey event into a [DialogueScript] the existing runner can play.
##
## The journey events were authored with exactly the step kinds
## [DialogueScript] already has, so this is a translation and not a second
## dialogue system: the runner, the dialogue box, the history and the condition
## evaluator are all the ones that were already written and tested.
##
## Two differences the translation resolves:
##
## 1. The JSON uses integer step kinds; [DialogueScript] uses strings.
## 2. The JSON has a narration kind of its own; [DialogueScript] expresses
##    narration as a line with no speaker, which is what the dialogue box
##    already renders in italics.
##
## The player's name is substituted here, once, on the way in. Nothing
## downstream ever has to know the player typed a name.
##
## [codeblock]
## var script := JourneyDialogue.build(run, run.events["the-konkur"], "Darya")
## Dialogue.start_script(script)
## [/codeblock]

## Node name a choice can target to end the conversation, matching the `.dlg`
## convention so authored events and generated ones behave identically.
const END_TARGET := "end"


## Builds a playable script from an event dictionary as it appears in
## `journey.json`. [param player_name] may be empty, in which case the token is
## left alone rather than replaced with nothing.
static func build(run: JourneyData, event: Dictionary, player_name: String,
		document_name: String = "") -> DialogueScript:
	var script := DialogueScript.new()
	script.id = String(event.get("uuid", event.get("node", "journey")))
	script.source_path = "journey://%s/%s" % [run.run_id, script.id]

	var event_nodes: Dictionary = event.get("nodes", {})
	for node_name: String in event_nodes:
		var steps: Array = []
		for step: Dictionary in event_nodes[node_name]:
			var translated := _step(run, step, player_name, document_name)
			if not translated.is_empty():
				steps.append(translated)
		script.nodes[node_name] = steps

	script.entry = "start" if script.nodes.has("start") else _first(event_nodes)
	if script.entry.is_empty():
		script.errors.append("%s has no nodes" % script.id)

	# The same check test_content.gd makes of .dlg files. A generated script can
	# have a dangling target just as easily as a typed one.
	for dangling: String in script.dangling_targets():
		script.errors.append("dangling target: %s" % dangling)

	return script


## Builds the fallback beat for a node with no authored conversation, from the
## dataset's own title and summary.
##
## This is what keeps later seasons playable: there are 1,074 nodes and only a
## few dozen authored events, so most of the graph would otherwise be unreachable.
## It is deliberately plain - two lines of narration and one way onward - because
## a procedural beat that tried to sound authored would be worse than one that
## is visibly a stub.
static func build_stub(run: JourneyData, node_index: int) -> DialogueScript:
	var node: Dictionary = run.nodes[node_index]
	var is_good := int(node.get("kind", JourneyData.NODE_BAD)) == JourneyData.NODE_GOOD

	var script := DialogueScript.new()
	script.id = "stub:%s" % String(node.get("id", "?"))
	script.source_path = "journey://%s/%s" % [run.run_id, script.id]

	var summary := String(node.get("sum", "")).strip_edges()
	var steps: Array = [
		{"kind": DialogueScript.LINE, "speaker": "", "mood": "",
		 "text": String(node.get("title", ""))},
	]
	if not summary.is_empty():
		steps.append({"kind": DialogueScript.LINE, "speaker": "", "mood": "",
			"text": summary})
	steps.append({
		"kind": DialogueScript.CHOICES,
		"options": [{
			# First person, and an action - the same rule the authored events
			# follow. A generated beat that says "Go on" while every written one
			# says "I take it" reads as a different game.
			"text": "I let it happen." if is_good else "I take it.",
			"condition": "",
			"target": END_TARGET,
		}],
	})

	script.nodes["start"] = steps
	script.entry = "start"
	return script


static func _first(event_nodes: Dictionary) -> String:
	for key: String in event_nodes:
		return key
	return ""


static func _step(run: JourneyData, step: Dictionary, player_name: String,
		document_name: String) -> Dictionary:
	match int(step.get("k", -1)):
		JourneyData.STEP_LINE:
			return {
				"kind": DialogueScript.LINE,
				"speaker": String(step.get("who", "")),
				"mood": String(step.get("mood", "")),
				"text": run.render(String(step.get("text", "")), player_name, document_name),
			}
		JourneyData.STEP_NARRATION:
			# Narration is a line with no speaker; the box already italicises it.
			return {
				"kind": DialogueScript.LINE,
				"speaker": "",
				"mood": "",
				"text": run.render(String(step.get("text", "")), player_name, document_name),
			}
		JourneyData.STEP_CHOICES:
			var options: Array = []
			for option: Dictionary in step.get("options", []):
				options.append({
					"text": run.render(String(option.get("text", "")), player_name, document_name),
					"condition": String(option.get("if", "")),
					"target": String(option.get("to", END_TARGET)),
				})
			return {"kind": DialogueScript.CHOICES, "options": options}
		JourneyData.STEP_SET:
			return {
				"kind": DialogueScript.SET,
				"name": String(step.get("name", "")),
				"op": String(step.get("op", "=")),
				"expr": String(step.get("expr", "")),
			}
		JourneyData.STEP_JUMP:
			return {"kind": DialogueScript.JUMP, "target": String(step.get("to", END_TARGET))}
		JourneyData.STEP_BRANCH:
			return {
				"kind": DialogueScript.BRANCH,
				"condition": String(step.get("condition", "")),
				"target": String(step.get("to", END_TARGET)),
			}
		JourneyData.STEP_COMMAND:
			# The runner hands commands to the scene as a PackedStringArray, the
			# same shape `@music tense` produces from a .dlg file.
			var args := PackedStringArray()
			var raw := String(step.get("args", "")).strip_edges()
			if not raw.is_empty():
				args = raw.split(" ", false)
			return {
				"kind": DialogueScript.COMMAND,
				"name": String(step.get("name", "")),
				"args": args,
			}
		JourneyData.STEP_END:
			return {"kind": DialogueScript.END}
	return {}
