extends CharacterBody2D

# --- Knockback ---
var knockback: Vector2 = Vector2.ZERO
@export var knockback_speed: float = 200.0
@export var knockback_duration: float = 0.2

@onready var drop_slime = preload("res://Enemies/EnemyDrops/slimedrop.tscn")

# --- Jump settings ---
@export var jump_force := 100.0
@export var charge_jump_force := 350.0
@export var small_hop_force := 60.0
@export var mini_hop_force := 40.0  # New: for tactical approach
@export var search_hop_force := 70.0  # New: for searching
@export var air_time := 0.2
@export var search_air_time := 0.15  # Shorter air time for search hops
@export var mini_air_time := 0.1  # Even shorter for mini hops
@export var jump_cooldown := 3.0  # Reduced from 5.0 for more responsive movement
@export var mini_hop_cooldown := 1.5  # Faster cooldown for approach hops
@export var spit_speed := 250.0
@export var spit_delay := 0.2
@export var jumps_before_spit := 5
@export var attack_recovery_time := 2.0  # Reduced from 3.0

# --- LOS Tracking (From Bat) ---
var has_los: bool = false
var last_seen_positions: Array[Vector2] = []
var search_target: Vector2
var searching: bool = false
var los_memory_timer: float = 0.0
@export var los_memory_duration: float = 4.0
@export var search_ahead_distance: float = 80.0  # Shorter for slime
var reached_last_seen: bool = false
var search_patience_timer: float = 0.0
@export var search_patience: float = 2.5  # Shorter patience
var circle_search_angle: float = 0.0
@export var circle_search_radius: float = 50.0  # Smaller radius
var dynamic_search_points: Array[Vector2] = []

# --- Jump Range Management ---
@export var max_jump_range: float = 50.0  # Maximum jump distance
@export var approach_range: float = 25.0  # Range where mini hops start
@export var attack_range: float = 15.0  # Close combat range

# --- States ---
enum { IDLE, WANDER, CHASE, SEARCH_HOP, CIRCLE_SEARCH, INVESTIGATE, APPROACH }
var state = IDLE

# --- Nodes ---
@onready var hurtbox = $HurtBox
@onready var stats = $Stats
@onready var playerdetectionzone = $PlayerDetectionArea
@onready var sprite = $Sprite2D
@onready var anim_player = $AnimationPlayer
@onready var hit_box = $Marker2D/HitBox

# --- Scenes ---
var MegaSpitScene := preload("res://Enemies/Projectiles/megaspit.tscn")
var DeathEffectScene := preload("res://Effects/slime_death.tscn")

# --- Vars ---
var move_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var dying: bool = false
var knockback_force = 1
var home_position: Vector2
var is_jumping := false
var can_jump := true
var jump_count := 0
var jump_target: Vector2 = Vector2.ZERO
var last_jump_time: float = 0.0
var is_in_attack_recovery: bool = false
var last_attack_type: int = -1
@export var damage := 1

func _ready() -> void:
	home_position = global_position
	hit_box.damage = damage
	
	if velocity != Vector2.ZERO:
		hit_box.knockback_vector = velocity.normalized() * knockback_force

func _physics_process(delta: float) -> void:
	# Update LOS memory timer
	if los_memory_timer > 0:
		los_memory_timer -= delta
	
	# Update search patience
	if search_patience_timer > 0:
		search_patience_timer -= delta
	
	seek_player()
	global_position += velocity * delta

	if velocity != Vector2.ZERO:
		hit_box.knockback_vector = velocity.normalized() * knockback_force
		
	if knockback_timer > 0:
		velocity = knockback
		knockback_timer -= delta
		if knockback_timer <= 0 and dying:
			spawn_death_effect()
			queue_free()
	else:
		velocity = move_velocity

	move_and_slide()

