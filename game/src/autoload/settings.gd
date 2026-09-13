extends Node
## Autoload `Settings`: player preferences, persisted to `user://settings.cfg`.
##
## Separate from [GameState] on purpose - preferences survive across saves and
## across a "new game", and must never end up inside a save file.

signal changed(key: String, value: Variant)

const PATH := "user://settings.cfg"

## Characters per second for the typewriter effect. 0 means "instant".
##
## These used to top out at 80 with "normal" at 45, which makes an ordinary
## hundred-character line take over two seconds to finish. That reads as the
## game being broken rather than as atmosphere, and the natural response is to
## mash the advance key - which skips the line before it can be read.
const TEXT_SPEEDS := {"slow": 45.0, "normal": 90.0, "fast": 220.0, "instant": 0.0}

const DEFAULTS := {
	"audio/master": 0.9,
	"audio/music": 0.7,
	"audio/sfx": 0.9,
	"display/fullscreen": false,
	"gameplay/text_speed": "fast",
	"gameplay/auto_advance": false,
	"gameplay/language": "en",
	"input/tap_to_move": true,  # touch devices walk by tapping the floor
}

var _values: Dictionary = DEFAULTS.duplicate(true)


func _ready() -> void:
	load_settings()


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	var old: Variant = _values.get(key)
	if typeof(old) == typeof(value) and old == value:
		return
	_values[key] = value
	_apply(key)
	changed.emit(key, value)
	save_settings()


## Characters per second the dialogue box should type at.
func text_speed_cps() -> float:
	return TEXT_SPEEDS.get(String(get_value("gameplay/text_speed")), 45.0)


## Changes a setting for this session only, without writing settings.cfg.
## For development switches and tests - never for anything the player did.
func override(key: String, value: Variant) -> void:
	_values[key] = value
	_apply(key)
	changed.emit(key, value)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		for key: String in DEFAULTS:
			var parts := key.split("/")
			if config.has_section_key(parts[0], parts[1]):
				_values[key] = config.get_value(parts[0], parts[1])
	apply_all()


func save_settings() -> void:
	var config := ConfigFile.new()
	for key: String in _values:
		var parts := key.split("/")
		config.set_value(parts[0], parts[1], _values[key])
	var err := config.save(PATH)
	if err != OK:
		push_warning("could not save settings: %s" % error_string(err))


func reset_to_defaults() -> void:
	_values = DEFAULTS.duplicate(true)
	apply_all()
	save_settings()


func apply_all() -> void:
	for key: String in _values:
		_apply(key)


func _apply(key: String) -> void:
	match key:
		"audio/master", "audio/music", "audio/sfx":
			var bus_name := key.get_slice("/", 1).capitalize()
			var bus := AudioServer.get_bus_index(bus_name)
			if bus != -1:
				var volume := float(get_value(key))
				AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
				AudioServer.set_bus_mute(bus, volume <= 0.0)
		"display/fullscreen":
			# Mobile is always fullscreen; changing the mode there does nothing good.
			if not OS.has_feature("mobile"):
				DisplayServer.window_set_mode(
					DisplayServer.WINDOW_MODE_FULLSCREEN if bool(get_value(key))
					else DisplayServer.WINDOW_MODE_WINDOWED)
		"gameplay/language":
			TranslationServer.set_locale(String(get_value(key)))
