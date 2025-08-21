extends Control

@onready var player_inv: Inv = load("res://Inventory/playerinventory.tres")

# Items
@onready var stick: InvItem = load("res://Inventory/Items/Stick.tres")
@onready var grass: InvItem = load("res://Inventory/Items/Grass.tres")
@onready var rock: InvItem = load("res://Inventory/Items/Rock.tres")
@onready var Axe: InvItem = load("res://Inventory/Items/Axe.tres")

# UI References
@onready var label: Label = $Label      # Stick count
@onready var label2: Label = $Label2    # Rock count
@onready var label3: Label = $Label3    # Grass count
@onready var sprite: Sprite2D = $Material
@onready var sprite1: Sprite2D = $Material2
@onready var sprite2: Sprite2D = $Material3
@onready var button: Button = $Button
@onready var resultname: Label = $ResultName
@onready var Result: Sprite2D = $Result
@onready var hide_button: TextureButton = $HideButton   # Hide button as TextureButton

func _ready():
	# Safety checks
	if not player_inv:
		push_error("Player inventory not loaded!")
		return
	if not stick or not Axe or not rock or not grass:
		push_error("Item resources not loaded!")
		return

	# Connect inventory update to refresh UI
	update_material_counts()
	player_inv.update.connect(update_material_counts)

	# Set item textures
	if stick.texture:
		sprite.texture = stick.texture
	if rock.texture:
		sprite1.texture = rock.texture
	if grass.texture:
		sprite2.texture = grass.texture
	if Axe.texture:
		Result.texture = Axe.texture

	# Connect craft button
	button.pressed.connect(_on_craft_axe)

	# Connect hide button
	hide_button.pressed.connect(_on_hide_button_pressed)


# --- Update UI counts ---
func update_material_counts():
	var stick_count = player_inv.count_item(stick)
	var rock_count = player_inv.count_item(rock)
	var grass_count = player_inv.count_item(grass)

	label.text = "Sticks: %d/1" % stick_count
	label2.text = "Rocks: %d/2" % rock_count
	label3.text = "Grass: %d/1" % grass_count
	resultname.text = "Axe"


# --- Craft Axe ---
func _on_craft_axe():
	var has_rocks = player_inv.count_item(rock)
	var has_grass = player_inv.count_item(grass)
	var has_stick = player_inv.count_item(stick)

	if has_rocks >= 2 and has_grass >= 1 and has_stick >= 1:
		# Remove required materials
		player_inv.remove_item(rock, 2)
		player_inv.remove_item(grass, 1)
		player_inv.remove_item(stick, 1)

		# Add crafted item
		player_inv.insert(Axe)
		print("Crafted Axe!")

		# Refresh labels
		update_material_counts()
	else:
		push_warning("Not enough materials! Need: 2 Rocks, 1 Grass, 1 Stick")


# --- Hide materials when pressing the hide button ---
func _on_hide_button_pressed():
	# Hide all material icons, labels, and craft button
	sprite.hide()
	sprite1.hide()
	sprite2.hide()
	label.hide()
	label2.hide()
	label3.hide()
	button.hide()
	# Keep Axe icon and ResultName visible
	Result.show()
	resultname.show()
