extends StaticBody2D


func spawn_grass_effect() -> void:
	var effect_scene = preload("res://Effects/grass_effect.tscn")
	var effect_instance = effect_scene.instantiate()
	effect_instance.global_position = global_position
	get_parent().add_child(effect_instance)

func _on_hurt_box_area_entered(area: Area2D) -> void:
	spawn_grass_effect()
	queue_free()
