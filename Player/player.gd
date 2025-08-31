class_name PlayerEntity
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
@export var weapon_type: String = ""  # Example: "Axe", "Sword", etc.
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
@onready var sword_node = $Sword
@onready var longsword_node = $LongSword
var weapon_hitbox: Area2D = null

# --- Station Placement ---
var equipped_station: InvItem = null
var station_preview: Node2D = null   # ghost preview node


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
	# --- Station Preview Follow Mouse ---
	if station_preview:
		var mouse_pos = get_global_mouse_position()
		# Snap to grid (optional, change 16 to tile size)
		mouse_pos = mouse_pos.snapped(Vector2(16, 16))
		station_preview.global_position = mouse_pos

	# --- Attack Input ---
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_rolling:
		start_attack()
		return

	# --- Pick Input ---
	if Input.is_action_just_pressed("Pick"):
		var nearest = get_nearest_bush()
		if nearest:
			nearest.drop_berry(self)
		else:
			try_pick_from_choppingboard()

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
	if Input.is_action_just_pressed("interact"):
		try_place_on_choppingboard()
	# --- Station Placement ---
	if station_preview and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_place_station()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			print("Cancelled placement")
			_clear_station()


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

func equip_item(item: InvItem) -> void:
	if not item:
		print("No item equipped")
		_clear_weapon()
		_clear_food()
		return

	print("Equipping: ", item.name, " | Category: ", item.Category)

	match item.Category:
		"Weapon":
			_clear_food()  # make sure no food is equipped
			_equip_weapon(item)
		"Food":
			_clear_weapon()  # make sure no weapon is equipped
			_equip_food(item)
		"Stations":
			_clear_weapon()
			_clear_food()
			_equip_station(item)
		_:
			print("Item category not handled: ", item.Category)
			_clear_weapon()
			_clear_food()


func _disable_weapon(node: Node) -> void:
	if not node:
		return
	node.hide()
	node.set_process(false)
	node.set_physics_process(false)

	var hitbox = node.get_node_or_null("Marker2D/HitBox")
	if hitbox:
		hitbox.monitoring = false
		hitbox.damage = 0                # 🔥 reset damage
		hitbox.knockback_vector = Vector2.ZERO  # 🔥 reset knockback

func _enable_weapon(node: Node) -> void:
	if not node:
		return
	node.show()
	node.set_process(true)
	node.set_physics_process(true)

	var hitbox = node.get_node_or_null("Marker2D/HitBox")
	if hitbox:
		hitbox.monitoring = true

func _equip_weapon(item: InvItem) -> void:
	# Hide both weapon nodes first
	_disable_weapon(sword_node)
	_disable_weapon(longsword_node)

	# Reset everything to avoid stale values
	equipped_weapon = null
	weapon_hitbox = null
	weapon_damage = 0
	weapon_knockback = 0.0

	# Pick the right weapon node
	match item.weaponlength:
		"Short":
			if sword_node:
				equipped_weapon = sword_node
				
				_enable_weapon(sword_node)
				weapon_hitbox = sword_node.get_node("Marker2D/HitBox")
				print(weapon_hitbox)
		"Long":
			if longsword_node:
				equipped_weapon = longsword_node
				
				_enable_weapon(longsword_node)
				weapon_hitbox = longsword_node.get_node("Marker2D/HitBox")
				print(weapon_hitbox)
		_:
			push_error("Unknown weaponlength: %s" % item.weaponlength)
			return

	# Apply stats
	if equipped_weapon and weapon_hitbox:
		equipped_weapon.show()
		_set_weapon_sprite(item.texture, item.weaponlength)

		weapon_damage = item.damage
		weapon_knockback = item.knockback_strength
		weapon_type = item.weapon_type  # 🔥 assuming your InvItem has this property
		_update_weapon_collision()      # 🔥 update collision setu
		print("Equipped ", item.name, " | Damage: ", weapon_damage, " | Knockback: ", weapon_knockback)
	else:
		push_error("Equipped weapon missing hitbox!")
		return

	# Reset and re-add skill
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
func _update_weapon_collision():
	if not weapon_hitbox:
		return

	# Reset all first
	for i in range(1, 21): # Godot supports up to 20 collision layers
		weapon_hitbox.set_collision_layer_value(i, false)
		weapon_hitbox.set_collision_mask_value(i, false)

	# ✅ Default layers (always on)
	weapon_hitbox.set_collision_layer_value(5, true)  # Layer 5 ON
	weapon_hitbox.set_collision_mask_value(4, true)   # Mask 4 ON

	# ✅ Extra layers if weapon is Axe
	if weapon_type == "Axe":
		weapon_hitbox.set_collision_layer_value(10, true)  # Layer 10 ON
		weapon_hitbox.set_collision_mask_value(9, true)    # Mask 9 ON

