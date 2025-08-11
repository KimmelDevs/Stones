extends Node2D

@export var speed: float = 60.0

var target: Node2D = null
var chasing := false
var attacking := false

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Node2D = $Sprite2D  # Replace with your sprite node name
@onready var detector_area: Area2D = $Detector
@onready var chase_area: Area2D = $Chase_Area

func _ready() -> void:
	chase_area.connect("body_entered", Callable(self, "_on_chase_area_body_entered"))
	chase_area.connect("body_exited", Callable(self, "_on_chase_area_body_exited"))
	detector_area.connect("body_entered", Callable(self, "_on_detector_body_entered"))
	detector_area.connect("body_exited", Callable(self, "_on_detector_body_exited"))

func _process(delta: float) -> void:
	if chasing and target:
		if not attacking:
			anim_player.play("Walk")
			var direction = (target.global_position - global_position).normalized()
			global_position += direction * speed * delta
			
			if direction.x < 0:
				sprite.scale.x = -1
				_flip_areas(true)
			elif direction.x > 0:
				sprite.scale.x = 1
				_flip_areas(false)
		else:
			anim_player.stop()
			# TODO: Add attack logic here
	else:
		anim_player.stop()

func _flip_areas(flip: bool) -> void:
	detector_area.scale.x = -1 if flip else 1
	chase_area.scale.x = -1 if flip else 1

func _on_chase_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		target = body
		chasing = true
		print("Player entered chase area: start chasing")

func _on_chase_area_body_exited(body: Node2D) -> void:
	if body == target:
		chasing = false
		attacking = false
		target = null
		print("Player left chase area: stop chasing")

func _on_detector_body_entered(body: Node2D) -> void:
	if body == target:
		attacking = true
		print("Player entered attack range: attack!")

func _on_detector_body_exited(body: Node2D) -> void:
	if body == target:
		attacking = false
		print("Player left attack range: stop attacking")
