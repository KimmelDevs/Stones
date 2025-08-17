extends Resource
class_name Inv

@export var slots: Array[InvSlot]
signal update

# --- Inventory validation before any update ---
func validate_inventory():
	if slots == null:
		slots = []
	for slot in slots:
		if slot == null:
			continue  # skip null slots
		if slot.item != null and slot.amount < 1:
			# If an item exists but amount is invalid, fix it
			slot.amount = 1
		elif slot.item == null:
			# Only touch empty slots if amount is negative
			if slot.amount < 0:
				slot.amount = 0


# --- Insert item into inventory ---
func insert(item: InvItem):
	validate_inventory()
	# Try to find any slot that already has this item
	var itemslots = slots.filter(func(slot): return slot.item == item)
	if !itemslots.is_empty():
		# Add to the first existing stack
		itemslots[0].amount += 1
	else:
		# Otherwise, find an empty slot
		var emptyslots = slots.filter(func(slot): return slot.item == null)
		if !emptyslots.is_empty():
			emptyslots[0].item = item
			emptyslots[0].amount = 1
	update.emit()

# --- Remove a certain amount of an item ---
func remove_item(item: InvItem, amount: int = 1) -> bool:
	validate_inventory()
	var remaining = amount
	for slot in slots:
		if slot.item == item:
			if slot.amount >= remaining:
				slot.amount -= remaining
				if slot.amount <= 0:
					slot.item = null
					slot.amount = 0
				update.emit()
				return true
			else:
				remaining -= slot.amount
				slot.item = null
				slot.amount = 0
	update.emit()
	return remaining <= 0

# --- Remove by resource path ---
func remove_item_by_path(item_path: String, amount: int = 1) -> bool:
	validate_inventory()
	var remaining = amount
	for slot in slots:
		if slot.item and slot.item.resource_path == item_path:
			if slot.amount >= remaining:
				slot.amount -= remaining
				if slot.amount <= 0:
					slot.item = null
					slot.amount = 0
				update.emit()
				return true
			else:
				remaining -= slot.amount
				slot.item = null
				slot.amount = 0
	update.emit()
	return remaining <= 0

# --- Check if inventory has item ---
func has_item(item: InvItem, amount: int = 1) -> bool:
	validate_inventory()
	return count_item(item) >= amount

func has_item_by_path(item_path: String, amount: int = 1) -> bool:
	validate_inventory()
	return count_item_by_path(item_path) >= amount

# --- Count total of a specific item ---
func count_item(item: InvItem) -> int:
	validate_inventory()
	var total := 0
	for slot in slots:
		if slot.item == item:
			total += slot.amount
	return total

# --- Count total by resource path ---
func count_item_by_path(item_path: String) -> int:
	validate_inventory()
	var total := 0
	for slot in slots:
		if slot.item and slot.item.resource_path == item_path:
			total += slot.amount
	return total
