extends StaticBody2D

# --- State ---
var dying: bool = false
var is_shaking: bool = false

# --- Nodes ---
@onready var hurtbox = $HurtBox
@onready var stats = $Stats

func _physics_process(delta: float) -> void:
	if dying:
		spawn_death_effect()
		queue_free()

func _on_hurt_box_area_entered(area: Area2D) -> void:
	stats.set_health(stats.health - area.damage)
	hurtbox.create_hit_effect()
	shake()

	if stats.health <= 0:
		dying = true

func spawn_death_effect() -> void:
	var effect_scene = preload("res://Inventory/scenes/logs.tscn") # replace with tree death effect
	var effect_instance = effect_scene.instantiate()
	effect_instance.global_position = global_position
	get_parent().add_child(effect_instance)

func shake() -> void:
	if is_shaking:
		return # Prevent overlapping shakes
	is_shaking = true

	var original_pos = position
	var t = create_tween() # create fresh tween each time

	t.tween_property(self, "position", original_pos + Vector2(5, 0), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "position", original_pos - Vector2(5, 0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "position", original_pos, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Reset is_shaking when tween finishes
	t.finished.connect(Callable(self, "_on_shake_finished"))

func _on_shake_finished() -> void:
	is_shaking = false
