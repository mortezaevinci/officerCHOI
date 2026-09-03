class_name DialogueExpression
extends RefCounted
## Evaluates the little expressions writers put in `.dlg` files.
##
## Conditions (`if trust_park >= 2 and not told_truth`), assignment right-hand
## sides (`set suspicion += 1`) and `{interpolation}` in dialogue text all come
## through here. Story variables from [GameState] are exposed as plain names.
##
## Godot's [Expression] class does the actual work, so writers get the whole of
## GDScript's expression syntax without us hand-rolling a parser.

## Evaluates [param expr] against [param context] (normally `GameState.vars`).
## Returns [param fallback] if the expression is malformed, after logging it -
## a broken condition must never take down a conversation mid-scene.
static func evaluate(expr: String, context: Dictionary, fallback: Variant = null) -> Variant:
	if expr.strip_edges().is_empty():
		return fallback

	var names := PackedStringArray()
	var values: Array = []
	for key: Variant in context:
		var name := String(key)
		if not name.is_valid_identifier():
			continue  # not addressable from an expression anyway
		names.append(name)
		values.append(context[key])

	var expression := Expression.new()
	if expression.parse(expr, names) != OK:
		push_error("dialogue expression failed to parse: '%s' (%s)"
			% [expr, expression.get_error_text()])
		return fallback

	var result: Variant = expression.execute(values, null, false)
	if expression.has_execute_failed():
		push_error("dialogue expression failed to run: '%s' (%s)"
			% [expr, expression.get_error_text()])
		return fallback
	return result


## Evaluates a condition and coerces the result to a bool the way a writer
## expects: 0, "", null and an unknown variable are all false.
static func is_true(condition: String, context: Dictionary) -> bool:
	if condition.strip_edges().is_empty():
		return true  # no condition means "always"
	return truthy(evaluate(condition, context, false))


## The one place that decides what counts as true, so conditions in dialogue and
## [method GameState.has_flag] never disagree.
static func truthy(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return value != 0
		TYPE_STRING, TYPE_STRING_NAME:
			return not String(value).is_empty()
		TYPE_ARRAY, TYPE_DICTIONARY:
			return not value.is_empty()
	return value != null


## Replaces `{expr}` spans in dialogue text with their evaluated value, so a
## line can read "You owe me {debt} favours." A span that fails to evaluate is
## left in place rather than blanked, so it is obvious in-game.
static func interpolate(text: String, context: Dictionary) -> String:
	if not text.contains("{"):
		return text
	var out := ""
	var i := 0
	while i < text.length():
		var open := text.find("{", i)
		if open == -1:
			out += text.substr(i)
			break
		var close := text.find("}", open + 1)
		if close == -1:
			out += text.substr(i)
			break
		out += text.substr(i, open - i)
		var expr := text.substr(open + 1, close - open - 1)
		var value: Variant = evaluate(expr, context, null)
		out += "{%s}" % expr if value == null else str(value)
		i = close + 1
	return out
