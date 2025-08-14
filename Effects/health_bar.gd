extends ProgressBar

var stats

func _ready():
	# Adjust this path depending on where your Stats node is
	stats = get_parent().get_node("Stats")  
	
	# Set initial bar size
	max_value = stats.max_health
	value = stats.health
	
	# Connect the health change signal
	stats.connect("health_changed", Callable(self, "_on_health_changed"))

func _on_health_changed(new_health: float) -> void:
	value = new_health
	visible = new_health < max_value  # Hide when full HP
