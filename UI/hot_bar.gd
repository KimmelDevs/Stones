extends Control

signal selection_changed(item)

@onready var inv = preload("res://Inventory/playerinventory.tres")
@onready var slots: Array = $HBoxContainer.get_children()

var selected_index: int = 0

func _ready():
	update_slots()
	inv.update.connect(_on_inventory_changed)

	# Connect clicks for selection
	for i in range(slots.size()):
		var slot = slots[i]
		slot.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				selected_index = i
				_update_selection()
		)

	_update_selection()

func update_slots():
	for i in range(slots.size()):
		if i < inv.slots.size():
			slots[i].update(inv.slots[i])
		else:
			slots[i].update(null)

func _on_inventory_changed():
	update_slots()
	emit_signal("selection_changed", get_selected_item())

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode >= KEY_1 and event.keycode < KEY_1 + slots.size():
			selected_index = event.keycode - KEY_1
			_update_selection()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			selected_index = (selected_index - 1) % slots.size()
			_update_selection()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			selected_index = (selected_index + 1) % slots.size()
			_update_selection()

func _update_selection():
	for i in range(slots.size()):
		slots[i].modulate = Color(1, 1, 1) if i == selected_index else Color(0.8, 0.8, 0.8)
	emit_signal("selection_changed", get_selected_item())

func get_selected_item():
	if selected_index < inv.slots.size():
		var slot = inv.slots[selected_index]
		if slot and slot.item:
			return slot.item
	return null
