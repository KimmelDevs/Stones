extends Node2D

@onready var marker: Marker2D = $Marker2D
@onready var spear_sprite: Sprite2D = $Marker2D/Sprite2D
@onready var anim: AnimationPlayer = $Marker2D/AnimationPlayer

var is_charging: bool = false

func _process(delta: float) -> void:
	# --- Rotate marker to face mouse ---
	var mouse_pos = get_global_mouse_position()
	var dir = (mouse_pos - global_position).normalized()
	marker.rotation = dir.angle()  # pure orbit around center, no drift

	# --- Handle mouse input ---
	if Input.is_action_just_pressed("attack"):
		if not is_charging:
			is_charging = true
			anim.play("Charge")

	if Input.is_action_just_released("attack"):
		if is_charging:
			is_charging = false
			anim.play("Attack")
