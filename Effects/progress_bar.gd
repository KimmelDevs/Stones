extends ProgressBar


var stats = PlayerStats

func _ready() -> void:
	if not stats:
		push_error("No PlayerStats assigned to EnergyBar!")
		return

	# Set initial max and value
	max_value = stats.max_energy
	value = stats.get_energy()

	# Listen for energy changes
	stats.connect("energy_changed", Callable(self, "_on_energy_changed"))

func _on_energy_changed(new_value: int) -> void:
	value = new_value
