extends StaticBody2D
class_name CraftingBench

# --- Exported Variables ---
@export var crafting_ui_scene: PackedScene  # Assign your Crafting_UI.tscn here

# --- Internal Variables ---
var crafting_ui_instance: Crafting_UI = null
var player_in_area: bool = false
var player_ref: CharacterBody2D = null
var is_interactable: bool = false

# --- Signal callbacks for the Area2D ---
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player_in_area = true
		player_ref = body
		print("Player can interact with crafting bench")
		
	if body is PlayerEntity:
		is_interactable = true
		# Notify UIManager that this bench is interactable
		UiManager.set_interactable_bench(self)

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		player_in_area = false
		is_interactable = false
		player_ref = null
		print("Player left crafting bench area")
		# Notify UIManager that no bench is interactable
		UiManager.clear_interactable_bench()
		
		# Hide the UI if it exists
		if crafting_ui_instance:
			crafting_ui_instance.visible = false

# --- Check for input every frame ---
func _process(delta: float) -> void:
	if is_interactable and Input.is_action_just_pressed("Pick"):  # Default "E"
		open_crafting_ui()

# --- Open / instantiate the Crafting UI ---
func open_crafting_ui() -> void:
	if crafting_ui_instance == null:
		crafting_ui_instance = crafting_ui_scene.instantiate() as Crafting_UI
		get_tree().current_scene.add_child(crafting_ui_instance)
	crafting_ui_instance.visible = true
