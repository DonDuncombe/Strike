class_name RangedWeaponData
extends WeaponData

## Scene to spawn when firing. Its root must use the Projectile script.
@export var projectile_scene: PackedScene
## Projectile spawn offset from the player in world pixels. X is mirrored with horizontal firing direction; Y remains a vertical offset.
@export var spawn_offset: Vector2 = Vector2(16.0, 0.0)
## Speed in world pixels per second assigned to each spawned projectile. Overrides the projectile scene speed.
@export var projectile_speed: float = 600.0

func _on_execute(user: CharacterBody2D, fire_direction: Vector2) -> void:
	if projectile_scene == null:
		push_error("RangedWeaponData: No projectile_scene assigned on %s" % weapon_name)
		return

	var projectile_instance := projectile_scene.instantiate() as Projectile
	if projectile_instance == null:
		push_error("RangedWeaponData: Instantiated scene is not of type Projectile.")
		return

	# Calculate spawn point respecting current facing direction
	var rotated_offset := Vector2(spawn_offset.x * fire_direction.x, spawn_offset.y)
	projectile_instance.global_position = user.global_position + rotated_offset
	projectile_instance.speed = projectile_speed
	projectile_instance.setup(fire_direction, damage, user)

	# Spawn projectile under the scene tree root to decouple movement from user
	user.get_tree().current_scene.add_child(projectile_instance)
