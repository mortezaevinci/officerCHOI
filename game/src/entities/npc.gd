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

@onready var _body: Node2D = $Body

var _target = null  # Vector2 or null


func _ready() -> void:
	add_to_group("npcs")


func _physics_process(delta: float) -> void:
	if _target == null:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 8.0 * delta)
		move_and_slide()
		return

	var to_target: Vector2 = _target - global_position
	if to_target.length() <= arrive_radius:
		_target = null
		velocity = Vector2.ZERO
		arrived.emit()
	else:
		velocity = to_target.normalized() * speed
		if _body and absf(to_target.x) > 1.0:
			_body.scale.x = signf(to_target.x)
	move_and_slide()


func walk_to(point: Vector2) -> void:
	_target = point


func stop() -> void:
	_target = null
	velocity = Vector2.ZERO