func seek_player() -> void:
	if is_jumping or is_in_attack_recovery:
		return
		
	var player = playerdetectionzone.player
	if not player:
		if state in [CHASE, SEARCH_HOP, CIRCLE_SEARCH, INVESTIGATE, APPROACH]:
			state = WANDER
		return

	if check_line_of_sight(player):
		has_los = true
		searching = false
		los_memory_timer = los_memory_duration
		search_patience_timer = search_patience
		
		update_last_seen_positions(player.global_position)
		
		# Determine appropriate state based on distance
		var distance = global_position.distance_to(player.global_position)
		
		if distance <= attack_range and can_jump:
			state = CHASE
			execute_attack_pattern(player.global_position)
		elif distance <= approach_range:
			state = APPROACH
			mini_hop_approach(player.global_position)
		else:
			state = CHASE
			tactical_chase_jump(player.global_position)
			
	else:
		has_los = false
		
		if los_memory_timer > 0:
			if not searching:
				if not last_seen_positions.is_empty():
					search_target = last_seen_positions[-1]
				searching = true
				reached_last_seen = false
				search_patience_timer = search_patience
				state = SEARCH_HOP
			
			handle_search_behavior()
		else:
			# Memory expired - return to wandering
			searching = false
			reached_last_seen = false
			last_seen_positions.clear()
			dynamic_search_points.clear()
			if state in [CHASE, SEARCH_HOP, CIRCLE_SEARCH, INVESTIGATE, APPROACH]:
				state = WANDER
				wander_jump()

func check_line_of_sight(player: Node2D) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	return result.is_empty() or result["collider"] == player

func update_last_seen_positions(player_pos: Vector2) -> void:
	if last_seen_positions.is_empty() or last_seen_positions[-1].distance_to(player_pos) > 15.0:
		last_seen_positions.append(player_pos)
		if last_seen_positions.size() > 3:  # Keep more positions for better prediction
			last_seen_positions.pop_front()

func handle_search_behavior() -> void:
	if search_patience_timer <= 0:
		state = WANDER
		wander_jump()
		return
	
	match state:
		SEARCH_HOP:
			search_hop_to_target()
		CIRCLE_SEARCH:
			handle_circle_search()
		INVESTIGATE:
			handle_investigation()

func search_hop_to_target() -> void:
	if not can_jump:
		return
		
	var target = get_intelligent_search_target()
	var distance = global_position.distance_to(target)
	
	# Use shorter hops for searching
	var hop_distance = min(distance, max_jump_range * 0.8)
	var direction = (target - global_position).normalized()
	var hop_target = global_position + direction * hop_distance
	
	start_search_hop(hop_target)

func get_intelligent_search_target() -> Vector2:
	if last_seen_positions.is_empty():
		return search_target
	
	var last_seen_pos = last_seen_positions[-1]
	
	# Go to last seen position first
	if not reached_last_seen:
		if global_position.distance_to(last_seen_pos) < 20.0:
			reached_last_seen = true
			state = CIRCLE_SEARCH
		return last_seen_pos
	
	# Predict based on movement pattern
	if last_seen_positions.size() >= 2:
		var older_pos = last_seen_positions[-2]
		var recent_pos = last_seen_positions[-1]
		var movement_dir = (recent_pos - older_pos).normalized()
		
		var prediction_distance = search_ahead_distance * (0.7 + randf() * 0.6)
		return recent_pos + movement_dir * prediction_distance
	else:
		return last_seen_pos

func handle_circle_search() -> void:
	if not can_jump:
		return
		
	circle_search_angle += 1.5  # Increment angle for next position
	
	if not last_seen_positions.is_empty():
		var center = last_seen_positions[-1]
		var search_pos = center + Vector2(cos(circle_search_angle), sin(circle_search_angle)) * circle_search_radius
		
		start_search_hop(search_pos)
		
		# Switch to investigation after partial circle
		if circle_search_angle > PI:  # Half circle instead of full
			state = INVESTIGATE
			generate_dynamic_search_points()

func handle_investigation() -> void:
	if not can_jump:
		return
		
	if dynamic_search_points.is_empty():
		state = WANDER
		wander_jump()
		return
	
	var target = dynamic_search_points[0]
	
	# Check if we're close enough to this search point
	if global_position.distance_to(target) < 25:
		dynamic_search_points.pop_front()
		if dynamic_search_points.is_empty():
			state = WANDER
			wander_jump()
		return
	
	start_search_hop(target)

