extends CharacterBody2D

# --- Combat / Knockback ---
var knockback: Vector2 = Vector2.ZERO
@export var knockback_speed: float = 200.0
@export var knockback_duration: float = 0.2

# --- Movement ---
@export var acceleration: float = 180
@export var maxspeed: float = 60
@export var friction: float = 180
@export var wander_change_interval: float = 2.0
@export var wander_radius: float = 200

# --- Chase with Cat-like Movement ---
@export var chase_radius: float = 250.0
@export var prowl_sway_speed: float = 3.0
@export var prowl_sway_amplitude: float = 12.0
@export var feline_unpredictability: float = 0.01  # Cats are unpredictable

# --- Pounce Attack (Cat-specific) ---
@export var sneak_distance: float = 20.0
@export var attack_range: float = 50.0
@export var attack_cooldown: float = 0.8
@export var attack_dive_speed: float = 200.0
@export var anticipation_time: float = 0.5
@export var recovery_time: float = 0.4
var can_attack: bool = true
@onready var hitbox = $HitBox
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# --- Advanced LOS & Hunting Behavior ---
var has_los: bool = false
var last_seen_positions: Array[Vector2] = []
var hunt_target: Vector2
var hunting: bool = false
var los_memory_timer: float = 0.0
@export var los_memory_duration: float = 5.0
@export var stalk_ahead_distance: float = 100.0
var reached_last_seen: bool = false
var hunt_patience_timer: float = 0.0
@export var hunt_patience: float = 3.5

# --- Wall Avoidance & Feline Grace ---
@export var wall_avoid_distance: float = 70.0
@export var wall_avoid_strength: float = 120.0
var stuck_timer: float = 0.0
var last_position: Vector2
var circle_search_angle: float = 0.0
@export var circle_search_radius: float = 55.0
var dynamic_search_points: Array[Vector2] = []

# --- Cat Personality ---
@export var curiosity_factor: float = 0.35
@export var laziness: float = 0.015  # Higher than bats - cats are lazy
var idle_fidget_timer: float = 0.0
var personality_timer: float = 0.0

# --- Nodes ---
@onready var hurtbox = $HurtBox
@onready var stats = $Stats
@onready var playerdetectionzone = $PlayerDetectionArea
@onready var sprite = $Sprite2D
@onready var soft_collision: Area2D = $SoftCollision

# --- State machine ---
enum { IDLE, WANDER, CHASE, SNEAK, ANTICIPATE, DIVE, RECOVER, CIRCLE_SEARCH, INVESTIGATE }
var state = IDLE

# --- Variables ---
var move_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var dying: bool = false
var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var home_position: Vector2
var has_sneaked: bool = false

# Cat movement vars
var sway_time: float = 0.0
var prowl_intensity: float = 1.0

# Attack vars
var attack_target: Vector2
var attack_timer: float = 0.0
var valid_attack_target: Vector2 = Vector2.ZERO  # Safe target position

func _ready() -> void:
	home_position = global_position
	hitbox.damage = 1.8
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
				if dist <= sneak_distance and can_attack:
					state = SNEAK
					attack_timer = 0.5
					move_velocity = Vector2.ZERO
					anim_player.play("Attack")
				else:
					chase_with_feline_intelligence(player, delta)
					if anim_player.current_animation != "Walk":
						anim_player.play("Walk")
			else:
				if hunting:
					# Continue hunting behavior
					pass
				else:
					state = WANDER

		CIRCLE_SEARCH:
			handle_circle_search(delta)

		INVESTIGATE:
			handle_investigation(delta)

		SNEAK:
			attack_timer -= delta
			# Add slight stalking movement
			var stalk_wiggle = Vector2(sin(personality_timer * 6) * 3, cos(personality_timer * 4) * 2)
			move_velocity = stalk_wiggle
			
			if attack_timer <= 0:
				if playerdetectionzone.player != null:
					state = ANTICIPATE
					attack_timer = anticipation_time
					# Find a safe attack target position
					valid_attack_target = find_safe_attack_position(playerdetectionzone.player.global_position)
					move_velocity = Vector2.ZERO
					anim_player.play("ReadyJump")
				else:
					state = WANDER
					move_velocity = Vector2.ZERO

		ANTICIPATE:
			attack_timer -= delta
			# Cat wiggles before pouncing
			var anticipation_wiggle = Vector2(sin(personality_timer * 10) * 4, 0)
			move_velocity = anticipation_wiggle
			
			if attack_timer <= 0:
				if valid_attack_target != Vector2.ZERO:
					state = DIVE
					anim_player.play("LandAttack")
				else:
					state = WANDER

		DIVE:
			if valid_attack_target != Vector2.ZERO:
				var dir = (valid_attack_target - global_position).normalized()
				move_velocity = dir * attack_dive_speed
				update_sprite_facing(dir)
				if global_position.distance_to(valid_attack_target) < 15:
					state = RECOVER
					attack_timer = recovery_time
					move_velocity = Vector2.ZERO
					anim_player.play("LandAttack")
					valid_attack_target = Vector2.ZERO
			else:
				state = WANDER
				move_velocity = Vector2.ZERO

		RECOVER:
			attack_timer -= delta
			# Cat lands and looks around alertly
			var alert_look = Vector2(cos(personality_timer * 8) * 6, 0)
			move_velocity = alert_look
			
			if attack_timer <= 0:
				state = CHASE
				can_attack = false
				await get_tree().create_timer(attack_cooldown).timeout
				can_attack = true

	# Apply movement with feline grace
	apply_movement_with_avoidance(delta)

