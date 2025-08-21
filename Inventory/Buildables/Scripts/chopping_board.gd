extends StaticBody2D

@export var board_inv: Inv = preload("res://Inventory/choppingboardinventory.tres")

signal board_updated
@onready var food_sprite: Sprite2D = $Sprite2D2

func _ready():
	add_to_group("chopping_board")
	_update_sprite()
	if board_inv:
		board_inv.update.connect(_on_board_inv_update)

func _on_board_inv_update():
	emit_signal("board_updated")
	print("Chopping board inventory updated")
	_update_sprite()

# Automatically update the sprite when inventory changes
func _update_sprite():
	# Clear sprite by default
	food_sprite.texture = null

	print("Checking slots...")
	for slot in board_inv.slots:
		if slot.item:
			print("Slot has:", slot.item.name, "Category:", slot.item.Category, "Food type:", slot.item.food_type)
		else:
			print("Slot is empty")

		if slot.item \
		and slot.item.Category == "Food" \
		and slot.item.food_type == "Corpse":
			food_sprite.texture = slot.item.texture
			print("✅ Corpse sprite set!")
			return  # only show the first corpse

# Optional: process corpses into meat
func chop():
	for slot in board_inv.slots:
		if slot.item \
		and slot.item.Category == "Food" \
		and slot.item.food_type == "Corpse":
			print("Chopping corpse:", slot.item.name)
			board_inv.remove_item(slot.item, 1)
			_update_sprite()   # refresh sprite after removal
			return
