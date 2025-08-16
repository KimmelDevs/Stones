class_name HitBox
extends Area2D

# These will be set by the player when attacking
@export var damage: int = 0
@export var knockback_vector: Vector2 = Vector2.ZERO

# Signal for when this hitbox hits an enemy
signal hit(target)

func _on_body_entered(body: Node):
	if body.has_method("apply_damage"):
		body.apply_damage(damage, knockback_vector)
		emit_signal("hit", body)
