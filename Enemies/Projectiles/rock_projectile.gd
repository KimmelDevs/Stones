extends Node2D

@export var speed: float = 500.0
@export var lifetime: float = 4.0

var velocity: Vector2 = Vector2.ZERO
var thrown: bool = false
@onready var rock_hitbox: HitBox = $Sprite2D/HitBox
@export var weapon_damage: int = 1
@export var weapon_knockback: int = 1
var dir_vector: Vector2 = Vector2.ZERO

func start_throw(target_pos: Vector2):
	velocity = (target_pos - global_position).normalized() * speed
	dir_vector = (target_pos - global_position).normalized()
	thrown = true

	# Assign hitbox values before enabling it
	if rock_hitbox:
		rock_hitbox.damage = weapon_damage
		rock_hitbox.knockback_vector = dir_vector * (weapon_knockback * 0.3)
		rock_hitbox.monitoring = true  # Enable collision AFTER setup


func _ready():
	if thrown:
		await get_tree().create_timer(lifetime).timeout
		queue_free()

func _physics_process(delta):
	if thrown:
		position += velocity * delta




func _on_hit_box_body_shape_entered(_body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if thrown:
		print("Rock hit:", body.name)
		queue_free()
