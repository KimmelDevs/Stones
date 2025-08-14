extends Control

var is_open = false

func _process(delta):
	if Input.is_action_just_pressed("Inventory"):
		if is_open:
			close()
		else:
			open()
	
func _ready():
	close()
func open():
	visible = true
	is_open = true
	
func close():
	visible = false
	is_open = false
