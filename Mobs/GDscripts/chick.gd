extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

# --- Evolution Scenes ---
var RoosterScene = preload("res://Mobs/Scenes/Rooster.tscn")
var HenScene = preload("res://Mobs/Scenes/hen.tscn")
var DeathEffectScene = preload("res://Effects/bat_death.tscn")  # Create this effect scene

# --- Combat / Knockback ---
var knockback: Vector2 = Vector2.ZERO
@export var knockback_speed: float = 150.0
@export var knockback_duration: float = 0.3

# --- Nodes ---
@onready var hurtbox = $HurtBox
@onready var stats = $Stats
@onready var soft_collision: Area2D = $SoftCollision

# --- States ---
enum State { IDLE, IDLING, WANDER, FLEEING }
var state: State = State.IDLE

# --- Facing direction ---
enum Facing { DOWN, UP, LEFT, RIGHT }
var facing: Facing = Facing.DOWN

# --- Timers ---
var state_timer: float = 0.0
var evolution_timer: float = 720.0  # 12 minutes in seconds (12 * 60)
var knockback_timer: float = 0.0
@export var idle_time_range: Vector2 = Vector2(1.5, 3.0) # seconds
@export var wander_time_range: Vector2 = Vector2(0.5, 1.5)
@export var flee_time: float = 2.0  # How long to flee when hurt

# --- Movement ---
@export var speed: float = 25.0
@export var flee_speed: float = 60.0  # Faster when fleeing
var wander_dir: Vector2 = Vector2.ZERO
var home_position: Vector2
var dying: bool = false

# --- Behavior ---
var has_been_hurt: bool = false
var flee_direction: Vector2 = Vector2.ZERO

func _ready():
	home_position = global_position
	reset_idle_timer()


func _process(delta: float) -> void:
	# Update evolution timer
	evolution_timer -= delta
	if evolution_timer <= 0 and not dying:
		evolve_into_adult()
		return
	
	state_timer -= delta
	
	# Handle knockback
	if knockback_timer > 0:
		velocity = knockback
		knockback_timer -= delta
		if knockback_timer <= 0 and dying:
			spawn_death_effect()
			queue_free()
			return
	else:
		handle_state_machine(delta)
	
	move_and_slide()

func handle_state_machine(delta: float) -> void:
	match state:
		State.IDLE:
			play_idle_animation()
			velocity = apply_soft_collision(Vector2.ZERO)
			if state_timer <= 0:
				state = State.IDLING
				state_timer = randf_range(0.5, 1.5) # short "cute" action
				
		State.IDLING:
			play_idling_animation()
			velocity = apply_soft_collision(Vector2.ZERO)
			if state_timer <= 0:
				if not has_been_hurt:
					start_wandering()
				else:
					# Stay more cautious after being hurt
					state = State.IDLE
					reset_idle_timer()
					
		State.WANDER:
			var target_velocity = wander_dir * speed
			velocity = apply_soft_collision(target_velocity)
			update_facing_from_velocity()
			play_walk_animation()
			
			# Stay near home area
			var home_distance = global_position.distance_to(home_position)
			if home_distance > 80:  # Return to home if too far
				wander_dir = (home_position - global_position).normalized()
			
			if state_timer <= 0:
				velocity = Vector2.ZERO
				state = State.IDLE
				reset_idle_timer()
				
		State.FLEEING:
			var flee_velocity = flee_direction * flee_speed
			velocity = apply_soft_collision(flee_velocity)
			update_facing_from_velocity()
			play_walk_animation()
			
			if state_timer <= 0:
				state = State.IDLE
				reset_idle_timer()

func start_wandering() -> void:
	state = State.WANDER
	# More cautious wandering if hurt before
	var wander_intensity = 0.5 if has_been_hurt else 1.0
	wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * wander_intensity
	state_timer = randf_range(wander_time_range.x, wander_time_range.y)

func apply_soft_collision(base_velocity: Vector2) -> Vector2:
	if soft_collision and soft_collision.is_colliding():
		var push_vector = soft_collision.get_push_vector()
		return base_velocity + push_vector * 100
	return base_velocity

func evolve_into_adult() -> void:
	# 50/50 chance to become rooster or hen
	var evolution_scene = RoosterScene if randf() > 0.5 else HenScene
	
	# Spawn the evolved creature
	var evolved_creature = evolution_scene.instantiate()
	evolved_creature.global_position = global_position
	get_parent().add_child(evolved_creature)
	
	# Optional: Add evolution effect
	spawn_evolution_effect()
	
	# Remove this chicken
	queue_free()

