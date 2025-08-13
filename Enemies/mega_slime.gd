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

# --- Attack / Jump ---
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 0.5
@export var jump_force := 200.0
@export var air_time := 0.4
@export var jump_cooldown := 2.0
@export var spit_speed := 250.0
@export var spit_delay := 0.2
@export var jumps_before_spit := 3
var can_attack: bool = true
var is_jumping := false
var can_jump := true
var jump_count := 0

# --- Nodes ---
@onready var hurtbox = $HurtBox
@onready var stats = $Stats
@onready var playerdetectionzone = $PlayerDetectionArea
@onready var sprite = $Sprite2D
@onready var anim_player = $AnimationPlayer

# --- Projectile Scene ---
var MegaSpitScene := preload("res://Enemies/Projectiles/megaspit.tscn")

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

	if is_jumping:
		velocity = move_velocity
	else:
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

				if global_position.distance_to(home_position) > wander_radius:
					var dir_to_home = (home_position - global_position).normalized()
					move_velocity = move_velocity.move_toward(dir_to_home * maxspeed, acceleration * delta)

				if move_velocity.length() > 0.1:
					update_sprite_facing(move_velocity)

			CHASE:
				var player = playerdetectionzone.player
				if player != null and not is_jumping:
					_chase_with_boxer_movement(player, delta)

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

	var effective_sway = sway_amplitude
	if dist_to_player < attack_range * 2:
		effective_sway *= 0.4

	var to_player = (player.global_position - global_position).normalized()
	var perp = Vector2(-to_player.y, to_player.x) * sway_direction
	sway_time += delta * sway_speed
	var sway_offset = perp * sin(sway_time) * effective_sway

	var lunge_forward = Vector2.ZERO
	if dist_to_player <= attack_range * 1.5 and can_attack and can_jump:
		start_jump_sequence(player)
		return

	var chase_target = player.global_position + sway_offset + lunge_forward
	var random_offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
	chase_target += random_offset * 0.1

	if chase_target.distance_to(home_position) > chase_radius:
		var dir_to_home = (chase_target - home_position).normalized()
		chase_target = home_position + dir_to_home * chase_radius

	var dir = (chase_target - global_position).normalized()
	move_velocity = move_velocity.move_toward(dir * maxspeed, acceleration * delta)

	if randf() < unpredictability:
		sway_direction *= -1

	update_sprite_facing(dir)

# --- Jump & MegaSpit ---
func start_jump_sequence(player: Node2D) -> void:
	if not player or not is_instance_valid(player):
		return
	can_jump = false
	is_jumping = true
	move_velocity = (player.global_position - global_position).normalized() * jump_force
	anim_player.play("anticipation")
	await get_tree().create_timer(0.5).timeout
	anim_player.play("jump")
	await get_tree().create_timer(air_time).timeout
	is_jumping = false
	move_velocity = Vector2.ZERO
	anim_player.play("idle")
	jump_count += 1
	if jump_count >= jumps_before_spit:
		jump_count = 0
		await shoot_mega_spit(player)
	await get_tree().create_timer(jump_cooldown).timeout
	can_jump = true

func shoot_mega_spit(player: Node2D) -> void:
	if not player or not is_instance_valid(player):
		return
	anim_player.play("ready_shoot")
	await anim_player.animation_finished
	anim_player.play("shoot")
	for i in range(3):
		var spit = MegaSpitScene.instantiate()
		get_tree().current_scene.add_child(spit)
		spit.global_position = global_position
		var dir = (player.global_position - global_position).normalized()
		spit.velocity = dir * spit_speed
		if spit.has_node("AnimationPlayer"):
			spit.get_node("AnimationPlayer").play("spit")
		await get_tree().create_timer(spit_delay).timeout
	anim_player.play("finish_shoot")
	await anim_player.animation_finished
	anim_player.play("idle")

# --- Utility ---
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
