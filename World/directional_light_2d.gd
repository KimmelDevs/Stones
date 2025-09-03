extends DirectionalLight2D

@export var day_color: Color 
@export var night_color: Color 
@export var day_start: DateTime
@export var night_start: DateTime

enum DayState { Day, Night }
var current_state: DayState = DayState.Day

func _on_time_system_updated(date_time: DateTime) -> void:
	# Convert current time to minutes since midnight
	var current_minutes = date_time.hours * 60 + date_time.minutes
	var day_minutes = day_start.hours * 60 + day_start.minutes
	var night_minutes = night_start.hours * 60 + night_start.minutes

	# Determine state
	if current_minutes >= day_minutes and current_minutes < night_minutes:
		_set_state(DayState.Day)
	else:
		_set_state(DayState.Night)


func _set_state(state: DayState) -> void:
	if state == current_state:
		return  # no change

	current_state = state
	match state:
		DayState.Day:
			color = day_color
		DayState.Night:
			color = night_color
