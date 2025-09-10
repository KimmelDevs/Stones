extends Area2D

@export_file("tscn") var target_scene: String   # Choose the scene in Inspector

func _on_body_entered(body: Node) -> void:
	if body.has_method("player"):  # safer than checking body.name
		print("Hello")
		SceneManager.change_scene(target_scene)
