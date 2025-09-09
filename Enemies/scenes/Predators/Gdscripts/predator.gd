extends CharacterBody2D

# --- Combat / Knockback ---
var knockback: Vector2 = Vector2.ZERO
@export var knockback_speed: float = 180.0
@export var knockback_duration: float = 0.25

# --- Snake-like Movement ---
@export var slither_acceleration: float = 200
@export var slither_maxspeed: float = 85  # Faster than original plant, slower than cat
@export var slither_friction: float = 160
@export var wander_change_interval: float = 3.0
@export var wander_radius: float = 150

# --- Serpentine Motion ---
@export var serpentine_frequency: float = 4.0  # How fast the snake wiggles
@export var serpentine_amplitude: float = 15.0  # How wide the wiggle
@export var body_follow_segments: int = 8  # Visual trail segments
var serpentine_time: float = 0.0
var movement_trail: Array[Vector2] = []

# --- Snake Vine Attack System ---
@export var strike_range: float = 90.0  # Snake strike distance
@export var coil_grab_range: float = 70.0  # Close range grab
@export var strike_speed: float = 250.0  # Very fast strike
@export var attack_cooldown: float = 1.5
@export var strike_anticipation_time: float = 0.6
@export var coil_duration: float = 1.0  # How long it coils around target
var can_attack: bool = true
var is_striking: bool = false
var is_coiling: bool = false

# --- Snake Hunting Behavior ---
var has_los: bool = false
var last_seen_positions: Array[Vector2] = []
var hunt_target: Vector2
var hunting: bool = false
var los_memory_timer: float = 0.0
@export var los_memory_duration: float = 5.5
@export var stalk_distance: float = 110.0  # Stalking distance
var reached_last_seen: bool = false
var hunt_patience_timer: float = 0.0
@export var hunt_patience: float = 4.0

# --- Snake Navigation ---
@export var wall_avoid_distance: float = 50.0
@export var wall_avoid_strength: float = 100.0
var stuck_timer: float = 0.0
var last_position: Vector2
var search_angle: float = 0.0
@export var search_radius: float = 70.0
var dynamic_search_points: Array[Vector2] = []

# --- Snake Personality ---
@export var snake_aggression: float = 0.8  # More aggressive than plant
@export var territorial_behavior: float = 0.6  # Guards territory
var slither_intensity: float = 1.0
var territorial_timer: float = 0.0

# --- Nodes ---
@onready var hurtbox = $HurtBox
@onready var stats = $Stats
@onready var player_detection_area = $PlayerDetectionArea
@onready var sprite = $Sprite2D
@onready var soft_collision: Area2D = $SoftCollision
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_box: HitBox = $HitBox

# Player reference
var player: Node2D = null

# --- State machine ---
enum { IDLE, WANDER, STALK, COIL_READY, STRIKE, COILING, RETREAT, SEARCH, PATROL }
var state = IDLE

# --- Variables ---
var move_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var dying: bool = false
var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var home_position: Vector2

# Snake movement vars
var current_direction: Vector2 = Vector2.RIGHT
var target_direction: Vector2 = Vector2.RIGHT
var direction_change_speed: float = 3.0

# Attack vars
var strike_target: Vector2
var attack_timer: float = 0.0
var valid_strike_target: Vector2 = Vector2.ZERO
var pre_strike_position: Vector2

func _ready() -> void:
	home_position = global_position
	if hit_box:
		hit_box.damage = 2.5  # Strong snake bite
		hit_box.knockback_vector = Vector2(1, 0)
	last_position = global_position
	current_direction = Vector2.RIGHT
	
	# Initialize movement trail for serpentine effect
	for i in range(body_follow_segments):
		movement_trail.append(global_position)
	
	# Connect signals properly
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurt_box_area_entered)
	if stats:
		stats.no_health.connect(_on_stats_no_health)
	if player_detection_area:
		player_detection_area.body_entered.connect(_on_player_detection_area_body_entered)
		player_detection_area.body_exited.connect(_on_player_detection_area_body_exited)

