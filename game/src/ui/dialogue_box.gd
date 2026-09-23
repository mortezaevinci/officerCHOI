class_name DialogueBox
extends Control
## Presents whatever the `Dialogue` autoload is playing.
##
## Self-driving: drop this scene into a room or a conversation view and it
## connects itself to the runner. Nothing else has to wire it up.
##
## Input model, deliberately the same on desktop and phone - anywhere on the
## box advances, a tap while text is still typing finishes the line instantly,
## and choices are big buttons.

signal line_finished_typing()

## Extra pause after a line finishes typing before auto-advance fires.
const AUTO_ADVANCE_DELAY := 1.4

@onready var _panel: Control = $Panel
@onready var _speaker: Label = $Panel/Margin/Rows/Speaker
@onready var _text: RichTextLabel = $Panel/Margin/Rows/Text
@onready var _continue: Control = $Panel/Margin/Rows/Continue
@onready var _choices: VBoxContainer = $Choices
## The advance button, on the RIGHT. Choices are on the LEFT, so a reflexive
## tap where "I understand" usually sits can never pick an option by accident.
@onready var _understand: Button = $Understand

var _typing: bool = false
var _awaiting_choice: bool = false
var _chars_shown: float = 0.0
var _auto_timer: float = 0.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The prompt keeps its slot at all times and fades instead of
	# appearing, so finishing a line does not reflow the panel.
	_continue.visible = true
	_continue.modulate.a = 0.0
	# Hidden until there is a line to acknowledge. Pressing it does exactly
	# what tapping the box does: finish the line if it is still typing,
	# otherwise move on.
	_understand.visible = false
	_understand.pressed.connect(_step)
	set_process(false)

	Dialogue.started.connect(_on_started)
	Dialogue.line_shown.connect(_on_line_shown)
	Dialogue.choices_offered.connect(_on_choices_offered)
	Dialogue.finished.connect(_on_ended)
	Dialogue.cancelled.connect(_on_ended)


func _process(delta: float) -> void:
	if _typing:
		var cps := Settings.text_speed_cps()
		if cps <= 0.0:
			_finish_typing()
			return
		_chars_shown += cps * delta
		_text.visible_characters = int(_chars_shown)
		if _text.visible_characters >= _text.get_total_character_count():
			_finish_typing()
		return

	if _awaiting_choice or not visible:
		return

	if bool(Settings.get_value("gameplay/auto_advance")):
		_auto_timer += delta
		if _auto_timer >= AUTO_ADVANCE_DELAY:
			_auto_timer = 0.0
			Dialogue.advance()


func _gui_input(event: InputEvent) -> void:
	if _awaiting_choice:
		return
	if _is_tap(event):
		_step()
		accept_event()


## A click or a touch anywhere on the box. Both mean the same thing here, which
## is what keeps the desktop and phone experience identical.
static func _is_tap(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _awaiting_choice:
		return
	if event.is_action_pressed("advance") or event.is_action_pressed("ui_accept"):
		_step()
		get_viewport().set_input_as_handled()


## One press: finish the line if it is still typing, otherwise move on.
func _step() -> void:
	if _typing:
		_finish_typing()
	else:
		Dialogue.advance()


func _finish_typing() -> void:
	_typing = false
	_chars_shown = 0.0
	_text.visible_characters = -1
	_continue.modulate.a = 1.0
	_auto_timer = 0.0
	line_finished_typing.emit()


func _on_started(_script_id: String) -> void:
	visible = true
	set_process(true)
	_clear_choices()


func _on_line_shown(speaker: String, _mood: String, text: String) -> void:
	_awaiting_choice = false
	_clear_choices()
	_panel.visible = true
	_understand.visible = true

	# The label keeps its slot whether or not there is a name in it. Toggling
	# visible made the panel a different height on narration than on speech,
	# which moved every line as the speaker changed.
	_speaker.text = CharacterDb.display_name(speaker)
	_speaker.visible = true
	_speaker.modulate.a = 0.0 if _speaker.text.is_empty() else 1.0
	_speaker.add_theme_color_override("font_color", CharacterDb.color(speaker))

	# Narration reads better in italics; spoken lines stay upright.
	_text.text = "[i]%s[/i]" % text if speaker.is_empty() else text
	_text.visible_characters = 0
	_chars_shown = 0.0
	_continue.modulate.a = 0.0
	_typing = Settings.text_speed_cps() > 0.0
	if not _typing:
		_finish_typing()


func _on_choices_offered(options: Array) -> void:
	_awaiting_choice = true
	_continue.modulate.a = 0.0
	# The advance button goes away entirely while a choice is up: there is
	# nothing to acknowledge, and leaving it there is what would invite the
	# accidental press this layout exists to prevent.
	_understand.visible = false
	_clear_choices()

	for option: Dictionary in options:
		var button := Button.new()
		button.text = String(option["text"])
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = Vector2(0, 64)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var index := int(option["index"])
		button.pressed.connect(func() -> void: _pick(index))
		_choices.add_child(button)

	_choices.visible = true
	# Keyboard and gamepad players need something focused to move from.
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Control).grab_focus()


func _pick(index: int) -> void:
	_awaiting_choice = false
	_clear_choices()
	Dialogue.choose(index)


func _clear_choices() -> void:
	for child: Node in _choices.get_children():
		child.queue_free()
	_choices.visible = false


func _on_ended(_script_id: String) -> void:
	visible = false
	set_process(false)
	_typing = false
	_awaiting_choice = false
	_understand.visible = false
	_clear_choices()
