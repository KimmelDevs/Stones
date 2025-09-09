extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var DeathEffectScene = preload("res://Inventory/scenes/chicken_meat.tscn")

# --- Combat / Knockback ---
var knockback: Vector2 = Vector2.ZERO
@export var knockback_speed: float = 150.0
@export var knockback_duration: float = 0.3

# --- Movement (Updated from pig system) ---
@export var acceleration: float = 150.0
@export var speed: float = 25.0
@export var flee_speed: float = 80.0
@export var friction: float = 200.0
@export var safe_distance: float = 180.0
@export var flee_dodge_strength: float = 0.4
@export var flee_cooldown: float = 2.0

# --- Pickup System ---
var is_being_carried: bool = false
var carrier: Node2D = null
var throw_velocity: Vector2 = Vector2.ZERO
var is_thrown: bool = false
var land_timer: float = 0.0
@export var land_duration: float = 1.0
@export var bounce_factor: float = 0.3

# --- Nodes ---
@onready var hurtbox = $HurtBox
@onready var stats = $Stats
@onready var soft_collision: Area2D = $SoftCollision
@onready var player_detection = $PlayerDetectionArea

# --- States ---
enum State { IDLE, IDLING, WANDER, FLEEING, ALERT }
var state: State = State.IDLE

# --- Facing direction ---
enum Facing { DOWN, UP, LEFT, RIGHT }
var facing: Facing = Facing.DOWN

# --- Timers ---
var state_timer: float = 0.0
var evolution_timer: float = 720.0  # 12 minutes in seconds
var knockback_timer: float = 0.0
@export var idle_time_range: Vector2 = Vector2(1.5, 3.0)
@export var wander_time_range: Vector2 = Vector2(0.5, 1.5)
@export var flee_time: float = 2.0

# --- Movement Variables ---
var move_velocity: Vector2 = Vector2.ZERO
var wander_dir: Vector2 = Vector2.ZERO
var home_position: Vector2
var dying: bool = false

# --- Behavior ---
var has_been_hurt: bool = false
var flee_direction: Vector2 = Vector2.ZERO

# --- Player Detection & Line of Sight ---
var player: Node2D = null
var has_los: bool = false
var last_seen_position: Vector2
var searching: bool = false
var los_memory_timer: float = 0.0
@export var los_memory_duration: float = 2.0  # Chickens forget faster than pigs
var search_timer: float = 0.0
@export var search_duration: float = 1.5

# --- Enhanced Flee System (From pig) ---
var flee_panic_level: float = 0.0
var wall_escape_timer: float = 0.0
var wall_escape_dir: Vector2 = Vector2.ZERO
@export var wall_escape_time: float = 1.0
var current_flee_speed: float = 0.0
var flee_accel_timer: float = 0.0
@export var flee_accel_step: float = 15.0
@export var flee_accel_interval: float = 0.3
@export var initial_flee_speed: float = 50.0
var zigzag_timer: float = 0.0
var zigzag_direction: int = 1
var flee_timer: float = 0.0
var alert_timer: float = 0.0

# --- Smart Behaviors ---
var last_danger_position: Vector2
var danger_memory_timer: float = 0.0
@export var danger_memory_duration: float = 5.0
@export var caution_radius: float = 100.0
@export var wall_detection_distance: float = 40.0

func _ready():
	home_position = global_position
	reset_idle_timer()
	
	# Add to pickupable group
	add_to_group("pickupable")

func _process(delta: float) -> void:
	# Handle being thrown
	if is_thrown:
		land_timer -= delta
		if land_timer <= 0:
			is_thrown = false
			throw_velocity = Vector2.ZERO
			# Panic after being thrown
			if not dying:
				has_been_hurt = true
				initiate_panic_flee()
			return
	
	# Don't process normal behavior if being carried
	if is_being_carried:
		return
	
	# Update evolution timer

	
	state_timer -= delta
	update_los_tracking(delta)
	
	# Reduce danger memory over time
	if danger_memory_timer > 0:
		danger_memory_timer -= delta
	
	# Handle knockback
	if knockback_timer > 0:
		velocity = knockback
		knockback_timer -= delta
		if knockback_timer <= 0 and dying:
			spawn_death_effect()
			queue_free()
			return
	else:
		handle_state_machine(delta)
	
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
		
		if los_memory_timer > 0:
			los_memory_timer -= delta
			if not searching:
				searching = true
				search_timer = search_duration
		else:
			searching = false