func _physics_process(delta: float) -> void:
	serpentine_time += delta
	territorial_timer += delta
	check_if_stuck(delta)
	seek_player()
	update_movement_trail()
	
	match state:
		IDLE:
			handle_idle_behavior(delta)
			
		WANDER:
			handle_slither_wander(delta)
			
		STALK:
			if player != null:
				var dist = global_position.distance_to(player.global_position)
				if dist <= coil_grab_range and can_attack:
					state = COIL_READY
					attack_timer = strike_anticipation_time
					pre_strike_position = global_position
					move_velocity = Vector2.ZERO
					play_safe_animation("IdleDown")  # Coiling preparation
				else:
					stalk_with_serpentine_movement(player, delta)
					if move_velocity.length() > 0.1:
						play_directional_animation("Run", current_direction)
			else:
				if hunting:
					# Continue hunting behavior
					pass
				else:
					state = WANDER
					
		SEARCH:
			handle_serpentine_search(delta)
			
		PATROL:
			handle_territorial_patrol(delta)
			
		COIL_READY:
			attack_timer -= delta
			# Snake coils and prepares to strike
			var coil_wiggle = Vector2(sin(serpentine_time * 12) * 4, cos(serpentine_time * 10) * 3)
			move_velocity = coil_wiggle
			
			if attack_timer <= 0:
				if player != null:
					state = STRIKE
					attack_timer = 0.4  # Strike duration
					valid_strike_target = calculate_strike_target(player.global_position)
					is_striking = true
					move_velocity = Vector2.ZERO
					play_directional_animation("Attack", (valid_strike_target - global_position).normalized())
				else:
					state = WANDER
					move_velocity = Vector2.ZERO
					
		STRIKE:
			attack_timer -= delta
			# Lightning fast snake strike
			if valid_strike_target != Vector2.ZERO:
				var strike_dir = (valid_strike_target - global_position).normalized()
				move_velocity = strike_dir * strike_speed
				current_direction = strike_dir
				
				# Check if we hit the target or reached max distance
				if global_position.distance_to(valid_strike_target) < 20 or global_position.distance_to(pre_strike_position) > strike_range:
					state = COILING
					attack_timer = coil_duration
					is_striking = false
					is_coiling = true
			
			if attack_timer <= 0:
				state = RETREAT
				attack_timer = 0.8
				is_striking = false
				
		COILING:
			attack_timer -= delta
			# Snake wraps around target area
			var coil_motion = Vector2(sin(serpentine_time * 8) * 12, cos(serpentine_time * 8) * 12)
			move_velocity = coil_motion
			
			if attack_timer <= 0:
				state = RETREAT
				attack_timer = 0.6
				is_coiling = false
				
		RETREAT:
			attack_timer -= delta
			# Snake quickly retreats with serpentine motion
			var retreat_dir = (pre_strike_position - global_position).normalized()
			var serpentine_retreat = add_serpentine_motion(retreat_dir * slither_maxspeed * 1.2, delta)
			move_velocity = serpentine_retreat
			current_direction = retreat_dir
			
			if attack_timer <= 0:
				state = STALK
				can_attack = false
				get_tree().create_timer(attack_cooldown).timeout.connect(func(): can_attack = true)
				valid_strike_target = Vector2.ZERO
	
	# Apply serpentine movement
	apply_serpentine_movement(delta)

func calculate_strike_target(target_pos: Vector2) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var direction = (target_pos - global_position).normalized()
	var max_strike = min(strike_range, global_position.distance_to(target_pos) * 1.2)  # Overshoot slightly
	
	# Check if direct strike path is clear
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + direction * max_strike)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		return global_position + direction * max_strike
	
	# If blocked, strike as far as possible
	var safe_distance = global_position.distance_to(result["position"]) - 10
	return global_position + direction * max(safe_distance, 25)

