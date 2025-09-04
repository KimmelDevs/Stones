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
@export var attack_range: float = 50.0
@export var attack_cooldown: float = 0.5
@export var attack_dive_speed: float = 180.0
@export var anticipation_time: float = 0.4
@export var recovery_time: float = 0.6
var can_attack: bool = true
@onready var hitbox = $HitBox

# --- LOS Tracking (ENHANCED) ---
var has_los: bool = false
var last_seen_positions: Array[Vector2] = []
var search_target: Vector2
var searching: bool = false
var los_memory_timer: float = 0.0
@export var los_memory_duration: float = 5.0
@export var search_ahead_distance: float = 120.0
var reached_last_seen: bool = false
var search_patience_timer: float = 0.0
@export var search_patience: float = 3.0

# --- Wall Avoidance & Liveliness ---
@export var wall_avoid_distance: float = 80.0
@export var wall_avoid_strength: float = 150.0
var stuck_timer: float = 0.0
var last_position: Vector2
var circle_search_angle: float = 0.0
@export var circle_search_radius: float = 60.0
var dynamic_search_points: Array[Vector2] = []

# --- Personality/Behavior ---
@export var curiosity_factor: float = 0.3
@export var restlessness: float = 0.02
var idle_fidget_timer: float = 0.0
var personality_timer: float = 0.0

# --- Nodes ---
@onready var hurtbox = $HurtBox
@onready var stats = $Stats
@onready var playerdetectionzone = $PlayerDetectionArea
@onready var sprite = $AnimatedSprite2D
@onready var soft_collision: Area2D = $SoftCollision

# --- State machine ---
enum { IDLE, WANDER, CHASE, ANTICIPATE, DIVE, RECOVER, CIRCLE_SEARCH, INVESTIGATE }
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

# Attack vars
var attack_target: Vector2
var attack_timer: float = 0.0

func _ready() -> void:
	home_position = global_position
	hitbox.damage = 2
	hitbox.knockback_vector = Vector2(1, 0)
	last_position = global_position

func _physics_process(delta: float) -> void:
	check_if_stuck(delta)
	seek_player()

	match state:
		IDLE:
			handle_idle_behavior(delta)

		WANDER:
			handle_wander_behavior(delta)

		CHASE:
			var player = playerdetectionzone.player
			if player != null:
				var dist = global_position.distance_to(player.global_position)
				if dist <= attack_range and can_attack:
					state = ANTICIPATE
					attack_timer = anticipation_time
					attack_target = player.global_position
					move_velocity = Vector2.ZERO
				else:
					_chase_with_intelligent_search(player, delta)

		CIRCLE_SEARCH:
			handle_circle_search(delta)

		INVESTIGATE:
			handle_investigation(delta)

		ANTICIPATE:
			attack_timer -= delta
			if attack_timer <= 0:
				state = DIVE
				attack_timer = 0.0

		DIVE:
			var dir = (attack_target - global_position).normalized()
			move_velocity = dir * attack_dive_speed
			if global_position.distance_to(attack_target) < 10:
				state = RECOVER
				attack_timer = recovery_time
				move_velocity = Vector2.ZERO

		RECOVER:
			attack_timer -= delta
			if attack_timer <= 0:
				state = CHASE
				can_attack = false
				await get_tree().create_timer(attack_cooldown).timeout
				can_attack = true

	# Apply movement with wall avoidance
	apply_movement_with_avoidance(delta)

func handle_idle_behavior(delta: float) -> void:
	# Add fidgeting and restlessness
	idle_fidget_timer -= delta
	
	if idle_fidget_timer <= 0:
		# Occasional small movements to look alive
		var fidget_dir = Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		move_velocity = move_velocity.move_toward(fidget_dir * maxspeed * 0.2, acceleration * delta * 0.5)
		idle_fidget_timer = randf_range(2.0, 4.0)
	else:
		move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta)
	
	# Chance to start wandering (restlessness)
	if randf() < restlessness:
		state = WANDER

