extends CharacterBody2D

# --- Movement ---
@export var acceleration: float = 120
@export var maxspeed: float = 45
@export var flee_speed: float = 120
@export var friction: float = 200
@export var wander_change_interval: float = 2.0
@export var wander_radius: float = 120
@export var safe_distance: float = 280
@export var flee_dodge_strength: float = 0.6
@export var flee_cooldown: float = 1.5

# --- Line of Sight ---
var has_los: bool = false
var last_seen_position: Vector2
var searching: bool = false
var los_memory_timer: float = 0.0
@export var los_memory_duration: float = 3.0  # Shorter than bat - pigs forget faster
var search_timer: float = 0.0
@export var search_duration: float = 2.0

# --- Personality & Liveliness ---
@export var curiosity: float = 0.4          # How often pig investigates things
@export var nervousness: float = 0.3        # How jumpy/alert the pig is
@export var laziness: float = 0.7           # Tendency to rest/graze
@export var social_distance: float = 60.0   # Preferred distance from threats
var personality_timer: float = 0.0
var alert_timer: float = 0.0
var grazing_spots: Array[Vector2] = []

# --- Smart Behaviors ---
var last_danger_position: Vector2
var danger_memory_timer: float = 0.0
@export var danger_memory_duration: float = 8.0
@export var caution_radius: float = 150.0
var path_blocked_timer: float = 0.0
var stuck_prevention_timer: float = 0.0

# --- Wall Avoidance (Enhanced) ---
var wall_escape_timer: float = 0.0
var wall_escape_dir: Vector2 = Vector2.ZERO
@export var wall_escape_time: float = 1.5
@export var wall_detection_distance: float = 60.0
var last_position: Vector2

# --- Flee Enhancement ---
var current_flee_speed: float = 0.0
var flee_accel_timer: float = 0.0
@export var flee_accel_step: float = 10.0
@export var flee_accel_interval: float = 0.35
var flee_panic_level: float = 0.0        # Increases over time when fleeing
@export var initial_flee_speed: float = 65.0  # Start running immediately
var zigzag_timer: float = 0.0
var zigzag_direction: int = 1

# --- Sleep/Rest System (Enhanced) ---
@export var sleep_chance: float = 0.25
@export var sleep_duration: float = 200
@export var graze_chance: float = 0.6
@export var graze_duration: float = 120
var sleep_timer: float = 0.0
var activity_level: float = 1.0         # Decreases over time, increases after rest

# --- Nodes ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stats = $Stats
@onready var hurtbox = $HurtBox
@onready var player_detection = $PlayerDetectionArea

# --- State machine (Enhanced) ---
enum { WANDER, GRAZE, SLEEP, FLEE, INVESTIGATE, CAUTIOUS, ALERT }
var state = WANDER
var previous_state = WANDER

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
var investigate_target: Vector2
var investigate_timer: float = 0.0

func _ready() -> void:
	home_position = global_position
	last_position = global_position
	sprite.play("Idle")
	generate_grazing_spots()
	
	# Don't enable regen here - it's controlled by state now!
	# stats.health_regen_enabled = true  # Removed this line
	
	# Add some personality variation
	curiosity += randf_range(-0.2, 0.2)
	nervousness += randf_range(-0.15, 0.15)
	laziness += randf_range(-0.2, 0.2)

func _physics_process(delta: float) -> void:
	personality_timer += delta
	update_activity_level(delta)
	check_stuck_prevention(delta)
	update_los_tracking(delta)  # LOS tracking
	
	# Reduce danger memory over time
	if danger_memory_timer > 0:
		danger_memory_timer -= delta

	# Control healing based on activity - only heal when resting!
	if state in [SLEEP, GRAZE]:
		stats.health_regen_enabled = true
	else:
		stats.health_regen_enabled = false

	match state:
		WANDER:
			handle_wander(delta)
		GRAZE:
			handle_graze(delta)
		SLEEP:
			handle_sleep(delta)
		FLEE:
			handle_flee(delta)
		INVESTIGATE:
			handle_investigate(delta)
		CAUTIOUS:
			handle_cautious(delta)
		ALERT:
			handle_alert(delta)

	# Smart sprite flipping with momentum consideration
	update_sprite_facing()
	
	# Apply movement
	if not dying:
		velocity = move_velocity
		move_and_slide()

func check_line_of_sight(target: Node2D) -> bool:
	if not target:
		return false
		
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	return result.is_empty() or result["collider"] == target

func update_los_tracking(delta: float) -> void:
	if not player:
		has_los = false
		searching = false
		return
	
	if check_line_of_sight(player):
		has_los = true
		searching = false
		los_memory_timer = los_memory_duration
		last_seen_position = player.global_position
	else:
		has_los = false
		
		# If we recently saw the player, start searching
		if los_memory_timer > 0:
			los_memory_timer -= delta
			if not searching:
				searching = true
				search_timer = search_duration
		else:
			# Memory expired, stop searching
			searching = false

