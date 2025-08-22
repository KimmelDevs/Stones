extends StaticBody2D

@export var board_inv: Inv = preload("res://Inventory/choppingboardinventory.tres")

signal board_updated
@onready var food_sprite: Sprite2D = $Sprite2D2
var player_in_area: bool = false
var player_ref: CharacterBody2D = null
@onready var animplay: AnimationPlayer = $AnimationPlayer
func _ready():
	add_to_group("chopping_board")
	_update_sprite()
	if board_inv:
		board_inv.update.connect(_on_board_inv_update)

func _process(delta: float) -> void:
	if player_in_area and Input.is_action_just_pressed("Chop"):
		chop()

func _on_board_inv_update():
	emit_signal("board_updated")
	print("Chopping board inventory updated")
	_update_sprite()

func _update_sprite():
	food_sprite.texture = null
	print("Checking slots...")
	for slot in board_inv.slots:
		if slot.item:
			print("Slot has:", slot.item.name, "Category:", slot.item.Category, "Food type:", slot.item.food_type)
		else:
			print("Slot is empty")

		if slot.item and slot.item.Category == "Food" and slot.item.food_type == "Corpse":
			food_sprite.texture = slot.item.texture
			print("✅ Corpse sprite set!")
			return
func chop():
	for slot in board_inv.slots:
		if slot.item and slot.item.name == "Pig Corpse":
			print("Chopping PigCorpse:", slot.item.name)
			animplay.play("Chopping")
			await get_tree().create_timer(2.5).timeout  
			animplay.stop()  
			# Remove 1 PigCorpse from inventory
			board_inv.remove_item(slot.item, 1)
			_update_sprite()
			
			# Spawn the drops
			var head_scene = preload("res://Inventory/scenes/pig_head.tscn")
			var wings_scene = preload("res://Inventory/scenes/pork.tscn")
			var foot_scene = preload("res://Inventory/scenes/pig_foot.tscn")
			var foot_instance = foot_scene.instantiate()
			var head_instance = head_scene.instantiate()
			var wings_instance = wings_scene.instantiate()
			
			# Set their positions at the chopping board
			head_instance.global_position = global_position
			wings_instance.global_position = global_position
			foot_instance.global_position = global_position
			# Add them to the scene tree
			get_tree().current_scene.add_child(head_instance)
			get_tree().current_scene.add_child(wings_instance)
			get_tree().current_scene.add_child(foot_instance)
			return  # only chop 1 item at a time
		elif slot.item and slot.item.name == "Pig Head":
			print("Chopping PigCorpse:", slot.item.name)
			animplay.play("Chopping")
			await get_tree().create_timer(2.5).timeout  
			animplay.stop() 
			# Remove 1 PigCorpse from inventory
			board_inv.remove_item(slot.item, 1)
			_update_sprite()
			
			# Spawn the drops
			var head_scene = preload("res://Inventory/scenes/pig_bits.tscn")
			
			var head_instance = head_scene.instantiate()
			
			# Set their positions at the chopping board
			head_instance.global_position = global_position
			# Add them to the scene tree
			get_tree().current_scene.add_child(head_instance)
			return  # only chop 1 item at a time

	for slot in board_inv.slots:
		if slot.item:
			# Print the path for debugging
			print("Slot item resource path:", slot.item.resource_path)
			
			# Check if it matches the PigCorpse
			if slot.item.resource_path.ends_with("PigCorpse.tres"):
				print("Chopping PigCorpse:", slot.item.name)
				
				# Remove 1 PigCorpse from inventory
				board_inv.remove_item(slot.item, 1)
				_update_sprite()
				
				# Spawn the drops
				var head_scene = preload("res://Enemies/EnemyDrops/bat_head.tscn")
				var wings_scene = preload("res://Enemies/EnemyDrops/bat_wings.tscn")
				
				var head_instance = head_scene.instantiate()
				var wings_instance = wings_scene.instantiate()
				
				# Set their positions at the chopping board
				head_instance.global_position = global_position
				wings_instance.global_position = global_position
				
				# Add them to the scene tree
				get_tree().current_scene.add_child(head_instance)
				get_tree().current_scene.add_child(wings_instance)
				
				print("Spawned bat_head and bat_wings!")
				return  # only chop 1 item at a time



func _on_interactable_area_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player_in_area = true
		player_ref = body
		print("Player in chopping board area")

func _on_interactable_area_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		player_in_area = false
		player_ref = null
		print("Player left chopping board area")