func handle_wander_behavior(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0:
		pick_new_wander_direction()
		wander_timer = wander_change_interval + randf_range(-0.5, 0.5)  # Add variety
	
	# Apply wall avoidance to wander direction
	var avoid_vector = get_wall_avoidance_vector()
	var final_direction = (wander_direction + avoid_vector * 0.7).normalized()
	
	move_velocity = move_velocity.move_toward(final_direction * maxspeed, acceleration * delta)

	# Keep near home with some flexibility
	var home_distance = global_position.distance_to(home_position)
	if home_distance > wander_radius:
		var urgency = (home_distance - wander_radius) / wander_radius
		var dir_to_home = (home_position - global_position).normalized()
		move_velocity = move_velocity.move_toward(dir_to_home * maxspeed, acceleration * delta * (1.0 + urgency))

	# Face where moving
	if move_velocity.length() > 0.1:
		update_sprite_facing(move_velocity)

func handle_circle_search(delta: float) -> void:
	circle_search_angle += delta * 2.0  # Adjust speed as needed
	
	if not last_seen_positions.is_empty():
		var center = last_seen_positions[-1]
		var search_pos = center + Vector2(cos(circle_search_angle), sin(circle_search_angle)) * circle_search_radius
		
		var dir = (search_pos - global_position).normalized()
		move_velocity = move_velocity.move_toward(dir * maxspeed * 0.8, acceleration * delta)
		update_sprite_facing(dir)
		
		# Switch to investigation if we complete a circle or time out
		if circle_search_angle > TAU or search_patience_timer <= 0:
			state = INVESTIGATE
			generate_dynamic_search_points()

func handle_investigation(delta: float) -> void:
	search_patience_timer -= delta
	
	if dynamic_search_points.is_empty() or search_patience_timer <= 0:
		state = WANDER
		return
	
	var target = dynamic_search_points[0]
	var dir = (target - global_position).normalized()
	
	# Add some organic movement
	var organic_offset = Vector2(sin(personality_timer * 3) * 10, cos(personality_timer * 2.5) * 8)
	var final_target = target + organic_offset
	dir = (final_target - global_position).normalized()
	
	move_velocity = move_velocity.move_toward(dir * maxspeed * 0.7, acceleration * delta)
	update_sprite_facing(dir)
	
	# Reached this search point
	if global_position.distance_to(target) < 25:
		dynamic_search_points.pop_front()

func generate_dynamic_search_points() -> void:
	dynamic_search_points.clear()
	
	if last_seen_positions.size() >= 2:
		var last_pos = last_seen_positions[-1]
		var movement_dir = (last_seen_positions[-1] - last_seen_positions[-2]).normalized()
		
		# Create multiple search points in an arc around predicted direction
		for i in range(3):
			var angle_offset = (i - 1) * 0.8  # Spread of search arc
			var search_dir = movement_dir.rotated(angle_offset)
			var distance = search_ahead_distance * (0.7 + randf() * 0.6)  # Vary distances
			dynamic_search_points.append(last_pos + search_dir * distance)

func check_if_stuck(delta: float) -> void:
	personality_timer += delta
	
	# Check if we're stuck
	if global_position.distance_to(last_position) < 5:
		stuck_timer += delta
		if stuck_timer > 1.0:  # Stuck for 1 second
			# Force unstuck behavior
			var escape_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			move_velocity = escape_dir * maxspeed * 1.5
			stuck_timer = 0
	else:
		stuck_timer = 0
		last_position = global_position

func get_wall_avoidance_vector() -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var avoidance = Vector2.ZERO
	
	# Cast rays in multiple directions
	var directions = [
		Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
		Vector2.ONE.normalized(), Vector2(-1, 1).normalized(),
		Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()
	]
	
	for dir in directions:
		var query = PhysicsRayQueryParameters2D.create(
			global_position, 
			global_position + dir * wall_avoid_distance
		)
		query.exclude = [self]
		var result = space_state.intersect_ray(query)
		
		if not result.is_empty():
			var distance = global_position.distance_to(result["position"])
			var strength = (wall_avoid_distance - distance) / wall_avoid_distance
			avoidance -= dir * strength * wall_avoid_strength
	
	return avoidance

func apply_movement_with_avoidance(delta: float) -> void:
	if knockback_timer > 0:
		velocity = knockback
		knockback_timer -= delta
		if knockback_timer <= 0 and dying:
			spawn_Death_effect()
			queue_free()
	else:
		if not dying:
			var total_velocity = move_velocity
			
			# Soft collision
			if soft_collision.is_colliding():
				total_velocity += soft_collision.get_push_vector() * delta * 400
			
			# Wall avoidance (stronger when moving)
			if move_velocity.length() > 10:
				var avoidance = get_wall_avoidance_vector()
				total_velocity += avoidance * delta
			
			velocity = total_velocity
	
	move_and_slide()

func _chase_with_intelligent_search(player: Node2D, delta: float) -> void:
	var target: Vector2
	
	if has_los:
		# Direct chase with boxer-style movement
		target = player.global_position
		reached_last_seen = false
		
		# Add subtle sway to make movement more interesting
		sway_time += delta * sway_speed
		var sway_offset = Vector2(0, sin(sway_time) * sway_amplitude)
		target += sway_offset
		
	elif searching:
		search_patience_timer -= delta
		target = get_intelligent_search_target()
		
		# If we've been searching too long, switch to circle search
		if search_patience_timer <= 0:
			state = CIRCLE_SEARCH
			search_patience_timer = search_patience
			return
	else:
		target = home_position

	var dir = (target - global_position).normalized()
	
	# Add unpredictability to chase
	if randf() < unpredictability:
		var random_offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		dir = (target + random_offset - global_position).normalized()
	
	move_velocity = move_velocity.move_toward(dir * maxspeed, acceleration * delta)
	update_sprite_facing(dir)

func get_intelligent_search_target() -> Vector2:
	if last_seen_positions.is_empty():
		return search_target
	
	var last_seen_pos = last_seen_positions[-1]
	
	# Go to last seen position first
	if not reached_last_seen:
		if global_position.distance_to(last_seen_pos) < 15.0:
			reached_last_seen = true
		return last_seen_pos
	
	# Predict based on movement pattern
	if last_seen_positions.size() >= 2:
		var older_pos = last_seen_positions[-2]
		var recent_pos = last_seen_positions[-1]
		var movement_dir = (recent_pos - older_pos).normalized()
		
		# Add some randomness to prediction
		var prediction_distance = search_ahead_distance * (0.8 + randf() * 0.4)
		return recent_pos + movement_dir * prediction_distance
	else:
		# Create a search pattern around last known position
		var search_offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
		return last_seen_pos + search_offset

func check_line_of_sight(player: Node2D) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	return result.is_empty() or result["collider"] == player

func update_last_seen_positions(player_pos: Vector2) -> void:
	if last_seen_positions.is_empty() or last_seen_positions[-1].distance_to(player_pos) > 20.0:
		last_seen_positions.append(player_pos)
		if last_seen_positions.size() > 2:
			last_seen_positions.pop_front()

func seek_player() -> void:
	var player = playerdetectionzone.player
	if not player:
		return

	if check_line_of_sight(player):
		has_los = true
		searching = false
		los_memory_timer = los_memory_duration
		search_patience_timer = search_patience
		
		update_last_seen_positions(player.global_position)
		
		if state in [IDLE, WANDER, CIRCLE_SEARCH, INVESTIGATE]:
			state = CHASE
	else:
		has_los = false
		
		if los_memory_timer > 0:
			los_memory_timer -= get_process_delta_time()
			
			if not searching:
				if not last_seen_positions.is_empty():
					search_target = last_seen_positions[-1]
				searching = true
				reached_last_seen = false
				search_patience_timer = search_patience
				state = CHASE
		else:
			# Memory expired
			searching = false
			reached_last_seen = false
			last_seen_positions.clear()
			dynamic_search_points.clear()
			if state in [CHASE, ANTICIPATE, DIVE, RECOVER, CIRCLE_SEARCH, INVESTIGATE]:
				state = WANDER

func pick_new_wander_direction() -> void:
	# Smarter wander direction picking with wall awareness
	var attempts = 0
	var best_direction = Vector2.ZERO
	
	while attempts < 5:
		var test_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var avoidance = get_wall_avoidance_vector()
		
		# Prefer directions that don't lead to walls
		if avoidance.dot(test_dir) > -0.5:  # Not directly into wall
			best_direction = test_dir
			break
		attempts += 1
	
	wander_direction = best_direction if best_direction != Vector2.ZERO else Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func _on_hurt_box_area_entered(area: Area2D) -> void:
	knockback = area.knockback_vector * knockback_speed
	knockback_timer = knockback_duration
	stats.set_health(stats.health - area.damage)
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
