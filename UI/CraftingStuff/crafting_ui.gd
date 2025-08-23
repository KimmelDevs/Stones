class_name Crafting_UI
extends PanelContainer

@onready var tree: Tree = %Tree
@onready var grid_container: GridContainer = %GridContainer
@onready var title_label: Label = %TitleLabel
@onready var item_texture: TextureRect = %ItemTexture
@export var inventory_slot: PackedScene = null
@export var recipe_array: Array[ItemRecipe] = []
var player_inventory : Inv = null
var Recipe_material_dictionary : Dictionary = {}

# Category buttons
@onready var stations: TextureButton = $MarginContainer/HBoxContainer/Icons/Stations
@onready var armors: TextureButton = $MarginContainer/HBoxContainer/Icons/Armors
@onready var tools: TextureButton = $MarginContainer/HBoxContainer/Icons/Tools
@onready var consumables: TextureButton = $MarginContainer/HBoxContainer/Icons/Consumables
@onready var materials: TextureButton = $MarginContainer/HBoxContainer/Icons/Materials

# Current category filter
var selected_category: String = ""

func _ready() -> void:
	# Connect button signals
	stations.pressed.connect(_on_stations_pressed)
	armors.pressed.connect(_on_armors_pressed)
	tools.pressed.connect(_on_tools_pressed)
	consumables.pressed.connect(_on_consumables_pressed)
	materials.pressed.connect(_on_materials_pressed)

	# Default category = Stations
	reset_category_buttons()
	stations.modulate = Color(1,1,1,1)
	selected_category = "Stations"

	build_recipe_tree()
	visible = false  # Hide by default

func set_player_inventory(new_inventory : Inv):
	player_inventory = new_inventory

# --- Recipe Tree ---
func build_recipe_tree() -> void:
	tree.clear()
	tree.hide_root = true
	var tree_root : TreeItem = tree.create_item()

	var first_item: TreeItem = null
	
	for recipe in recipe_array:
		# Filter by category
		if selected_category == "" or recipe.category == selected_category:
			var new_recipe_slot : TreeItem = tree.create_item(tree_root)
			new_recipe_slot.set_icon(0, recipe.recipe_final_item.texture)
			new_recipe_slot.set_text(0, recipe.recipe_final_item.name)

			# Save first recipe for default selection
			if first_item == null:
				first_item = new_recipe_slot

	# Auto-select the first recipe if available
	if first_item != null:
		tree.set_selected(first_item, 0)
		_on_tree_cell_selected()  # Trigger material window build

func _on_tree_cell_selected() -> void:
	var cell_recipe_name: String = tree.get_selected().get_text(0)
	print(cell_recipe_name)
	
	for recipe in recipe_array:
		if recipe.recipe_final_item.name == cell_recipe_name:
			build_recipe_material_window(recipe)
			return

# --- Recipe Materials Window ---
func build_recipe_material_window(selected_recipe : ItemRecipe) -> void:
	clean_material_window()
	title_label.text = selected_recipe.recipe_final_item.name
	item_texture.texture = selected_recipe.recipe_final_item.texture
	
	for Recipe_material in selected_recipe.recipe_material_array:
		if Recipe_material_dictionary.has(Recipe_material):
			Recipe_material_dictionary[Recipe_material] += 1
		else:
			Recipe_material_dictionary[Recipe_material] = 1
	print(Recipe_material_dictionary)
	
	for material in Recipe_material_dictionary.keys():
		var new_material = inventory_slot.instantiate() as InventorySlot
		grid_container.add_child(new_material)
		
		# Temporary InvSlot
		var temp_slot = InvSlot.new()
		temp_slot.item = material
		temp_slot.amount = Recipe_material_dictionary[material]
		
		new_material.update(temp_slot)

func clean_material_window() -> void:
	Recipe_material_dictionary.clear()
	for child in grid_container.get_children():
		child.queue_free()

# --- UI Toggle ---
func _process(delta: float) -> void:
	if UiManager.is_interactable() and Input.is_action_just_pressed("Pick"):
		visible = not visible
	elif not UiManager.is_interactable():
		visible = false

# --- Category Buttons ---
func reset_category_buttons() -> void:
	var all_buttons = [stations, armors, tools, consumables, materials]
	for btn in all_buttons:
		btn.modulate = Color(0.5, 0.5, 0.5, 1.0) # darken

func _on_stations_pressed() -> void:
	reset_category_buttons()
	stations.modulate = Color(1,1,1,1)
	selected_category = "Stations"
	build_recipe_tree()

func _on_armors_pressed() -> void:
	reset_category_buttons()
	armors.modulate = Color(1,1,1,1)
	selected_category = "Armors"
	build_recipe_tree()

func _on_tools_pressed() -> void:
	reset_category_buttons()
	tools.modulate = Color(1,1,1,1)
	selected_category = "Tool"
	build_recipe_tree()

func _on_consumables_pressed() -> void:
	reset_category_buttons()
	consumables.modulate = Color(1,1,1,1)
	selected_category = "Consumables"
	build_recipe_tree()

func _on_materials_pressed() -> void:
	reset_category_buttons()
	materials.modulate = Color(1,1,1,1)
	selected_category = "Materials"
	build_recipe_tree()
