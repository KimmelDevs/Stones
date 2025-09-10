extends Control

@onready var hours: Label = $ClockBackground/ClockControl/Hours
@onready var minutes: Label = $ClockBackground/ClockControl/Minutes
@onready var day: Label = $DayControl/Day

func _ready() -> void:
	# Connect to the global TimeSystem's signal
	TimeSystems.updated.connect(_on_time_system_updated)

	# Optional: update immediately with current time
	_on_time_system_updated(TimeSystems.date_time)

func _on_time_system_updated(date_time: DateTime) -> void:
	day.text = str(date_time.days)
	minutes.text = str(date_time.minutes).pad_zeros(2)
	hours.text = str(date_time.hours).pad_zeros(2)
