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

# --- Attack ---
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 0.5
@export var attack_dive_speed: float = 180.0
@export var anticipation_time: float = 0.4
@export var recovery_time: float = 0.6
var can_attack: bool = true
@onready var hitbox = $HitBox

# --- Nodes ---
@onready var hurtbox = $HurtBox
@onready var stats = $Stats
@onready var playerdetectionzone = $PlayerDetectionArea
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- State machine ---
enum { IDLE, WANDER, CHASE, ANTICIPATE, DIVE, RECOVER, SEARCH }
var state = IDLE

# --- Variables ---
var move_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var dying: bool = false
var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var home_position: Vector2

# Attack vars
var attack_target: Vector2
var attack_timer: float = 0.0

# Last known player position
var last_known_player_pos: Vector2 = Vector2.ZERO

# --- Timer Node for cooldown ---
@onready var attack_cooldown_timer: Timer = Timer.new()

# Nearby wolves from WolfDetection
var nearby_wolves: Array = []

func _ready() -> void:
	home_position = global_position
	hitbox.damage = 2
	hitbox.knockback_vector = Vector2(1, 0)

	# Setup cooldown timer
	attack_cooldown_timer.wait_time = attack_cooldown
	attack_cooldown_timer.one_shot = true
	add_child(attack_cooldown_timer)
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_finished)

	# Connect player exit
	playerdetectionzone.body_exited.connect(_on_player_exited)

func _physics_process(delta: float) -> void:
	seek_player()

	match state:
		IDLE:
			move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta)
			sprite.play("idle_down")
			if randf() < 0.01:
				state = WANDER

		WANDER:
			wander_timer -= delta
			if wander_timer <= 0:
				pick_new_wander_direction()
				wander_timer = wander_change_interval
			move_velocity = move_velocity.move_toward(wander_direction * maxspeed, acceleration * delta)
			play_movement_animation(move_velocity)

		CHASE:
			var player = playerdetectionzone.player
			if player != null:
				last_known_player_pos = player.global_position
				var dist = global_position.distance_to(player.global_position)
				if dist <= attack_range and can_attack:
					state = ANTICIPATE
					attack_timer = anticipation_time
					attack_target = player.global_position
					move_velocity = Vector2.ZERO
					sprite.play("howl_down")
				else:
					# --- Surround behavior ---
					var surround_pos = get_surround_position(player.global_position)
					var dir = (surround_pos - global_position).normalized()
					move_velocity = move_velocity.move_toward(dir * maxspeed, acceleration * delta)
					play_movement_animation(move_velocity)

		ANTICIPATE:
			attack_timer -= delta
			if attack_timer <= 0:
				state = DIVE
				attack_timer = 0.0

		DIVE:
			var dir = (attack_target - global_position).normalized()
			move_velocity = dir * attack_dive_speed
			play_movement_animation(move_velocity, true)
			if global_position.distance_to(attack_target) < 10:
				state = RECOVER
				attack_timer = recovery_time
				move_velocity = Vector2.ZERO

		RECOVER:
			attack_timer -= delta
			if attack_timer <= 0:
				state = CHASE
				can_attack = false
				attack_cooldown_timer.start()

		SEARCH:
			var dir = (last_known_player_pos - global_position).normalized()
			move_velocity = move_velocity.move_toward(dir * maxspeed, acceleration * delta)
			play_movement_animation(move_velocity)
			# Stop searching when close
			if global_position.distance_to(last_known_player_pos) < 10:
				state = WANDER

	# Knockback handling
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


# --- Utility ---
func pick_new_wander_direction() -> void:
	wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func seek_player() -> void:
	if playerdetectionzone.can_see_player():
		if state in [IDLE, WANDER, SEARCH]:
			state = CHASE
	else:
		if state in [CHASE, ANTICIPATE, DIVE, RECOVER]:
			state = SEARCH

# --- Surround logic with wolves ---
func get_surround_position(player_pos: Vector2) -> Vector2:
	var target_pos = player_pos

	if nearby_wolves.size() > 0:
		# Make a pack list including this Boxer
		var pack = nearby_wolves.duplicate()
		pack.append(self)
		# Sort so the order is consistent
		pack.sort_custom(func(a, b): return int(a.get_instance_id()) < int(b.get_instance_id()))

		var index = pack.find(self)
		var angle_step = TAU / pack.size()

		# Assign a unique angle around the player
		var surround_angle = index * angle_step
		var offset = Vector2(cos(surround_angle), sin(surround_angle)) * 80
		target_pos = player_pos + offset
	
	return target_pos

# --- Player exit handling ---
func _on_player_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		last_known_player_pos = body.global_position
		state = SEARCH

# --- Hurt handling ---
func _on_hurt_box_area_entered(area: Area2D) -> void:
	# Apply knockback
	knockback = area.knockback_vector * knockback_speed
	knockback_timer = knockback_duration

	# Cancel current attack/chase state
	if state in [CHASE, ANTICIPATE, DIVE, RECOVER]:
		state = IDLE
		move_velocity = Vector2.ZERO
		attack_timer = 0.0

	# Apply damage
	stats.set_health(stats.health - area.damage)
	hurtbox.create_hit_effect()

	# Handle death
	if stats.health <= 0:
		dying = true


func spawn_Death_effect() -> void:
	var effect_scene = preload("res://Enemies/scenes/grey_wolf_death.tscn")
	var effect_instance = effect_scene.instantiate()
	effect_instance.global_position = global_position
	get_parent().add_child(effect_instance)

# --- Timer callback ---
func _on_attack_cooldown_finished() -> void:
	can_attack = true

# --- Wolf Detection Area signals ---
func _on_wolf_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("Wolf") and body != self:
		if not nearby_wolves.has(body):
			nearby_wolves.append(body)

func _on_wolf_detection_body_exited(body: Node2D) -> void:
	if body.is_in_group("Wolf") and body != self:
		nearby_wolves.erase(body)

var last_anim_dir: String = "Down"  # Stores the last facing direction

func play_movement_animation(dir: Vector2, is_running := false) -> void:
	var anim_prefix: String
	if is_running:
		anim_prefix = "Run"
	else:
		anim_prefix = "Walk"

	if dir.length() < 1:
		# Standing still → play Idle animation in last direction
		sprite.play("Idle" + last_anim_dir)
		return

	# --- Horizontal movement dominates ---
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			last_anim_dir = "Right"
		else:
			last_anim_dir = "Left"
	else:
		if dir.y > 0:
			last_anim_dir = "Down"
		else:
			last_anim_dir = "Up"

	# --- Diagonals ---
	if abs(dir.x) > 0.5 and abs(dir.y) > 0.5:
		if dir.x > 0 and dir.y < 0:
			last_anim_dir = "UpRight"
		elif dir.x < 0 and dir.y < 0:
			last_anim_dir = "UpLeft"
		elif dir.x > 0 and dir.y > 0:
			last_anim_dir = "DownRight"
		elif dir.x < 0 and dir.y > 0:
			last_anim_dir = "DownLeft"

	sprite.play(anim_prefix + last_anim_dir)
