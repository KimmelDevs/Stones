extends Node2D

@export var damage := 200
var velocity := Vector2.ZERO

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var explosion_area: Area2D = $ExplosionArea
@onready var hit_box: Area2D = $HitBox

func _ready() -> void:
	# Explosion area should be off until projectile explodes
	explosion_area.monitoring = false
	explosion_area.connect("body_entered", Callable(self, "_on_explosion_area_body_entered"))
	
	# Connect HitBox detection
	hit_box.connect("area_entered", Callable(self, "_on_hit_box_area_entered"))
	
	anim_player.play("spit") # Flying animation

func _physics_process(delta: float) -> void:
	global_position += velocity * delta

	# Destroy if way off-screen
	if global_position.length() > 5000:
		queue_free()

# Trigger explosion animation and effect
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

# HitBox collision → trigger explosion
func _on_hit_box_area_entered(area: Area2D) -> void:
	queue_free()
