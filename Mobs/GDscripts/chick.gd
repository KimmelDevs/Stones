extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

# --- States ---
enum State { IDLE, IDLING, WANDER }
var state: State = State.IDLE

# --- Facing direction ---
enum Facing { DOWN, UP, LEFT, RIGHT }
var facing: Facing = Facing.DOWN

# --- Timers ---
var state_timer: float = 0.0
@export var idle_time_range: Vector2 = Vector2(1.5, 3.0) # seconds
@export var wander_time_range: Vector2 = Vector2(0.5, 1.5)

# --- Movement ---
@export var speed: float = 25.0
var wander_dir: Vector2 = Vector2.ZERO

func _ready():
	_reset_idle_timer()

func _process(delta: float) -> void:
	state_timer -= delta
	
	match state:
		State.IDLE:
			_play_idle_animation()
			if state_timer <= 0:
				state = State.IDLING
				state_timer = randf_range(0.5, 1.5) # short "cute" action

		State.IDLING:
			_play_idling_animation()
			if state_timer <= 0:
				state = State.WANDER
				wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
				state_timer = randf_range(wander_time_range.x, wander_time_range.y)

		State.WANDER:
			velocity = wander_dir * speed
			move_and_slide()
			_update_facing_from_velocity()
			_play_walk_animation()
			if state_timer <= 0:
				velocity = Vector2.ZERO
				state = State.IDLE
				_reset_idle_timer()

# --- Animations ---
func _play_idle_animation() -> void:
	match facing:
		Facing.UP: animated_sprite_2d.play("IdleUp")
		Facing.DOWN: animated_sprite_2d.play("IdleDown")
		Facing.LEFT: animated_sprite_2d.play("IdleLeft")
		Facing.RIGHT: animated_sprite_2d.play("IdleRight")

func _play_idling_animation() -> void:
	match facing:
		Facing.UP: animated_sprite_2d.play("IdlingUp")
		Facing.DOWN: animated_sprite_2d.play("IdlingDown")
		Facing.LEFT: animated_sprite_2d.play("IdlingLeft")
		Facing.RIGHT: animated_sprite_2d.play("IdlingRight")

func _play_walk_animation() -> void:
	match facing:
		Facing.UP: animated_sprite_2d.play("WalkUp")
		Facing.DOWN: animated_sprite_2d.play("WalkDown")
		Facing.LEFT: animated_sprite_2d.play("WalkLeft")
		Facing.RIGHT: animated_sprite_2d.play("WalkRight")

# --- Direction handling ---
func _update_facing_from_velocity() -> void:
	if abs(velocity.x) > abs(velocity.y):
		facing = Facing.RIGHT if velocity.x > 0 else Facing.LEFT
	elif velocity != Vector2.ZERO:
		facing = Facing.DOWN if velocity.y > 0 else Facing.UP

# --- Helpers ---
func _reset_idle_timer():
	state_timer = randf_range(idle_time_range.x, idle_time_range.y)
