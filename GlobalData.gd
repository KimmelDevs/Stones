extends Node

@export var all_items : Dictionary

func _ready() -> void:
	get_all_items()

func get_all_items():
	for file_name in DirAccess.get_files_at("res://Inventory/Items"):
		var path = "res://Inventory/Items/" + file_name
		var res = load(path)
	
		# ✅ Check if loaded resource is an InvItem
		if res is InvItem:
			var current_item: InvItem = res
			if current_item.Item_Recipe.is_empty():
				continue
			all_items[current_item.Item_Recipe] = current_item
