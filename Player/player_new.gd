extends CharacterBody2D

@export var speed: float = 100.0
@export var roll_speed: float = 200.0
@export var roll_duration: float = 0.4

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var last_direction: String = "Down"  # Default facing
var is_rolling: bool = false
var roll_timer: float = 0.0
var roll_direction: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if is_rolling:
		# --- Handle rolling movement ---
		velocity = roll_direction * roll_speed
		move_and_slide()

		roll_timer -= delta
		if roll_timer <= 0:
			is_rolling = false
		return

	var input_vector := Vector2.ZERO
	
	# --- Movement input ---
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1
		last_direction = "Up"
	elif Input.is_action_pressed("move_down"):
		input_vector.y += 1
		last_direction = "Down"
	elif Input.is_action_pressed("move_left"):
		input_vector.x -= 1
		last_direction = "Left"
	elif Input.is_action_pressed("move_right"):
		input_vector.x += 1
		last_direction = "Right"

	input_vector = input_vector.normalized()
	velocity = input_vector * speed
	move_and_slide()

	# --- Roll input ---
	if Input.is_action_just_pressed("roll"):
		_start_roll()
		return

	# --- Animation handling ---
	if input_vector == Vector2.ZERO:
		animation_player.play("Idle" + last_direction)
	else:
		if input_vector.x != 0:
			animation_player.play("WalkLeft" if input_vector.x < 0 else "WalkRight")
		elif input_vector.y != 0:
			animation_player.play("WalkUp" if input_vector.y < 0 else "WalkDown")

func _start_roll() -> void:
	is_rolling = true
	roll_timer = roll_duration

	match last_direction:
		"Up":
			roll_direction = Vector2.UP
			animation_player.play("RollUp")
		"Down":
			roll_direction = Vector2.DOWN
			animation_player.play("RollDown")
		"Left":
			roll_direction = Vector2.LEFT
			animation_player.play("RollLeft")
		"Right":
			roll_direction = Vector2.RIGHT
			animation_player.play("RollRight")
