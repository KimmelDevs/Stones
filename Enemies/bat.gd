extends CharacterBody2D

var knockback: Vector2 = Vector2.ZERO
@export var knockback_speed: float = 200.0
@export var knockback_duration: float = 0.2

var knockback_timer: float = 0.0
@onready var stats = $Stats

func _physics_process(delta: float) -> void:
	if knockback_timer > 0:
		velocity = knockback
		knockback_timer -= delta
	else:
		velocity = Vector2.ZERO  # Replace with your normal movement here

	move_and_slide()

func _on_hurt_box_area_entered(area: Area2D) -> void:
	knockback = area.knockback_vector * knockback_speed
	knockback_timer = knockback_duration
	# Example: reduce health from stats node
	stats.health -= 1
	
	print("Health:", stats.health)


func _on_stats_no_health():
	queue_free()
