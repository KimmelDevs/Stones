extends Node

var is_dragging: bool = false
var dragged_icon: Sprite2D = null
var selected_slot_index: int = -1
var source_container: Object = null  # can be InventoryUI or HotbarUI

func _ready():
	dragged_icon = Sprite2D.new()
	dragged_icon.visible = false
	dragged_icon.z_index = 999
	get_tree().root.add_child(dragged_icon) # add to root so it works everywhere

func start_drag(container, slot_index, texture):
	is_dragging = true
	selected_slot_index = slot_index
	source_container = container
	dragged_icon.texture = texture
	dragged_icon.visible = true

func stop_drag():
	is_dragging = false
	selected_slot_index = -1
	source_container = null
	dragged_icon.visible = false

func update_drag_position():
	if is_dragging:
		# Offset so mouse feels like it grabs the item
		dragged_icon.global_position = get_viewport().get_mouse_position() + Vector2(8, 8)
