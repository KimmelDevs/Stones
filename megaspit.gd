extends Node2D

@export var damage := 200
var velocity := Vector2.ZERO

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var explosion_area: Area2D = $ExplosionArea

func _ready() -> void:
	# ExplosionArea should be disabled until projectile explodes
	explosion_area.monitoring = false
	explosion_area.connect("body_entered", Callable(self, "_on_explosion_area_body_entered"))
	anim_player.play("spit") # Flying animation

func _physics_process(delta: float) -> void:
	global_position += velocity * delta

	# Optional: destroy if too far off-screen or out of range
	if global_position.length() > 5000:
		queue_free()

# Call this when projectile hits something (wall, player, etc.)
func trigger_explosion() -> void:
	velocity = Vector2.ZERO
	explosion_area.monitoring = true
	anim_player.play("explode")
	await anim_player.animation_finished
	queue_free()

# Explosion damage
func _on_explosion_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
