class_name ItemRecipe
extends Resource

@export var recipe_name: String = ""
@export var recipe_final_item: RecipeMaterial = null   # single output with quantity
@export var recipe_materials: Array[RecipeMaterial] = []  # inputs with quantity
@export var category: String = ""
