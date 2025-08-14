extends Panel

@onready var item_visual: Sprite2D = $CenterContainer/Panel/ItemDisplay
@onready var item_count: Label = $CenterContainer/Panel/Label
@onready var name_label: Label = $CenterContainer/Panel/NameLabel

func _ready():
	# Connect hover signals
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))

	# Hide name label by default
	name_label.visible = false

func update(slot: InvSlot):
	if !slot.item:
		item_visual.visible = false
		item_count.visible = false
		name_label.text = ""
	else:
		item_visual.visible = true
		item_visual.texture = slot.item.texture
		name_label.text = slot.item.name  # ✅ Display name
		if slot.amount > 1:
			item_count.visible = true
			item_count.text = str(slot.amount)
		else:
			item_count.visible = false

# Show name on hover
func _on_mouse_entered():
	if name_label.text != "":
		name_label.visible = true

# Hide name when not hovering
func _on_mouse_exited():
	name_label.visible = false