func generate_grazing_spots() -> void:
	grazing_spots.clear()
	for i in range(4):
		var angle = (i * PI * 0.5) + randf_range(-0.3, 0.3)
		var distance = randf_range(30, wander_radius * 0.8)
		grazing_spots.append(home_position + Vector2(cos(angle), sin(angle)) * distance)

func update_activity_level(delta: float) -> void:
	# Activity decreases over time, making pig more likely to rest
	activity_level -= delta * 0.002
	activity_level = max(0.2, activity_level)
	
	# Resting restores activity
	if state in [SLEEP, GRAZE]:
		activity_level += delta * 0.01
		activity_level = min(1.0, activity_level)

func check_stuck_prevention(delta: float) -> void:
	if global_position.distance_to(last_position) < 3:
		stuck_prevention_timer += delta
		if stuck_prevention_timer > 1.0:
			# Force unstuck
			var escape_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			move_velocity = escape_dir * maxspeed * 1.2
			stuck_prevention_timer = 0
	else:
		stuck_prevention_timer = 0
		last_position = global_position

func handle_wander(delta: float) -> void:
	wander_timer -= delta
	
	# Smart state transitions based on personality and activity
	if wander_timer <= 0:
		wander_count += 1
		pick_new_wander_direction()
		wander_timer = wander_change_interval + randf_range(-0.8, 0.8)
		
		# Dynamic behavior selection based on pig's state
		var rest_chance = (1.0 - activity_level) * laziness
		var curiosity_chance = curiosity * activity_level
		
		if wander_count >= 4 and randf() < rest_chance:
			if randf() < graze_chance:
				state = GRAZE
				find_nearby_grazing_spot()
			else:
				state = SLEEP
				sleep_timer = sleep_duration * randf_range(0.7, 1.3)
			wander_count = 0
			return
		elif randf() < curiosity_chance:
			state = INVESTIGATE
			pick_investigation_target()
			investigate_timer = randf_range(3, 6)
			return
	
	# Enhanced movement with wall avoidance
	var target_velocity = calculate_wander_velocity(delta)
	move_velocity = move_velocity.move_toward(target_velocity, acceleration * delta)
	
	# Dynamic animation
	update_movement_animation()

func calculate_wander_velocity(delta: float) -> Vector2:
	var base_velocity: Vector2
	
	if wall_escape_timer > 0:
		wall_escape_timer -= delta
		base_velocity = wall_escape_dir * maxspeed
	else:
		base_velocity = wander_direction * maxspeed
		
		# Keep near home with gradual urgency
		var home_distance = global_position.distance_to(home_position)
		if home_distance > wander_radius:
			var urgency = min(1.5, home_distance / wander_radius)
			var dir_to_home = (home_position - global_position).normalized()
			base_velocity = base_velocity.lerp(dir_to_home * maxspeed * urgency, 0.7)
		
		# Check for walls and danger zones
		var avoidance = get_smart_avoidance()
		base_velocity += avoidance
		
		# Apply caution around remembered danger spots
		if danger_memory_timer > 0:
			var danger_distance = global_position.distance_to(last_danger_position)
			if danger_distance < caution_radius:
				var flee_dir = (global_position - last_danger_position).normalized()
				var caution_strength = (caution_radius - danger_distance) / caution_radius
				base_velocity += flee_dir * maxspeed * caution_strength * 0.5
	
	return base_velocity

func get_smart_avoidance() -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var avoidance = Vector2.ZERO
	
	# Multiple direction checks for better wall avoidance
	var check_directions = [
		move_velocity.normalized(),  # Current direction
		move_velocity.normalized().rotated(PI * 0.25),
		move_velocity.normalized().rotated(-PI * 0.25),
		Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN
	]
	
	for dir in check_directions:
		var query = PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + dir * wall_detection_distance
		)
		query.exclude = [self]
		var result = space_state.intersect_ray(query)
		
		if not result.is_empty():
			var distance = global_position.distance_to(result["position"])
			var strength = (wall_detection_distance - distance) / wall_detection_distance
			avoidance -= dir * strength * 100
	
	# If significant avoidance needed, commit to a detour
	if avoidance.length() > 50 and wall_escape_timer <= 0:
		wall_escape_dir = avoidance.normalized()
		wall_escape_timer = wall_escape_time
	
	return avoidance

func handle_graze(delta: float) -> void:
	move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta)
	
	# Just use Idle animation for now (TODO: Add proper graze animation later)
	sprite.play("Idle")
	
	# Heal while grazing (eating restores health!)
	if stats.health < stats.max_health:
		stats.time_since_damage += delta * 2.0  # Accelerate natural regen while eating
	
	sleep_timer -= delta
	if sleep_timer <= 0:
		state = WANDER
		wander_count = 0

