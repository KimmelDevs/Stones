extends Control

@onready var heartuifull = $HeartUIFull
@onready var heartempty = $HeartsEmpty

# Internal storage
var _hearts := 4
var _max_hearts := 4
var ui_ready := false  # Track if _ready() finished

var hearts: int:
	set(value):
		_hearts = clamp(value, 0, _max_hearts)
		if ui_ready:
			heartuifull.size.x = _hearts * 15

var max_hearts: int:
	set(value):
		_max_hearts = max(value, 1)
		hearts = _hearts  # re-clamp
		if ui_ready:
			heartempty.size.x = _max_hearts * 15

func _ready():
	ui_ready = true
	max_hearts = PlayerStats.max_health
	hearts = PlayerStats.health
	PlayerStats.health_changed.connect(set_hearts)

func set_hearts(value: int) -> void:
	hearts = value  # Will trigger setter
