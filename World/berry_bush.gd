extends StaticBody2D

var state = "berries"
@export var item: InvItem

@onready var timer = $Growth_timer
@onready var sprite = $AnimatedSprite2D
@onready var berry_scene = preload("res://World/scenes/berry.tscn")

func _ready():
	add_to_group("berry_bush")
	if state == "no berries":
		timer.start()

func _process(delta):
	if state == "no berries":
		sprite.play("NoBerries")
	else:
		sprite.play("Berries")

func drop_berry(player: Node):
	if state != "berries":
		return
	state = "no berries"
	timer.start()

	var berry_instance = berry_scene.instantiate()
	berry_instance.global_position = $Marker2D.global_position
	berry_instance.z_index = 1
	get_parent().add_child(berry_instance)

	if player != null and player.has_method("collect"):
		player.collect(item)

	await get_tree().create_timer(260).timeout
	state = "berries"