func handle_sleep(delta: float) -> void:
	move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta)
	
	if not sleeping:
		sleeping = true
		sprite.play("Sleep")
	
	# Heal while sleeping (deep rest regenerates health!)
	if stats.health < stats.max_health:
		# Boost the natural regen system while sleeping
		stats.time_since_damage += delta * 3.0  # 3x faster regen trigger
		
		# Optional: Direct healing if you want it faster
		# stats.health_regen_timer += delta * 1.5  # 1.5x faster healing ticks
	
	sleep_timer -= delta
	if sleep_timer <= 0:
		state = WANDER
		sleeping = false
		wander_count = 0

func handle_investigate(delta: float) -> void:
	investigate_timer -= delta
	
	if investigate_timer <= 0 or global_position.distance_to(investigate_target) < 20:
		state = WANDER
		return
	
	var dir = (investigate_target - global_position).normalized()
	var cautious_speed = maxspeed * 0.6  # Move slower when investigating
	
	# Add some hesitation and sniffing behavior
	if randf() < 0.05:  # 5% chance per frame to pause and sniff
		move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta)
		sprite.play("Idle")
	else:
		move_velocity = move_velocity.move_toward(dir * cautious_speed, acceleration * delta * 0.8)
		sprite.play("Walk")

func handle_cautious(delta: float) -> void:
	alert_timer -= delta
	
	if alert_timer <= 0:
		state = WANDER
		return
	
	# Only be cautious if we can see the player
	if has_los and player and global_position.distance_to(player.global_position) < social_distance * 2:
		var dir = (global_position - player.global_position).normalized()
		move_velocity = move_velocity.move_toward(dir * maxspeed * 0.4, acceleration * delta)
	else:
		move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta)
	
	sprite.play("Idle")

func handle_alert(delta: float) -> void:
	alert_timer -= delta
	
	# If we're searching for a player we lost sight of
	if searching and search_timer > 0:
		search_timer -= delta
		
		# Look towards last seen position
		if global_position.distance_to(last_seen_position) > 20:
			var dir = (last_seen_position - global_position).normalized()
			move_velocity = move_velocity.move_toward(dir * maxspeed * 0.3, acceleration * delta)
		else:
			# Reached last seen position, look around briefly
			move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta)
		
		# If we find the player again with LOS, react
		if has_los and player:
			search_timer = 0
			searching = false
			if global_position.distance_to(player.global_position) < safe_distance * 0.5:
				initiate_panic_flee()
			else:
				state = CAUTIOUS
				alert_timer = randf_range(2, 4)
		
		# Stop searching after timeout
		if search_timer <= 0:
			searching = false
			state = CAUTIOUS
			alert_timer = randf_range(1, 3)
	else:
		# Normal alert behavior
		move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta * 2)
		
		if alert_timer <= 0:
			if has_los and player and global_position.distance_to(player.global_position) < safe_distance * 0.5:
				state = FLEE
				initiate_panic_flee()
			else:
				state = CAUTIOUS
				alert_timer = randf_range(2, 4)
	
	sprite.play("Idle")

func handle_flee(delta: float) -> void:
	flee_panic_level = min(1.0, flee_panic_level + delta * 0.5)
	
	if wall_escape_timer > 0:
		wall_escape_timer -= delta
		move_velocity = move_velocity.move_toward(wall_escape_dir * current_flee_speed, acceleration * delta * 1.5)
	else:
		if player:
			var base_dir = (global_position - player.global_position).normalized()
			
			# Enhanced zigzag with panic-influenced randomness
			zigzag_timer += delta
			if zigzag_timer >= 0.4:  # Change direction every 0.4 seconds
				zigzag_direction *= -1
				zigzag_timer = 0.0
			
			var zigzag_strength = flee_dodge_strength * (0.5 + flee_panic_level * 0.5)
			var flee_dir = base_dir.rotated(zigzag_direction * zigzag_strength * randf_range(0.7, 1.3))
			
			# Gradual speed increase with panic (more controlled)
			flee_accel_timer += delta
			if flee_accel_timer >= flee_accel_interval:
				flee_accel_timer = 0.0
				# Slower, more controlled acceleration that caps at reasonable speed
				current_flee_speed = min(current_flee_speed + flee_accel_step, flee_speed)
			
			move_velocity = move_velocity.move_toward(flee_dir * current_flee_speed, acceleration * delta * 2)
			
			# Wall avoidance while fleeing
			var avoidance = get_smart_avoidance()
			if avoidance.length() > 30:
				wall_escape_dir = (flee_dir + avoidance.normalized()).normalized()
				wall_escape_timer = wall_escape_time * 0.8
			
			sprite.play("Run")
			
			# Check if escaped
			if global_position.distance_to(player.global_position) > safe_distance:
				flee_timer += delta
				if flee_timer >= flee_cooldown:
					end_flee_sequence()
		else:
			flee_timer += delta
			if flee_timer >= flee_cooldown:
				end_flee_sequence()

