extends Panel
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var center_container: CenterContainer = $CenterContainer
@onready var item_display: Sprite2D = $CenterContainer/Panel/ItemDisplay
@onready var quantity_label: Label = $CenterContainer/Panel/Label
@onready var name_label: Label = $CenterContainer/Panel/NameLabel
@onready var catergory_label: Label = $CenterContainer/Panel/CatergoryLabel

func display_recipe_material(recipe_mat: RecipeMaterial, player_inventory: Inv):
	if recipe_mat and recipe_mat.item:
		var inv_item: InvItem = recipe_mat.item
		item_display.texture = inv_item.texture
		name_label.text = inv_item.name

		var player_has := 0
		if player_inventory:
			player_has = player_inventory.count_item(inv_item)

		quantity_label.text = "%d / %d" % [player_has, recipe_mat.quantity]

		if player_has < recipe_mat.quantity:
			quantity_label.add_theme_color_override("font_color", Color(1, 0, 0)) # red
		else:
			quantity_label.add_theme_color_override("font_color", Color(0, 1, 0)) # green
	else:
		item_display.texture = null
		name_label.text = "?"
		quantity_label.text = "0 / ?"