func generate_dynamic_search_points() -> void:
	dynamic_search_points.clear()
	
	if last_seen_positions.size() >= 2:
		var last_pos = last_seen_positions[-1]
		var movement_dir = (last_seen_positions[-1] - last_seen_positions[-2]).normalized()
		
		# Create 2-3 search points in an arc
		for i in range(2):
			var angle_offset = (i - 0.5) * 1.0  # Spread arc
			var search_dir = movement_dir.rotated(angle_offset)
			var distance = search_ahead_distance * (0.6 + randf() * 0.4)
			dynamic_search_points.append(last_pos + search_dir * distance)

# --- Tactical Movement Functions ---

func mini_hop_approach(target_position: Vector2) -> void:
	if not can_jump:
		return
		
	var distance = global_position.distance_to(target_position)
	var hop_distance = min(distance, max_jump_range * 0.5)  # Short approach hops
	var direction = (target_position - global_position).normalized()
	var hop_target = global_position + direction * hop_distance
	
	start_mini_hop(hop_target)

func tactical_chase_jump(target_position: Vector2) -> void:
	if not can_jump:
		return
		
	var distance = global_position.distance_to(target_position)
	var jump_distance = min(distance, max_jump_range)
	var direction = (target_position - global_position).normalized()
	var jump_target_pos = global_position + direction * jump_distance
	
	start_jump_sequence(jump_target_pos, jump_force, air_time)

func wander_jump() -> void:
	if not can_jump:
		return
		
	var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var wander_distance = randf_range(15, max_jump_range * 0.7)
	var wander_target = home_position + random_dir * wander_distance
	
	# Keep within reasonable distance from home
	var home_distance = home_position.distance_to(wander_target)
	if home_distance > 100:
		wander_target = home_position + (wander_target - home_position).normalized() * 100
	
	start_jump_sequence(wander_target, jump_force * 0.6, air_time)

func execute_attack_pattern(target_position: Vector2) -> void:
	if not can_jump or is_in_attack_recovery:
		return
		
	var attack_choice = randi() % 3  # Simplified attack patterns for close range
	
	match attack_choice:
		0: start_jump_sequence(target_position, jump_force, air_time)  # Direct hop
		1: charge_jump(target_position)  # Power jump
		2: multi_hop_combo(target_position)  # Combo attack

# --- Jump Functions (Modified for shorter ranges) ---

func start_jump_sequence(target_position: Vector2, force: float, jump_air_time: float) -> void:
	if is_jumping or not can_jump:
		return
		
	can_jump = false
	is_jumping = true
	jump_target = target_position
	last_jump_time = Time.get_time_dict_from_system()["second"]

	sprite.flip_h = target_position.x > global_position.x
	anim_player.play("anticipation")
	await get_tree().create_timer(0.3).timeout  # Shorter anticipation

	var dir = (jump_target - global_position).normalized()
	move_velocity = dir * force
	anim_player.play("jump")
	await get_tree().create_timer(jump_air_time).timeout

	is_jumping = false
	move_velocity = Vector2.ZERO
	anim_player.play("idle")

	jump_count += 1
	
	if jump_count >= jumps_before_spit and state == CHASE and randf() < 0.6:
		jump_count = 0
		await shoot_mega_spit()

	await get_tree().create_timer(jump_cooldown).timeout
	can_jump = true

func start_mini_hop(target_position: Vector2) -> void:
	if is_jumping or not can_jump:
		return
		
	can_jump = false
	is_jumping = true
	jump_target = target_position

	sprite.flip_h = target_position.x > global_position.x
	anim_player.play("anticipation")
	await get_tree().create_timer(0.2).timeout  # Very short anticipation

	var dir = (jump_target - global_position).normalized()
	move_velocity = dir * mini_hop_force
	anim_player.play("jump")
	await get_tree().create_timer(mini_air_time).timeout

	is_jumping = false
	move_velocity = Vector2.ZERO
	anim_player.play("idle")

	await get_tree().create_timer(mini_hop_cooldown).timeout
	can_jump = true

func start_search_hop(target_position: Vector2) -> void:
	if is_jumping or not can_jump:
		return
		
	can_jump = false
	is_jumping = true
	jump_target = target_position

	sprite.flip_h = target_position.x > global_position.x
	anim_player.play("anticipation")
	await get_tree().create_timer(0.2).timeout

	var dir = (jump_target - global_position).normalized()
	move_velocity = dir * search_hop_force
	anim_player.play("jump")
	await get_tree().create_timer(search_air_time).timeout

	is_jumping = false
	move_velocity = Vector2.ZERO
	anim_player.play("idle")

	# No cooldown for search hops - immediate jump availability
	can_jump = true