func handle_idle_behavior(delta: float) -> void:
	# Snake idles with subtle slithering motion, facing last movement direction
	var idle_slither = Vector2(sin(serpentine_time * 2) * 2, cos(serpentine_time * 1.5) * 1.5)
	move_velocity = move_velocity.move_toward(idle_slither, slither_acceleration * delta * 0.3)
	
	# Face the direction of last significant movement (like after an attack)
	play_directional_animation("Idle", current_direction)
	
	# Snakes are more active than plants
	if randf() < 0.08:  # Higher chance to start moving
		state = WANDER

func handle_slither_wander(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0:
		pick_new_slither_direction()
		wander_timer = wander_change_interval + randf_range(-0.8, 0.8)
	
	# Apply wall avoidance
	var avoid_vector = get_wall_avoidance_vector()
	target_direction = (wander_direction + avoid_vector * 0.7).normalized()
	
	# Smooth direction changes (snakes don't turn instantly)
	current_direction = current_direction.move_toward(target_direction, direction_change_speed * delta)
	
	# Add serpentine motion to the movement
	var base_velocity = current_direction * slither_maxspeed
	var serpentine_velocity = add_serpentine_motion(base_velocity, delta)
	move_velocity = move_velocity.move_toward(serpentine_velocity, slither_acceleration * delta)
	
	# Stay near territory
	var home_distance = global_position.distance_to(home_position)
	if home_distance > wander_radius:
		var urgency = (home_distance - wander_radius) / wander_radius
		target_direction = (home_position - global_position).normalized()
		slither_intensity = 1.0 + urgency * 0.5
	
	if move_velocity.length() > 0.1:
		play_directional_animation("Run", current_direction)

func handle_serpentine_search(delta: float) -> void:
	search_angle += delta * 2.2
	
	if not last_seen_positions.is_empty():
		var center = last_seen_positions[-1]
		var search_pos = center + Vector2(cos(search_angle), sin(search_angle)) * search_radius
		
		target_direction = (search_pos - global_position).normalized()
		current_direction = current_direction.move_toward(target_direction, direction_change_speed * delta)
		
		var base_velocity = current_direction * slither_maxspeed * 0.7
		var serpentine_velocity = add_serpentine_motion(base_velocity, delta)
		move_velocity = move_velocity.move_toward(serpentine_velocity, slither_acceleration * delta)
		play_directional_animation("Run", current_direction)
		
		if search_angle > TAU or hunt_patience_timer <= 0:
			state = PATROL
			generate_patrol_points()

func handle_territorial_patrol(delta: float) -> void:
	hunt_patience_timer -= delta
	
	if dynamic_search_points.is_empty() or hunt_patience_timer <= 0:
		state = WANDER
		hunting = false
		return
	
	var target = dynamic_search_points[0]
	target_direction = (target - global_position).normalized()
	current_direction = current_direction.move_toward(target_direction, direction_change_speed * delta)
	
	# Patrol at moderate speed - more alert than wandering but not full chase
	var patrol_speed = slither_maxspeed * 0.75
	var patrol_velocity = current_direction * patrol_speed
	var serpentine_velocity = add_serpentine_motion(patrol_velocity, delta)
	move_velocity = move_velocity.move_toward(serpentine_velocity, slither_acceleration * delta)
	play_directional_animation("Run", current_direction)  # Alert patrolling
	
	if global_position.distance_to(target) < 20:
		dynamic_search_points.pop_front()

func generate_patrol_points() -> void:
	dynamic_search_points.clear()
	
	if last_seen_positions.size() >= 1:
		var last_pos = last_seen_positions[-1]
		
		# Create patrol points in a snake-like search pattern
		for i in range(3):
			var angle = (i * TAU / 3) + randf_range(-0.5, 0.5)
			var patrol_dir = Vector2(cos(angle), sin(angle))
			var distance = stalk_distance * (0.7 + randf() * 0.5)
			dynamic_search_points.append(last_pos + patrol_dir * distance)

func add_serpentine_motion(base_velocity: Vector2, delta: float) -> Vector2:
	# Create the classic snake slithering motion
	var perpendicular = Vector2(-base_velocity.y, base_velocity.x).normalized()
	var serpentine_offset = sin(serpentine_time * serpentine_frequency) * serpentine_amplitude * slither_intensity
	var serpentine_motion = perpendicular * serpentine_offset
	
	return base_velocity + serpentine_motion * delta * 60  # Scale for frame rate

func update_movement_trail() -> void:
	# Add current position to front, remove old positions
	movement_trail.push_front(global_position)
	if movement_trail.size() > body_follow_segments:
		movement_trail.pop_back()

func stalk_with_serpentine_movement(player_target: Node2D, delta: float) -> void:
	var target_pos: Vector2
	
	if has_los:
		target_pos = player_target.global_position
		reached_last_seen = false
		
		# Snakes approach with calculated precision
		var approach_distance = stalk_distance * 0.7
		var dir_to_player = (target_pos - global_position).normalized()
		target_pos = target_pos - dir_to_player * approach_distance
		
	elif hunting:
		hunt_patience_timer -= delta
		target_pos = get_snake_hunt_target()
		
		if hunt_patience_timer <= 0:
			state = SEARCH
			hunt_patience_timer = hunt_patience
			return
	else:
		target_pos = home_position
	
	target_direction = (target_pos - global_position).normalized()
	current_direction = current_direction.move_toward(target_direction, direction_change_speed * delta)
	
	# Snake stalking with serpentine motion
	var stalk_speed = slither_maxspeed * snake_aggression
	var base_velocity = current_direction * stalk_speed
	var serpentine_velocity = add_serpentine_motion(base_velocity, delta)
	move_velocity = move_velocity.move_toward(serpentine_velocity, slither_acceleration * delta)

func get_snake_hunt_target() -> Vector2:
	if last_seen_positions.is_empty():
		return hunt_target
	
	var last_seen_pos = last_seen_positions[-1]
	
	if not reached_last_seen:
		if global_position.distance_to(last_seen_pos) < 15.0:
			reached_last_seen = true
		return last_seen_pos
	
	# Snake prediction based on territorial knowledge
	if last_seen_positions.size() >= 2:
		var older_pos = last_seen_positions[-2]
		var recent_pos = last_seen_positions[-1]
		var movement_dir = (recent_pos - older_pos).normalized()
		
		var prediction_distance = stalk_distance * (0.8 + randf() * 0.6)
		return recent_pos + movement_dir * prediction_distance
	else:
		var flank_offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		return last_seen_pos + flank_offset

func check_if_stuck(delta: float) -> void:
	if global_position.distance_to(last_position) < 3:
		stuck_timer += delta
		if stuck_timer > 1.0:  # Snakes escape faster
			var escape_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			var escape_velocity = escape_dir * slither_maxspeed * 1.4
			move_velocity = add_serpentine_motion(escape_velocity, delta)
			stuck_timer = 0
			
			if stuck_timer > 2.5:
				var safe_pos = find_safe_snake_position()
				if safe_pos != Vector2.ZERO:
					global_position = safe_pos
				stuck_timer = 0
	else:
		stuck_timer = 0
		last_position = global_position

func find_safe_snake_position() -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var slither_distance = 45.0
	
	var angles = [0, PI/4, PI/2, 3*PI/4, PI, 5*PI/4, 3*PI/2, 7*PI/4]
	for angle in angles:
		var test_dir = Vector2(cos(angle), sin(angle))
		var test_pos = global_position + test_dir * slither_distance
		
		var query = PhysicsRayQueryParameters2D.create(global_position, test_pos)
		query.exclude = [self]
		var result = space_state.intersect_ray(query)
		
		if result.is_empty():
			return test_pos
	
	return Vector2.ZERO

func get_wall_avoidance_vector() -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var avoidance = Vector2.ZERO
	
	var directions = [
		Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
		Vector2.ONE.normalized(), Vector2(-1, 1).normalized()
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

func apply_serpentine_movement(delta: float) -> void:
	if knockback_timer > 0:
		velocity = knockback
		knockback_timer -= delta
		if knockback_timer <= 0 and dying:
			spawn_death_effect()
			queue_free()
	else:
		if not dying:
			var total_velocity = move_velocity
			
			# Soft collision (snakes are flexible)
			if soft_collision and soft_collision.is_colliding():
				total_velocity += soft_collision.get_push_vector() * delta * 250
			
			# Wall avoidance for moving snakes
			if move_velocity.length() > 5:
				var avoidance = get_wall_avoidance_vector()
				total_velocity += avoidance * delta * 0.9
			
			velocity = total_velocity
	
	move_and_slide()

func check_line_of_sight(player_target: Node2D) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player_target.global_position)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	return result.is_empty() or result["collider"] == player_target

func update_last_seen_positions(player_pos: Vector2) -> void:
	if last_seen_positions.is_empty() or last_seen_positions[-1].distance_to(player_pos) > 15.0:
		last_seen_positions.append(player_pos)
		if last_seen_positions.size() > 3:
			last_seen_positions.pop_front()

func seek_player() -> void:
	if not player:
		return
	
	if check_line_of_sight(player):
		has_los = true
		hunting = false
		los_memory_timer = los_memory_duration
		hunt_patience_timer = hunt_patience
		
		update_last_seen_positions(player.global_position)
		
		if state in [IDLE, WANDER, SEARCH, PATROL]:
			state = STALK
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
					state = STALK
		else:
			hunting = false
			reached_last_seen = false
			last_seen_positions.clear()
			dynamic_search_points.clear()
			if state in [STALK, COIL_READY, STRIKE, COILING, RETREAT, SEARCH, PATROL]:
				state = WANDER

func pick_new_slither_direction() -> void:
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

func play_directional_animation(anim_base: String, direction: Vector2) -> void:
	if not animation_player:
		return
		
	var anim_name = ""
	
	# Determine direction for animation
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			anim_name = anim_base + "Right"
		else:
			anim_name = anim_base + "Left"
	else:
		if direction.y > 0:
			anim_name = anim_base + "Down"
		else:
			anim_name = anim_base + "Up"
	
	# Fallback animations
	if not animation_player.has_animation(anim_name):
		if anim_base == "Run":
			anim_name = "RunDown"
		elif anim_base == "Idle":
			anim_name = "IdleDown"
		elif anim_base == "Attack":
			anim_name = "AttackDown"
	
	if not animation_player.has_animation(anim_name):
		anim_name = "IdleDown"
	
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)

func play_safe_animation(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)

# Signal handlers
func _on_hurt_box_area_entered(area: Area2D) -> void:
	if not area.has_method("get") or not area.get("damage") or not area.get("knockback_vector"):
		return
		
	knockback = area.knockback_vector * knockback_speed
	knockback_timer = knockback_duration
	
	if stats:
		stats.set_health(stats.health - area.damage)
	
	if hurtbox and hurtbox.has_method("create_hit_effect"):
		hurtbox.create_hit_effect()
	
	play_directional_animation("Hurt", knockback.normalized())
	
	if stats and stats.health <= 0:
		dying = true

func _on_stats_no_health() -> void:
	dying = true
	spawn_death_effect()
	queue_free()

func _on_player_detection_area_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.has_method("player"):
		player = body
		print("Snake detected player: ", body.name)

func _on_player_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		print("Player left snake's territory")

func spawn_death_effect() -> void:
	var effect_path = "res://Effects/bat_death.tscn"
	if ResourceLoader.exists(effect_path):
		var effect_scene = load(effect_path)
		var effect_instance = effect_scene.instantiate()
		effect_instance.global_position = global_position
		get_parent().add_child(effect_instance)
