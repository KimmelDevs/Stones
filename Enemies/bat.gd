extends CharacterBody2D

# --- Combat / Knockback ---
var knockback: Vector2 = Vector2.ZERO
@export var knockback_speed: float = 200.0
@export var knockback_duration: float = 0.2

# --- Movement ---
@export var acceleration: float = 200
@export var maxspeed: float = 50
@export var friction: float = 200
@export var wander_change_interval: float = 1.5
@export var wander_radius: float = 150

# --- Chase Boxer Movement ---
@export var chase_radius: float = 200.0
@export var sway_speed: float = 4.0
@export var sway_amplitude: float = 20.0
@export var unpredictability: float = 0.005

# --- Attack ---
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 0.5
var can_attack: bool = true

# --- Nodes ---
@onready var hurtbox = $HurtBox
@onready var stats = $Stats
@onready var playerdetectionzone = $PlayerDetectionArea
@onready var sprite = $AnimatedSprite2D
@onready var anim_player = $AnimationPlayer

# --- State machine ---
enum { IDLE, WANDER, CHASE }
var state = IDLE

# --- Variables ---
var move_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var dying: bool = false
var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var home_position: Vector2

# Boxer sway vars
var sway_time: float = 0.0
var sway_direction: int = 1

func _ready() -> void:
	home_position = global_position

func _physics_process(delta: float) -> void:
	seek_player()

	match state:
		IDLE:
			move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta)
			if randf() < 0.01:
				state = WANDER

		WANDER:
			wander_timer -= delta
			if wander_timer <= 0:
				pick_new_wander_direction()
				wander_timer = wander_change_interval
			move_velocity = move_velocity.move_toward(wander_direction * maxspeed, acceleration * delta)

			# Keep near home
			if global_position.distance_to(home_position) > wander_radius:
				var dir_to_home = (home_position - global_position).normalized()
				move_velocity = move_velocity.move_toward(dir_to_home * maxspeed, acceleration * delta)

			# Face where moving
			if move_velocity.length() > 0.1:
				update_sprite_facing(move_velocity)

		CHASE:
			var player = playerdetectionzone.player
			if player != null:
				_chase_with_boxer_movement(player, delta)

	# Apply knockback if active
	if knockback_timer > 0:
		velocity = knockback
		knockback_timer -= delta
		if knockback_timer <= 0 and dying:
			spawn_Death_effect()
			queue_free()
	else:
		if not dying:
			velocity = move_velocity

	move_and_slide()
func _chase_with_boxer_movement(player: Node2D, delta: float) -> void:
	var dist_to_player = global_position.distance_to(player.global_position)

	# Adjust sway amplitude based on distance
	var effective_sway = sway_amplitude
	if dist_to_player < attack_range * 2:
		effective_sway *= 0.4  # smaller sway when close

	# Main direction toward player
	var to_player = (player.global_position - global_position).normalized()

	# Perpendicular vector for sideways movement
	var perp = Vector2(-to_player.y, to_player.x) * sway_direction

	# Add sinusoidal sway for curved motion
	sway_time += delta * sway_speed
	var sway_offset = perp * sin(sway_time) * effective_sway

	# Add slight forward lunge effect when close
	var lunge_forward = Vector2.ZERO
	if dist_to_player <= attack_range * 1.5 and can_attack:
		lunge_forward = to_player * 15.0

	# Combine sway + lunge to create a curved path
	var chase_target = player.global_position + sway_offset + lunge_forward

	# Optional: Add some noise for unpredictability
	var random_offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
	chase_target += random_offset * 0.1  # small jitter

	# Limit to chase radius
	if chase_target.distance_to(home_position) > chase_radius:
		var dir_to_home = (chase_target - home_position).normalized()
		chase_target = home_position + dir_to_home * chase_radius

	# Smooth movement toward chase target
	var dir = (chase_target - global_position).normalized()
	move_velocity = move_velocity.move_toward(dir * maxspeed, acceleration * delta)

	# Random sway flip
	if randf() < unpredictability:
		sway_direction *= -1

	# Face toward actual chase target (not strictly the player)
	update_sprite_facing(dir)

	

func pick_new_wander_direction() -> void:
	wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func seek_player() -> void:
	if playerdetectionzone.can_see_player():
		state = CHASE
	else:
		if state == CHASE:
			state = WANDER

func _on_hurt_box_area_entered(area: Area2D) -> void:
	knockback = area.knockback_vector * knockback_speed
	knockback_timer = knockback_duration
	stats.health -= 1
	hurtbox.create_hit_effect()
	if stats.health <= 0:
		dying = true

func spawn_Death_effect() -> void:
	var effect_scene = preload("res://Effects/bat_death.tscn")
	var effect_instance = effect_scene.instantiate()
	effect_instance.global_position = global_position
	get_parent().add_child(effect_instance)

func update_sprite_facing(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		sprite.flip_h = direction.x < 0
