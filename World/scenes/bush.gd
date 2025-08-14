extends StaticBody2D

@onready var bush_cam = $BushCamera
@onready var anim = $AnimationPlayer

var player_in_area = false
var hiding_player: CharacterBody2D = null
var player_ref: CharacterBody2D = null

# Called when a body enters the bush detection area
func _on_hideable_area_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player_in_area = true
		player_ref = body
		print("Player can hide")

# Called when a body exits the bush detection area
func _on_hideable_area_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		player_in_area = false
		# Automatically unhide if the player was hiding
		if hiding_player == body:
			unhide_player()
		player_ref = null
		print("Player left bush area")

# Called every frame to check input
func _process(delta):
	if player_in_area and Input.is_action_just_pressed("Hide") and hiding_player == null:
		hide_player(player_ref)
	elif hiding_player != null and Input.is_action_just_pressed("Hide"):
		unhide_player()

# Hides the player
func hide_player(player: CharacterBody2D) -> void:
	hiding_player = player
	
	# Stop player movement and rolling
	player.can_move = false
	player.can_roll = false
	player.visible = false
	
	# Disable hurtbox and collisions
	var hurtbox = player_ref.get_node("HurtBox")
	hurtbox.monitoring = false
	hurtbox.monitorable = false
	player_ref.set_collision_layer_value(2, false)
	
	# Switch camera to bush
	bush_cam.make_current()
	
	# Play hiding animation
	anim.play("Hide")
	print("Player is hiding")

# Unhides the player
func unhide_player() -> void:
	if hiding_player == null:
		return
	
	# Allow movement and rolling again
	hiding_player.can_move = true
	hiding_player.can_roll = true
	hiding_player.visible = true
	
	# Re-enable hurtbox and collisions
	var hurtbox = player_ref.get_node("HurtBox")
	hurtbox.monitoring = true
	hurtbox.monitorable = true
	player_ref.set_collision_layer_value(2, true)
	
	# Switch camera back to player's main camera
	var player_cam = hiding_player.get_node("Camera2D")
	if player_cam:
		player_cam.make_current()
	
	hiding_player = null
	anim.play("Idle")
	print("Player is back")
