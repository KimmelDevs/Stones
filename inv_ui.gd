extends Control

@onready var inv = preload("res://Inventory/playerinventory.tres")
@onready var slots: Array = $NinePatchRect/GridContainer.get_children()

var is_open = false
var start_index = 6   # offset if hotbar uses first slots in inv

func _ready():
	close()
	update_slots()
	inv.update.connect(update_slots)

	# Connect slot click signals
	for i in range(slots.size()):
		slots[i].slot_index = i + start_index
		slots[i].connect("slot_clicked", Callable(self, "_on_slot_clicked"))

func update_slots():
	for i in range(min(inv.slots.size() - start_index, slots.size())):
		slots[i].slot_index = i + start_index
		slots[i].update(inv.slots[i + start_index])

func _process(delta):
	# Handle dragging icon following mouse
	if DragManager.is_dragging:
		DragManager.update_drag_position()

	if Input.is_action_just_pressed("Inventory"):
		if is_open:
			close()
		else:
			open()

func _on_slot_clicked(slot_index: int):
	if DragManager.is_dragging:
		var from_container = DragManager.source_container
		var from_index = DragManager.selected_slot_index

		if from_container and from_container != self:
			# --- Swap between Inventory <-> Hotbar ---
			var temp = from_container.inv.slots[from_index]
			from_container.inv.slots[from_index] = inv.slots[slot_index]
			inv.slots[slot_index] = temp

			from_container.update_slots()
			update_slots()
		else:
			# --- Swap inside Inventory ---
			var temp = inv.slots[from_index]
			inv.slots[from_index] = inv.slots[slot_index]
			inv.slots[slot_index] = temp
			update_slots()

		# End drag
		DragManager.stop_drag()

func _unhandled_input(event):
	# Cancel drag if left click outside slots
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if DragManager.is_dragging:
			var hovered_slot = false
			var mouse_pos = get_global_mouse_position()
			for slot in slots:
				if slot.get_global_rect().has_point(mouse_pos):
					hovered_slot = true
					break
			if !hovered_slot:
				DragManager.stop_drag()

func open():
	visible = true
	is_open = true

func close():
	visible = false
	is_open = false
