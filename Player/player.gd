extends CharacterBody2D

# --- Movement & combat settings ---
@export var SPEED: float = 100.0
@export var ROLL_SPEED: float = 200.0
@export var ROLL_DURATION: float = 0.5
@export var ATTACK_DURATION: float = 0.4 # Attack time in seconds

var last_direction := "down"
var is_rolling := false
var roll_timer := 0.0
var roll_direction := Vector2.ZERO
var can_move := true
var is_attacking := false
var attack_timer := 0.0

# --- Nodes ---
var animation_player: AnimationPlayer
var sword_hitbox: Area2D

func _ready():
	animation_player = $AnimationPlayer
	sword_hitbox = $Marker2D/HitBox

	if not animation_player:
		push_error("No AnimationPlayer node found at $AnimationPlayer")
	if not sword_hitbox:
		push_error("No HitBox node found at $Marker2D/HitBox")

func _physics_process(delta: float) -> void:
	# --- Handle attack duration ---
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false
			can_move = true
			play_idle_animation()
		# Stop player movement during attack
		return

	# --- Handle attack input ---
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_rolling:
		start_attack()
		return

	# --- Movement input ---
	var input_vector := Vector2.ZERO
	if can_move:
		input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# --- Handle roll input ---
	if Input.is_action_just_pressed("roll") and not is_rolling and not is_attacking:
		start_roll(input_vector)

	# --- Rolling ---
	if is_rolling:
		velocity = roll_direction * ROLL_SPEED
		move_and_slide()
		roll_timer -= delta
		if roll_timer <= 0:
			is_rolling = false
			can_move = true
			play_idle_animation()
		return

	# --- Normal movement ---
	velocity = input_vector * SPEED
	move_and_slide()

	# --- Animation updates ---
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

# --- Start a roll action ---
func start_roll(input_vector: Vector2) -> void:
	is_rolling = true
	can_move = false
	roll_timer = ROLL_DURATION

	if input_vector != Vector2.ZERO:
		roll_direction = input_vector.normalized()
	else:
		match last_direction:
			"right": roll_direction = Vector2.RIGHT
			"left":  roll_direction = Vector2.LEFT
			"up":    roll_direction = Vector2.UP
			"down":  roll_direction = Vector2.DOWN

	# Update last direction based on roll
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

# --- Start an attack ---
func start_attack() -> void:
	is_attacking = true
	can_move = false
	attack_timer = ATTACK_DURATION

	# Determine direction from mouse position
	var mouse_pos = get_global_mouse_position()
	var dir_vector = (mouse_pos - global_position).normalized()

	if abs(dir_vector.x) > abs(dir_vector.y):
		last_direction = "right" if dir_vector.x > 0 else "left"
	else:
		last_direction = "down" if dir_vector.y > 0 else "up"

	# Set knockback vector for sword hitbox
	sword_hitbox.knockback_vector = dir_vector

	# Play attack animation
	var anim_name = "attack_" + last_direction
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
	else:
		print("Missing attack animation:", anim_name)

# --- Play idle animation based on last direction ---
func play_idle_animation() -> void:
	match last_direction:
		"right": animation_player.play("idle_right")
		"left":  animation_player.play("idle_left")
		"up":    animation_player.play("idle_up")
		"down":  animation_player.play("idle_down")
