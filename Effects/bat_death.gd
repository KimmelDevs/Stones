extends Node2D

@onready var drop_wings_scene = preload("res://Enemies/EnemyDrops/bat_wings.tscn")
@onready var drop_head_scene = preload("res://Enemies/EnemyDrops/bat_head.tscn")
@onready var drop_meat_scene = preload("res://Inventory/Items/bat_meat.tscn")

func _ready() -> void:
	$AnimatedSprite2D.play("Animate")

func _on_animated_sprite_2d_animation_finished() -> void:
	# Spawn bat wings
	var wings_instance = drop_wings_scene.instantiate()
	wings_instance.global_position = global_position + Vector2(randf_range(-16, 16), randf_range(-16, 16))
	get_parent().add_child(wings_instance)

	# Spawn bat head
	var head_instance = drop_head_scene.instantiate()
	head_instance.global_position = global_position + Vector2(randf_range(-16, 16), randf_range(-16, 16))
	get_parent().add_child(head_instance)

	# Spawn bat meat
	var meat_instance = drop_meat_scene.instantiate()
	meat_instance.global_position = global_position + Vector2(randf_range(-16, 16), randf_range(-16, 16))
	get_parent().add_child(meat_instance)

	# Remove this node
	queue_free()
