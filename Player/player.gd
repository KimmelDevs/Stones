extends CharacterBody2D

const SPEED = 100.0
const ROLL_SPEED = 200.0
const ROLL_DURATION = 0.5  # seconds

var animation_player: AnimationPlayer
var last_direction := "down"
var is_rolling := false
var roll_timer := 0.0
var roll_direction := Vector2.ZERO
var can_move := true  # Lock movement during roll

func _ready():
	animation_player = $AnimationPlayer
	if not animation_player:
		push_error("No AnimationPlayer node found at $AnimationPlayer")

func _physics_process(delta: float) -> void:
	# Default to no input
	var input_vector := Vector2.ZERO
	if can_move:
		input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# --- Handle roll input first ---
	if Input.is_action_just_pressed("roll") and not is_rolling:
		start_roll(input_vector)

	# --- Rolling ---
	if is_rolling:
		velocity = roll_direction * ROLL_SPEED
		move_and_slide()
		roll_timer -= delta
		if roll_timer <= 0:
			is_rolling = false
			can_move = true
			play_idle_animation()  # Go back to idle after roll
		return

	# --- Normal movement ---
	velocity = input_vector * SPEED
	move_and_slide()

	# --- Normal animation updates ---
	if input_vector != Vector2.ZERO:
		if input_vector.x > 0:
			animation_player.play("walk_right")
			last_direction = "right"
		elif input_vector.x < 0:
			animation_player.play("walk_left")
			last_direction = "left"
		elif input_vector.y < 0:
			animation_player.play("walk_up")
			last_direction = "up"
		elif input_vector.y > 0:
			animation_player.play("walk_down")
			last_direction = "down"
	else:
		play_idle_animation()

func start_roll(input_vector: Vector2) -> void:
	is_rolling = true
	can_move = false  # Disable movement during roll
	roll_timer = ROLL_DURATION

	# Determine roll direction
	if input_vector != Vector2.ZERO:
		roll_direction = input_vector.normalized()
	else:
		match last_direction:
			"right":
				roll_direction = Vector2.RIGHT
			"left":
				roll_direction = Vector2.LEFT
			"up":
				roll_direction = Vector2.UP
			"down":
				roll_direction = Vector2.DOWN

	# Update last_direction based on roll_direction
	if roll_direction.x > 0:
		last_direction = "right"
	elif roll_direction.x < 0:
		last_direction = "left"
	elif roll_direction.y < 0:
		last_direction = "up"
	elif roll_direction.y > 0:
		last_direction = "down"

	# Play roll animation
	var anim_name = "roll_" + last_direction
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
	else:
		print("Missing roll animation:", anim_name)

func play_idle_animation() -> void:
	match last_direction:
		"right":
			animation_player.play("idle_right")
		"left":
			animation_player.play("idle_left")
		"up":
			animation_player.play("idle_up")
		"down":
			animation_player.play("idle_down")
