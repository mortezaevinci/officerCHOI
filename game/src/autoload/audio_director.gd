extends Node
## Autoload `AudioDirector`: one place to ask for music and sound effects.
##
## Music crossfades between two players so a track change never clicks. Sound
## effects come from a small pool, so a burst of UI clicks cannot run out of
## players or cut each other off.

const FADE_TIME := 1.2
const SFX_VOICES := 8

## Short names dialogue can use: `@music tense` instead of a full res:// path.
const MUSIC := {
	"none": "",
	# "precinct": "res://assets/audio/music/precinct_loop.ogg",
	# "tense": "res://assets/audio/music/tense_loop.ogg",
}

const SFX := {
	# "click": "res://assets/audio/sfx/ui_click.ogg",
	# "page": "res://assets/audio/sfx/page_turn.ogg",
}

var current_track: String = ""

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_is_a: bool = true
var _sfx: Array[AudioStreamPlayer] = []
var _next_voice: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	for i: int in SFX_VOICES:
		_sfx.append(_make_player("SFX"))


## Plays a track by short name or `res://` path. Repeating the current track is
## a no-op, so scenes can ask for their music without checking first.
func play_music(name_or_path: String, fade: float = FADE_TIME) -> void:
	var path := String(MUSIC.get(name_or_path, name_or_path))
	if path == current_track:
		return
	if path.is_empty():
		stop_music(fade)
		return
	if not ResourceLoader.exists(path):
		push_warning("AudioDirector: no music at '%s'" % path)
		return

	var incoming := _music_b if _active_is_a else _music_a
	var outgoing := _music_a if _active_is_a else _music_b
	_active_is_a = not _active_is_a
	current_track = path

	incoming.stream = load(path)
	incoming.volume_db = -60.0
	incoming.play()

	var tween := create_tween().set_parallel(true)
	tween.tween_property(incoming, "volume_db", 0.0, fade)
	if outgoing.playing:
		tween.tween_property(outgoing, "volume_db", -60.0, fade)
		tween.chain().tween_callback(outgoing.stop)


func stop_music(fade: float = FADE_TIME) -> void:
	current_track = ""
	for player: AudioStreamPlayer in [_music_a, _music_b]:
		if not player.playing:
			continue
		var tween := create_tween()
		tween.tween_property(player, "volume_db", -60.0, fade)
		tween.tween_callback(player.stop)


## Fires a one-shot by short name or `res://` path.
func play_sfx(name_or_path: String, pitch_variation: float = 0.0) -> void:
	var path := String(SFX.get(name_or_path, name_or_path))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var player := _sfx[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx.size()
	player.stream = load(path)
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


func _make_player(bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	# Fall back to Master if the bus layout has not been set up yet.
	player.bus = bus if AudioServer.get_bus_index(bus) != -1 else "Master"
	add_child(player)
	return player
