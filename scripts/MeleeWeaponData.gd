class_name MeleeWeaponData
extends WeaponData

## Radius of the melee hit circle in world pixels. Its center is placed half this distance ahead of the player.
@export var attack_range: float = 40.0
## Physics layers that melee attacks can hit, including bodies and areas. Enable the layers used by damageable targets.
@export_flags_2d_physics var target_collision_mask: int = 1

func _on_execute(user: CharacterBody2D, fire_direction: Vector2) -> void:
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = attack_range

	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, user.global_position + fire_direction * (attack_range * 0.5))
	query.collision_mask = target_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [user.get_rid()]

	# Results are per shape, so a target with several shapes must only be damaged once.
	var damaged: Array[Object] = []
	for result: Dictionary in user.get_world_2d().direct_space_state.intersect_shape(query, 16):
		var collider: Object = result.collider
		if collider == null or collider in damaged or not collider.has_method("take_damage"):
			continue
		damaged.append(collider)
		collider.take_damage(damage)