func start_attack_recovery() -> void:
	is_in_attack_recovery = true
	await get_tree().create_timer(attack_recovery_time).timeout
	is_in_attack_recovery = false

# --- Attack Functions (Adapted for shorter ranges) ---

func charge_jump(target_position: Vector2) -> void:
	var distance = global_position.distance_to(target_position)
	var actual_target = target_position
	
	if distance > max_jump_range:
		var direction = (target_position - global_position).normalized()
		actual_target = global_position + direction * max_jump_range
	
	await start_jump_sequence(actual_target, charge_jump_force, air_time)
	start_attack_recovery()

func multi_hop_combo(target_position: Vector2) -> void:
	# One positioning hop
	var setup_pos = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
	await start_mini_hop(setup_pos)
	
	# Attack hop
	var distance = global_position.distance_to(target_position)
	var actual_target = target_position
	
	if distance > max_jump_range:
		var direction = (target_position - global_position).normalized()
		actual_target = global_position + direction * max_jump_range
	
	await start_jump_sequence(actual_target, jump_force, air_time)
	
	if randf() < 0.5:
		await shoot_mega_spit()
	
	start_attack_recovery()

func fake_out_jump(player_position: Vector2) -> void:
	var retreat_dir = (global_position - player_position).normalized()
	var retreat_distance = min(20, max_jump_range * 0.7)
	var retreat_pos = global_position + retreat_dir * retreat_distance
	
	await start_mini_hop(retreat_pos)
	await get_tree().create_timer(0.3).timeout
	
	var attack_distance = global_position.distance_to(player_position)
	var actual_target = player_position
	
	if attack_distance > max_jump_range:
		var direction = (player_position - global_position).normalized()
		actual_target = global_position + direction * max_jump_range
	
	await start_jump_sequence(actual_target, charge_jump_force, air_time)
	start_attack_recovery()

# --- Mega Spit (Unchanged but balanced) ---
func shoot_mega_spit() -> void:
	var player = playerdetectionzone.player
	if not player or not is_instance_valid(player) or dying:
		return

	var spit_count = randi_range(1, 2)
	
	for i in range(spit_count):
		if dying or not is_instance_valid(self):
			return
		if not player or not is_instance_valid(player):
			return

		anim_player.play("ready_shoot")
		await anim_player.animation_finished
		if dying or not is_instance_valid(self):
			return

		sprite.flip_h = player.global_position.x > global_position.x
		anim_player.play("shoot")
		await anim_player.animation_finished
		if dying or not is_instance_valid(self):
			return

		var spit = MegaSpitScene.instantiate()
		get_tree().current_scene.add_child(spit)
		spit.global_position = global_position
		
		var direction = (player.global_position - global_position).normalized()
		var spread = randf_range(-0.15, 0.15)
		direction = direction.rotated(spread)
		spit.velocity = direction * spit_speed
		
		if spit.has_node("AnimationPlayer"):
			spit.get_node("AnimationPlayer").play("spit")

		anim_player.play("finish_shoot")
		await anim_player.animation_finished
		if dying or not is_instance_valid(self):
			return

		if i < spit_count - 1:
			await get_tree().create_timer(0.6).timeout

	anim_player.play("idle")

# --- Damage & Death (Unchanged) ---
func _on_hurt_box_area_entered(area: Area2D) -> void:
	knockback = area.knockback_vector * knockback_speed
	knockback_timer = knockback_duration
	stats.set_health(stats.health - area.damage)
	hurtbox.create_hit_effect()
	if stats.health <= 0:
		dying = true

func spawn_death_effect() -> void:
	var effect_instance = DeathEffectScene.instantiate()
	effect_instance.global_position = global_position

	var slime_instance = drop_slime.instantiate()
	slime_instance.global_position = global_position + Vector2(randf_range(-16, 16), randf_range(-16, 16))
	get_parent().add_child(slime_instance)
	get_parent().add_child(effect_instance)
