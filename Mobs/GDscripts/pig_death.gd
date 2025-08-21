extends Node2D

@onready var drop_corpse_scene = preload("res://Mobs/MobDrops/pig_corpse.tscn")


func _ready() -> void:
	$AnimatedSprite2D.play("Animate")

func _on_animated_sprite_2d_animation_finished() -> void:
	# Spawn bat wings
	var wings_instance = drop_corpse_scene.instantiate()
	wings_instance.global_position = global_position 
	get_parent().add_child(wings_instance)

	

	# Remove this node
	queue_free()
