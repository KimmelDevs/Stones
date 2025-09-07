extends CharacterBody2D

@export var speed: float = 100.0
@export var roll_speed: float = 200.0
@export var roll_duration: float = 0.4
@export var attack_duration: float = 0.5  # Duration of attack animation

@onready var left_hand_animation_player_2: AnimationPlayer = $LeftHandAnimationPlayer2
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var right_hand_animation_player: AnimationPlayer = $RightHandAnimationPlayer

var last_direction: String = "Down"  # Default facing
var is_rolling: bool = false
var is_left_hand_attacking: bool = false
var is_right_hand_attacking: bool = false
var roll_timer: float = 0.0
var left_attack_timer: float = 0.0
var right_attack_timer: float = 0.0
var roll_direction: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	var to_mouse = (mouse_pos - global_position).normalized()

	# Decide which cardinal direction is closest to the mouse
	if abs(to_mouse.x) > abs(to_mouse.y):
		if to_mouse.x > 0:
			last_direction = "Right"
		else:
			last_direction = "Left"
	else:
		if to_mouse.y > 0:
			last_direction = "Down"
		else:
			last_direction = "Up"
	# Update attack timers
	if is_left_hand_attacking:
		left_attack_timer -= delta
		if left_attack_timer <= 0:
			is_left_hand_attacking = false
	
	if is_right_hand_attacking:
		right_attack_timer -= delta
		if right_attack_timer <= 0:
			is_right_hand_attacking = false
	
	# --- Rolling Movement (highest priority) ---
	if is_rolling:
		velocity = roll_direction * roll_speed
		move_and_slide()
		roll_timer -= delta
		if roll_timer <= 0:
			is_rolling = false
		return
	
	# --- Attack Input (can attack while moving) ---
	if Input.is_action_just_pressed("left_click") and not is_left_hand_attacking and not is_rolling:
		start_left_hand_attack()
	
	if Input.is_action_just_pressed("right_click") and not is_right_hand_attacking and not is_rolling:
		start_right_hand_attack()
	
	# --- Roll input (can't roll while attacking) ---
	if Input.is_action_just_pressed("roll") and not is_left_hand_attacking and not is_right_hand_attacking:
		start_roll()
		return
	
	# --- Movement Input (ALWAYS allow movement unless rolling) ---
	# --- Movement Input ---
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_vector != Vector2.ZERO:
		mouse_pos = get_global_mouse_position()
		to_mouse = (mouse_pos - global_position).normalized()

		# Dot product measures alignment (-1 = opposite, 1 = same direction)
		var alignment = input_vector.normalized().dot(to_mouse)

		# Convert [-1,1] → [0.5, 1.5] as a speed multiplier
		var alignment_factor = lerp(0.5, 1.0, (alignment + 1.0) / 2.0)

		velocity = input_vector.normalized() * speed * alignment_factor
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	
	# --- Animation handling ---
	if input_vector == Vector2.ZERO:
		# Idle animations - face mouse direction
		animation_player.play("Idle" + last_direction)
		
		if not is_left_hand_attacking:
			left_hand_animation_player_2.play("Idle" + last_direction)
		if not is_right_hand_attacking:
			right_hand_animation_player.play("Idle" + last_direction)
	else:
		# Walking animations - face mouse direction while moving
		match last_direction:
			"Right":
				animation_player.play("WalkRight")
				if not is_left_hand_attacking:
					left_hand_animation_player_2.play("WalkRight")
				if not is_right_hand_attacking:
					right_hand_animation_player.play("WalkRight")
			"Left":
				animation_player.play("WalkLeft")
				if not is_left_hand_attacking:
					left_hand_animation_player_2.play("WalkLeft")
				if not is_right_hand_attacking:
					right_hand_animation_player.play("WalkLeft")
			"Up":
				animation_player.play("WalkUp")
				if not is_left_hand_attacking:
					left_hand_animation_player_2.play("WalkUp")
				if not is_right_hand_attacking:
					right_hand_animation_player.play("WalkUp")
			"Down":
				animation_player.play("WalkDown")
				if not is_left_hand_attacking:
					left_hand_animation_player_2.play("WalkDown")
				if not is_right_hand_attacking:
					right_hand_animation_player.play("WalkDown")

func start_roll() -> void:
	is_rolling = true
	roll_timer = roll_duration
	
	# Use current input or last direction
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector != Vector2.ZERO:
		roll_direction = input_vector.normalized()
		# Update last_direction based on roll direction
		if input_vector.x > 0:
			last_direction = "Right"
		elif input_vector.x < 0:
			last_direction = "Left"
		elif input_vector.y < 0:
			last_direction = "Up"
		elif input_vector.y > 0:
			last_direction = "Down"
	else:
		# No input, use last direction
		match last_direction:
			"Up": roll_direction = Vector2.UP
			"Down": roll_direction = Vector2.DOWN
			"Left": roll_direction = Vector2.LEFT
			"Right": roll_direction = Vector2.RIGHT
	
	# Play roll animations
	match last_direction:
		"Up":
			animation_player.play("RollUp")
			right_hand_animation_player.play("RollUp")
			left_hand_animation_player_2.play("RollUp")
		"Down":
			animation_player.play("RollDown")
			left_hand_animation_player_2.play("RollDown")
			right_hand_animation_player.play("RollDown")
		"Left":
			animation_player.play("RollLeft")
			left_hand_animation_player_2.play("RollLeft")
			right_hand_animation_player.play("RollLeft")
		"Right":
			animation_player.play("RollRight")
			animation_player.play("RollRight")
			left_hand_animation_player_2.play("RollRight")
			right_hand_animation_player.play("RollRight")

func start_left_hand_attack() -> void:
	is_left_hand_attacking = true
	left_attack_timer = attack_duration
	
	match last_direction:
		"Up":
			left_hand_animation_player_2.play("LeftHandAttackUp")
		"Down":
			left_hand_animation_player_2.play("LeftHandAttackDown")
		"Left":
			left_hand_animation_player_2.play("LeftHandAttackLeft")
		"Right":
			left_hand_animation_player_2.play("LeftHandAttackRight")

func start_right_hand_attack() -> void:
	is_right_hand_attacking = true
	right_attack_timer = attack_duration
	
	match last_direction:
		"Up":
			right_hand_animation_player.play("RightHandAttackUp")
		"Down":
			right_hand_animation_player.play("RightHandAttackDown")
		"Left":
			right_hand_animation_player.play("RightHandAttackLeft")
		"Right":
			right_hand_animation_player.play("RightHandAttackRight")
