extends CharacterBody2D

# --- Movement ---
@export var acceleration: float = 100
@export var maxspeed: float = 40
@export var flee_speed: float = 80
@export var friction: float = 200
@export var wander_change_interval: float = 2.0
@export var wander_radius: float = 120
@export var safe_distance: float = 300     # how far it must run before calming down
@export var flee_dodge_strength: float = 0.4  # zigzag when fleeing
@export var flee_cooldown: float = 2.0     # cooldown after losing player
# --- Variables ---
var wall_escape_timer: float = 0.0
var wall_escape_dir: Vector2 = Vector2.ZERO
@export var wall_escape_time: float = 2.0   # seconds of committed detour
# --- Flee variables ---
var current_flee_speed: float = 10.0
var flee_accel_timer: float = 0.0
@export var flee_accel_step: float = 8.0     # increase by 8
@export var flee_accel_interval: float = 0.5 # every 0.5 sec
@export var sleep_chance: float = 0.3   # 30% chance to sleep
@export var sleep_duration: float = 270 # how long sleep lasts
var sleep_timer: float = 0.0

# --- Nodes ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stats = $Stats
@onready var hurtbox = $HurtBox
@onready var player_detection = $PlayerDetectionArea

# --- State machine ---
enum { WANDER, SLEEP, FLEE }
var state = WANDER

# --- Variables ---
var move_velocity: Vector2 = Vector2.ZERO
var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var home_position: Vector2
var wander_count: int = 0
var sleeping: bool = false
var dying: bool = false
var player: Node2D = null
var flee_timer: float = 0.0

func _ready() -> void:
	home_position = global_position
	sprite.play("Idle")

func _physics_process(delta: float) -> void:
	match state:
		WANDER:
			_do_wander(delta)

		SLEEP:
			move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta)
			if not sleeping:
				sleeping = true
				sprite.play("Sleep")

			# countdown timer
			sleep_timer -= delta
			if sleep_timer <= 0:
				state = WANDER
				sleeping = false
				wander_count = 0


		FLEE:
			_do_flee(delta)

	# --- Flip sprite depending on movement ---
	if abs(move_velocity.x) > 1:
		sprite.flip_h = move_velocity.x < 0

	# --- Apply movement for all states ---
	if not dying:
		velocity = move_velocity
		move_and_slide()

# --- Wander logic ---
func _do_wander(delta: float) -> void:
	if wall_escape_timer > 0:
		# Committed detour to escape wall
		wall_escape_timer -= delta
		move_velocity = move_velocity.move_toward(wall_escape_dir * maxspeed, acceleration * delta)
	else:
		wander_timer -= delta
		if wander_timer <= 0:
			pick_new_wander_direction()
			wander_timer = wander_change_interval
			wander_count += 1

			# After 7 wander cycles, roll for sleep chance
			if wander_count >= 7:
				wander_count = 0
				if randf() < sleep_chance:
					state = SLEEP
					sleep_timer = sleep_duration
					return

		# Normal wander movement
		move_velocity = move_velocity.move_toward(wander_direction * maxspeed, acceleration * delta)

		# Keep near home
		if global_position.distance_to(home_position) > wander_radius:
			var dir_to_home = (home_position - global_position).normalized()
			move_velocity = move_velocity.move_toward(dir_to_home * maxspeed, acceleration * delta)

		# --- Wall avoidance ---
		if is_on_wall():
			# Commit to a detour for a while
			wall_escape_dir = wander_direction.rotated(randf_range(-1.0, 1.0)).normalized()
			wall_escape_timer = wall_escape_time
			move_velocity = wall_escape_dir * maxspeed

	# Play walk or idle animation
	if move_velocity.length() > 5:
		if sprite.animation != "Walk":
			sprite.play("Walk")
	else:
		if sprite.animation != "Idle":
			sprite.play("Idle")


# --- Pick random wander direction ---
func pick_new_wander_direction() -> void:
	wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

# --- Flee logic ---
func _do_flee(delta: float) -> void:
	if wall_escape_timer > 0:
		# Committed wall escape movement
		wall_escape_timer -= delta
		move_velocity = move_velocity.move_toward(wall_escape_dir * current_flee_speed, acceleration * delta)
	else:
		if player:
			var dir = (global_position - player.global_position).normalized()

			# Zigzag fleeing (random dodge offset)
			dir = dir.rotated(randf_range(-flee_dodge_strength, flee_dodge_strength))

			# --- Gradual flee speed increase ---
			flee_accel_timer += delta
			if flee_accel_timer >= flee_accel_interval:
				flee_accel_timer = 0.0
				current_flee_speed = min(current_flee_speed + flee_accel_step, flee_speed)

			# Move away with gradual speed
			move_velocity = move_velocity.move_toward(dir * current_flee_speed, acceleration * delta)

			# --- Wall avoidance ---
			if is_on_wall():
				# Pick a committed detour for 2 sec
				wall_escape_dir = dir.rotated(randf_range(-1.0, 1.0)).normalized()
				wall_escape_timer = wall_escape_time
				move_velocity = wall_escape_dir * current_flee_speed

			# Always play run animation while fleeing
			if sprite.animation != "Run":
				sprite.play("Run")

			# Check if safe distance reached
			if global_position.distance_to(player.global_position) > safe_distance:
				flee_timer += delta
				if flee_timer >= flee_cooldown:
					player = null
					state = WANDER
					flee_timer = 0.0
					current_flee_speed = 0.0  # reset after calming
		else:
			# no player but still in flee mode, gradually calm down
			flee_timer += delta
			if flee_timer >= flee_cooldown:
				state = WANDER
				flee_timer = 0.0
				current_flee_speed = 0.0  # reset

	# Apply velocity
	if not dying:
		velocity = move_velocity
		move_and_slide()

# --- When pig gets hurt ---
func _on_hurt_box_area_entered(area: Area2D) -> void:
	if dying:
		return

	stats.set_health(stats.health - area.damage)
	sprite.play("Hurt")

	if stats.health <= 0:
		dying = true
		sprite.play("Death")
		await sprite.animation_finished
		queue_free()
	else:
		# Switch to flee immediately after being hurt
		if player_detection.get_overlapping_bodies().size() > 0:
			player = player_detection.get_overlapping_bodies()[0]

		state = FLEE
		flee_timer = 0.0
		if sprite.animation != "Run":
			sprite.play("Run")

# --- Reset wander if woken up ---
func wake_up() -> void:
	if state == SLEEP and not dying:
		state = WANDER
		wander_count = 0
		sleeping = false

# --- Death from Stats signal ---
func _on_stats_no_health() -> void:
	if not dying:
		dying = true
		sprite.play("Death")
		await sprite.animation_finished
		queue_free()

# --- Player detection logic ---
func _on_player_detection_area_body_entered(body: Node2D) -> void:
	if stats.health < stats.max_health:
		player = body
		state = FLEE
		flee_timer = 0.0

func _on_player_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		# Don’t instantly return to wander; let flee logic handle cooldown
		player = null
