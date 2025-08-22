extends Area2D

@export var tree_scene: PackedScene = load("res://World/scenes/normal_tree.tscn")
@export var spawn_count: int = 5
@export var spawn_area: Vector2 = Vector2(500, 500)

func _ready():
	randomize()
	for i in range(spawn_count):
		spawn_tree()

func spawn_tree():
	if tree_scene == null:
		push_error("Tree scene path is wrong!")
		return

	var tree = tree_scene.instantiate()
	get_tree().current_scene.add_child(tree)  # add first

	# now set world position
	var random_pos = Vector2(
		randf_range(-spawn_area.x/2, spawn_area.x/2),
		randf_range(-spawn_area.y/2, spawn_area.y/2)
	)
	tree.global_position = global_position + random_pos

	# find AnimatedSprite2D (search recursively just in case name differs)
	var sprite: AnimatedSprite2D = tree.find_child("AnimatedSprite2D", true, false)

	if sprite:
		match randi_range(0, 2):
			0:
				sprite.play("BabyTree")
			1:
				sprite.play("TeenTree")
			2:
				sprite.play("AdultTree")
				tree.is_adult = true
				tree.can_chop = true

	print("Spawned tree at:", tree.global_position)
