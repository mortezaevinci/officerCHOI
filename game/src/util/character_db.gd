class_name CharacterDb
extends RefCounted
## Looks up who a speaker is: display name, colour, portrait files.
##
## Backed by content/characters/characters.json so a writer can add a character
## without touching code. Unknown speakers still work - they just get the raw
## name and the default colour - so writing never blocks on this file.

const PATH := "res://content/characters/characters.json"
const DEFAULT_COLOR := Color(0.92, 0.92, 0.95)

static var _data: Dictionary = {}
static var _loaded: bool = false


static func all() -> Dictionary:
	if not _loaded:
		_load()
	return _data


## Reloads after an edit. Called by tests; safe any time.
static func reload() -> void:
	_loaded = false
	_load()


## Speaker ids are matched case-insensitively, so a writer can type "Choi:" and
## the entry can be keyed "choi". Use this whenever two ids are compared.
static func canonical_id(id: String) -> String:
	return id.strip_edges().to_lower()


static func get_character(id: String) -> Dictionary:
	return all().get(canonical_id(id), {})


## True when this speaker has an entry. Unknown speakers still print, so this is
## for tooling and tests rather than for gameplay.
static func is_known(id: String) -> bool:
	return all().has(canonical_id(id))


## The name to print in the dialogue box. Falls back to the id, so an
## unregistered "Choi:" still reads correctly on screen.
static func display_name(id: String) -> String:
	if id.is_empty():
		return ""
	var entry := get_character(id)
	return String(entry.get("display_name", id))


static func color(id: String) -> Color:
	var entry := get_character(id)
	if entry.has("color"):
		return Color(String(entry["color"]))
	return DEFAULT_COLOR


## Portrait path for a mood, e.g. ("park", "worried"). Returns "" when there is
## no art yet - callers are expected to fall back to a placeholder.
static func portrait_path(id: String, mood: String = "") -> String:
	var entry := get_character(id)
	var folder := String(entry.get("portrait_folder", "res://assets/art/portraits"))
	var slug := String(entry.get("portrait_prefix", canonical_id(id)))
	var candidates := []
	if not mood.is_empty():
		candidates.append("%s/%s_%s.png" % [folder, slug, mood])
	candidates.append("%s/%s.png" % [folder, slug])
	for path: String in candidates:
		if ResourceLoader.exists(path):
			return path
	return ""


static func _load() -> void:
	_loaded = true
	_data = {}
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Dictionary):
		push_error("characters.json is not a JSON object")
		return
	for key: Variant in parsed:
		var id := String(key)
		if id.begins_with("_"):
			continue  # "_comment" and friends are notes to the team
		_data[canonical_id(id)] = parsed[key]
