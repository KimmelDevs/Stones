extends Node

# --- Health ---
@export var max_health: float = 1
var health: float

# --- Health Regen ---
@export var health_regen_enabled: bool = false
@export var health_regen_delay: float = 15.0  # Seconds without damage before regen starts
@export var health_regen_interval: float = 2.0  # How often to heal
@export var health_regen_amount: float = 1.0   # How much to heal per tick
var time_since_damage: float = 0.0
var health_regen_timer: float = 0.0

# --- Energy ---
@export var max_energy: int = 10
@export var energy_regen_interval: float = 2.0
var energy: int
var energy_regen_timer: float = 0.0

# --- Signals ---
signal no_health
signal health_changed(value)
signal energy_changed(value)

func _ready():
	health = max_health
	energy = max_energy

	# If this is the global PlayerStats singleton, always enable regen
	# Otherwise (for enemies), disable unless manually turned on
	if self == PlayerStats:
		health_regen_enabled = true

func _process(delta: float) -> void:
	# Increment timers
	time_since_damage += delta
	energy_regen_timer += delta

	# --- Health Regen ---
	if health_regen_enabled and health < max_health:
		if time_since_damage >= health_regen_delay:
			health_regen_timer += delta
			if health_regen_timer >= health_regen_interval:
				health_regen_timer = 0.0
				set_health(health + health_regen_amount)

	# --- Energy Regen ---
	if energy_regen_timer >= energy_regen_interval:
		energy_regen_timer = 0.0
		add_energy(1)

# --- Health Functions ---
func set_health(value: float) -> void:
	var old_health = health
	health = clamp(value, 0, max_health)
	emit_signal("health_changed", health)

	# Reset regen if damage occurred
	if health < old_health:
		time_since_damage = 0.0
		health_regen_timer = 0.0

	if health <= 0:
		emit_signal("no_health")

func get_health() -> float:
	return health

func damage(amount: float) -> void:
	set_health(health - amount)

# --- Energy Functions ---
func set_energy(value: int) -> void:
	energy = clamp(value, 0, max_energy)
	emit_signal("energy_changed", energy)

func add_energy(amount: int) -> void:
	set_energy(energy + amount)

func consume_energy(amount: int) -> bool:
	if energy >= amount:
		set_energy(energy - amount)
		return true
	return false

func get_energy() -> int:
	return energy
