extends Node2D

@export var speed: float = 60.0
@export var attack_damage: int = 200

var target: Node2D = null
var chasing := false
var attacking := false
var can_attack := true  # Prevents overlapping attacks

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Node2D = $Sprite2D  # Replace with your sprite node name
@onready var detector_area: Area2D = $Detector
@onready var chase_area: Area2D = $Chase_Area

func _ready() -> void:
	chase_area.connect("body_entered", Callable(self, "_on_chase_area_body_entered"))
	chase_area.connect("body_exited", Callable(self, "_on_chase_area_body_exited"))
	detector_area.connect("body_entered", Callable(self, "_on_detector_body_entered"))
	detector_area.connect("body_exited", Callable(self, "_on_detector_body_exited"))
	anim_player.connect("animation_finished", Callable(self, "_on_animation_finished"))

func _process(delta: float) -> void:
	if chasing and target and not attacking:
		anim_player.play("Walk")
		var direction = (target.global_position - global_position).normalized()
		global_position += direction * speed * delta

		# Flip enemy based on player position
		if direction.x < 0:
			sprite.scale.x = -1
			_flip_areas(true)
		elif direction.x > 0:
			sprite.scale.x = 1
			_flip_areas(false)
	elif not attacking:
		anim_player.stop()

func _flip_areas(flip: bool) -> void:
	detector_area.scale.x = -1 if flip else 1
	chase_area.scale.x = -1 if flip else 1

# --- CHASE AREA ---
func _on_chase_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		target = body
		chasing = true
		print("Player entered chase area: start chasing")

func _on_chase_area_body_exited(body: Node2D) -> void:
	if body == target and not attacking:  # Don't stop chasing mid-attack
		chasing = false
		target = null
		print("Player left chase area: stop chasing")

# --- DETECTOR AREA ---
func _on_detector_body_entered(body: Node2D) -> void:
	if body == target and can_attack:
		attacking = true
		chasing = false  # Stop moving toward player during attack
		can_attack = false  

		# Flip toward player before attacking
		if target.global_position.x < global_position.x:
			sprite.scale.x = -1
			_flip_areas(true)
		else:
			sprite.scale.x = 1
			_flip_areas(false)

		anim_player.play("attack")
		print("Player entered attack range: attacking!")

func _on_detector_body_exited(body: Node2D) -> void:
	# Don't reset attacking here — let the attack finish
	if body == target:
		print("Player left attack range, but attack will finish.")

# --- ANIMATION FINISH ---
func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack":
		if target and "take_damage" in target:
			target.take_damage(attack_damage)
			print("Hit player for", attack_damage, "damage!")

		attacking = false
		can_attack = true
