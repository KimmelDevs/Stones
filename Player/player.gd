extends CharacterBody2D

# --- Movement & Combat Settings ---
@export var SPEED: float = 100.0
@export var ROLL_SPEED: float = 200.0
@export var ROLL_DURATION: float = 0.5
@export var ATTACK_DURATION: float = 0.4
@export var Inv: Inv
@export var max_hunger: int = 100
var hunger: int = max_hunger
var equipped_food: InvItem = null  # store the current food
@onready var camera_shake = $Camera2D
signal hunger_changed(value)
var knockback: Vector2 = Vector2.ZERO
@export var knockback_speed: float = 200.0
@export var knockback_duration: float = 0.2
var knockback_timer: float = 0.0

# --- State Variables ---
var last_direction := "down"
var is_rolling := false
var roll_timer := 0.0
var roll_direction := Vector2.ZERO
var can_move := true
var can_roll := true
var is_attacking := false
var attack_timer := 0.0

var equipped_weapon: Node = null    # reference to the weapon node
var weapon_damage: int = 0          # damage of the equipped weapon
var weapon_knockback: float = 0.0   # knockback strength of the equipped weapon
var equipped_skill: Node = null

# --- References ---
var stats = PlayerStats
@onready var hurtbox = $HurtBox
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sword_hitbox: Area2D = $Sword/Marker2D/HitBox


func _ready():
	stats.connect("no_health", Callable(self, "queue_free"))
	
	# Find the HotBar node in the current scene
	var world = get_tree().current_scene
	var hotbar = world.get_node("CanvasLayer/HotBar")
	if hotbar:
		hotbar.selection_changed.connect(equip_item)
	else:
		push_error("HotBar not found in scene!")
	# 🔥 Connect inventory update signal
	if Inv:
		Inv.update.connect(_on_inventory_updated)

func _physics_process(delta: float) -> void:
	# --- Handle attack duration ---
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false
			can_move = true
			play_idle_animation()
		return
	if knockback_timer > 0:
		velocity = knockback
		move_and_slide()
		knockback_timer -= delta
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
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			# If food is equipped → eat
			if equipped_food:
				_consume_food(equipped_food)


func set_hunger(value: int) -> void:
	hunger = clamp(value, 0, max_hunger)
	emit_signal("hunger_changed", hunger)

func get_hunger() -> int:
	return hunger
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
# --- Equip Item ---
func equip_item(item: InvItem) -> void:
	if not item:
		print("No item equipped")
		_clear_weapon()
		return

	print("Equipping: ", item.name, " | Category: ", item.Category)

	match item.Category:
		"Weapon":
			_equip_weapon(item)
		"Food":
			_equip_food(item)
		_:
			print("Item category not handled: ", item.Category)
			_clear_weapon()
func _equip_weapon(item: InvItem) -> void:
	if not $Sword:
		push_error("Sword node not found!")
		_clear_weapon()
		return

	# ✅ Update weapon sprite
	_set_weapon_sprite(item.texture)

	# Update stats
	equipped_weapon = $Sword
	weapon_damage = item.damage
	weapon_knockback = item.knockback_strength

	# 🔥 Handle skill script
	if equipped_skill:
		equipped_skill.queue_free()
		equipped_skill = null

	if item.skill_scene:
		equipped_skill = item.skill_scene.instantiate()
		equipped_skill.player = self

		if equipped_skill.has_method("haveinv"):
			equipped_skill.inventory = preload("res://Inventory/playerinventory.tres")

		add_child(equipped_skill)
		print("Equipped skill scene: ", equipped_skill.name)
	else:
		print("No skill scene for this item")
		equipped_skill = null

	print("Weapon Damage: ", weapon_damage, " | Knockback: ", weapon_knockback)


