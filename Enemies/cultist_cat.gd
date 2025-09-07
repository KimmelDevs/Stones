extends CharacterBody2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hurtbox = $HurtBox
@onready var stats = $Stats
@onready var playerdetectionzone = $PlayerDetectionArea
@onready var hitbox = $HitBox
@onready var soft_collision: Area2D = $SoftCollision

# --- Combat / Knockback ---
var knockback: Vector2 = Vector2.ZERO
@export var knockback_speed: float = 200.0
@export var knockback_duration: float = 0.2

# --- Movement ---
@export var acceleration: float = 180
@export var maxspeed: float = 60
@export var friction: float = 180
@export var wander_change_interval: float = 2.0
@export var wander_radius: float = 120

# --- Chase Movement ---
@export var chase_radius: float = 180.0
@export var approach_distance: float = 80.0  # Distance to start cartwheeling

# --- Attack System ---
@export var cartwheel_range: float = 60.0
@export var punch_range: float = 55.0
@export var attack_cooldown: float = 1.2
@export var cartwheel_speed: float = 120.0
@export var cartwheel_duration: float = 1
@export var cartwheel_windup_delay: float = 0.2
@export var punch_duration: float = 0.6
var can_attack: bool = true

# --- LOS Tracking ---
var has_los: bool = false
var last_seen_positions: Array[Vector2] = []
var search_target: Vector2
var searching: bool = false
var los_memory_timer: float = 0.0
@export var los_memory_duration: float = 4.0
@export var search_ahead_distance: float = 100.0
var reached_last_seen: bool = false
var search_patience_timer: float = 0.0
@export var search_patience: float = 2.5

# --- Wall Avoidance ---
@export var wall_avoid_distance: float = 60.0
@export var wall_avoid_strength: float = 120.0
var stuck_timer: float = 0.0
var last_position: Vector2

# --- State Machine ---
enum State { IDLE, WANDER, CHASE, CARTWHEEL_WINDUP, CARTWHEEL, PUNCH, RECOVER, SEARCH, HURT }
var state = State.IDLE

# --- Variables ---
var move_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var dying: bool = false
var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var home_position: Vector2

# Attack variables
var attack_target: Vector2
var attack_timer: float = 0.0
var cartwheel_direction: Vector2 = Vector2.ZERO
var current_facing: String = "right"  # Track which way we're facing
var hurt_timer: float = 0.0
@export var hurt_duration: float = 0.1
var cartwheel_windup_timer: float = 0.0

# Player tracking delay
var player_exit_timer: float = 0.0
@export var player_memory_time: float = 3.0

func _ready() -> void:
	home_position = global_position
	if hitbox:
		hitbox.damage = 2
		hitbox.knockback_vector = Vector2(1, 0)
	last_position = global_position
	# Start with proper walking animation
	current_facing = "right"
	animation_player.play("WalkRight")

func _physics_process(delta: float) -> void:
	check_if_stuck(delta)
	update_player_memory(delta)
	seek_player()
	
	match state:
		State.IDLE:
			handle_idle_behavior(delta)
		
		State.WANDER:
			handle_wander_behavior(delta)
		
		State.CHASE:
			handle_chase_behavior(delta)
		
		State.CARTWHEEL_WINDUP:
			handle_cartwheel_windup(delta)
		
		State.CARTWHEEL:
			handle_cartwheel_attack(delta)
		
		State.PUNCH:
			handle_punch_attack(delta)
		
		State.RECOVER:
			handle_recovery(delta)
		
		State.SEARCH:
			handle_search_behavior(delta)
		
		State.HURT:
			handle_hurt_behavior(delta)
	
	# Apply movement
	apply_movement_with_avoidance(delta)

func handle_idle_behavior(delta: float) -> void:
	move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta)
	update_animation_and_facing()
	
	# Occasionally start wandering
	if randf() < 0.01:
		state = State.WANDER

