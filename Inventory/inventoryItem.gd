extends Resource
class_name InvItem

@export var name: String = ""
@export var texture: Texture2D
@export var Category: String = ""  # e.g., "Weapon", "Food", "Consumable"

# Weapon-specific fields
@export var weapon_type: String = ""  # e.g., "Sword", "Bow", "Staff"
@export var skill_scene: PackedScene  # instead of Script, now a .tscn
@export var knockback_strength: float = 0.0  # force applied when hitting enemies
@export var damage: int = 0  # damage dealt by weapon

# Food-specific field
@export var nutrition: int = 0  # for food items, 0 by default
