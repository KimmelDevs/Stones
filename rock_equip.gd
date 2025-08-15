extends Node2D

@export var rock_projectile_scene: PackedScene = preload("res://Equipments/Weapons/rock_projectile.tscn")
@export var inventory: Inv
@export var rock_item_path: String = "res://Inventory/Items/Rock.tres"

var player: Node = null

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			throw_rock()

func throw_rock():
	# Make sure we have at least 1 rock
	if inventory and inventory.remove_item_by_path(rock_item_path, 1):
		var rock = rock_projectile_scene.instantiate()
		rock.global_position = player.global_position if player else global_position
		rock.start_throw(get_global_mouse_position()) # pass the target
		get_tree().current_scene.add_child(rock)
	else:
		print("No more rocks in inventory!")
