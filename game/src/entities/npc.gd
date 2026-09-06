class_name Npc
extends CharacterBody2D
## A character in a room who is not the player.
##
## Static by default. [method walk_to] exists so a scripted beat can send
## someone across the room; call it from a `@command` handler in the room.

signal arrived()

@export var display_name: String = "Officer"
@export var speed: float = 160.0
@export var arrive_radius: float = 6.0

const WALK_FPS := 9.0
const DIRECTION_ROW := {Vector2.UP: 0, Vector2.LEFT: 1, Vector2.DOWN: 2, Vector2.RIGHT: 3}
const WALK_COLUMNS := 9

@onready var _body: Node2D = $Body
@onready var _sprite: Sprite2D = $Body/Sprite

var _target = null  # Vector2 or null
var facing: Vector2 = Vector2.DOWN
var _step_time: float = 0.0


func _ready() -> void:
	add_to_group("npcs")


func _physics_process(delta: float) -> void:
	if _target == null:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 8.0 * delta)
		move_and_slide()
		_update_animation(delta)
		return

	var to_target: Vector2 = _target - global_position
	if to_target.length() <= arrive_radius:
		_target = null
		velocity = Vector2.ZERO
		arrived.emit()
	else:
		velocity = to_target.normalized() * speed
		_face(to_target)
	move_and_slide()
	_update_animation(delta)


func _face(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		facing = Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
	else:
		facing = Vector2.DOWN if direction.y > 0.0 else Vector2.UP


## Same sheet layout as the player: row is the facing, column is the stride.
func _update_animation(delta: float) -> void:
	if _sprite == null:
		return
	var walking := velocity.length_squared() > 4.0
	if walking:
		_step_time += delta * WALK_FPS
	else:
		_step_time = 0.0
	var row: int = DIRECTION_ROW.get(facing, DIRECTION_ROW[Vector2.DOWN])
	var column := 1 + int(_step_time) % (WALK_COLUMNS - 1) if walking else 0
	_sprite.frame = row * WALK_COLUMNS + column


func walk_to(point: Vector2) -> void:
	_target = point


func stop() -> void:
	_target = null
	velocity = Vector2.ZERO
