extends Panel

@onready var item_visual: Sprite2D = $CenterContainer/Panel/ItemDisplay
@onready var item_count: Label = $CenterContainer/Panel/Label

func update(slot: InvSlot):
	if !slot.item:
		item_visual.visible = false
		item_count.visible = false
	else:
		item_visual.visible = true
		item_visual.texture = slot.item.texture
		if slot.amount >1:
			item_count.visible = true
			item_count.text = str(slot.amount)
