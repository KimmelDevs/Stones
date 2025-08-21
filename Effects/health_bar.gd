extends ProgressBar

var stats

func _ready():
	# Get reference to Stats node
	stats = get_parent().get_node("Stats")
	
	# Initialize ProgressBar values
	max_value = stats.max_health
	value = stats.health
	
	# Hide bar if already full
	visible = stats.health < stats.max_health
	
	# Connect signal
	stats.connect("health_changed", Callable(self, "_on_health_changed"))

func _on_health_changed(new_health: float) -> void:
	value = new_health
	visible = new_health < stats.max_health
