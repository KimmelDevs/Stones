extends Camera2D

@export var decay: float = 5.0
@export var max_offset: float = 8.0
@export var max_roll: float = 0.1

var trauma: float = 0.0
var trauma_power: float = 2.0
var base_position := Vector2.ZERO

func _ready():
	# Remember the camera’s default position
	base_position = position

func _process(delta: float) -> void:
	if trauma > 0:
		trauma = max(trauma - decay * delta, 0)
		var shake = pow(trauma, trauma_power)

		rotation = randf_range(-1, 1) * max_roll * shake
		position = base_position + Vector2(
			randf_range(-1, 1) * max_offset * shake,
			randf_range(-1, 1) * max_offset * shake
		)
	else:
		rotation = 0
		position = base_position

func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)
