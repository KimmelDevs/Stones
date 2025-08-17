extends Control

@onready var inv = preload("res://Inventory/playerinventory.tres")
@onready var crafting_slots: Array = %CraftingSlotGroup.get_children()
@onready var result_slot = %ResultSlot.get_child(0)

var crafting_data: Array = []  # temporary array to hold items placed in crafting grid

func _ready():
	visible = false  # hide at start
	crafting_data.resize(crafting_slots.size())

	# Connect crafting slot signals
	for i in range(crafting_slots.size()):
		crafting_slots[i].slot_index = i
		crafting_slots[i].connect("slot_clicked", Callable(self, "_on_crafting_slot_clicked"))

	# Connect result slot signal
	result_slot.slot_index = -1  # mark special index
	result_slot.connect("slot_clicked", Callable(self, "_on_result_slot_clicked"))

	update_slots()

func _input(event):
	if event.is_action_pressed("Craft"):
		visible = not visible  # toggle crafting UI

func update_slots():
	# update crafting slots
	for i in range(crafting_slots.size()):
		if crafting_data[i]:
			crafting_slots[i].update(crafting_data[i])
		else:
			crafting_slots[i].update(null)

	# update result slot (for now just empty)
	result_slot.update(null)

# --- Slot Handlers ---
func _on_crafting_slot_clicked(slot_index: int) -> void:
	if DragManager.is_dragging:
		var from_container = DragManager.source_container
		var from_index = DragManager.selected_slot_index

		if from_container and from_container != self:
			# Swap with external container
			var temp = from_container.inv.slots[from_index]
			from_container.inv.slots[from_index] = crafting_data[slot_index]
			crafting_data[slot_index] = temp

			from_container.update_slots()
			update_slots()
		else:
			# Swap inside crafting grid
			var temp = crafting_data[from_index]
			crafting_data[from_index] = crafting_data[slot_index]
			crafting_data[slot_index] = temp
			update_slots()

		DragManager.stop_drag()

func _on_result_slot_clicked(slot_index: int) -> void:
	if DragManager.is_dragging:
		# just drop into result slot for now
		result_slot.update(DragManager.dragged_item)
		DragManager.stop_drag()
func invpass():
	pass
