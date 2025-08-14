extends Control

@onready var inv = preload("res://Inventory/playerinventory.tres")
@onready var slots: Array = $NinePatchRect/GridContainer.get_children()

var is_open = false

func update_slots():
	for i in range(min(inv.slots.size(), slots.size())):
		slots[i].update(inv.slots[i])
func _process(delta):
	if Input.is_action_just_pressed("Inventory"):
		if is_open:
			close()
		else:
			open()
	
func _ready():
	close()
	update_slots()
	inv.update.connect(update_slots)
func open():
	visible = true
	is_open = true
	
func close():
	visible = false
	is_open = false
