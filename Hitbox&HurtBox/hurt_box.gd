extends Area2D

@export var show_effect: bool = true
@onready var timer: Timer = $Timer

const HitEffect = preload("res://Effects/Deaths/Scenes/hit_effect.tscn")

var invincible: bool = false:
	set(value):
		invincible = value
		if invincible:
			emit_signal("invisibility_started")
		else:
			emit_signal("invincibility_ended")

signal invisibility_started
signal invincibility_ended

func create_hit_effect():
	var effect = HitEffect.instantiate()
	var main = get_tree().current_scene
	main.add_child(effect)
	effect.global_position = global_position - Vector2(0, 8)

func start_invisibility(duration: float):
	self.invincible = true
	timer.start(duration)

func _on_timer_timeout() -> void:
	self.invincible = false  # Ends invisibility, triggers signal

func _on_invisibility_started() -> void:
	set_deferred("monitoring", false)  # disable hurtbox

func _on_invincibility_ended() -> void:
	set_deferred("monitoring", true)   # enable hurtbox
