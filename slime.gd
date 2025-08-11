extends Node2D

@export var damage := 200
@export var jump_force := 200.0
@export var air_time := 0.4        # Time in air during jump
@export var jump_cooldown := 2.0   # Time between jumps
@export var chase_speed := 60.0    # Walking speed

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Node2D = $Sprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var hit_area: Area2D = $HitArea

var target: Node2D = null
var is_jumping := false
var can_jump := true
var is_chasing := false
var velocity := Vector2.ZERO

func _ready() -> void:
	detection_area.connect("body_entered", Callable(self, "_on_detection_area_body_entered"))
	detection_area.connect("body_exited", Callable(self, "_on_detection_area_body_exited"))
	hit_area.connect("body_entered", Callable(self, "_on_hit_area_body_entered"))
	anim_player.play("idle")

func _physics_process(delta: float) -> void:
	if is_jumping and target:
		# Move slime while in air
		global_position += velocity * delta
	elif is_chasing and target and not is_jumping:
		# Walk towards player
		var dir = (target.global_position - global_position).normalized()
		global_position += dir * chase_speed * delta
		anim_player.play("walk")

		# Face player
		sprite.scale.x = 1 if dir.x < 0 else -1
		# Jump is NOT triggered here anymore — handled by timers/jump sequence

# --- Detection events ---
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		target = body
		is_chasing = true
		if can_jump:
			start_jump_sequence()

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == target:
		target = null
		is_chasing = false
		anim_player.play("idle")

# --- Jump logic ---
func start_jump_sequence() -> void:
	if target and target.is_inside_tree() and can_jump:
		can_jump = false
		is_chasing = false

		# Face player before jumping
		sprite.scale.x = 1 if target.global_position.x < global_position.x else -1

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

		# Cooldown before next jump
		await get_tree().create_timer(jump_cooldown).timeout
		can_jump = true

		# If still chasing after cooldown, jump again
		if target and is_instance_valid(target) and target.is_inside_tree():
			start_jump_sequence()

# --- Damage handling ---
func _on_hit_area_body_entered(body: Node2D) -> void:
	if is_jumping and body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
