extends Node2D

@export var speed: float = 500.0
@export var lifetime: float = 4.0
@export var inventory: Inv
@export var rock_item_path: String = "res://Inventory/Items/Rock.tres"

var player: Node = null
var velocity: Vector2 = Vector2.ZERO
var thrown: bool = false

func _process(delta):
	if not thrown and player:
		global_position = player.global_position

func _input(event):
	if event is InputEventMouseButton:
		# Throw on left click
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not thrown:
			if inventory.remove_item(rock_item_path, 1):
				var target = get_global_mouse_position()
				velocity = (target - global_position).normalized() * speed
				thrown = true
				# Start lifetime countdown after throw
				await get_tree().create_timer(lifetime).timeout
				queue_free()
			else:
				print("No more rocks in inventory!")

func _physics_process(delta):
	if thrown:
		position += velocity * delta

func _on_body_entered(body):
	if thrown:
		print("Hit:", body.name)
		queue_free()