func handle_state_machine(delta: float) -> void:
	# Don't process state machine if being carried or thrown
	if is_being_carried or is_thrown:
		return
		
	match state:
		State.IDLE:
			handle_idle(delta)
		State.IDLING:
			handle_idling(delta)
		State.WANDER:
			handle_wander(delta)
		State.FLEEING:
			handle_flee(delta)
		State.ALERT:
			handle_alert(delta)
	
	# Apply movement
	if not dying:
		if is_thrown:
			velocity = throw_velocity
			throw_velocity = throw_velocity.move_toward(Vector2.ZERO, friction * delta * 2)
		else:
			velocity = move_velocity
		update_facing_from_velocity()

func handle_idle(delta: float) -> void:
	play_idle_animation()
	move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta)
	
	if state_timer <= 0:
		state = State.IDLING
		state_timer = randf_range(0.5, 1.5)

func handle_idling(delta: float) -> void:
	play_idling_animation()
	move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta)
	
	if state_timer <= 0:
		if not has_been_hurt:
			start_wandering()
		else:
			state = State.IDLE
			reset_idle_timer()

func handle_wander(delta: float) -> void:
	var target_velocity = calculate_wander_velocity(delta)
	move_velocity = move_velocity.move_toward(target_velocity, acceleration * delta)
	play_walk_animation()
	
	if state_timer <= 0:
		state = State.IDLE
		reset_idle_timer()

func handle_alert(delta: float) -> void:
	alert_timer -= delta
	
	# If searching for lost player
	if searching and search_timer > 0:
		search_timer -= delta
		
		if global_position.distance_to(last_seen_position) > 20:
			var dir = (last_seen_position - global_position).normalized()
			move_velocity = move_velocity.move_toward(dir * speed * 0.3, acceleration * delta)
		else:
			move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta)
		
		if has_los and player:
			search_timer = 0
			searching = false
			# Only flee if previously hurt
			if has_been_hurt and global_position.distance_to(player.global_position) < safe_distance * 0.5:
				initiate_panic_flee()
			else:
				alert_timer = randf_range(1, 2)
		
		if search_timer <= 0:
			searching = false
			alert_timer = randf_range(1, 2)
	else:
		move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta * 2)
		
		if alert_timer <= 0:
			# Only panic flee if has been hurt before
			if has_been_hurt and has_los and player and global_position.distance_to(player.global_position) < safe_distance * 0.5:
				initiate_panic_flee()
			else:
				state = State.IDLE
				reset_idle_timer()
	
	play_idle_animation()

func calculate_wander_velocity(delta: float) -> Vector2:
	var base_velocity: Vector2
	
	if wall_escape_timer > 0:
		wall_escape_timer -= delta
		base_velocity = wall_escape_dir * speed
	else:
		base_velocity = wander_dir * speed
		
		# Stay near home
		var home_distance = global_position.distance_to(home_position)
		if home_distance > 80:
			var dir_to_home = (home_position - global_position).normalized()
			base_velocity = base_velocity.lerp(dir_to_home * speed, 0.7)
		
		# Wall avoidance
		var avoidance = get_smart_avoidance()
		if avoidance.length() > 0:
			base_velocity += avoidance * 0.01  # Scale down the avoidance force
		
		# Avoid remembered danger spots
		if danger_memory_timer > 0:
			var danger_distance = global_position.distance_to(last_danger_position)
			if danger_distance < caution_radius:
				var flee_dir = (global_position - last_danger_position).normalized()
				var caution_strength = (caution_radius - danger_distance) / caution_radius
				base_velocity += flee_dir * speed * caution_strength * 0.5
	
	return base_velocity

