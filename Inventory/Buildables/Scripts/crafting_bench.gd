extends StaticBody2D
class_name CraftingBench


var player_in_area = false
var player_ref: CharacterBody2D = null

var is_interactable = false
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player_in_area = true
		player_ref = body
		print("Player can hide")
	if body is PlayerEntity:
		is_interactable = true


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		player_in_area = false
		is_interactable = false
		player_ref = null
		print("Player left bush area")
