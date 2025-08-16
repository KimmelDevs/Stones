extends Node2D  # Or Area2D depending on your setup

@export var player: Node2D  # Reference to player
var knockback_vector: Vector2 = Vector2.ZERO

func _ready():
	var hitbox: HitBox = $Marker2D/HitBox
	hitbox.knockback_vector = knockback_vector
func set_player(player_node: Node2D) -> void:
	player = player_node
	# Optional: link weapon to player here

func set_hitbox_knockback(dir_vector: Vector2) -> void:
	knockback_vector = dir_vector
	var hitbox = $Marker2D/HitBox
	if hitbox and hitbox.has_variable("knockback_vector"):
		hitbox.knockback_vector = dir_vector
