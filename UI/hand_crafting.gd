extends Control

@onready var inv = preload("res://UI/CraftingAreaInventory.tres")
@onready var resultinv = preload("res://UI/ResultSlot.tres")
@onready var crafting_slots: Array = %CraftingSlotGroup.get_children()
@onready var result_slot = %ResultSlot.get_child(0)
@onready var playerinventory = preload("res://Inventory/playerinventory.tres")

var crafting_data: Array = []   # items in crafting grid

func _ready():
	visible = false
	crafting_data.resize(crafting_slots.size())

	# Connect slots
	for i in range(crafting_slots.size()):
		crafting_slots[i].slot_index = i
		crafting_slots[i].connect("slot_clicked", Callable(self, "_on_crafting_slot_clicked"))

	result_slot.slot_index = -1
	result_slot.connect("slot_clicked", Callable(self, "_on_result_slot_clicked"))

	update_slots()

func _input(event):
	if event.is_action_pressed("Craft"):
		visible = not visible

func update_slots():
	# update crafting slots
	for i in range(crafting_slots.size()):
		if crafting_data[i]:
			crafting_slots[i].update(crafting_data[i])
		else:
			crafting_slots[i].update(null)

	# check if a recipe matches
	var result = check_recipe()
	if result:
		result_slot.update(result)
	else:
		result_slot.update(null)

# --- Check crafting recipes from GlobalData ---
func check_recipe() -> InvItem:
	for item in GlobalData.all_items.values():
		var recipe: Array = item.Item_Recipe
		if recipe.size() != crafting_data.size():
			continue

		var is_match := true
		for i in range(crafting_data.size()):
			var wanted = recipe[i]   # String like "Stick" or null
			var got = crafting_data[i]  # InvItem or null

			if wanted == null and got == null:
				continue
			elif wanted == null and got != null:
				is_match = false
				break
			elif wanted != null:
				if got == null:
					is_match = false
					break
				elif not (got is InvItem):  # safety guard
					is_match = false
					break
				elif got.name != wanted:  # ✅ compare by name
					is_match = false
					break

		if is_match:
			return item

	return null


# --- Slot Handlers ---
func _on_crafting_slot_clicked(slot_index: int) -> void:
	if DragManager.is_dragging:
		var from_container = DragManager.source_container
		var from_index = DragManager.selected_slot_index

		if from_container and from_container != self:
			var temp = from_container.inv.slots[from_index]
			from_container.inv.slots[from_index] = crafting_data[slot_index]
			crafting_data[slot_index] = temp

			from_container.update_slots()
			update_slots()
		else:
			var temp = crafting_data[from_index]
			crafting_data[from_index] = crafting_data[slot_index]
			crafting_data[slot_index] = temp
			update_slots()

		DragManager.stop_drag()

func _on_result_slot_clicked(slot_index: int) -> void:
	var result_item: InvItem = check_recipe()
	if result_item == null:
		return

	# Add result item to player inventory
	playerinventory.add_item(result_item)

	# Consume items from crafting grid
	var recipe = result_item.Item_Recipe
	for i in range(crafting_data.size()):
		if recipe[i] != null:
			crafting_data[i] = null

	update_slots()
