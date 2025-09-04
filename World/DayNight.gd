extends CanvasModulate

@export var gradient: GradientTexture1D
var time_of_day: float = 0.0  # Normalized value (0–1 ping-pong across 24 hours)

func _on_time_system_updated(date_time: DateTime) -> void:
	var total_minutes_in_day = 24 * 60
	var current_minutes = date_time.hours * 60 + date_time.minutes
	
	# Normalize to [0, 2) instead of [0, 1)
	var cycle = float(current_minutes) / total_minutes_in_day * 2.0
	
	# Ping-pong the cycle (goes 0→1→0)
	if cycle > 1.0:
		time_of_day = 2.0 - cycle
	else:
		time_of_day = cycle

	# Sample gradient with ping-pong time
	self.color = gradient.gradient.sample(time_of_day)
