extends Node2D

@export var damage := 200
@export var jump_force := 200.0
@export var air_time := 0.4          # Time in air after a jump
@export var jump_cooldown := 2.0     # Time before next jump
@export var chase_speed := 60.0      # Speed when chasing on the ground
@export var spit_speed := 250.0      # Speed of megaspit
@export var spit_delay := 0.2        # Delay between spits
@export var jumps_before_spit := 3   # How many jumps before shooting

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Node2D = $Sprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var hit_area: Area2D = $HitArea

var target: Node2D = null
var is_jumping := false
var can_jump := true
var is_chasing := false
var velocity := Vector2.ZERO
var jump_count := 0

var MegaSpitScene := preload("res://Enemies/Projectiles/megaspit.tscn")

func _ready() -> void:
	detection_area.connect("body_entered", Callable(self, "_on_detection_area_body_entered"))
	detection_area.connect("body_exited", Callable(self, "_on_detection_area_body_exited"))
	hit_area.connect("body_entered", Callable(self, "_on_hit_area_body_entered"))

func _physics_process(delta: float) -> void:
	if is_jumping and target:
		global_position += velocity * delta
	elif is_chasing and target and not is_jumping:
		var dir = (target.global_position - global_position).normalized()
		global_position += dir * chase_speed * delta
		anim_player.play("walk")

		if dir.x < 0:
			sprite.scale.x = 1
		elif dir.x > 0:
			sprite.scale.x = -1

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		target = body
		is_chasing = true
		if can_jump:
			start_jump_sequence()

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == target:
		is_chasing = false
		target = null
		anim_player.play("idle")

func start_jump_sequence() -> void:
	if target and target.is_inside_tree():
		can_jump = false
		is_chasing = false

		if target.global_position.x < global_position.x:
			sprite.scale.x = 1
		else:
			sprite.scale.x = -1

		anim_player.play("anticipation")
		await get_tree().create_timer(0.5).timeout
		jump_towards_player()

func jump_towards_player() -> void:
	if target and target.is_inside_tree():
		is_jumping = true
		var dir = (target.global_position - global_position).normalized()
		velocity = dir * jump_force
		anim_player.play("jump")

		await get_tree().create_timer(air_time).timeout
		velocity = Vector2.ZERO
		is_jumping = false
		anim_player.play("idle")

		jump_count += 1
		if jump_count >= jumps_before_spit:
			jump_count = 0
			await shoot_mega_spit()

		await get_tree().create_timer(jump_cooldown).timeout
		can_jump = true

		if target and is_instance_valid(target) and target.is_inside_tree():
			is_chasing = true
			if can_jump:
				start_jump_sequence()

# --- Mega spit attack ---
func shoot_mega_spit() -> void:
	if not target or not is_instance_valid(target):
		return

	# Added extra delay before preparing to shoot
	await get_tree().create_timer(0.5).timeout

	# Face the player before shooting
	if target.global_position.x < global_position.x:
		sprite.scale.x = 1
	else:
		sprite.scale.x = -1

	# Play ready animation and wait for it to finish
	anim_player.play("ready_shoot")
	await anim_player.animation_finished

	# Play shooting animation and shoot 3 spits
	anim_player.play("shoot")
	for i in range(3):
		var spit = MegaSpitScene.instantiate()
		get_tree().current_scene.add_child(spit)
		spit.global_position = global_position
		var dir = (target.global_position - global_position).normalized()
		spit.velocity = dir * spit_speed

		if spit.has_node("AnimationPlayer"):
			spit.get_node("AnimationPlayer").play("spit")

		await get_tree().create_timer(spit_delay).timeout

	# Play finish animation
	anim_player.play("finish_shoot")
	await anim_player.animation_finished

	# Return to idle before resuming jumps
	anim_player.play("idle")
