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
		sprite.play("NoMugworth")
	else:
		sprite.play("MugWorth")

func drop_berry(player: Node):
	if state != "berries":
		return
	state = "no berries"
	timer.start()


	if player != null and player.has_method("collect"):
		player.collect(item)

	await get_tree().create_timer(260).timeout
	state = "berries"
