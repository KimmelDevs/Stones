extends Node

@export var max_health: int = 1
var health: int:
	set(value):
		health = value
		if health <= 0:
			emit_signal("no_health")
	get:
		return health

signal no_health

func _ready():
	health = max_health