func _set_weapon_sprite(texture: Texture2D, weaponlength: String = "") -> void:
	if not equipped_weapon:
		return

	var weapon_sprite = equipped_weapon.get_node("Marker2D/Sprite2D") as Sprite2D
	if not weapon_sprite:
		push_error("Sprite2D node not found in weapon!")
		return

	if texture:
		weapon_sprite.texture = texture
		weapon_sprite.show()

		if weaponlength == "Short":
			# Scale properly to 12x12
			var target_size = Vector2(12, 12)
			var tex_size = texture.get_size()
			if tex_size != Vector2.ZERO:
				weapon_sprite.scale = target_size / tex_size
		else:
			# Long weapons keep their original size
			weapon_sprite.scale = Vector2.ONE
	else:
		weapon_sprite.texture = null
		weapon_sprite.hide()
func _clear_food() -> void:
	equipped_food = null
func try_place_on_choppingboard():
	var boards = get_tree().get_nodes_in_group("chopping_board")
	var nearest: Node = null
	var nearest_dist = INF
	var place_range = 32

	for board in boards:
		var dist = board.global_position.distance_to(global_position)
		if dist < nearest_dist and dist <= place_range:
			nearest = board
			nearest_dist = dist

	if nearest and equipped_food \
		and equipped_food.Category == "Food" \
		and equipped_food.food_type == "Corpse":
		
		# ✅ Duplicate first before removing
		var new_item = equipped_food.duplicate(true)

		# Remove from player inventory
		if Inv.remove_item(equipped_food, 1):
			# Insert into board inventory
			nearest.board_inv.insert(new_item)

			print("Placed corpse on chopping board!")
			
			# Clear equipped AFTER
			equipped_food = null
func try_pick_from_choppingboard():
	var boards = get_tree().get_nodes_in_group("chopping_board")
	var nearest: Node = null
	var nearest_dist := INF
	var pick_range := 32.0

	for board in boards:
		var dist = board.global_position.distance_to(global_position)
		if dist < nearest_dist and dist <= pick_range:
			nearest = board
			nearest_dist = dist

	if not nearest or not nearest.board_inv:
		return

	for slot in nearest.board_inv.slots:
		if slot.item:
			var board_item: InvItem = slot.item

			# Find a matching *reference* already in player inventory to stack onto
			var stack_ref: InvItem = _find_existing_player_item_ref(board_item)

			# Remove 1 from the board first (we're moving that exact reference out)
			if nearest.board_inv.remove_item(board_item, 1):
				# If we found an existing ref, insert THAT ref so Inv.insert() stacks.
				# Otherwise insert the board's item (new stack).
				if stack_ref:
					Inv.insert(stack_ref)
				else:
					Inv.insert(board_item)

				print("Picked back ", board_item.name, " from chopping board!")
			return

