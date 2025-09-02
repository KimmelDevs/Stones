class_name DateTime extends Resource

@export_range(0,59) var seconds: int = 0
@export_range(0,59) var minutes: int = 0
@export_range(0,59) var hours: int = 0
@export var days:int =0

var delta_time:float = 0
func increase_by_sec(delta_seconds: float) -> void:
	delta_time += delta_seconds
	
	# Only process whole seconds
	var delta_int_secs: int = int(delta_time)
	if delta_int_secs <= 0:
		return
	
	delta_time -= delta_int_secs
	
	# Add seconds
	seconds += delta_int_secs
	if seconds >= 60:
		minutes += seconds / 60
		seconds = seconds % 60
	
	if minutes >= 60:
		hours += minutes / 60
		minutes = minutes % 60
	
	if hours >= 24:
		days += hours / 24
		hours = hours % 24
	print( str(hours) + str(days)+ str(seconds) + str(minutes) )
