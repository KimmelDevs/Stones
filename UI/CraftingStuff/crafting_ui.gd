class_name Crafting_UI
extends PanelContainer

# --- Scene References ---
@onready var tree: Tree = %Tree
@onready var grid_container: GridContainer = %GridContainer
@onready var title_label: Label = %TitleLabel
@onready var item_texture: TextureRect = %ItemTexture
@onready var button: Button = %Button

# Slot scene for required materials
const RESOURCE_NEED = preload("res://UI/CraftingStuff/ResourceNeed.tscn")

# --- Data ---
@export var recipe_array: Array[ItemRecipe] = []
@export var player_inventory : Inv = null

# Category buttons
@onready var stations: TextureButton = $MarginContainer/HBoxContainer/Icons/Stations
@onready var armors: TextureButton = $MarginContainer/HBoxContainer/Icons/Armors
@onready var tools: TextureButton = $MarginContainer/HBoxContainer/Icons/Tools
@onready var consumables: TextureButton = $MarginContainer/HBoxContainer/Icons/Consumables
@onready var materials: TextureButton = $MarginContainer/HBoxContainer/Icons/Materials

# Current category filter
var selected_category: String = ""

# --- Setup ---
func _ready() -> void:
	# Connect button signals
	stations.pressed.connect(_on_stations_pressed)
	armors.pressed.connect(_on_armors_pressed)
	tools.pressed.connect(_on_tools_pressed)
	consumables.pressed.connect(_on_consumables_pressed)
	materials.pressed.connect(_on_materials_pressed)

	# Default category
	reset_category_buttons()
	stations.modulate = Color(1,1,1,1)
	selected_category = "Stations"

	build_recipe_tree()
	visible = false  # Hidden by default

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
			new_recipe_slot.set_icon(0, recipe.recipe_final_item.item.texture)
			new_recipe_slot.set_text(0, recipe.recipe_final_item.item.name)

			if first_item == null:
				first_item = new_recipe_slot

	# Auto-select first recipe
	if first_item != null:
		tree.set_selected(first_item, 0)
		_on_tree_cell_selected()

func _on_tree_cell_selected() -> void:
	var cell_recipe_name: String = tree.get_selected().get_text(0)
	for recipe in recipe_array:
		if recipe.recipe_final_item.item.name == cell_recipe_name:
			build_recipe_material_window(recipe)
			return

# --- Build Materials Window ---
func build_recipe_material_window(selected_recipe : ItemRecipe) -> void:
	clean_material_window()

	# --- Final Item ---
	var final_item = selected_recipe.recipe_final_item
	title_label.text = "%s x%d" % [final_item.item.name, final_item.quantity]
	item_texture.texture = final_item.item.texture

	# --- Required Materials ---
	for recipe_mat in selected_recipe.recipe_materials:
		var new_material = RESOURCE_NEED.instantiate()
		grid_container.add_child(new_material)
		new_material.display_recipe_material(recipe_mat, player_inventory)

func clean_material_window() -> void:
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
		btn.modulate = Color(0.5, 0.5, 0.5, 1.0)

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
