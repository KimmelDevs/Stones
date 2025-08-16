extends Node2D

@export var speed: float = 500.0
@export var lifetime: float = 4.0

var velocity: Vector2 = Vector2.ZERO
var thrown: bool = false

func start_throw(target_pos: Vector2):
	velocity = (target_pos - global_position).normalized() * speed
	thrown = true

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