func get_smart_avoidance() -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var avoidance = Vector2.ZERO
	
	var check_directions = [
		move_velocity.normalized(),
		move_velocity.normalized().rotated(PI * 0.25),
		move_velocity.normalized().rotated(-PI * 0.25),
		Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN
	]
	
	for dir in check_directions:
		if dir.length() == 0:
			continue
			
		var query = PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + dir * wall_detection_distance
		)
		query.exclude = [self]
		var result = space_state.intersect_ray(query)
		
		if not result.is_empty():
			var distance = global_position.distance_to(result["position"])
			var strength = (wall_detection_distance - distance) / wall_detection_distance
			avoidance -= dir * strength * 80
	
	if avoidance.length() > 30 and wall_escape_timer <= 0:
		wall_escape_dir = avoidance.normalized()
		wall_escape_timer = wall_escape_time
	
	return avoidance

func handle_flee(delta: float) -> void:
	flee_panic_level = min(1.0, flee_panic_level + delta * 0.6)
	
	if wall_escape_timer > 0:
		wall_escape_timer -= delta
		move_velocity = move_velocity.move_toward(wall_escape_dir * current_flee_speed, acceleration * delta * 1.5)
	else:
		if player:
			var base_dir = (global_position - player.global_position).normalized()
			
			# Enhanced zigzag with panic
			zigzag_timer += delta
			if zigzag_timer >= 0.35:  # Faster direction changes for chicken
				zigzag_direction *= -1
				zigzag_timer = 0.0
			
			var zigzag_strength = flee_dodge_strength * (0.4 + flee_panic_level * 0.6)
			var flee_dir = base_dir.rotated(zigzag_direction * zigzag_strength * randf_range(0.8, 1.2))
			
			# Speed acceleration with panic
			flee_accel_timer += delta
			if flee_accel_timer >= flee_accel_interval:
				flee_accel_timer = 0.0
				current_flee_speed = min(current_flee_speed + flee_accel_step, flee_speed)
			
			move_velocity = move_velocity.move_toward(flee_dir * current_flee_speed, acceleration * delta * 2.5)
			
			# Wall avoidance
			var avoidance = get_smart_avoidance()
			if avoidance.length() > 25:
				wall_escape_dir = (flee_dir + avoidance.normalized()).normalized()
				wall_escape_timer = wall_escape_time * 0.7
			
			play_walk_animation()
			
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
	state = State.FLEEING
	flee_timer = 0.0
	current_flee_speed = initial_flee_speed
	flee_panic_level = 0.1
	zigzag_timer = 0.0
	has_been_hurt = true
	
	if player:
		last_danger_position = player.global_position
		danger_memory_timer = danger_memory_duration

func end_flee_sequence() -> void:
	state = State.ALERT
	alert_timer = randf_range(2, 4)
	flee_timer = 0.0
	current_flee_speed = 0.0
	
	# Make chicken more skittish
	idle_time_range = Vector2(2.0, 4.0)
	wander_time_range = Vector2(0.3, 0.8)

func start_wandering() -> void:
	state = State.WANDER
	var wander_intensity = 0.5 if has_been_hurt else 1.0
	wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * wander_intensity
	state_timer = randf_range(wander_time_range.x, wander_time_range.y)

func apply_soft_collision(base_velocity: Vector2) -> Vector2:
	if soft_collision and soft_collision.is_colliding():
		var push_vector = soft_collision.get_push_vector()
		return base_velocity + push_vector * 100
	return base_velocity

# --- Pickup System Functions ---
func can_be_picked_up() -> bool:
	return not is_being_carried and not dying

func get_picked_up(picker: Node2D) -> void:
	if is_being_carried or dying:
		return
	
	is_being_carried = true
	carrier = picker
	state = State.IDLE
	move_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	
	# Disable collision while being carried
	set_collision_layer_value(1, false)  # Disable physics layer
	set_collision_mask_value(1, false)   # Disable collision detection
	
	# Play scared animation
	animated_sprite_2d.play("IdleDown")  # or create a "scared" animation
	
	print("Chick got picked up by ", picker.name)