func spawn_evolution_effect() -> void:
	# You can create a special evolution effect here
	# For now, just use a simple visual indicator
	var tween = create_tween()
	tween.tween_property(animated_sprite_2d, "modulate", Color.YELLOW, 0.3)
	tween.tween_property(animated_sprite_2d, "scale", Vector2(1.5, 1.5), 0.3)
	tween.parallel().tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.3)

# --- Animations ---
func play_idle_animation() -> void:
	match facing:
		Facing.UP: animated_sprite_2d.play("IdleUp")
		Facing.DOWN: animated_sprite_2d.play("IdleDown")
		Facing.LEFT: animated_sprite_2d.play("IdleLeft")
		Facing.RIGHT: animated_sprite_2d.play("IdleRight")

func play_idling_animation() -> void:
	match facing:
		Facing.UP: animated_sprite_2d.play("IdlingUp")
		Facing.DOWN: animated_sprite_2d.play("IdlingDown")
		Facing.LEFT: animated_sprite_2d.play("IdlingLeft")
		Facing.RIGHT: animated_sprite_2d.play("IdlingRight")

func play_walk_animation() -> void:
	match facing:
		Facing.UP: animated_sprite_2d.play("WalkUp")
		Facing.DOWN: animated_sprite_2d.play("WalkDown")
		Facing.LEFT: animated_sprite_2d.play("WalkLeft")
		Facing.RIGHT: animated_sprite_2d.play("WalkRight")

# --- Direction handling ---
func update_facing_from_velocity() -> void:
	if abs(velocity.x) > abs(velocity.y):
		facing = Facing.RIGHT if velocity.x > 0 else Facing.LEFT
	elif velocity != Vector2.ZERO:
		facing = Facing.DOWN if velocity.y > 0 else Facing.UP

# --- Combat Functions ---
func _on_hurt_box_area_entered(area: Area2D) -> void:
	if dying:
		return
		
	# Apply knockback
	if area.has_method("get") and area.get("knockback_vector"):
		knockback = area.knockback_vector * knockback_speed
	elif area.knockback_vector:
		knockback = area.knockback_vector * knockback_speed
	else:
		# Fallback knockback direction
		var direction = (global_position - area.global_position).normalized()
		knockback = direction * knockback_speed
		
	knockback_timer = knockback_duration
	
	# Take damage
	if stats:
		# Properly get damage from the area
		var damage_amount = 1  # Default damage
		if area.has_signal("damage") or "damage" in area:
			damage_amount = area.damage
		elif area.get("damage") != null:
			damage_amount = area.get("damage")
		
		print("Taking damage: ", damage_amount, " | Current health: ", stats.health)
		stats.set_health(stats.health - damage_amount)
		
	# Create hurt effect
	if hurtbox and hurtbox.has_method("create_hit_effect"):
		hurtbox.create_hit_effect()
	
	# Chicken behavior when hurt
	has_been_hurt = true
	
	if stats and stats.health <= 0:
		dying = true
	else:
		# Flee in opposite direction of attack
		if area.has_method("get") and area.get("knockback_vector"):
			flee_direction = -area.knockback_vector.normalized()
		else:
			flee_direction = (global_position - area.global_position).normalized()
			
		state = State.FLEEING
		state_timer = flee_time
		
		# Make chicken more skittish after being hurt
		idle_time_range = Vector2(2.0, 4.0)  # Longer idle times
		wander_time_range = Vector2(0.3, 0.8)  # Shorter wander times

func _on_stats_no_health() -> void:
	dying = true

func spawn_death_effect() -> void:
	if DeathEffectScene:
		var effect_instance = DeathEffectScene.instantiate()
		effect_instance.global_position = global_position
		get_parent().add_child(effect_instance)
	
	# Optional: Drop feathers or other items
	spawn_death_drops()

func spawn_death_drops() -> void:
	# You can add feather drops or other items here
	# For example:
	# var feather_scene = preload("res://Items/Feather.tscn")
	# var feather = feather_scene.instantiate()
	# feather.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
	# get_parent().add_child(feather)
	pass

# --- Helpers ---
func reset_idle_timer():
	state_timer = randf_range(idle_time_range.x, idle_time_range.y)

# --- Debug (optional) ---
func get_time_until_evolution() -> String:
	var minutes = int(evolution_timer / 60)
	var seconds = int(evolution_timer) % 60
	return "%d:%02d" % [minutes, seconds]