func handle_wander_behavior(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0:
		pick_new_wander_direction()
		wander_timer = wander_change_interval + randf_range(-0.5, 0.5)
	
	# Apply wall avoidance
	var avoid_vector = get_wall_avoidance_vector()
	var final_direction = (wander_direction + avoid_vector * 0.5).normalized()
	
	move_velocity = move_velocity.move_toward(final_direction * maxspeed * 0.6, acceleration * delta)
	
	# Stay near home
	var home_distance = global_position.distance_to(home_position)
	if home_distance > wander_radius:
		var dir_to_home = (home_position - global_position).normalized()
		move_velocity = move_velocity.move_toward(dir_to_home * maxspeed, acceleration * delta)
	
	update_animation_and_facing()

func handle_chase_behavior(delta: float) -> void:
	var player = playerdetectionzone.player
	if not player:
		state = State.WANDER
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Check if we should attack
	if distance_to_player <= cartwheel_range and distance_to_player > punch_range and can_attack:
		# Cartwheel attack
		start_cartwheel_attack(player.global_position)
		return
	elif distance_to_player <= punch_range and can_attack:
		# Punch attack
		start_punch_attack(player.global_position)
		return
	
	# Chase the player
	var target_pos: Vector2
	if has_los:
		target_pos = player.global_position
		reached_last_seen = false
	elif searching:
		target_pos = get_intelligent_search_target()
		search_patience_timer -= delta
		if search_patience_timer <= 0:
			state = State.SEARCH
			return
	else:
		target_pos = home_position
	
	var dir = (target_pos - global_position).normalized()
	move_velocity = move_velocity.move_toward(dir * maxspeed, acceleration * delta)
	
	update_animation_and_facing()

func handle_cartwheel_windup(delta: float) -> void:
	cartwheel_windup_timer -= delta
	move_velocity = Vector2.ZERO  # Stay still during windup
	
	if cartwheel_windup_timer <= 0:
		# Start the actual cartwheel movement
		state = State.CARTWHEEL
		attack_timer = cartwheel_duration

func handle_cartwheel_attack(delta: float) -> void:
	attack_timer -= delta
	
	# Move in cartwheel direction
	move_velocity = cartwheel_direction * cartwheel_speed
	
	if attack_timer <= 0:
		state = State.RECOVER
		attack_timer = 0.5  # Slightly longer recovery after cartwheel
		move_velocity = Vector2.ZERO

func handle_punch_attack(delta: float) -> void:
	attack_timer -= delta
	move_velocity = Vector2.ZERO  # Stay still during punch
	
	if attack_timer <= 0:
		state = State.RECOVER
		attack_timer = 0.4  # Recovery time
		move_velocity = Vector2.ZERO

func handle_recovery(delta: float) -> void:
	attack_timer -= delta
	move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta * 2)
	update_animation_and_facing()
	
	if attack_timer <= 0:
		state = State.CHASE
		start_attack_cooldown()

func handle_search_behavior(delta: float) -> void:
	search_patience_timer -= delta
	
	if search_patience_timer <= 0 or last_seen_positions.is_empty():
		state = State.WANDER
		return
	
	var target = last_seen_positions[-1] if not last_seen_positions.is_empty() else home_position
	var dir = (target - global_position).normalized()
	
	move_velocity = move_velocity.move_toward(dir * maxspeed * 0.7, acceleration * delta)
	update_animation_and_facing()
	
	# Reached search target
	if global_position.distance_to(target) < 30:
		state = State.WANDER

func handle_hurt_behavior(delta: float) -> void:
	hurt_timer -= delta
	# Stay mostly still during hurt animation, but allow knockback movement
	if knockback_timer <= 0:
		move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta * 3)
	
	if hurt_timer <= 0:
		# Return to previous state or chase if player is nearby
		var player = playerdetectionzone.player
		if player and has_los and global_position.distance_to(player.global_position) <= chase_radius:
			state = State.CHASE
		else:
			state = State.WANDER
		# Force animation update when exiting hurt state
		update_animation_and_facing()

func update_player_memory(delta: float) -> void:
	# Handle delayed player nulling
	if player_exit_timer > 0:
		player_exit_timer -= delta
		if player_exit_timer <= 0:
			playerdetectionzone.player = null

func start_cartwheel_attack(target_pos: Vector2) -> void:
	state = State.CARTWHEEL_WINDUP
	cartwheel_windup_timer = cartwheel_windup_delay
	cartwheel_direction = (target_pos - global_position).normalized()
	attack_target = target_pos
	can_attack = false
	
	# Play cartwheel animation based on direction during windup
	if cartwheel_direction.x >= 0:
		current_facing = "right"
		animation_player.play("CartWheelRight")
	else:
		current_facing = "left"
		animation_player.play("CartWheelLeft")
	
	# Update hitbox direction
	if hitbox:
		hitbox.knockback_vector = cartwheel_direction

func start_punch_attack(target_pos: Vector2) -> void:
	state = State.PUNCH
	attack_timer = punch_duration
	attack_target = target_pos
	can_attack = false
	
	# Determine punch direction
	var dir_to_target = (target_pos - global_position).normalized()
	if dir_to_target.x >= 0:
		current_facing = "right"
		animation_player.play("PunchRight")
	else:
		current_facing = "left"
		animation_player.play("PunchLeft")
	
	# Update hitbox direction
	if hitbox:
		hitbox.knockback_vector = dir_to_target

