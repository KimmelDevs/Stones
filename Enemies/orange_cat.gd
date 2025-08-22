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

# --- Chase (no sway) ---
@export var chase_radius: float = 200.0

# --- Attack ---
@export var attack_range: float = 50.0
@export var attack_cooldown: float = 0.5
@export var attack_dive_speed: float = 180.0
@export var anticipation_time: float = 0.4
@export var recovery_time: float = 0.6
var can_attack: bool = true
@onready var hitbox = $HitBox
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# --- Nodes ---
@onready var hurtbox = $HurtBox
@onready var stats = $Stats
@onready var playerdetectionzone = $PlayerDetectionArea
@onready var sprite = $Sprite2D

@export var sneak_distance: float = 20.0

# --- State machine ---
enum { IDLE, WANDER, CHASE, SNEAK, ANTICIPATE, DIVE, RECOVER }
var state = IDLE

# --- Variables ---
var move_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var dying: bool = false
var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var home_position: Vector2
var has_sneaked: bool = false

# Attack vars
var attack_target: Vector2
var attack_timer: float = 0.0

func _ready() -> void:
	home_position = global_position
	hitbox.damage = 1.5
	hitbox.knockback_vector = Vector2(1, 0)

func _physics_process(delta: float) -> void:
	seek_player()

	match state:
		IDLE:
			move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta)
			if randf() < 0.01:
				state = WANDER
			if anim_player.current_animation != "Idle":
				anim_player.play("Idle")

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
				if anim_player.current_animation != "Walk":
					anim_player.play("Walk")

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
					_chase_aggressive(player, delta)
					if anim_player.current_animation != "Walk":
						anim_player.play("Walk")
			else:
				state = WANDER

		SNEAK:
			attack_timer -= delta
			if attack_timer <= 0:
				if playerdetectionzone.player != null:
					state = ANTICIPATE
					attack_timer = anticipation_time
					attack_target = playerdetectionzone.player.global_position
					move_velocity = Vector2.ZERO
					anim_player.play("ReadyJump")
				else:
					state = WANDER
					move_velocity = Vector2.ZERO

		ANTICIPATE:
			attack_timer -= delta
			if attack_timer <= 0:
				if attack_target != null:
					state = DIVE
					anim_player.play("LandAttack")
				else:
					state = WANDER

		DIVE:
			if attack_target != null:
				var dir = (attack_target - global_position).normalized()
				move_velocity = dir * attack_dive_speed
				update_sprite_facing(dir)
				if global_position.distance_to(attack_target) < 10:
					state = RECOVER
					attack_timer = recovery_time
					move_velocity = Vector2.ZERO
					anim_player.play("LandAttack")
			else:
				state = WANDER
				move_velocity = Vector2.ZERO

		RECOVER:
			attack_timer -= delta
			if attack_timer <= 0:
				state = CHASE
				can_attack = false
				await get_tree().create_timer(attack_cooldown).timeout
				can_attack = true

	# Apply knockback if active
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

# --- Aggressive chase (straight line, no sway) ---
func _chase_aggressive(player: Node2D, delta: float) -> void:
	var dir = (player.global_position - global_position).normalized()
	move_velocity = move_velocity.move_toward(dir * maxspeed, acceleration * delta)
	update_sprite_facing(dir)

func pick_new_wander_direction() -> void:
	wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func seek_player() -> void:
	if playerdetectionzone.can_see_player():
		if state in [IDLE, WANDER]:
			state = CHASE
	else:
		if state in [CHASE, ANTICIPATE, DIVE, RECOVER]:
			state = WANDER

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
		if direction.x < 0:
			sprite.flip_h = true
			hitbox.scale.x = -1  # flip hitbox horizontally
		else:
			sprite.flip_h = false
			hitbox.scale.x = 1   # reset hitbox scale
