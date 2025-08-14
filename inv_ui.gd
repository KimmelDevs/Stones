extends Control

@onready var inv = preload("res://Inventory/playerinventory.tres")
@onready var slots: Array = $NinePatchRect/GridContainer.get_children()

var is_open = false
var start_index = 6

var selected_slot_index: int = -1
var is_dragging: bool = false
@onready var dragged_icon: Sprite2D = Sprite2D.new()

func _ready():
	close()
	update_slots()
	inv.update.connect(update_slots)

	# Connect slot click signals and set their index
	for i in range(slots.size()):
		slots[i].slot_index = i + start_index
		slots[i].connect("slot_clicked", Callable(self, "_on_slot_clicked"))

	# Setup dragged icon
	dragged_icon.visible = false
	dragged_icon.z_index = 999
	add_child(dragged_icon)

func update_slots():
	for i in range(min(inv.slots.size() - start_index, slots.size())):
		slots[i].slot_index = i + start_index
		slots[i].update(inv.slots[i + start_index])

func _process(delta):
	if is_dragging:
		dragged_icon.global_position = get_global_mouse_position()

	if Input.is_action_just_pressed("Inventory"):
		if is_open:
			close()
		else:
			open()

func _on_slot_clicked(slot_index: int):
	if !is_dragging:
		# Pick up the item if it exists
		if inv.slots[slot_index].item:
			selected_slot_index = slot_index
			is_dragging = true
			dragged_icon.texture = inv.slots[slot_index].item.texture
			dragged_icon.visible = true
	else:
		# Place / swap
		var temp = inv.slots[selected_slot_index]
		inv.slots[selected_slot_index] = inv.slots[slot_index]
		inv.slots[slot_index] = temp

		# End dragging
		selected_slot_index = -1
		is_dragging = false
		dragged_icon.visible = false
		update_slots()
func _unhandled_input(event):
	# Cancel drag if left click outside slots
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_dragging:
			var hovered_slot = false
			var mouse_pos = get_global_mouse_position()
			for slot in slots:
				if slot.get_global_rect().has_point(mouse_pos):
					hovered_slot = true
					break
			if !hovered_slot:
				is_dragging = false
				selected_slot_index = -1
				dragged_icon.visible = false


func open():
	visible = true
	is_open = true

func close():
	visible = false
	is_open = false
