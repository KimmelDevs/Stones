extends Panel

signal slot_clicked(slot_index)

@onready var item_visual: Sprite2D = $CenterContainer/Panel/ItemDisplay
@onready var item_count: Label = $CenterContainer/Panel/Label
@onready var name_label: Label = $CenterContainer/Panel/NameLabel
@onready var category_label: Label = $CenterContainer/Panel/CatergoryLabel

var slot_index: int  # set by InventoryUI so it knows which inventory slot this represents

func _ready():
	# Connect mouse hover signals
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))
	
	# Hide labels by default
	name_label.visible = false
	category_label.visible = false

func update(slot: InvSlot):
	if !slot.item:
		item_visual.visible = false
		item_count.visible = false
		name_label.text = ""
		category_label.text = ""
	else:
		item_visual.visible = true
		item_visual.texture = slot.item.texture
		name_label.text = slot.item.name 
		category_label.text = slot.item.Category

		# Set category color
		match slot.item.Category:
			"Food":
				category_label.modulate = Color.BLUE
			"Material":
				category_label.modulate = Color.GREEN
			"Tool":
				category_label.modulate = Color.RED
			_:
				category_label.modulate = Color.BURLYWOOD  # default color if unknown

		# Show item count if more than 1
		if slot.amount > 1:
			item_count.visible = true
			item_count.text = str(slot.amount)
		else:
			item_count.visible = false

func _on_mouse_entered():
	if name_label.text != "":
		name_label.visible = true
		category_label.visible = true  # now category acts like name

func _on_mouse_exited():
	name_label.visible = false
	category_label.visible = false

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("slot_clicked", slot_index)
