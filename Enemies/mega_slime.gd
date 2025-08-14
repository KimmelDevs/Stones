extends CharacterBody2D

# --- Knockback ---
var knockback: Vector2 = Vector2.ZERO
@export var knockback_speed: float = 200.0
@export var knockback_duration: float = 0.2

# --- Jump settings ---
@export var jump_force := 200.0
@export var air_time := 0.4
@export var jump_cooldown := 2.0
@export var spit_speed := 250.0
@export var spit_delay := 0.2	
@export var jumps_before_spit := 3

# --- States ---
enum { IDLE, WANDER, CHASE }
var state = IDLE

# --- Nodes ---
@onready var hurtbox = $HurtBox
@onready var stats = $Stats
@onready var playerdetectionzone = $PlayerDetectionArea
@onready var sprite = $Sprite2D
@onready var anim_player = $AnimationPlayer


# --- Projectile Scene ---
var MegaSpitScene := preload("res://Enemies/Projectiles/megaspit.tscn")

# --- Vars ---
var move_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var dying: bool = false
var home_position: Vector2
var is_jumping := false
var can_jump := true
var jump_count := 0
var jump_target: Vector2 = Vector2.ZERO  # Fixed landing spot

func _ready() -> void:
	home_position = global_position

func _physics_process(delta: float) -> void:
	seek_player()

	if knockback_timer > 0:
		velocity = knockback
		knockback_timer -= delta
		if knockback_timer <= 0 and dying:
			spawn_Death_effect()
			queue_free()
	else:
		velocity = move_velocity

	move_and_slide()

func seek_player() -> void:
	if is_jumping or not can_jump:
		return

	if playerdetectionzone.can_see_player():
		state = CHASE
		var player = playerdetectionzone.player
		if player:
			start_jump_sequence(player.global_position)
	else:
		state = WANDER
		var random_pos = home_position + Vector2(randf_range(-150, 150), randf_range(-150, 150))
		start_jump_sequence(random_pos)

# --- Jump & MegaSpit ---
func start_jump_sequence(target_position: Vector2) -> void:
	if is_jumping or not can_jump:
		return

	can_jump = false
	is_jumping = true
	jump_target = target_position  # Lock in landing spot

	# Flip only once at anticipation
	if jump_target.x < global_position.x:
		sprite.flip_h = false
	else:
		sprite.flip_h = true

	# Start anticipation
	anim_player.play("anticipation")
	await get_tree().create_timer(0.5).timeout

	# Launch toward fixed target
	var dir = (jump_target - global_position).normalized()
	move_velocity = dir * jump_force
	anim_player.play("jump")
	await get_tree().create_timer(air_time).timeout

	is_jumping = false
	move_velocity = Vector2.ZERO
	anim_player.play("idle")

	jump_count += 1
	if jump_count >= jumps_before_spit and state == CHASE:
		jump_count = 0
		await shoot_mega_spit()

	await get_tree().create_timer(jump_cooldown).timeout
	can_jump = true

func shoot_mega_spit() -> void:
	var player = playerdetectionzone.player
	if not player or not is_instance_valid(player):
		return

	anim_player.play("ready_shoot")
	await anim_player.animation_finished

	# FIX: Use global_position.x and keep flip logic consistent
	if player.global_position.x < global_position.x:
		sprite.flip_h = true   # Facing left
	else:
		sprite.flip_h = false  # Facing right

	anim_player.play("shoot")

	var target_pos = player.global_position  # Lock aim position now

	for i in range(3):
		var spit = MegaSpitScene.instantiate()
		get_tree().current_scene.add_child(spit)
		spit.global_position = global_position
		var dir = (target_pos - global_position).normalized()
		spit.velocity = dir * spit_speed
		if spit.has_node("AnimationPlayer"):
			spit.get_node("AnimationPlayer").play("spit")
		await get_tree().create_timer(spit_delay).timeout

	anim_player.play("finish_shoot")
	await anim_player.animation_finished
	anim_player.play("idle")

# --- Damage ---
func _on_hurt_box_area_entered(area: Area2D) -> void:
	knockback = area.knockback_vector * knockback_speed
	knockback_timer = knockback_duration
	stats.set_health(stats.health - 1)
	hurtbox.create_hit_effect()
	if stats.health <= 0:
		dying = true

func spawn_Death_effect() -> void:
	var effect_scene = preload("res://Effects/slime_death.tscn")
	var effect_instance = effect_scene.instantiate()
	effect_instance.global_position = global_position
	get_parent().add_child(effect_instance)
