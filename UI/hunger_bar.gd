extends Control

@onready var meat_full = $MeatFull
@onready var meat_empty = $MeatEmpty
var stats = PlayerStats

# Internal storage
var _hunger := 4
var _max_hunger := 4
var ui_ready := false

func _ready() -> void:
	if not stats:
		push_error("No PlayerStats assigned to HungerBar!")
		return

	ui_ready = true

	# Set initial values
	_max_hunger = stats.max_hunger
	_hunger = stats.get_hunger()

	# Update UI sizes
	meat_empty.size.x = _max_hunger * 15
	meat_full.size.x = _hunger * 15

	# Listen for hunger changes
	stats.connect("hunger_changed", Callable(self, "_on_hunger_changed"))

func _on_hunger_changed(new_value: int) -> void:
	_hunger = clamp(new_value, 0, _max_hunger)
	if ui_ready:
		meat_full.size.x = _hunger * 15
