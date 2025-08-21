extends Control

var is_open = false

func _ready():
	close()
	
func _process(delta: float) -> void:
	# Handle dragging icon following mouse


	if Input.is_action_just_pressed("Craft"):
		if is_open:
			close()
		else:
			open()

func open() -> void:
	visible = true
	is_open = true

func close() -> void:
	visible = false
	is_open = false