func find_safe_attack_position(target_pos: Vector2) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var direction = (target_pos - global_position).normalized()
	
	# First check if direct path to target is clear
	var query = PhysicsRayQueryParameters2D.create(global_position, target_pos)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	# If path is clear, use the target position
	if result.is_empty():
		return target_pos
	
	# If blocked, find the closest safe position along the path
	var safe_distance = global_position.distance_to(result["position"]) - 20  # Leave some buffer
	if safe_distance < 10:
		safe_distance = 10  # Minimum distance
	
	var safe_position = global_position + direction * safe_distance
	
	# Try alternative positions around the target if the direct path is blocked
	var angles = [0, PI/4, -PI/4, PI/2, -PI/2, 3*PI/4, -3*PI/4]
	for angle in angles:
		var test_dir = direction.rotated(angle)
		var test_pos = global_position + test_dir * min(safe_distance, global_position.distance_to(target_pos) * 0.8)
		
		# Check if this position is clear
		var test_query = PhysicsRayQueryParameters2D.create(global_position, test_pos)
		test_query.exclude = [self]
		var test_result = space_state.intersect_ray(test_query)
		
		if test_result.is_empty():
			return test_pos
	
	# If all else fails, return a safe position close to current location
	return global_position + direction * 20

func is_position_safe(pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	
	# Check in multiple directions around the position to ensure it's not inside a wall
	var check_directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	for dir in check_directions:
		var query = PhysicsRayQueryParameters2D.create(pos, pos + dir * 16)
		query.exclude = [self]
		var result = space_state.intersect_ray(query)
		
		# If we immediately hit something, this position might be inside a wall
		if not result.is_empty() and pos.distance_to(result["position"]) < 8:
			return false
	
	return true

func handle_idle_behavior(delta: float) -> void:
	idle_fidget_timer -= delta
	
	if idle_fidget_timer <= 0:
		# Cat-like fidgeting - grooming, stretching, etc.
		var fidget_type = randf()
		if fidget_type < 0.3:
			# Lazy stretch movement
			var stretch_dir = Vector2(randf_range(-0.2, 0.2), randf_range(-0.1, 0.1))
			move_velocity = move_velocity.move_toward(stretch_dir * maxspeed * 0.15, acceleration * delta * 0.4)
		elif fidget_type < 0.6:
			# Quick ear perk (small alert movement)
			var alert_dir = Vector2(randf_range(-0.4, 0.4), randf_range(-0.2, 0.2))
			move_velocity = move_velocity.move_toward(alert_dir * maxspeed * 0.3, acceleration * delta * 0.6)
		else:
			# Settle down
			move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta)
		
		idle_fidget_timer = randf_range(1.5, 4.0)
		if anim_player.current_animation != "Idle":
			anim_player.play("Idle")
	else:
		move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta)
	
	# Chance to start wandering (cat curiosity)
	if randf() < laziness * curiosity_factor:
		state = WANDER

