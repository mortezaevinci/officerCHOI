extends Control
## Step one: which life you are about to have.
##
## The nationalities are not settings on one game - they are five different
## games that happen to share a codebase, because the same choice costs a
## different amount depending on the passport you made it with. Each is a
## separate journey document, and only the ones that have authored
## conversations can be picked.
##
## The locked entries are deliberately visible rather than hidden. Seeing that
## four other lives exist, and that you are not being offered them, is part of
## the point.

## Order they are offered in, with the run id each maps to.
const CHOICES: Array[Dictionary] = [
	{"run": "palestine", "label": "Palestinian", "note": "born under occupation"},
	{"run": "usa", "label": "US citizen", "note": "born already arrived"},
	{"run": "nigeria", "label": "Nigerian", "note": "born suspected"},
	{"run": "iran", "label": "Iranian", "note": "born sanctioned"},
	{"run": "mexico", "label": "Mexican", "note": "born next door"},
]

@onready var _rows: VBoxContainer = $Center/Rows/Choices
@onready var _back: Button = $Center/Rows/Back


func _ready() -> void:
	var playable := JourneyData.available_runs()
	var first: Button = null

	for choice: Dictionary in CHOICES:
		var run := String(choice["run"])
		var enabled := playable.has(run)

		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 72)
		button.focus_mode = Control.FOCUS_ALL
		button.disabled = not enabled
		button.text = "%s - %s" % [choice["label"], choice["note"]] if enabled \
			else "%s - not written yet" % choice["label"]
		if enabled:
			button.pressed.connect(_on_chosen.bind(run))
			if first == null:
				first = button
		_rows.add_child(button)

	_back.pressed.connect(_on_back)
	(first if first != null else _back).grab_focus()


func _on_chosen(run: String) -> void:
	GameState.set_var("journey_run", run)
	GameState.set_var("season", 1)
	GameState.set_var("mission", 0)
	SceneFlow.goto(GamePaths.NAME_ENTRY)


func _on_back() -> void:
	SceneFlow.goto(GamePaths.MAIN_MENU)
