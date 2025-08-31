extends StaticBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer: Timer = $Timer

# Path to your normal tree scene
const TREE_SCENE = preload("res://World/scenes/normal_tree.tscn")

func _ready() -> void:
	# Start sapling animation
	sprite.play("default")  # make sure your sapling anim is called "default"
	timer.start()           # start the timer

func _on_timer_timeout() -> void:
	# Replace sapling with normal tree
	var tree = TREE_SCENE.instantiate()
	tree.global_position = global_position
	
	get_parent().add_child(tree)
	queue_free()
"res://Player/player.tscn"
