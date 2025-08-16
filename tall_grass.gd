extends Node2D

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var bat_scene: PackedScene = preload("res://Enemies/bat.tscn")
@onready var mega_slime_scene: PackedScene = preload("res://Enemies/mega_slime.tscn")

func _on_area_2d_body_entered(body: Node2D) -> void:
	anim.play("Stepped")

func _on_area_2d_body_exited(body: Node2D) -> void:
	anim.play("Normal")

	# 5% chance to spawn an enemy
	if randf() <= 0.01:
		var enemy_scene: PackedScene
		if randi() % 2 == 0:
			enemy_scene = bat_scene
		else:
			enemy_scene = mega_slime_scene

		var enemy = enemy_scene.instantiate()
		get_parent().add_child(enemy)
		enemy.global_position = global_position
