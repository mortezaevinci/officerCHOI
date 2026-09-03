class_name TestCase
extends RefCounted
## Base class for a test file. Every `test_*` method in a subclass is run.
##
## Deliberately tiny - no addon, nothing to install, and it runs headless in
## about a second. Enough for the parts of this game that are worth testing:
## the dialogue parser, the runner's branching, and save round-trips.

var failures: PackedStringArray = []
var assertions: int = 0
## The running scene tree, handed over by the runner. Tests that need to put a
## node in the tree (to make `_ready` and `@onready` actually happen) use this.
var tree: SceneTree = null


## Optional hook, run before each test method.
func before_each() -> void:
	pass


## Optional hook, run after each test method.
func after_each() -> void:
	pass


func assert_true(condition: bool, message: String = "") -> void:
	assertions += 1
	if not condition:
		failures.append(_describe("expected true", message))


func assert_false(condition: bool, message: String = "") -> void:
	assertions += 1
	if condition:
		failures.append(_describe("expected false", message))


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	assertions += 1
	if actual != expected:
		failures.append(_describe("expected %s, got %s" % [expected, actual], message))


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	assertions += 1
	if actual == unexpected:
		failures.append(_describe("did not expect %s" % [unexpected], message))


func assert_has(container: Variant, key: Variant, message: String = "") -> void:
	assertions += 1
	if not container.has(key):
		failures.append(_describe("expected to contain %s" % [key], message))


func assert_empty(container: Variant, message: String = "") -> void:
	assertions += 1
	if not container.is_empty():
		failures.append(_describe("expected empty, got %s" % [container], message))


func fail(message: String) -> void:
	assertions += 1
	failures.append(message)


func _describe(problem: String, message: String) -> String:
	return problem if message.is_empty() else "%s - %s" % [message, problem]
