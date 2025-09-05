extends Node

var is_dragging: bool = false
var dragged_icon: Sprite2D = null
var selected_slot_index: int = -1
var source_container: Object = null  # can be InventoryUI or HotbarUI

func _ready():
	dragged_icon = Sprite2D.new()
	dragged_icon.visible = false
	dragged_icon.z_index = 9999  # Much higher z_index to ensure it's on top
	dragged_icon.modulate.a = 0.7  # Make it 70% opaque (30% transparent)
	
	# Try to find the UI CanvasLayer first, fallback to root
	var canvas_layer = find_canvas_layer()
	if canvas_layer:
		canvas_layer.add_child.call_deferred(dragged_icon)
	else:
		get_tree().root.add_child.call_deferred(dragged_icon)

# Helper function to find the UI CanvasLayer
func find_canvas_layer() -> CanvasLayer:
	# Since World is the main scene, just look for CanvasLayer in the root
	for child in get_tree().root.get_children():
		if child is CanvasLayer:
			return child
	return null

func _process(_delta):
	update_drag_position()

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
		# Put the icon exactly at the mouse position
		dragged_icon.global_position = get_viewport().get_mouse_position()
