extends Control

signal selection_changed(item) # Emits the actual selected item

@onready var inv = preload("res://Inventory/playerinventory.tres")
@onready var slots: Array = $HBoxContainer.get_children()  # Your 6 inv_ui_slot nodes

var selected_index: int = 0

func _ready():
	update_slots()
	inv.update.connect(update_slots)
	_update_selection()

func update_slots():
	for i in range(slots.size()):
		if i < inv.slots.size():
			slots[i].update(inv.slots[i])
		else:
			slots[i].update(null)

func _input(event):
	# Number keys to select slot
	if event is InputEventKey and event.pressed:
		if event.keycode >= KEY_1 and event.keycode < KEY_1 + slots.size():
			selected_index = event.keycode - KEY_1
			_update_selection()

	# Scroll wheel selection
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			selected_index = (selected_index - 1) % slots.size()
			_update_selection()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			selected_index = (selected_index + 1) % slots.size()
			_update_selection()

func _update_selection():
	for i in range(slots.size()):
		if i == selected_index:
			slots[i].modulate = Color(1, 1, 1)
		else:
			slots[i].modulate = Color(0.8, 0.8, 0.8)

	# Emit currently selected item
	emit_signal("selection_changed", get_selected_item())

func get_selected_item():
	if selected_index < inv.slots.size():
		var slot = inv.slots[selected_index]
		if slot and slot.item:
			return slot.item  # Return the actual InvItem
	return null