# --- Helper for weapon sprite ---
func _set_weapon_sprite(texture: Texture2D) -> void:
	var sword_sprite = $Sword.get_node("Marker2D/Sprite2D") as Sprite2D
	
	if not sword_sprite:
		push_error("Sprite2D node not found!")
		return
	
	if texture:
		sword_sprite.texture = texture
		sword_sprite.visible = false

		# scale properly to 12x12
		var target_size = Vector2(12, 12)
		var tex_size = texture.get_size()
		if tex_size != Vector2.ZERO:
			sword_sprite.scale = target_size / tex_size
	else:
		# remove texture and hide
		sword_sprite.texture = null
		sword_sprite.visible = false
func _clear_weapon() -> void:
	equipped_weapon = null
	weapon_damage = 0
	weapon_knockback = 0.0
	_set_weapon_sprite(null)

	if equipped_skill:
		equipped_skill.queue_free()
		equipped_skill = null
func _equip_food(item: InvItem) -> void:
	_clear_weapon()  # keep your existing weapon cleanup

	if not item:
		print("No food item equipped")
		equipped_food = null
		return

	equipped_food = item
	print("Equipped food: ", item.name)

func _consume_food(item: InvItem) -> void:
	if not item:
		return

	# 🥩 Restore hunger
	PlayerStats.set_hunger(PlayerStats.get_hunger() + item.nutrition)

	# ❤️ Heal player
	PlayerStats.set_health(PlayerStats.get_health() + item.damage)

	print("Ate ", item.name, " → +", item.nutrition, " hunger, +", item.damage, " health")

	# 🔻 Remove 1 from stack (or remove item completely)
	if Inv and Inv.remove_item(item, 1):  # remove 1 count of this food
		print("Removed 1x ", item.name, " from inventory")
	else:
		print("Could not remove item from inventory")

	# ✅ If stack is gone → unequip
	if not Inv.has_item(item):
		equipped_food = null
		print(item.name, " is all gone! Unequipped.")


func _on_inventory_updated():
	print("Inventory changed, checking equipment…")

	# If you want to re-check current equipped item from hotbar:
	var world = get_tree().current_scene
	var hotbar = world.get_node("CanvasLayer/HotBar")
	if hotbar and hotbar.get_selected_item():
		equip_item(hotbar.get_selected_item())

	# Or, if you just want to make sure equipped skill is still valid:
	elif equipped_skill and not Inv.slots.any(func(slot): return slot.item == equipped_skill):
		print("Equipped skill no longer in inventory, removing…")
		equipped_skill.queue_free()
		equipped_skill = null

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
	if not equipped_weapon:
		print("You can't attack without a weapon!")
		return

	is_attacking = true
	can_move = false
	attack_timer = ATTACK_DURATION

	# --- Use last_direction for animation + knockback ---
	var dir_vector = Vector2.ZERO
	match last_direction:
		"right": dir_vector = Vector2.RIGHT
		"left":  dir_vector = Vector2.LEFT
		"up":    dir_vector = Vector2.UP
		"down":  dir_vector = Vector2.DOWN

	var anim_name = "attack_" + last_direction
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

	# --- Apply weapon stats to HitBox ---
	if sword_hitbox:
		sword_hitbox.damage = weapon_damage
		sword_hitbox.knockback_vector = dir_vector * (weapon_knockback * 0.3)


		
# --- Play Idle Animation ---
func play_idle_animation() -> void:
	match last_direction:
		"right": animation_player.play("idle_right")
		"left":  animation_player.play("idle_left")
		"up":    animation_player.play("idle_up")
		"down":  animation_player.play("idle_down")

# --- When Hit ---
func _on_hurt_box_area_entered(area: Area2D):
	knockback = area.knockback_vector * knockback_speed
	knockback_timer = knockback_duration
	stats.set_health(stats.health - area.damage)
	hurtbox.create_hit_effect()
	stats.set_health(stats.health - 1)
	hurtbox.start_invisibility(2)
	hurtbox.create_hit_effect()
	camera_shake.add_trauma(0.9)

func player():
	pass

func collect(item):
	Inv.insert(item)


func _on_hit_box_area_entered(area: Area2D) -> void:
	camera_shake.add_trauma(0.7)
