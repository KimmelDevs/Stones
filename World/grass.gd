extends StaticBody2D

@onready var drop_grass_scene = preload("res://Inventory/scenes/grass_item.tscn")

func spawn_grass_effect() -> void:
	var effect_scene = preload("res://Effects/grass_effect.tscn")
	var effect_instance = effect_scene.instantiate()
	effect_instance.global_position = global_position
	get_parent().add_child(effect_instance)

func _on_hurt_box_area_entered(_area: Area2D) -> void:
	spawn_grass_effect()
	var grass_instance = drop_grass_scene.instantiate()
	grass_instance.global_position = global_position
	get_parent().add_child(grass_instance)
	queue_free()
