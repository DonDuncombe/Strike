class_name EquipmentManager
extends Node2D

@export_category("References")
## Player whose weapon signals and facing drive this equipment. Leave empty to use the parent PlayerController.
@export var player: PlayerController
## Node that holds the weapon visuals. Its horizontal scale is mirrored to follow the player facing direction.
@export var weapon_anchor: Node2D
## Sprite used to display the active weapon texture when the weapon resource provides one.
@export var weapon_sprite: Sprite2D
## AnimationPlayer for attack, attack_melee and attack_ranged animations. Assign to enable weapon attack visuals.
@export var animation_player: AnimationPlayer

var current_weapon: WeaponData = null

func _ready() -> void:
	if player == null:
		player = get_parent() as PlayerController
		
	if player != null:
		player.weapon_switched.connect(_on_weapon_switched)
		player.weapon_used.connect(_on_weapon_used)
		
		# Sync initial state if inventory already contains items
		if not player.inventory.is_empty():
			_on_weapon_switched(player.active_weapon_index, player.inventory[player.active_weapon_index])

func _process(_delta: float) -> void:
	if player == null or weapon_anchor == null:
		return
		
	# Synchronize anchor scale/facing with player direction
	var facing_dir: float = player._get_current_facing_direction()
	weapon_anchor.scale.x = absf(weapon_anchor.scale.x) * facing_dir

func _on_weapon_switched(_index: int, weapon_data: WeaponData) -> void:
	current_weapon = weapon_data
	
	if current_weapon == null:
		if weapon_sprite != null:
			weapon_sprite.texture = null
		return

	# Handle weapon display switching
	if weapon_sprite != null:
		# If WeaponData is extended with a texture export property:
		if current_weapon.get("texture") != null:
			weapon_sprite.texture = current_weapon.get("texture") as Texture2D

func _on_weapon_used(_index: int, weapon_data: WeaponData) -> void:
	if animation_player == null or weapon_data == null:
		return

	# Play specific animation based on weapon type or trigger default attack
	var anim_name: StringName = &"attack"
	if weapon_data is MeleeWeaponData:
		anim_name = &"attack_melee"
	elif weapon_data is RangedWeaponData:
		anim_name = &"attack_ranged"

	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
