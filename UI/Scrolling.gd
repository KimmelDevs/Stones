extends CharacterBody2D

var scroll_speed := 20

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			$"../Panel/Crafting".position.y += scroll_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			$"../Panel/Crafting".position.y -= scroll_speed
