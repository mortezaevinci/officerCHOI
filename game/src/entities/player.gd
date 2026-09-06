class_name Player
extends CharacterBody2D
## The character the player walks around a room with.
##
## Two control schemes, both always live: WASD / arrows / gamepad stick, and
## tap-or-click a spot on the floor to walk there. The touch scheme is what
## makes the game playable on a phone without any on-screen buttons.
##
## Movement is locked while a conversation is running - the room does that by
## setting [member movement_locked].

signal arrived()
signal facing_changed(facing: Vector2)

@export var speed: float = 220.0
## How quickly the character reaches full speed. Low values feel floaty.
@export var acceleration: float = 1800.0
@export var friction: float = 2200.0
## Distance at which a tap-to-move target counts as reached.
@export var arrive_radius: float = 6.0

## Set by the room while dialogue, menus or cutscenes are up.
var movement_locked: bool = false:
	set(value):
		movement_locked = value
		if value:
			velocity = Vector2.ZERO
			_move_target = null

var facing: Vector2 = Vector2.DOWN

## Frames per second of the walk cycle. LPC sheets read well around 8-10.
const WALK_FPS := 9.0
## LPC walk sheets: 9 columns, and rows in this order.
const DIRECTION_ROW := {Vector2.UP: 0, Vector2.LEFT: 1, Vector2.DOWN: 2, Vector2.RIGHT: 3}
const WALK_COLUMNS := 9

@onready var _body: Node2D = $Body
@onready var _sprite: Sprite2D = $Body/Sprite
@onready var _camera: Camera2D = $Camera

var _move_target = null  # Vector2 or null
var _step_time: float = 0.0


## Stops the camera at the edges of a room, so the player never sees past the
## walls. Rooms call this with their own bounds on entry.
func set_camera_limits(bounds: Rect2) -> void:
	if _camera == null or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	_camera.limit_left = int(bounds.position.x)
	_camera.limit_top = int(bounds.position.y)
	_camera.limit_right = int(bounds.position.x + bounds.size.x)
	_camera.limit_bottom = int(bounds.position.y + bounds.size.y)
	_camera.reset_smoothing()


func _ready() -> void:
	add_to_group("player")


func _unhandled_input(event: InputEvent) -> void:
	if movement_locked or not bool(Settings.get_value("input/tap_to_move")):
		return
	# Only unhandled events reach here, so a tap on the dialogue box or a menu
	# button never doubles as a walk order.
	if event is InputEventScreenTouch and event.pressed:
		_set_move_target(get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_set_move_target(get_global_mouse_position())
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if movement_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		_move_target = null  # a key press cancels a walk-to order

	var desired := input
	if _move_target != null:
		var to_target: Vector2 = _move_target - global_position
		if to_target.length() <= arrive_radius:
			_move_target = null
			desired = Vector2.ZERO
			arrived.emit()
		else:
			desired = to_target.normalized()

	if desired != Vector2.ZERO:
		velocity = velocity.move_toward(desired * speed, acceleration * delta)
		_set_facing(desired)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	_update_animation(delta)

	# Walking into a wall should not leave the character trying forever.
	if _move_target != null and get_slide_collision_count() > 0 and velocity.length() < 8.0:
		_move_target = null


## Picks the frame off the walk sheet: the row is which way we face, the column
## is where we are in the stride. Column 0 is the standing pose, so an idle
## character just sits on it.
func _update_animation(delta: float) -> void:
	if _sprite == null:
		return

	if is_walking():
		_step_time += delta * WALK_FPS
	else:
		_step_time = 0.0

	var row: int = DIRECTION_ROW.get(facing, DIRECTION_ROW[Vector2.DOWN])
	var column := 0
	if is_walking():
		column = 1 + int(_step_time) % (WALK_COLUMNS - 1)
	_sprite.frame = row * WALK_COLUMNS + column


## Sends the character to a point without player input (cutscenes, `@walk_to`).
func walk_to(point: Vector2) -> void:
	if movement_locked:
		return
	_set_move_target(point)


func stop() -> void:
	_move_target = null
	velocity = Vector2.ZERO


func is_walking() -> bool:
	return velocity.length_squared() > 4.0


func _set_move_target(point: Vector2) -> void:
	_move_target = point


func _set_facing(direction: Vector2) -> void:
	var next := Vector2.DOWN
	if absf(direction.x) > absf(direction.y):
		next = Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
	else:
		next = Vector2.DOWN if direction.y > 0.0 else Vector2.UP
	if next == facing:
		return
	facing = next
	# No mirroring: the sheet has a real left and a real right row, and flipping
	# would put buttons, holsters and partings on the wrong side.
	facing_changed.emit(facing)
