extends CharacterBody2D

# --- Movement & Combat Settings ---
@export var SPEED: float = 100.0
@export var ROLL_SPEED: float = 200.0
@export var ROLL_DURATION: float = 0.5
@export var ATTACK_DURATION: float = 0.4
@export var Inv: Inv

# --- State Variables ---
var last_direction := "down"
var is_rolling := false
var roll_timer := 0.0
var roll_direction := Vector2.ZERO
var can_move := true
var can_roll := true
var is_attacking := false
var attack_timer := 0.0

# --- References ---
var stats = PlayerStats
@onready var hurtbox = $HurtBox
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sword_hitbox: Area2D = $Marker2D/HitBox

func _ready():
	stats.connect("no_health", Callable(self, "queue_free"))

	# Find the HotBar node in the current scene
	var world = get_tree().current_scene
	var hotbar = world.get_node("CanvasLayer/HotBar")
	if hotbar:
		hotbar.selection_changed.connect(equip_item)
	else:
		push_error("HotBar not found in scene!")
		

func _physics_process(delta: float) -> void:
	# --- Handle attack duration ---
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false
			can_move = true
			play_idle_animation()
		return

	# --- Attack Input ---
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_rolling:
		start_attack()
		return

	# --- Pick Input ---
	if Input.is_action_just_pressed("Pick"):
		var nearest = get_nearest_bush()
		if nearest:
			nearest.drop_berry(self)

	# --- Movement Input ---
	var input_vector := Vector2.ZERO
	if can_move:
		input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# --- Roll Input ---
	if Input.is_action_just_pressed("roll") and can_roll and not is_rolling and not is_attacking:
		if stats.consume_energy(3):
			start_roll(input_vector)
		else:
			print("Not enough energy to roll!")

	# --- Rolling Movement ---
	if is_rolling:
		velocity = roll_direction * ROLL_SPEED
		move_and_slide()
		roll_timer -= delta
		if roll_timer <= 0:
			is_rolling = false
			can_move = true
			play_idle_animation()
		return

	# --- Normal Movement ---
	velocity = input_vector * SPEED
	move_and_slide()

	# --- Animations ---
	if input_vector != Vector2.ZERO:
		if input_vector.x > 0:
			animation_player.play("walk_right")
			last_direction = "right"
		elif input_vector.x < 0:
			animation_player.play("walk_left")
			last_direction = "left"
		elif input_vector.y < 0:
			animation_player.play("walk_up")
			last_direction = "up"
		elif input_vector.y > 0:
			animation_player.play("walk_down")
			last_direction = "down"
	else:
		play_idle_animation()

# --- Get nearest bush (only with berries) ---
func get_nearest_bush() -> Node:
	var bushes = get_tree().get_nodes_in_group("berry_bush")
	var nearest_bush = null
	var nearest_dist = INF
	var pick_range = 32 # Max distance to pick

	for bush in bushes:
		if bush.state != "berries": # Skip bushes with no berries
			continue
		var dist = bush.global_position.distance_to(global_position)
		if dist < nearest_dist and dist <= pick_range:
			nearest_bush = bush
			nearest_dist = dist

	return nearest_bush
func equip_item(item):
	if item and item is InvItem:
		print(item.name)

		if item.name == "Rock":
			var rock_scene = preload("res://Equipments/Weapons/rock_equip.tscn")
			var rock_instance = rock_scene.instantiate()
			rock_instance.player = self
			rock_instance.inventory = Inv  # pass inventory reference
			get_tree().current_scene.add_child(rock_instance)

			
	else:
		print("No item equipped")


# --- Start a Roll ---
func start_roll(input_vector: Vector2) -> void:
	is_rolling = true
	can_move = false
	roll_timer = ROLL_DURATION

	if input_vector != Vector2.ZERO:
		roll_direction = input_vector.normalized()
	else:
		match last_direction:
			"right": roll_direction = Vector2.RIGHT
			"left":  roll_direction = Vector2.LEFT
			"up":    roll_direction = Vector2.UP
			"down":  roll_direction = Vector2.DOWN

	if roll_direction.x > 0:
		last_direction = "right"
	elif roll_direction.x < 0:
		last_direction = "left"
	elif roll_direction.y < 0:
		last_direction = "up"
	elif roll_direction.y > 0:
		last_direction = "down"

	var anim_name = "roll_" + last_direction
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

# --- Start an Attack ---
func start_attack() -> void:
	is_attacking = true
	can_move = false
	attack_timer = ATTACK_DURATION

	var mouse_pos = get_global_mouse_position()
	var dir_vector = (mouse_pos - global_position).normalized()

	if abs(dir_vector.x) > abs(dir_vector.y):
		last_direction = "right" if dir_vector.x > 0 else "left"
	else:
		last_direction = "down" if dir_vector.y > 0 else "up"

	sword_hitbox.knockback_vector = dir_vector

	var anim_name = "attack_" + last_direction
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

# --- Play Idle Animation ---
func play_idle_animation() -> void:
	match last_direction:
		"right": animation_player.play("idle_right")
		"left":  animation_player.play("idle_left")
		"up":    animation_player.play("idle_up")
		"down":  animation_player.play("idle_down")

# --- When Hit ---
func _on_hurt_box_area_entered(_area: Area2D):
	stats.set_health(stats.health - 1)
	hurtbox.start_invisibility(2)
	hurtbox.create_hit_effect()

func player():
	pass

func collect(item):
	Inv.insert(item)
