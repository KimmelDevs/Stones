extends CharacterBody2D

# --- Knockback ---
var knockback: Vector2 = Vector2.ZERO
@export var knockback_speed: float = 200.0
@export var knockback_duration: float = 0.2

@onready var drop_slime = preload("res://Enemies/EnemyDrops/slimedrop.tscn")
# --- Jump settings ---
@export var jump_force := 200.0
@export var charge_jump_force := 350.0
@export var small_hop_force := 120.0
@export var air_time := 0.4
@export var jump_cooldown := 2.0
@export var spit_speed := 250.0
@export var spit_delay := 0.2
@export var jumps_before_spit := 3

# --- States ---
enum { IDLE, WANDER, CHASE }
var state = IDLE

# --- Nodes ---
@onready var hurtbox = $HurtBox
@onready var stats = $Stats
@onready var playerdetectionzone = $PlayerDetectionArea
@onready var sprite = $Sprite2D
@onready var anim_player = $AnimationPlayer
@onready var hit_box = $Marker2D/HitBox
# --- Scenes ---
var MegaSpitScene := preload("res://Enemies/Projectiles/megaspit.tscn")
#var SmallSlimeScene := preload("res://Enemies/small_slime.tscn")
var DeathEffectScene := preload("res://Effects/slime_death.tscn")
#var SlimePuddleScene := preload("res://Enemies/Effects/slime_puddle.tscn")

# --- Vars ---
var move_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var dying: bool = false
var knockback_force =1
var home_position: Vector2
var is_jumping := false
var can_jump := true
var jump_count := 0
var jump_target: Vector2 = Vector2.ZERO
@export var damage := 1
func _ready() -> void:
	home_position = global_position
	# Set damage directly to 2
	hit_box.damage = damage
	
	# Set knockback direction from spit velocity
	if velocity != Vector2.ZERO:
		hit_box.knockback_vector = velocity.normalized() * knockback_force


func _physics_process(delta: float) -> void:
	seek_player()
	global_position += velocity * delta

	if velocity != Vector2.ZERO:
		hit_box.knockback_vector = velocity.normalized() * knockback_force
	if knockback_timer > 0:
		velocity = knockback
		knockback_timer -= delta
		if knockback_timer <= 0 and dying:
			spawn_death_effect()
			#split_on_death()
			queue_free()
	else:
		velocity = move_velocity

	move_and_slide()

func seek_player() -> void:
	if is_jumping or not can_jump:
		return

	if playerdetectionzone.can_see_player():
		state = CHASE
		var player = playerdetectionzone.player
		if player:
			var attack_choice = randi() % 4
			match attack_choice:
				0: start_jump_sequence(player.global_position, jump_force) # Hop chase
				1: charge_jump(player.global_position) # Long leap
				2: multi_hop_combo(player.global_position) # Small hops + big spit
				3: fake_out_jump(player.global_position) # Retreat hop
	else:
		state = WANDER
		var random_pos = home_position + Vector2(randf_range(-150, 150), randf_range(-150, 150))
		start_jump_sequence(random_pos, jump_force)

# --- Jump Sequence ---
func start_jump_sequence(target_position: Vector2, force: float) -> void:
	if is_jumping or not can_jump:
		return
	can_jump = false
	is_jumping = true
	jump_target = target_position

	sprite.flip_h = target_position.x < global_position.x
	anim_player.play("anticipation")
	await get_tree().create_timer(0.5).timeout

	var dir = (jump_target - global_position).normalized()
	move_velocity = dir * force
	anim_player.play("jump")
	await get_tree().create_timer(air_time).timeout

	is_jumping = false
	move_velocity = Vector2.ZERO
	anim_player.play("idle")

	jump_count += 1
	if jump_count >= jumps_before_spit and state == CHASE:
		jump_count = 0
		await shoot_mega_spit()

	await get_tree().create_timer(jump_cooldown).timeout
	can_jump = true

# --- Charge Jump ---
func charge_jump(target_position: Vector2) -> void:
	start_jump_sequence(target_position, charge_jump_force)

# --- Multi-Hop Combo ---
func multi_hop_combo(target_position: Vector2) -> void:
	for i in range(2):
		await start_jump_sequence(global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40)), small_hop_force)
	await start_jump_sequence(target_position, jump_force)
	await shoot_mega_spit()

# --- Fake-Out Jump ---
func fake_out_jump(player_position: Vector2) -> void:
	var retreat_dir = (global_position - player_position).normalized()
	var retreat_pos = global_position + retreat_dir * 100
	await start_jump_sequence(retreat_pos, jump_force)
	await start_jump_sequence(player_position, charge_jump_force)

# --- Mega Spit ---
func shoot_mega_spit() -> void:
	var player = playerdetectionzone.player
	if not player or not is_instance_valid(player):
		return

	anim_player.play("ready_shoot")
	await anim_player.animation_finished
	sprite.flip_h = player.global_position.x < global_position.x
	anim_player.play("shoot")

	var target_pos = player.global_position
	for i in range(3):
		var spit = MegaSpitScene.instantiate()
		get_tree().current_scene.add_child(spit)
		spit.global_position = global_position
		spit.velocity = (target_pos - global_position).normalized() * spit_speed
		if spit.has_node("AnimationPlayer"):
			spit.get_node("AnimationPlayer").play("spit")
		await get_tree().create_timer(spit_delay).timeout

	# Optional: Drop puddle on spit
	#if SlimePuddleScene:
		#var puddle = SlimePuddleScene.instantiate()
		#puddle.global_position = global_position
		#get_parent().add_child(puddle)

	anim_player.play("finish_shoot")
	await anim_player.animation_finished
	anim_player.play("idle")

# --- Damage ---
func _on_hurt_box_area_entered(area: Area2D) -> void:
	knockback = area.knockback_vector * knockback_speed
	knockback_timer = knockback_duration
	stats.set_health(stats.health - area.damage)
	hurtbox.create_hit_effect()
	if stats.health <= 0:
		dying = true

# --- Death Effects ---
func spawn_death_effect() -> void:
	var effect_instance = DeathEffectScene.instantiate()
	effect_instance.global_position = global_position
	


	var slime_instance = drop_slime.instantiate()
	slime_instance.global_position = global_position + Vector2(randf_range(-16, 16), randf_range(-16, 16))
	get_parent().add_child(slime_instance)
	get_parent().add_child(effect_instance)

#func split_on_death() -> void:
	#for i in range(2):
		#var small_slime = SmallSlimeScene.instantiate()
		#small_slime.global_position = global_position + Vector2(randf_range(-16, 16), randf_range(-16, 16))
		#get_parent().add_child(small_slime)
