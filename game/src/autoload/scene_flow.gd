extends Node
## Autoload `SceneFlow`: scene changes, fades, and the room -> desk -> room trip.
##
## Two ways to move:
##
## [b]goto[/b] replaces the scene outright (menu -> room, chapter -> chapter).
## [b]push[/b] / [b]pop[/b] keeps the current scene alive off-screen and layers
## another on top, then puts the first one back exactly as it was. That is what
## sitting down at a desk does: the room, the player's position and every NPC
## are still there when the conversation ends.
##
## An incoming scene can implement three optional hooks:
## [code]scene_configure(payload)[/code] before it enters the tree (read your
## arguments here), [code]scene_entered(payload)[/code] once it is in the tree,
## and [code]scene_resumed(payload)[/code] when a pushed scene above it popped.

signal scene_changed(path: String)
signal scene_pushed(path: String)
signal scene_popped(path: String)

const FADE_TIME := 0.35
const FADE_LAYER := 128

## Arguments handed to the scene being entered. Also readable afterwards, so a
## scene that needs them later (a return-to-room spawn point) can keep them.
var payload: Dictionary = {}

var _stack: Array[Node] = []
var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var layer := CanvasLayer.new()
	layer.layer = FADE_LAYER
	add_child(layer)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.visible = false
	layer.add_child(_fade)


## True while a transition is running. Guards against double-triggering an exit.
func is_busy() -> bool:
	return _busy


## Replaces the running scene. Clears any pushed scenes.
## [param spawn] names a Marker2D in the target room to place the player at.
func goto(path: String, spawn: String = "", extra: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true

	var incoming := _instantiate(path)
	if incoming == null:
		_busy = false
		return

	await fade_out()

	for node: Node in _stack:
		node.queue_free()
	_stack.clear()

	var old := get_tree().current_scene
	if old:
		old.queue_free()
		# Let the old scene finish leaving before the new one wakes up.
		await get_tree().process_frame

	payload = extra.duplicate()
	payload["spawn"] = spawn
	_install(incoming)
	scene_changed.emit(path)

	await fade_in()
	_busy = false


## Layers a scene on top, keeping the current one alive to come back to.
func push(path: String, extra: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true

	var incoming := _instantiate(path)
	if incoming == null:
		_busy = false
		return

	await fade_out()

	var old := get_tree().current_scene
	if old:
		# Detached, not freed: state, positions and timers all stay put.
		get_tree().root.remove_child(old)
		_stack.push_back(old)

	payload = extra.duplicate()
	_install(incoming)
	scene_pushed.emit(path)

	await fade_in()
	_busy = false


## Returns to the scene underneath. Does nothing if nothing was pushed.
func pop(extra: Dictionary = {}) -> void:
	if _busy or _stack.is_empty():
		return
	_busy = true

	await fade_out()

	var current := get_tree().current_scene
	var path := current.scene_file_path if current else ""
	if current:
		current.queue_free()
		await get_tree().process_frame

	var restored: Node = _stack.pop_back()
	payload = extra.duplicate()
	get_tree().root.add_child(restored)
	get_tree().current_scene = restored
	if restored.has_method("scene_resumed"):
		restored.call("scene_resumed", payload)
	scene_popped.emit(path)

	await fade_in()
	_busy = false


## Reloads the running scene, keeping [GameState] as it is.
func reload() -> void:
	var current := get_tree().current_scene
	if current:
		goto(current.scene_file_path, String(payload.get("spawn", "")))


## True when there is a scene to [method pop] back to.
func can_pop() -> bool:
	return not _stack.is_empty()


func fade_out(duration: float = FADE_TIME) -> void:
	_fade.visible = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, duration)
	await tween.finished


func fade_in(duration: float = FADE_TIME) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, duration)
	await tween.finished
	_fade.visible = false


func _instantiate(path: String) -> Node:
	if not ResourceLoader.exists(path):
		push_error("SceneFlow: no scene at '%s'" % path)
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("SceneFlow: '%s' is not a scene" % path)
		return null
	return packed.instantiate()


func _install(node: Node) -> void:
	# Two hooks, because the timing matters. `scene_configure` runs before the
	# scene enters the tree, so a scene can read its arguments in _ready - that
	# is where a conversation learns which file and which characters it is.
	# `scene_entered` runs after, when @onready nodes exist and the scene can
	# actually move things around.
	if node.has_method("scene_configure"):
		node.call("scene_configure", payload)
	get_tree().root.add_child(node)
	get_tree().current_scene = node
	if node.has_method("scene_entered"):
		node.call("scene_entered", payload)
