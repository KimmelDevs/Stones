class_name Crafting_UI
extends PanelContainer
@onready var tree: Tree = %Tree
@onready var grid_container: GridContainer = %GridContainer
@onready var title_label: Label = %TitleLabel
@onready var item_texture: TextureRect = %ItemTexture
@export var inventory_slot: PackedScene = null
@export var recipe_array: Array[ItemRecipe] = []

var Recipe_material_dictionary :Dictionary ={}

func _ready() -> void:
	build_recipe_tree()

func build_recipe_tree() -> void:
	tree.hide_root = true
	var tree_root : TreeItem = tree.create_item()
	
	for recipe in recipe_array:
		var new_recipe_slot : TreeItem = tree.create_item(tree_root)
		new_recipe_slot.set_icon(0,recipe.recipe_final_item.texture)
		new_recipe_slot.set_text(0,recipe.recipe_final_item.name)
		
func _on_tree_cell_selected() -> void:
	var cell_recipe_name: String = tree.get_selected().get_text(0)
	print(cell_recipe_name)
	
	for recipe in recipe_array:
		if recipe.recipe_final_item.name == cell_recipe_name:
			
			build_recipe_material_window(recipe)
			return
			
func build_recipe_material_window(selected_recipe : ItemRecipe) ->void:
	clean_material_window()
	title_label.text = selected_recipe.recipe_final_item.name
	item_texture.texture= selected_recipe.recipe_final_item.texture
	
	for Recipe_material in selected_recipe.recipe_material_array:
		if Recipe_material_dictionary.has(Recipe_material):
			Recipe_material_dictionary[Recipe_material] += 1
		else:
			Recipe_material_dictionary[Recipe_material] =1
	print(Recipe_material_dictionary)
	for material in Recipe_material_dictionary.keys():
		var new_material = inventory_slot.instantiate() as InventorySlot
		grid_container.add_child(new_material)
	
	# Create a temporary InvSlot
		var temp_slot = InvSlot.new()
		temp_slot.item = material  # This must be the Item object, not a string
		temp_slot.amount = Recipe_material_dictionary[material]
	
		new_material.update(temp_slot)
		


func clean_material_window() -> void:
	Recipe_material_dictionary.clear()
	
	for child in grid_container.get_children():
		child.queue_free()
