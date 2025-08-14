extends StaticBody2D

func _ready():
	fallfromtree()

func fallfromtree():
	$AnimationPlayer.play("falling_from_tree")
	await get_tree().create_timer(1.5).timeout
	$AnimationPlayer.play("Fade")
	
	# Wait until the fade animation finishes
	await $AnimationPlayer.animation_finished
	queue_free()
	print("+1 apple")
