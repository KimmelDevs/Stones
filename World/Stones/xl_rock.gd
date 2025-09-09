extends StaticBody2D

# Rock mining properties
@export var max_hits := 3
@export var min_drops := 1
@export var max_drops := 3

# Preload the collectible rock scene
@onready var drop_rock_scene = preload("res://World/scenes/rock.tscn")

var hits := 0

func _ready():
	# Make sure rock is in the correct group
	add_to_group("rocks")

func mine_hit(power: int) -> void:
	hits += power
	print("Rock hit! Hits: ", hits, "/", max_hits)
	
	if hits >= max_hits:
		print("Rock destroyed!")
		drop_items_on_destroy()
		queue_free()

func drop_items_on_destroy():
	# Random number of drops between min and max
	var num_drops = randi_range(min_drops, max_drops)
	print("Dropping ", num_drops, " rock items")
	
	for i in range(num_drops):
		var rock_instance = drop_rock_scene.instantiate()
		rock_instance.global_position = global_position + Vector2(randf_range(-16, 16), randf_range(-16, 16))
		get_parent().add_child(rock_instance)
		print("Dropped rock at: ", rock_instance.global_position)
