extends Node2D

@export var damage := 1
@export var knockback_force := 1.0
var velocity := Vector2.ZERO

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hit_box: HitBox = $HitBox

func _ready() -> void:
	hit_box.damage = damage
	# knockback will always follow the spit’s movement direction
	if velocity != Vector2.ZERO:
		hit_box.knockback_vector = velocity.normalized() * (knockback_force *0.3)

	# connect hitbox
	hit_box.connect("hit", Callable(self, "_on_hit_box_hit"))

	anim_player.play("spit")

func _physics_process(delta: float) -> void:
	global_position += velocity * delta

	# update knockback direction every frame to match spit direction
	if velocity != Vector2.ZERO:
		hit_box.knockback_vector = velocity.normalized() * knockback_force

	if global_position.length() > 5000:
		queue_free()

func trigger_explosion() -> void:
	velocity = Vector2.ZERO
	anim_player.play("explode")
	await anim_player.animation_finished
	queue_free()

func _on_hit_box_hit(target: Node) -> void:
	queue_free()
