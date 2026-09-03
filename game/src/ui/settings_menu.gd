extends Control
## Options overlay, usable from the title screen and from the pause menu.
## Every control writes straight through to [Settings], which saves itself.

@onready var _master: HSlider = $Center/Rows/MasterRow/Master
@onready var _music: HSlider = $Center/Rows/MusicRow/Music
@onready var _sfx: HSlider = $Center/Rows/SfxRow/Sfx
@onready var _text_speed: OptionButton = $Center/Rows/TextSpeedRow/TextSpeed
@onready var _auto_advance: CheckButton = $Center/Rows/AutoAdvance
@onready var _fullscreen: CheckButton = $Center/Rows/Fullscreen
@onready var _tap_to_move: CheckButton = $Center/Rows/TapToMove
@onready var _back: Button = $Center/Rows/Back

const SPEED_ORDER := ["slow", "normal", "fast", "instant"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i: int in SPEED_ORDER.size():
		_text_speed.add_item(SPEED_ORDER[i].capitalize(), i)

	_master.value = float(Settings.get_value("audio/master"))
	_music.value = float(Settings.get_value("audio/music"))
	_sfx.value = float(Settings.get_value("audio/sfx"))
	_text_speed.selected = SPEED_ORDER.find(String(Settings.get_value("gameplay/text_speed")))
	_auto_advance.button_pressed = bool(Settings.get_value("gameplay/auto_advance"))
	_fullscreen.button_pressed = bool(Settings.get_value("display/fullscreen"))
	_tap_to_move.button_pressed = bool(Settings.get_value("input/tap_to_move"))

	# Fullscreen is meaningless on a phone; tap-to-move is meaningless without a
	# touchscreen. Hide whichever does not apply rather than showing dead UI.
	_fullscreen.visible = not OS.has_feature("mobile")

	_master.value_changed.connect(func(v: float) -> void: Settings.set_value("audio/master", v))
	_music.value_changed.connect(func(v: float) -> void: Settings.set_value("audio/music", v))
	_sfx.value_changed.connect(func(v: float) -> void: Settings.set_value("audio/sfx", v))
	_text_speed.item_selected.connect(func(i: int) -> void:
		Settings.set_value("gameplay/text_speed", SPEED_ORDER[i]))
	_auto_advance.toggled.connect(func(on: bool) -> void:
		Settings.set_value("gameplay/auto_advance", on))
	_fullscreen.toggled.connect(func(on: bool) -> void:
		Settings.set_value("display/fullscreen", on))
	_tap_to_move.toggled.connect(func(on: bool) -> void:
		Settings.set_value("input/tap_to_move", on))
	_back.pressed.connect(queue_free)

	_back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
