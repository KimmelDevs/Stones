extends StaticBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Growth times in seconds
const TEEN_TIME = 180    # 3 minutes
const ADULT_TIME = 600   # 10 minutes

var is_adult: bool = false
var can_chop: bool = false

func _ready() -> void:
	# Start as Baby
	sprite.play("BabyTree")
	grow_to_teen()


func grow_to_teen() -> void:
	# After 3 minutes → TeenTree
	await get_tree().create_timer(TEEN_TIME).timeout
	sprite.play("TeenTree")
	grow_to_adult()


func grow_to_adult() -> void:
	# After 10 minutes → AdultTree
	await get_tree().create_timer(ADULT_TIME).timeout
	sprite.play("AdultTree")
	is_adult = true
	can_chop = true


func chop_tree() -> void:
	if can_chop:
		print("Tree chopped! You get some wood.")
		queue_free()  # remove the tree (or play a chopped animation if you want)
	else:
		print("Tree is too young to chop.")
