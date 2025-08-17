extends Control

@onready var player_inv: Inv = load("res://Inventory/playerinventory.tres")
@onready var stick: InvItem = load("res://Inventory/Items/Stick.tres")
@onready var long_stick: InvItem = load("res://Inventory/Items/LongStick.tres")
@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Material
@onready var button: Button = $Button
@onready var resultname: Label = $ResultName
@onready var Result: Sprite2D = $Result
func _ready():
	# Safety checks
	if not player_inv:
		push_error("Player inventory not loaded!")
		return
	if not stick or not long_stick:
		push_error("Item resources not loaded!")
		return

	# Update label at startup
	update_stick_count()
	player_inv.update.connect(update_stick_count)

	# Set Sprite2D texture to the Stick texture
	if stick.texture:
		sprite.texture = stick.texture
	if long_stick.texture:
		Result.texture = long_stick.texture
	# Connect button click
	button.pressed.connect(_on_craft_long_stick)

func update_stick_count():
	var count = player_inv.count_item(stick)
	label.text = "Sticks: %d" % count
	resultname.text = "LongStick"

# --- Craft LongStick ---
func _on_craft_long_stick():
	if player_inv.count_item(stick) >= 2:
		# Remove 2 sticks
		player_inv.remove_item(stick, 2)
		# Add 1 LongStick
		player_inv.insert(long_stick)
		# Update Sprite2D to LongStick texture
		if long_stick.texture:
			sprite.texture = long_stick.texture
	else:
		push_warning("Not enough sticks to craft LongStick!")
