extends ProgressBar

var stats = PlayerStats

func _ready() -> void:
	if not stats:
		push_error("No PlayerStats assigned to HungerBar!")
		return

	# Set initial max and value
	max_value = stats.max_hunger
	value = stats.get_hunger()

	# Listen for hunger changes
	stats.connect("hunger_changed", Callable(self, "_on_hunger_changed"))

func _on_hunger_changed(new_value: int) -> void:
	value = new_value
