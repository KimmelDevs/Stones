extends CharacterBody2D

const SPEED = 100.0
var animation_player: AnimationPlayer
var last_direction := "down" # Keeps track of last movement direction

func _ready():
	animation_player = $AnimationPlayer  # Ensure you have AnimationPlayer with animations set

func _physics_process(delta: float) -> void:
	var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_vector * SPEED
	move_and_slide()

	if input_vector != Vector2.ZERO:
		# Play walk animations & store last direction
		if input_vector.x > 0:
			animation_player.play("walk_right")
			last_direction = "right"
		elif input_vector.x < 0:
			animation_player.play("walk_left")
			last_direction = "left"
		elif input_vector.y < 0:
			animation_player.play("walk_up")
			last_direction = "up"
		elif input_vector.y > 0:
			animation_player.play("walk_down")
			last_direction = "down"
	else:
		# Play idle animation for the last direction faced
		match last_direction:
			"right":
				animation_player.play("idle_right")
			"left":
				animation_player.play("idle_left")
			"up":
				animation_player.play("idle_up")
			"down":
				animation_player.play("idle_down")
