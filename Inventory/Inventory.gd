extends Resource
class_name Inv

@export var slots: Array[InvSlot]
signal update

func insert(item: InvItem):
	var itemslots = slots.filter(func(slot): return slot.item == item)
	if !itemslots.is_empty():
		itemslots[0].amount += 1
	else:
		var emptyslots = slots.filter(func(slot): return slot.item == null)
		if !emptyslots.is_empty():
			emptyslots[0].item = item
			emptyslots[0].amount = 1
	update.emit()

func remove_item(item: InvItem, amount: int = 1) -> bool:
	for slot in slots:
		if slot.item == item:
			if slot.amount >= amount:
				slot.amount -= amount
				if slot.amount <= 0:
					slot.item = null
					slot.amount = 0
				update.emit()
				return true
			else:
				return false
	return false

func remove_item_by_path(item_path: String, amount: int = 1) -> bool:
	for slot in slots:
		if slot.item and slot.item.resource_path == item_path:
			if slot.amount >= amount:
				slot.amount -= amount
				if slot.amount <= 0:
					slot.item = null
					slot.amount = 0
				update.emit()
				return true
			else:
				return false
	return false
