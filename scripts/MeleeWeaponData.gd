class_name MeleeWeaponData
extends WeaponData

## Radius of the melee hit circle in world pixels. Its center is placed half this distance ahead of the player.
@export var attack_range: float = 40.0
## Reserved setting; currently unused. Melee attacks use a circle query, so changing this does not restrict the hit arc.
@export var attack_arc_degrees: float = 90.0
## Physics layers that melee attacks can hit, including bodies and areas. Enable the layers used by damageable targets.
@export_flags_2d_physics var target_collision_mask: int = 1

func _on_execute(user: CharacterBody2D, fire_direction: Vector2) -> void:
	var space_state := user.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	
	# Construct a circle shape for sweeping the melee attack area
	var circle := CircleShape2D.new()
	circle.radius = attack_range
	
	query.shape = circle
	query.transform = Transform2D(0.0, user.global_position + (fire_direction * (attack_range * 0.5)))
	query.collision_mask = target_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	
	var results := space_state.intersect_shape(query, 16)
	for result in results:
		var collider: Object = result.get("collider")
		if collider and collider != user and collider.has_method("take_damage"):
			collider.take_damage(damage)