func _equip_station(item: InvItem) -> void:
	if not item or not item.skill_scene:
		print("Station item has no scene to place!")
		return

	equipped_station = item
	station_preview = item.skill_scene.instantiate()

	# Add preview to world (NOT to player)
	get_tree().current_scene.add_child(station_preview)

	# Make semi-transparent blue
	if station_preview.has_node("Sprite2D"):
		var s: Sprite2D = station_preview.get_node("Sprite2D")
		s.modulate = Color(0, 0.5, 1, 0.5)

	# Disable collisions while previewing
	if station_preview is CollisionObject2D:
		station_preview.set_collision_layer(0)
		station_preview.set_collision_mask(0)

	print("Equipped station for placement: ", item.name)
func _clear_station() -> void:
	if station_preview:
		station_preview.queue_free()
		station_preview = null
	equipped_station = null
func _place_station() -> void:
	if not equipped_station or not station_preview:
		return

	# Create real station
	var placed_station = equipped_station.skill_scene.instantiate()
	get_tree().current_scene.add_child(placed_station)
	placed_station.global_position = station_preview.global_position

	# Delete preview
	station_preview.queue_free()
	station_preview = null

	# Remove 1 from inventory
	if Inv.remove_item(equipped_station, 1):
		print("Placed station: ", placed_station.name)
	else:
		print("Could not remove station from inventory!")

	# Unequip station
	equipped_station = null


func _find_existing_player_item_ref(item: InvItem) -> InvItem:
	# Prefer matching by resource_path if it exists; otherwise fall back to name/category/food_type.
	for s in Inv.slots:
		if s.item:
			if item.resource_path != "" and s.item.resource_path == item.resource_path:
				return s.item
			elif s.item.name == item.name \
				and s.item.Category == item.Category \
				and (s.item.has_method("get") and s.item.get("food_type") == item.get("food_type")):
				return s.item
	return null


func _clear_weapon() -> void:
	if equipped_weapon:
		var hitbox = equipped_weapon.get_node_or_null("Marker2D/HitBox")
		if hitbox:
			hitbox.damage = 0
			hitbox.knockback_vector = Vector2.ZERO

	_disable_weapon(sword_node)
	_disable_weapon(longsword_node)

	equipped_weapon = null
	weapon_hitbox = null
	weapon_damage = 0
	weapon_knockback = 0.0
	_set_weapon_sprite(null)

	if equipped_skill:
		equipped_skill.queue_free()
		equipped_skill = null

func _equip_food(item: InvItem) -> void:
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
	if not equipped_weapon or not weapon_hitbox:
		print("You can't attack without a weapon!")
		return

	is_attacking = true
	can_move = false
	attack_timer = ATTACK_DURATION

	var dir_vector = Vector2.ZERO
	match last_direction:
		"right": dir_vector = Vector2.RIGHT
		"left":  dir_vector = Vector2.LEFT
		"up":    dir_vector = Vector2.UP
		"down":  dir_vector = Vector2.DOWN

	var anim_name = "attack_" + last_direction
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

	# Apply weapon stats
	weapon_hitbox.damage = weapon_damage
	weapon_hitbox.knockback_vector = dir_vector * (weapon_knockback * 0.3)
	print(weapon_hitbox)
	print(weapon_damage)


		
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
	$Sprite2D.modulate = Color.PALE_VIOLET_RED
	
	camera_shake.add_trauma(1)

	# Reset color after 1 second
	await get_tree().create_timer(1.0).timeout
	$Sprite2D.modulate = Color(1, 1, 1, 1)  # reset to normal
	# If original isn’t pure white, save and restore:
	# var original_color = $Sprite2D.modulate
	# 
	# await get_tree().create_timer(1.0).timeout
	# $Sprite2D.modulate = original_color

	# Camera shake
func player():
	pass

func collect(item):
	Inv.insert(item)


func _on_hit_box_area_entered(area: Area2D) -> void:
	pass
		


func _on_hit_box_area_exited(area: Area2D) -> void:
	pass # Replace with function body.


func _on_hit_box_body_entered(body: Node2D) -> void:
	camera_shake.add_trauma(0.7) 