func initiate_panic_flee() -> void:
	state = FLEE
	flee_timer = 0.0
	current_flee_speed = initial_flee_speed  # Start with decent speed immediately
	flee_panic_level = 0.2
	zigzag_timer = 0.0
	
	# Remember this danger location
	if player:
		last_danger_position = player.global_position
		danger_memory_timer = danger_memory_duration

func end_flee_sequence() -> void:
	state = ALERT
	alert_timer = randf_range(3, 6)
	flee_timer = 0.0
	current_flee_speed = 0.0
	flee_panic_level = 0.0
	player = null
	activity_level = max(0.3, activity_level - 0.2)  # Fleeing is tiring

func pick_investigation_target() -> void:
	# Pick something interesting to investigate
	var angle = randf() * TAU
	var distance = randf_range(40, 80)
	investigate_target = global_position + Vector2(cos(angle), sin(angle)) * distance
	
	# Prefer grazing spots sometimes
	if randf() < 0.4 and not grazing_spots.is_empty():
		investigate_target = grazing_spots[randi() % grazing_spots.size()]

func find_nearby_grazing_spot() -> void:
	if not grazing_spots.is_empty():
		# Find closest grazing spot
		var closest_spot = grazing_spots[0]
		var closest_distance = global_position.distance_to(closest_spot)
		
		for spot in grazing_spots:
			var distance = global_position.distance_to(spot)
			if distance < closest_distance:
				closest_distance = distance
				closest_spot = spot
		
		# Move towards it briefly, then graze
		var dir = (closest_spot - global_position).normalized()
		move_velocity = dir * maxspeed * 0.5

func pick_new_wander_direction() -> void:
	var attempts = 0
	while attempts < 3:
		var test_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		
		# Avoid directions that lead directly to walls
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + test_direction * wall_detection_distance
		)
		query.exclude = [self]
		var result = space_state.intersect_ray(query)
		
		if result.is_empty() or global_position.distance_to(result["position"]) > 40:
			wander_direction = test_direction
			return
		
		attempts += 1
	
	# Fallback if all directions blocked
	wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func update_movement_animation() -> void:
	if move_velocity.length() > 8:
		if state == FLEE:
			sprite.play("Run")
		else:
			sprite.play("Walk")
	else:
		match state:
			GRAZE:
				sprite.play("Idle")  # TODO: Change to "Graze" when animation is ready
			SLEEP:
				sprite.play("Sleep")
			INVESTIGATE, ALERT, CAUTIOUS:
				sprite.play("Idle")
			_:
				sprite.play("Idle")

func update_sprite_facing() -> void:
	if abs(move_velocity.x) > 2:
		sprite.flip_h = move_velocity.x < 0

# --- Event Handlers ---
func _on_hurt_box_area_entered(area: Area2D) -> void:
	hurtbox.create_hit_effect()
	if dying:
		return

	stats.set_health(stats.health - area.damage)
	sprite.play("Hurt")

	if stats.health <= 0:
		dying = true
		spawn_Death_effect()
		queue_free()
	else:
		# Panic flee when hurt
		if player_detection.get_overlapping_bodies().size() > 0:
			player = player_detection.get_overlapping_bodies()[0]
		initiate_panic_flee()

func _on_player_detection_area_body_entered(body: Node2D) -> void:
	player = body
	
	# Only react if we can actually see the player!
	if not check_line_of_sight(player):
		return  # Don't react if we can't see them
	
	# React based on current state and nervousness
	if state == SLEEP:
		wake_up()
		state = ALERT
		alert_timer = randf_range(2, 4)
	elif state in [WANDER, GRAZE, INVESTIGATE]:
		if randf() < nervousness:
			initiate_panic_flee()
		else:
			state = ALERT
			alert_timer = randf_range(1, 3)

func _on_player_detection_area_body_exited(body: Node2D) -> void:
	if body == player and state != FLEE:
		player = null
		if state in [ALERT, CAUTIOUS]:
			state = WANDER

func wake_up() -> void:
	if state == SLEEP and not dying:
		state = WANDER
		wander_count = 0
		sleeping = false

func spawn_Death_effect() -> void:
	var effect_scene = preload("res://Mobs/Scenes/pig_death.tscn")
	var effect_instance = effect_scene.instantiate()
	effect_instance.global_position = global_position
	get_parent().add_child(effect_instance)

func _on_stats_no_health() -> void:
	if not dying:
		dying = true
		sprite.play("Death")
		await sprite.animation_finished
		queue_free()
