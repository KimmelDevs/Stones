extends StaticBody2D

@export var item: InvItem
var player = null

func _ready():
	add_to_group("collectables")

func _on_interactable_area_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player = body

func _on_interactable_area_body_exited(body: Node2D) -> void:
	if body == player:
		player = null

# Remove the _process function entirely - player will handle picking

func playercollect():
	if player:
		player.collect(item)
		queue_free()
