extends StaticBody2D

@export var item: InvItem
var player = null
var can_pick: bool = false  # true when player is in range

func _ready():
	add_to_group("collectables")

func _on_interactable_area_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player = body
		can_pick = true  # player is in range

func _on_interactable_area_body_exited(body: Node2D) -> void:
	if body == player:
		can_pick = false
		player = null

func _process(delta):
	if can_pick and Input.is_action_just_pressed("Pick"):  # assign "pick" in Input Map
		playercollect()
		self.queue_free()

func playercollect():
	if player:
		player.collect(item)
