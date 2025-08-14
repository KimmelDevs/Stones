extends StaticBody2D

var state = "berries"
var player_in_area = false

@onready var timer = $Growth_timer
@onready var sprite = $AnimatedSprite2D
@onready var berry_scene = preload("res://World/scenes/berry.tscn")

func _ready():
	if state == "no berries":
		timer.start()

func _process(delta):
	if state == "no berries":
		sprite.play("NoBerries")
	elif state == "berries":
		sprite.play("Berries")
		if player_in_area and Input.is_action_just_pressed("Pick"):
			state = "no berries"
			timer.start()
			print("pick")
			drop_berry()

func _on_pickable_area_body_entered(body: Node2D) -> void:
	if body.has_method("player"): 
		player_in_area = true
	

func _on_pickable_area_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		player_in_area = false
		

func drop_berry():
	var berry_instance = berry_scene.instantiate()
	berry_instance.global_position = $Marker2D.global_position
	berry_instance.z_index = 1  # make sure bush has z_index 0
	get_parent().add_child(berry_instance)
	print("dropped")

	# Wait before regrowing berries
	await get_tree().create_timer(260).timeout
	_on_growth_timer_timeout()

func _on_growth_timer_timeout() -> void:
	state = "berries"