func start_attack_cooldown() -> void:
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func update_animation_and_facing() -> void:
	if state in [State.CARTWHEEL_WINDUP, State.CARTWHEEL, State.PUNCH, State.HURT]:
		return  # Don't change animation during attacks or hurt state
	
	var is_moving = move_velocity.length() > 5.0
	var new_facing = ""
	
	if is_moving:
		# Determine facing based on movement direction
		if move_velocity.x >= 0:
			new_facing = "right"
		else:
			new_facing = "left"
	else:
		# Keep current facing when not moving
		new_facing = current_facing
	
	# Update animation if facing changed or if we need to ensure walk animation is playing
	if new_facing != current_facing or (is_moving and not animation_player.current_animation.begins_with("Walk")):
		current_facing = new_facing
		if is_moving:
			if current_facing == "right":
				animation_player.play("WalkRight")
			else:
				animation_player.play("WalkLeft")
		# If not moving, keep current animation (could add idle animations here later)

func check_if_stuck(delta: float) -> void:
	if global_position.distance_to(last_position) < 3:
		stuck_timer += delta
		if stuck_timer > 1.0:
			var escape_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			move_velocity = escape_dir * maxspeed * 1.2
			stuck_timer = 0
	else:
		stuck_timer = 0
		last_position = global_position

func get_wall_avoidance_vector() -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var avoidance = Vector2.ZERO
	
	var directions = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	
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
			spawn_death_effect()
			queue_free()
	else:
		if not dying:
			var total_velocity = move_velocity
			
			# Soft collision
			if soft_collision and soft_collision.is_colliding():
				total_velocity += soft_collision.get_push_vector() * delta * 300
			
			# Wall avoidance during movement
			if move_velocity.length() > 10 and state not in [State.CARTWHEEL_WINDUP, State.CARTWHEEL]:
				var avoidance = get_wall_avoidance_vector()
				total_velocity += avoidance * delta
			
			velocity = total_velocity
	
	move_and_slide()

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
		
		if state in [State.IDLE, State.WANDER, State.SEARCH]:
			state = State.CHASE
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
				if state in [State.IDLE, State.WANDER]:
					state = State.CHASE
		else:
			searching = false
			reached_last_seen = false
			last_seen_positions.clear()
			if state in [State.CHASE, State.SEARCH] and not state in [State.CARTWHEEL_WINDUP, State.CARTWHEEL, State.PUNCH, State.RECOVER, State.HURT]:
				state = State.WANDER

func check_line_of_sight(player: Node2D) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	return result.is_empty() or result["collider"] == player

func update_last_seen_positions(player_pos: Vector2) -> void:
	if last_seen_positions.is_empty() or last_seen_positions[-1].distance_to(player_pos) > 25.0:
		last_seen_positions.append(player_pos)
		if last_seen_positions.size() > 2:
			last_seen_positions.pop_front()

func get_intelligent_search_target() -> Vector2:
	if last_seen_positions.is_empty():
		return search_target
	
	var last_seen_pos = last_seen_positions[-1]
	
	if not reached_last_seen:
		if global_position.distance_to(last_seen_pos) < 20.0:
			reached_last_seen = true
		return last_seen_pos
	
	# Predict player movement
	if last_seen_positions.size() >= 2:
		var movement_dir = (last_seen_positions[-1] - last_seen_positions[-2]).normalized()
		return last_seen_positions[-1] + movement_dir * search_ahead_distance
	else:
		return last_seen_pos

func pick_new_wander_direction() -> void:
	var attempts = 0
	var best_direction = Vector2.ZERO
	
	while attempts < 3:
		var test_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var avoidance = get_wall_avoidance_vector()
		
		if avoidance.dot(test_dir) > -0.3:
			best_direction = test_dir
			break
		attempts += 1
	
	wander_direction = best_direction if best_direction != Vector2.ZERO else Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func spawn_death_effect() -> void:
	# Add your death effect here
	pass

# --- Signal Handlers ---
func _on_hurt_box_area_entered(area: Area2D) -> void:
	# Don't get hurt again if already in hurt state
	if state == State.HURT:
		return
		
	knockback = area.knockback_vector * knockback_speed
	knockback_timer = knockback_duration
	
	# Determine hurt direction based on knockback
	if area.knockback_vector.x >= 0:
		current_facing = "right"
		animation_player.play("HurtRight")
	else:
		current_facing = "left"
		animation_player.play("HurtLeft")
	
	# Enter hurt state
	state = State.HURT
	hurt_timer = hurt_duration
	
	if stats:
		stats.set_health(stats.health - area.damage)
		if hurtbox and hurtbox.has_method("create_hit_effect"):
			hurtbox.create_hit_effect()
		if stats.health <= 0:
			dying = true

func _on_player_detection_area_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):  # Assuming this is the player
		playerdetectionzone.player = body
		player_exit_timer = 0  # Cancel any pending exit timer

func _on_player_detection_area_body_exited(body: Node2D) -> void:
	if playerdetectionzone.player == body:
		# Start the exit timer instead of immediately nulling
		player_exit_timer = player_memory_time

func _on_stats_no_health() -> void:
	dying = true
	spawn_death_effect()
	queue_free()
