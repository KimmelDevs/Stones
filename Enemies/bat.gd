extends CharacterBody2D

var knockback: Vector2 = Vector2.ZERO
@export var knockback_speed: float = 200.0
@export var knockback_duration: float = 0.2
@export var acceleration: float = 200
@export var maxspeed: float = 50
@export var friction: float = 200
@export var wander_change_interval: float = 1.5
@export var wander_radius: float = 150  # Max distance from start
@onready var hurtbox = $HurtBox
enum {
	IDLE,
	WANDER,
	CHASE
}
var state = IDLE

var move_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var dying: bool = false

var wander_direction: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var home_position: Vector2

@onready var stats = $Stats
@onready var playerdetectionzone = $PlayerDetectionArea


func _ready() -> void:
	home_position = global_position


func _physics_process(delta: float) -> void:
	seek_player()

	match state:
		IDLE:
			move_velocity = move_velocity.move_toward(Vector2.ZERO, friction * delta)
			# Occasionally go into wander mode
			if randf() < 0.01:
				state = WANDER
		WANDER:
			wander_timer -= delta
			if wander_timer <= 0:
				pick_new_wander_direction()
				wander_timer = wander_change_interval
			
			move_velocity = move_velocity.move_toward(wander_direction * maxspeed, acceleration * delta)
			
			# Keep bat near home
			if global_position.distance_to(home_position) > wander_radius:
				var dir_to_home = (home_position - global_position).normalized()
				move_velocity = move_velocity.move_toward(dir_to_home * maxspeed, acceleration * delta)
		CHASE:
			var player = playerdetectionzone.player
			if player != null:
				var dir = (player.global_position - global_position).normalized()
				move_velocity = move_velocity.move_toward(dir * maxspeed, acceleration * delta)

	# Apply knockback first if active
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


func pick_new_wander_direction() -> void:
	wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()


func seek_player() -> void:
	if playerdetectionzone.can_see_player():
		state = CHASE
	else:
		if state == CHASE:
			state = WANDER  # Go back to wandering after losing sight


func _on_hurt_box_area_entered(area: Area2D) -> void:
	knockback = area.knockback_vector * knockback_speed
	knockback_timer = knockback_duration
	stats.health -= 1
	hurtbox.create_hit_effect()
	print("Health:", stats.health)
	if stats.health <= 0:
		dying = true


func spawn_Death_effect() -> void:
	var effect_scene = preload("res://Effects/bat_death.tscn")
	var effect_instance = effect_scene.instantiate()
	effect_instance.global_position = global_position
	get_parent().add_child(effect_instance)