func handle_wander_behavior(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0:
		pick_new_wander_direction()
		wander_timer = wander_change_interval + randf_range(-0.7, 0.7)
	
	# Apply wall avoidance to wander direction
	var avoid_vector = get_wall_avoidance_vector()
	var final_direction = (wander_direction + avoid_vector * 0.6).normalized()
	
	# Cat-like movement variations
	var movement_modifier = 1.0
	if randf() < 0.08:  # Sudden pause to sniff something
		movement_modifier = 0.05
	elif randf() < 0.03:  # Quick dart movement
		movement_modifier = 1.4
	
	move_velocity = move_velocity.move_toward(final_direction * maxspeed * movement_modifier, acceleration * delta)

	# Keep near home with feline independence
	var home_distance = global_position.distance_to(home_position)
	if home_distance > wander_radius:
		var urgency = (home_distance - wander_radius) / wander_radius
		var dir_to_home = (home_position - global_position).normalized()
		move_velocity = move_velocity.move_toward(dir_to_home * maxspeed, acceleration * delta * (1.0 + urgency * 0.8))

	# Face movement direction
	if move_velocity.length() > 0.1:
		update_sprite_facing(move_velocity)
		if anim_player.current_animation != "Walk":
			anim_player.play("Walk")

func handle_circle_search(delta: float) -> void:
	circle_search_angle += delta * 2.5  # Slightly faster than bat
	
	if not last_seen_positions.is_empty():
		var center = last_seen_positions[-1]
		var search_pos = center + Vector2(cos(circle_search_angle), sin(circle_search_angle)) * circle_search_radius
		
		var dir = (search_pos - global_position).normalized()
		# Cats move more cautiously when searching
		move_velocity = move_velocity.move_toward(dir * maxspeed * 0.7, acceleration * delta)
		update_sprite_facing(dir)
		
		if circle_search_angle > TAU or hunt_patience_timer <= 0:
			state = INVESTIGATE
			generate_dynamic_search_points()

func handle_investigation(delta: float) -> void:
	hunt_patience_timer -= delta
	
	if dynamic_search_points.is_empty() or hunt_patience_timer <= 0:
		state = WANDER
		hunting = false
		return
	
	var target = dynamic_search_points[0]
	var dir = (target - global_position).normalized()
	
	# Add cat-like cautious investigation movement
	var investigation_sway = Vector2(sin(personality_timer * 2) * 8, cos(personality_timer * 1.8) * 6)
	var final_target = target + investigation_sway
	dir = (final_target - global_position).normalized()
	
	move_velocity = move_velocity.move_toward(dir * maxspeed * 0.6, acceleration * delta)
	update_sprite_facing(dir)
	
	# Reached this search point
	if global_position.distance_to(target) < 20:
		dynamic_search_points.pop_front()

func generate_dynamic_search_points() -> void:
	dynamic_search_points.clear()
	
	if last_seen_positions.size() >= 2:
		var last_pos = last_seen_positions[-1]
		var movement_dir = (last_seen_positions[-1] - last_seen_positions[-2]).normalized()
		
		# Create search points in a cat-like pattern
		for i in range(3):
			var angle_offset = (i - 1) * 0.9
			var search_dir = movement_dir.rotated(angle_offset)
			var distance = stalk_ahead_distance * (0.6 + randf() * 0.7)
			dynamic_search_points.append(last_pos + search_dir * distance)

func check_if_stuck(delta: float) -> void:
	personality_timer += delta
	
	if global_position.distance_to(last_position) < 3:
		stuck_timer += delta
		if stuck_timer > 0.8:  # Cats get unstuck faster
			var escape_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			move_velocity = escape_dir * maxspeed * 1.3
			stuck_timer = 0
			
			# If really stuck, teleport to a safe nearby position
			if stuck_timer > 2.0:
				var safe_pos = find_safe_escape_position()
				if safe_pos != Vector2.ZERO:
					global_position = safe_pos
				stuck_timer = 0
	else:
		stuck_timer = 0
		last_position = global_position

func find_safe_escape_position() -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var escape_distance = 40.0
	
	# Try multiple directions to find a safe escape position
	var angles = [0, PI/4, PI/2, 3*PI/4, PI, 5*PI/4, 3*PI/2, 7*PI/4]
	for angle in angles:
		var test_dir = Vector2(cos(angle), sin(angle))
		var test_pos = global_position + test_dir * escape_distance
		
		# Check if path to this position is clear
		var query = PhysicsRayQueryParameters2D.create(global_position, test_pos)
		query.exclude = [self]
		var result = space_state.intersect_ray(query)
		
		if result.is_empty() and is_position_safe(test_pos):
			return test_pos
	
	return Vector2.ZERO  # No safe position found

func get_wall_avoidance_vector() -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var avoidance = Vector2.ZERO
	
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
			
			# Soft collision (cats are good at avoiding bumps)
			if soft_collision and soft_collision.is_colliding():
				total_velocity += soft_collision.get_push_vector() * delta * 300
			
			# Wall avoidance for moving cats
			if move_velocity.length() > 8:
				var avoidance = get_wall_avoidance_vector()
				total_velocity += avoidance * delta * 0.8
			
			velocity = total_velocity
	
	move_and_slide()

func chase_with_feline_intelligence(player: Node2D, delta: float) -> void:
	var target: Vector2
	
	if has_los:
		# Direct chase with cat-like prowling movement
		target = player.global_position
		reached_last_seen = false
		
		# Add prowling sway to make movement more cat-like
		sway_time += delta * prowl_sway_speed
		var prowl_offset = Vector2(0, sin(sway_time) * prowl_sway_amplitude)
		target += prowl_offset
		
	elif hunting:
		hunt_patience_timer -= delta
		target = get_intelligent_hunt_target()
		
		if hunt_patience_timer <= 0:
			state = CIRCLE_SEARCH
			hunt_patience_timer = hunt_patience
			return
	else:
		target = home_position

	var dir = (target - global_position).normalized()
	
	# Add cat unpredictability
	if randf() < feline_unpredictability:
		var random_offset = Vector2(randf_range(-25, 25), randf_range(-25, 25))
		dir = (target + random_offset - global_position).normalized()
	
	move_velocity = move_velocity.move_toward(dir * maxspeed, acceleration * delta)
	update_sprite_facing(dir)

func get_intelligent_hunt_target() -> Vector2:
	if last_seen_positions.is_empty():
		return hunt_target
	
	var last_seen_pos = last_seen_positions[-1]
	
	if not reached_last_seen:
		if global_position.distance_to(last_seen_pos) < 12.0:
			reached_last_seen = true
		return last_seen_pos
	
	# Predict based on movement pattern
	if last_seen_positions.size() >= 2:
		var older_pos = last_seen_positions[-2]
		var recent_pos = last_seen_positions[-1]
		var movement_dir = (recent_pos - older_pos).normalized()
		
		var prediction_distance = stalk_ahead_distance * (0.7 + randf() * 0.5)
		return recent_pos + movement_dir * prediction_distance
	else:
		var search_offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		return last_seen_pos + search_offset

func check_line_of_sight(player: Node2D) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	return result.is_empty() or result["collider"] == player

func update_last_seen_positions(player_pos: Vector2) -> void:
	if last_seen_positions.is_empty() or last_seen_positions[-1].distance_to(player_pos) > 15.0:
		last_seen_positions.append(player_pos)
		if last_seen_positions.size() > 2:
			last_seen_positions.pop_front()

func seek_player() -> void:
	var player = playerdetectionzone.player
	if not player:
		return

	if check_line_of_sight(player):
		has_los = true
		hunting = false
		los_memory_timer = los_memory_duration
		hunt_patience_timer = hunt_patience
		
		update_last_seen_positions(player.global_position)
		
		if state in [IDLE, WANDER, CIRCLE_SEARCH, INVESTIGATE]:
			state = CHASE
	else:
		has_los = false
		
		if los_memory_timer > 0:
			los_memory_timer -= get_process_delta_time()
			
			if not hunting:
				if not last_seen_positions.is_empty():
					hunt_target = last_seen_positions[-1]
				hunting = true
				reached_last_seen = false
				hunt_patience_timer = hunt_patience
				if state in [IDLE, WANDER]:
					state = CHASE
		else:
			hunting = false
			reached_last_seen = false
			last_seen_positions.clear()
			dynamic_search_points.clear()
			if state in [CHASE, ANTICIPATE, DIVE, RECOVER, CIRCLE_SEARCH, INVESTIGATE]:
				state = WANDER

func pick_new_wander_direction() -> void:
	var attempts = 0
	var best_direction = Vector2.ZERO
	
	while attempts < 4:
		var test_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var avoidance = get_wall_avoidance_vector()
		
		if avoidance.dot(test_dir) > -0.6:
			best_direction = test_dir
			break
		attempts += 1
	
	wander_direction = best_direction if best_direction != Vector2.ZERO else Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func _chase_aggressive(player: Node2D, delta: float) -> void:
	var dir = (player.global_position - global_position).normalized()
	move_velocity = move_velocity.move_toward(dir * maxspeed, acceleration * delta)
	update_sprite_facing(dir)

func _on_hurt_box_area_entered(area: Area2D) -> void:
	knockback = area.knockback_vector * knockback_speed
	knockback_timer = knockback_duration
	stats.set_health(stats.health - area.damage)
	hurtbox.create_hit_effect()
	if stats.health <= 0:
		dying = true

func spawn_Death_effect() -> void:
	var effect_scene = preload("res://Effects/bat_death.tscn")  # You might want to change this to cat_death.tscn
	var effect_instance = effect_scene.instantiate()
	effect_instance.global_position = global_position
	get_parent().add_child(effect_instance)

func update_sprite_facing(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		if direction.x < 0:
			sprite.flip_h = true
			hitbox.scale.x = -1
		else:
			sprite.flip_h = false
			hitbox.scale.x = 1