func get_thrown(throw_position: Vector2, force: Vector2) -> void:
	if not is_being_carried:
		return
	
	is_being_carried = false
	carrier = null
	is_thrown = true
	land_timer = land_duration
	
	# Re-enable collision
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	
	# Set position and throw velocity
	global_position = throw_position
	throw_velocity = force
	
	# Make chick panic and remember this trauma
	has_been_hurt = true
	last_danger_position = throw_position
	danger_memory_timer = danger_memory_duration * 2  # Remember being thrown longer
	
	# Visual effect - make chick flash red briefly
	animated_sprite_2d.modulate = Color.PALE_VIOLET_RED
	await get_tree().create_timer(0.5).timeout
	if animated_sprite_2d:  # Check if still exists
		animated_sprite_2d.modulate = Color.WHITE
	
	print("Chick got thrown!")

# --- Animations ---
func play_idle_animation() -> void:
	match facing:
		Facing.UP: animated_sprite_2d.play("IdleUp")
		Facing.DOWN: animated_sprite_2d.play("IdleDown")
		Facing.LEFT: animated_sprite_2d.play("IdleLeft")
		Facing.RIGHT: animated_sprite_2d.play("IdleRight")

func play_idling_animation() -> void:
	match facing:
		Facing.UP: animated_sprite_2d.play("IdlingUp")
		Facing.DOWN: animated_sprite_2d.play("IdlingDown")
		Facing.LEFT: animated_sprite_2d.play("IdlingLeft")
		Facing.RIGHT: animated_sprite_2d.play("IdlingRight")

func play_walk_animation() -> void:
	match facing:
		Facing.UP: animated_sprite_2d.play("WalkUp")
		Facing.DOWN: animated_sprite_2d.play("WalkDown")
		Facing.LEFT: animated_sprite_2d.play("WalkLeft")
		Facing.RIGHT: animated_sprite_2d.play("WalkRight")

func update_facing_from_velocity() -> void:
	if abs(move_velocity.x) > abs(move_velocity.y):
		facing = Facing.RIGHT if move_velocity.x > 0 else Facing.LEFT
	elif move_velocity != Vector2.ZERO:
		facing = Facing.DOWN if move_velocity.y > 0 else Facing.UP

# --- Player Detection Functions ---
func _on_player_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		
		# Only react if we can see the player
		if not check_line_of_sight(player):
			return
		
		# React based on current state
		if state == State.IDLE or state == State.IDLING or state == State.WANDER:
			if randf() < 0:  # 70% chance to flee immediately
				pass
			else:
				state = State.ALERT
				alert_timer = randf_range(1, 2)

func _on_player_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body == player:
		if state != State.FLEEING:
			player = null
			if state == State.ALERT:
				state = State.IDLE
				reset_idle_timer()

# --- Combat Functions ---
func _on_hurt_box_area_entered(area: Area2D) -> void:
	# Can't be hurt while being carried
	if is_being_carried:
		return
		
	if dying:
		return
	
	# Calculate direction away from attacker
	var direction_from_attacker = (global_position - area.global_position).normalized()
	var random_angle = randf_range(-PI/6, PI/6)
	direction_from_attacker = direction_from_attacker.rotated(random_angle)
	
	# Apply knockback
	knockback = direction_from_attacker * knockback_speed
	knockback_timer = knockback_duration
	
	# Take damage
	if stats:
		var damage_amount = 1
		if area.has_signal("damage") or "damage" in area:
			damage_amount = area.damage
		elif area.get("damage") != null:
			damage_amount = area.get("damage")
		
		stats.set_health(stats.health - damage_amount)
		
	# Create hurt effect
	if hurtbox and hurtbox.has_method("create_hit_effect"):
		hurtbox.create_hit_effect()
	
	has_been_hurt = true
	
	if stats and stats.health <= 0:
		dying = true
	else:
		# Panic flee when hurt - find the player if nearby
		if player_detection and player_detection.get_overlapping_bodies().size() > 0:
			for body in player_detection.get_overlapping_bodies():
				if body.is_in_group("player"):
					player = body
					break
		
		initiate_panic_flee()

func _on_stats_no_health() -> void:
	dying = true

func spawn_death_effect() -> void:
	if DeathEffectScene:
		var effect_instance = DeathEffectScene.instantiate()
		effect_instance.global_position = global_position
		get_parent().add_child(effect_instance)
	spawn_death_drops()

func spawn_death_drops() -> void:
	pass

func reset_idle_timer():
	state_timer = randf_range(idle_time_range.x, idle_time_range.y)
