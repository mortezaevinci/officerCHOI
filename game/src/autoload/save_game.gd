extends Node
## Autoload `SaveGame`: writes and reads run state as JSON under `user://saves/`.
##
## JSON rather than a binary format on purpose - saves stay diffable and
## hand-editable, which is worth far more during development than a few bytes.
## Nothing here knows about scenes; it saves what [GameState] holds plus enough
## to put the player back where they were.

signal saved(slot: int)
signal loaded(slot: int)

const DIR := "user://saves"
const AUTOSAVE_SLOT := 0
const MANUAL_SLOTS := 3
## Bumped when the save layout changes in a way old files cannot follow.
const FORMAT_VERSION := 1


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [DIR, slot]


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Saves the current run. [param scene_path] and [param spawn] are where a load
## should drop the player; pass them from the active scene.
func save_to_slot(slot: int, scene_path: String = "", spawn: String = "") -> bool:
	if not scene_path.is_empty():
		GameState.current_scene = scene_path
		GameState.current_spawn = spawn

	var payload := {
		"format": FORMAT_VERSION,
		"game_version": ProjectSettings.get_setting("application/config/version", "0.0.0"),
		"saved_at": Time.get_datetime_string_from_system(true),
		"state": GameState.to_dict(),
	}

	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("could not write save %d: %s" % [slot, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	saved.emit(slot)
	return true


## Reads a slot into [GameState]. Does not change scene - the caller decides,
## normally with `SceneFlow.goto(GameState.current_scene, GameState.current_spawn)`.
func load_from_slot(slot: int) -> bool:
	var data := read_slot(slot)
	if data.is_empty():
		return false
	GameState.from_dict(data.get("state", {}))
	loaded.emit(slot)
	return true


## Raw contents of a slot, or an empty dictionary. Use for save-menu previews.
func read_slot(slot: int) -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("save %d is not readable JSON" % slot)
		return {}
	var data: Dictionary = parsed
	if int(data.get("format", 0)) > FORMAT_VERSION:
		push_warning("save %d was written by a newer build" % slot)
	return data


## One-line description for a save-slot button.
func describe_slot(slot: int) -> String:
	var data := read_slot(slot)
	if data.is_empty():
		return "Empty"
	var state: Dictionary = data.get("state", {})
	var playtime := int(state.get("playtime", 0))
	return "Chapter %s  -  %02d:%02d  -  %s" % [
		state.get("vars", {}).get("chapter", "?"),
		playtime / 3600, (playtime / 60) % 60,
		data.get("saved_at", "").left(10),
	]


func delete_slot(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(slot_path(slot))


## The most recently written slot, or -1 when there is nothing to continue.
func latest_slot() -> int:
	var best := -1
	var best_time := ""
	for slot: int in range(0, MANUAL_SLOTS + 1):
		var data := read_slot(slot)
		if data.is_empty():
			continue
		var stamp := String(data.get("saved_at", ""))
		if stamp > best_time:
			best_time = stamp
			best = slot
	return best
