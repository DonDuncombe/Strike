class_name PlayerController
extends CharacterBody2D

signal state_changed(old_state: String, new_state: String)
signal weapon_switched(weapon_index: int, weapon_data: WeaponData)
signal weapon_used(weapon_index: int, weapon_data: WeaponData)
signal ability_changed(ability: StringName, unlocked: bool)
signal stamina_changed(value: float)
signal stamina_exhausted()

enum PlayerState { IDLE, WALK, JUMP, FALL, DASH, WALL_SLIDE, WALL_HOLD, WALL_CLIMB, WALL_REPOSITION, LEDGE_HANG, LEDGE_CLIMB }

@export_category("Node References")
## Sprite used for facing and animation. Leave empty to use the AnimatedSprite2D child named AnimatedSprite2D.
@export var sprite: AnimatedSprite2D

@export_category("Movement Base")
## Horizontal speed in world pixels per second at full stamina. Increase for faster running.
@export var move_speed: float = 140.0
## Ground acceleration in pixels per second squared. Higher values reach running speed sooner.
@export var acceleration: float = 1200.0
## Ground deceleration in pixels per second squared when movement input is released. Increase for quicker stops.
@export var friction: float = 1600.0
## Horizontal acceleration in the air in pixels per second squared. Increase for stronger air control.
@export var air_acceleration: float = 800.0
## Horizontal deceleration in the air without input, in pixels per second squared. Lower values preserve momentum.
@export var air_resistance: float = 300.0

@export_category("Animation Travel")
## Source-image pixels traveled per 11-frame walk cycle. Increase to slow footsteps relative to movement; sprite scale is applied automatically.
@export_range(1.0, 2000.0, 1.0) var walk_cycle_distance: float = 200.0
## Source-image pixels traveled per 25-frame climb cycle. Increase to slow hand and foot cycling; sprite scale is applied automatically.
@export_range(1.0, 2000.0, 1.0) var climb_cycle_distance: float = 200.0

@export_category("Stamina")
## Starting stamina percentage, from 0 to 100. Runtime changes update the HUD; zero stamina releases wall and ledge grips.
@export_range(0.0, 100.0, 0.1) var stamina: float = 100.0:
	set(value):
		var previous: float = stamina
		stamina = clampf(value, 0.0, 100.0)
		if not is_equal_approx(previous, stamina):
			stamina_changed.emit(stamina)
			if previous > 0.0 and stamina == 0.0:
				stamina_exhausted.emit()
## Stamina percentage points consumed per second while holding, climbing or sliding on a wall. Set to 0 for free wall movement.
@export_range(0.0, 100.0, 0.1) var wall_stamina_drain: float = 5.0
## Stamina percentage points consumed per second of active dashing, not per dash. Set to 0 for free dashes.
@export_range(0.0, 100.0, 0.1) var dash_stamina_drain: float = 10.0
## Stamina percentage points restored per second while standing still on the floor. Set to 0 to disable recovery.
@export_range(0.0, 100.0, 0.1) var stamina_recovery: float = 8.0
## Movement speed fraction at zero stamina, interpolated up to 1 at full stamina. 0.5 means half speed; tired wall climbing has an additional multiplier.
@export_range(0.5, 1.0, 0.01) var exhausted_speed_multiplier: float = 0.5

@export_category("Jump & Gravity")
## Full-stamina jump height in world pixels. Increase for higher jumps; gravity and takeoff speed are recalculated whenever this changes.
@export var jump_height: float = 90.0:
	set(value):
		jump_height = value
		_recalculate_physics()
## Seconds to reach the jump peak while holding Jump. Shorter times make the ascent snappier.
@export_range(0.01, 2.0, 0.01, "or_greater") var time_to_peak: float = 0.35:
	set(value):
		time_to_peak = maxf(value, 0.01)
		_recalculate_physics()
## Seconds used to calculate falling gravity from Jump Height. Shorter times give faster falls and stronger jump-release gravity.
@export_range(0.01, 2.0, 0.01, "or_greater") var time_to_descent: float = 0.30:
	set(value):
		time_to_descent = maxf(value, 0.01)
		_recalculate_physics()
## Maximum downward speed in world pixels per second. Lower this to limit long-fall speed.
@export var max_fall_speed: float = 2500.0
## Total jumps including the ground jump. Use 2 for one air jump; air jumps also require Double Jump Unlocked.
@export_range(1, 5, 1, "or_greater") var max_jumps: int = 2

@export_category("Unlockable Abilities")
## Allow dashing at startup. Progression code can change this with set_ability_unlocked("dash", unlocked).
@export var dash_unlocked: bool = true
## Allow up to Max Jumps minus one air jumps. Progression code can change this with set_ability_unlocked("double_jump", unlocked).
@export var double_jump_unlocked: bool = true
## Allow wall holding, climbing and wall jumping. Progression code can change this with set_ability_unlocked("wall_climb", unlocked).
@export var wall_climb_unlocked: bool = true
## Allow ledge grabbing and pull-ups. Progression code can change this with set_ability_unlocked("ledge_hang", unlocked); locking releases the grip.
@export var ledge_hang_unlocked: bool = true

@export_category("Ledge Hanging")
## Hang sprite scale multiplier relative to its normal scale. Adjust to match the smaller hang artwork to the walk and climb character size; does not resize collisions.
@export var ledge_sprite_scale: float = 1.65
## Hand contact point in source-image pixels relative to the center of a hang frame. Adjust to align the visible hands with the ledge; X is mirrored when facing left.
@export var ledge_sprite_grip: Vector2 = Vector2(19.0, -48.0)
## Pull-up movement speed in world pixels per second before stamina scaling. Increase to climb onto a ledge faster.
@export_range(1.0, 400.0, 1.0) var ledge_pull_up_speed: float = 120.0
## Stamina percentage points consumed per second while hanging or pulling up. Set to 0 for unlimited hang time.
@export_range(0.0, 100.0, 0.1) var ledge_stamina_drain: float = 5.0
## Seconds after releasing a ledge before another grab is allowed. Increase to avoid immediately catching the same ledge when dropping.
@export_range(0.0, 1.0, 0.01) var ledge_regrab_delay: float = 0.25

@export_group("Ledge Raycasting")
## Horizontal ray reach in world pixels beyond the player collider edge. Increase to grab from farther away; rays use the player collision mask.
@export_range(1.0, 40.0, 0.5) var ledge_grab_reach: float = 12.0
## World-pixel distance above and below the hand height for the two side rays. The lower ray must hit a wall and the upper ray must be clear; increase for a larger grab window.
@export_range(1.0, 30.0, 0.5) var ledge_height_tolerance: float = 10.0
## Hand detection height in world pixels relative to the player origin. Negative values raise the rays. Also determines the body height while hanging.
@export var ledge_grip_offset: float = -24.0
## Distance in world pixels inside the wall hit where the downward top ray starts. Increase for slightly rounded edges; keep smaller than platform width.
@export_range(0.1, 20.0, 0.1) var ledge_top_probe_inset: float = 2.0
## Extra world pixels below the lower side ray searched by the downward top ray.
@export_range(0.1, 20.0, 0.1) var ledge_top_probe_extension: float = 1.0
## Maximum side surface angle from vertical in degrees. Increase to accept slanted or rounded sides; 0 requires a vertical wall.
@export_range(0.0, 45.0, 0.5) var ledge_wall_angle_tolerance: float = 8.0
## Maximum top surface angle from horizontal in degrees. Increase to accept gently sloped tops; 0 requires a flat top.
@export_range(0.0, 45.0, 0.5) var ledge_top_angle_tolerance: float = 8.0
## World-pixel gap between the player collider and the ledge during hanging and pull-up. Keep above the CharacterBody2D safe margin.
@export_range(0.1, 10.0, 0.1) var ledge_clearance: float = 1.0
## Downward ray length in world pixels used to confirm ground at the pull-up destination. Must exceed Ledge Clearance.
@export_range(0.1, 30.0, 0.1) var ledge_support_probe_depth: float = 3.0

@export_category("Juice & Assist Timers")
## Seconds after leaving the floor during which a ground jump is still allowed. Increase to make edge jumps more forgiving.
@export var coyote_time: float = 0.15
## Seconds an early Jump press is remembered before a jump becomes available. Increase to make landing jumps more forgiving.
@export var jump_buffer_time: float = 0.12

@export_category("Wall Movement")
## Intentional up/down wall movement speed in world pixels per second before stamina scaling. Increase for faster climbing and descending.
@export var wall_climb_speed: float = 80.0
## Wall-jump velocity in pixels per second before stamina scaling. X is the outward speed; use a negative Y to launch upward.
@export var wall_jump_impulse: Vector2 = Vector2(250, -500)
## Seconds after wall jumping or pushing off during which horizontal input and wall grabbing are suppressed. Increase to preserve the launch trajectory.
@export var wall_jump_control_lock: float = 0.15
## Maximum seconds between Away and Jump presses, in either order, to count as a wall jump. A push-off without a wall jump spends the remaining air jumps. Set to 0 to require simultaneous input.
@export_range(0.0, 0.5, 0.01, "or_greater") var wall_jump_input_grace: float = 0.4
## Seconds of upward-climb lock after reaching the opposite wall following a wall jump. Holding and descending remain available.
@export_range(0.0, 5.0, 0.05, "or_greater") var wall_reposition_duration: float = 1.0
## Push-off velocity in pixels per second before stamina scaling. X controls outward speed and Y downward speed; magnitudes are used.
@export var wall_drop_impulse: Vector2 = Vector2(180.0, 120.0)
## Stamina percentage below which holding slips and intentional climbing slows. Increase to make fatigue start earlier.
@export_range(0.0, 100.0, 0.1) var wall_low_stamina_threshold: float = 15.0
## Downward slipping speed in world pixels per second while holding with low stamina. Set to 0 to keep a stationary grip until exhausted.
@export_range(0.0, 100.0, 0.1) var wall_tired_slide_speed: float = 30.0
## Additional fraction of intentional wall speed below the low-stamina threshold. 0.15 gives 15 percent of the stamina-adjusted speed.
@export_range(0.0, 1.0, 0.01) var wall_tired_climb_multiplier: float = 0.15

@export_category("Dash Feature")
## Dash speed in world pixels per second at full stamina. Increase for longer travel at the same duration.
@export var dash_speed: float = 1500.0
## Seconds a dash lasts. Increase for longer dash travel and more stamina consumed.
@export var dash_duration: float = 0.2
## Minimum seconds between dash starts. Increase to reduce how often the player can dash.
@export var dash_cooldown: float = 0.6
## For horizontal dashes, keep the vertical speed from dash start. Disable to make horizontal dashes travel flat.
@export var dash_preserve_vertical: bool = true

@export_category("Weapons")
## Ordered weapon resources available to the player. The first slot starts active; each is copied at startup so cooldowns are per player.
@export var inventory: Array[WeaponData] = []

var gravity_jump: float
var gravity_fall: float
var initial_jump_velocity: float

var jumps_left: int
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var wall_jump_timer: float = 0.0
var wall_reposition_timer: float = 0.0
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.RIGHT
var active_weapon_index: int = 0
var cached_input_dir: float = 0.0
var cached_climb_input: float = 0.0
var ground_jump_available: bool = false
var is_climbing: bool = false
var dash_start_vertical_velocity: float = 0.0
var current_state: PlayerState = PlayerState.IDLE

var _wall_jump_origin_normal: float = 0.0
var _wall_jump_input_timer: float = 0.0
var _wall_away_input_timer: float = 0.0
var _wall_away_normal: float = 0.0

var _ledge_regrab_timer: float = 0.0
var _ledge_direction: float = 0.0
var _ledge_top: Vector2
var _ledge_body: Node2D
var _ledge_body_transform: Transform2D
var _ledge_waypoints: Array[Vector2] = []

var _animation_cycle: float = 0.0
var _animation_travel: Vector2 = Vector2.ZERO
var _hang_visual_active: bool = false
var _sprite_rest_scale: Vector2
var _sprite_rest_position: Vector2

var _state_transitions: Dictionary[PlayerState, Array] = {}

@onready var _collision_shape: CollisionShape2D = _find_collision_shape()

func _ready() -> void:
	if sprite == null:
		sprite = get_node_or_null(^"AnimatedSprite2D") as AnimatedSprite2D
	_recalculate_physics()
	jumps_left = _air_jumps_available()
	for index: int in range(inventory.size()):
		if inventory[index] != null:
			inventory[index] = inventory[index].duplicate() as WeaponData
	_init_state_machine()
	_update_animation()

func _find_collision_shape() -> CollisionShape2D:
	var named: CollisionShape2D = get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if named != null:
		return named
	for child: Node in get_children():
		if child is CollisionShape2D:
			return child as CollisionShape2D
	return null

func _recalculate_physics() -> void:
	gravity_jump = (2.0 * jump_height) / (time_to_peak * time_to_peak)
	gravity_fall = (2.0 * jump_height) / (time_to_descent * time_to_descent)
	initial_jump_velocity = -((2.0 * jump_height) / time_to_peak)

# Call this from pickups or progression code; the exported flags set starting abilities.
func set_ability_unlocked(ability: StringName, unlocked: bool = true) -> void:
	match ability:
		&"ledge_hang":
			if ledge_hang_unlocked == unlocked:
				return
			ledge_hang_unlocked = unlocked
			if not unlocked and _is_on_ledge():
				_release_ledge()
		&"dash":
			if dash_unlocked == unlocked:
				return
			dash_unlocked = unlocked
			if not unlocked:
				is_dashing = false
				dash_timer = 0.0
		&"double_jump":
			if double_jump_unlocked == unlocked:
				return
			double_jump_unlocked = unlocked
			jumps_left = mini(jumps_left, _air_jumps_available())
			if unlocked and is_on_floor():
				jumps_left = _air_jumps_available()
		&"wall_climb":
			if wall_climb_unlocked == unlocked:
				return
			wall_climb_unlocked = unlocked
			if not unlocked:
				is_climbing = false
		_:
			push_warning("Unknown player ability: %s" % ability)
			return
	ability_changed.emit(ability, unlocked)

func _air_jumps_available() -> int:
	return maxi(0, max_jumps - 1) if double_jump_unlocked else 0

func get_stamina_speed_multiplier() -> float:
	return lerpf(exhausted_speed_multiplier, 1.0, stamina / 100.0)

func _recover_stamina(delta: float) -> void:
	if is_on_floor() and cached_input_dir == 0.0 and velocity.is_zero_approx() and not is_dashing:
		stamina += maxf(0.0, stamina_recovery) * delta

# Wall and ledge states are resolved directly in _process_state_transitions and the ledge handlers.
func _init_state_machine() -> void:
	_state_transitions = {
		PlayerState.IDLE: [
			{"target": PlayerState.DASH, "condition": _cond_is_dashing},
			{"target": PlayerState.WALL_SLIDE, "condition": _cond_is_wall_sliding},
			{"target": PlayerState.JUMP, "condition": _cond_is_jumping},
			{"target": PlayerState.FALL, "condition": _cond_is_falling},
			{"target": PlayerState.WALK, "condition": _cond_is_walking}
		],
		PlayerState.WALK: [
			{"target": PlayerState.DASH, "condition": _cond_is_dashing},
			{"target": PlayerState.WALL_SLIDE, "condition": _cond_is_wall_sliding},
			{"target": PlayerState.JUMP, "condition": _cond_is_jumping},
			{"target": PlayerState.FALL, "condition": _cond_is_falling},
			{"target": PlayerState.IDLE, "condition": _cond_is_idle}
		],
		PlayerState.JUMP: [
			{"target": PlayerState.DASH, "condition": _cond_is_dashing},
			{"target": PlayerState.WALL_SLIDE, "condition": _cond_is_wall_sliding},
			{"target": PlayerState.FALL, "condition": _cond_is_falling},
			{"target": PlayerState.WALK, "condition": _cond_is_grounded_walking},
			{"target": PlayerState.IDLE, "condition": _cond_is_idle}
		],
		PlayerState.FALL: [
			{"target": PlayerState.DASH, "condition": _cond_is_dashing},
			{"target": PlayerState.WALL_SLIDE, "condition": _cond_is_wall_sliding},
			{"target": PlayerState.JUMP, "condition": _cond_is_jumping},
			{"target": PlayerState.WALK, "condition": _cond_is_grounded_walking},
			{"target": PlayerState.IDLE, "condition": _cond_is_idle}
		],
		PlayerState.DASH: [
			{"target": PlayerState.WALL_SLIDE, "condition": _cond_dash_ended_wall_slide},
			{"target": PlayerState.JUMP, "condition": _cond_dash_ended_jumping},
			{"target": PlayerState.FALL, "condition": _cond_dash_ended_falling},
			{"target": PlayerState.WALK, "condition": _cond_dash_ended_walking},
			{"target": PlayerState.IDLE, "condition": _cond_dash_ended_idle}
		],
		PlayerState.WALL_SLIDE: [
			{"target": PlayerState.DASH, "condition": _cond_is_dashing},
			{"target": PlayerState.JUMP, "condition": _cond_is_jumping},
			{"target": PlayerState.FALL, "condition": _cond_not_wall_sliding},
			{"target": PlayerState.WALK, "condition": _cond_is_grounded_walking},
			{"target": PlayerState.IDLE, "condition": _cond_is_idle}
		]
	}

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_weapon_cooldowns(delta)
	_handle_weapon_input()

	cached_input_dir = Input.get_axis("move_left", "move_right")
	cached_climb_input = Input.get_axis("move_up", "move_down")
	if _is_on_ledge():
		_process_ledge(delta)
		_update_animation()
		return
	if _try_grab_ledge():
		_update_animation()
		return

	if not is_dashing:
		_handle_ground_state()
		_handle_dash_input()
	if is_dashing:
		_dash_physics_step(delta)
		return
	var jump_pressed: bool = Input.is_action_just_pressed("move_jump")
	if jump_pressed:
		jump_buffer_timer = jump_buffer_time
		if wall_climb_unlocked and stamina > 0.0 and is_on_wall_only() and _wall_is_tall_enough():
			_wall_jump_input_timer = maxf(0.0, wall_jump_input_grace)
	# Upgrade a recent downward push-off to a wall jump, even after losing contact.
	var late_wall_jump: bool = (
		jump_pressed and _wall_away_input_timer > 0.0
		and wall_climb_unlocked and stamina > 0.0 and not is_on_floor()
		and cached_input_dir * _wall_away_normal >= 0.0 and cached_climb_input <= 0.0
	)
	if late_wall_jump:
		_execute_wall_jump(_wall_away_normal)
	_apply_horizontal_movement(cached_input_dir, delta)
	if not late_wall_jump and not _handle_wall_interactions(cached_input_dir, cached_climb_input, delta):
		_handle_jump()
	_apply_gravity(delta)

	_resolve_facing(cached_input_dir)

	_move_with_animation_travel()
	_recover_stamina(delta)
	_process_state_transitions()
	_update_animation()

func _dash_physics_step(delta: float) -> void:
	_process_dash(delta)
	_update_sprite_facing(dash_direction.x)
	_move_with_animation_travel()
	_process_state_transitions()
	_update_animation()

func _is_on_ledge() -> bool:
	return current_state in [PlayerState.LEDGE_HANG, PlayerState.LEDGE_CLIMB]

# Collider bounds relative to the player origin, used by ledge and wall-height probes.
func _body_bounds() -> Rect2:
	if _collision_shape == null or _collision_shape.shape == null or _collision_shape.disabled:
		return Rect2()
	var bounds: Rect2 = _collision_shape.global_transform * _collision_shape.shape.get_rect()
	bounds.position -= global_position
	return bounds

func _ledge_ray(from: Vector2, to: Vector2) -> Dictionary:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, collision_mask, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query)

func _ledge_surface_is_grabbable(hit: Dictionary) -> bool:
	if hit.is_empty():
		return false
	var body: Node2D = hit.collider as Node2D
	if body is StaticBody2D:
		var solid: StaticBody2D = body as StaticBody2D
		if solid is AnimatableBody2D or solid.constant_linear_velocity != Vector2.ZERO or solid.constant_angular_velocity != 0.0:
			return false
		return not solid.is_shape_owner_one_way_collision_enabled(solid.shape_find_owner(int(hit.shape)))
	if body is TileMapLayer:
		var tiles: TileMapLayer = body as TileMapLayer
		if tiles.use_kinematic_bodies or tiles.tile_set == null:
			return false
		# Sample just inside the surface. A body RID identifies a quadrant, not an individual tile.
		var point: Vector2 = hit.position
		var normal: Vector2 = hit.normal
		var cell: Vector2i = tiles.local_to_map(tiles.to_local(point - normal * 0.1))
		var data: TileData = tiles.get_cell_tile_data(cell)
		if data == null:
			return false
		var has_solid_polygon: bool = false
		for layer: int in range(tiles.tile_set.get_physics_layers_count()):
			if (tiles.tile_set.get_physics_layer_collision_layer(layer) & collision_mask) == 0:
				continue
			if data.get_constant_linear_velocity(layer) != Vector2.ZERO or data.get_constant_angular_velocity(layer) != 0.0:
				return false
			for polygon: int in range(data.get_collision_polygons_count(layer)):
				if data.is_collision_polygon_one_way(layer, polygon):
					return false
				has_solid_polygon = true
		return has_solid_polygon
	return false

func _ledge_path_clear(from: Vector2, to: Vector2) -> bool:
	var pose: Transform2D = global_transform
	pose.origin = from
	if test_move(pose, to - from):
		return false
	pose.origin = to
	return not test_move(pose, Vector2.ZERO, null, safe_margin, true)

func _try_grab_ledge() -> bool:
	if not ledge_hang_unlocked or stamina <= 0.0 or is_dashing or is_on_floor():
		return false
	if _ledge_regrab_timer > 0.0 or wall_jump_timer > 0.0 or Input.is_action_pressed("move_down"):
		return false
	if velocity.y < 0.0 and not is_climbing:
		return false
	var direction: float = cached_input_dir
	if is_climbing and is_on_wall_only():
		direction = -get_wall_normal().x
	if is_zero_approx(direction):
		return false
	direction = signf(direction)
	var bounds: Rect2 = _body_bounds()
	if bounds.size == Vector2.ZERO:
		return false
	var side: float = bounds.end.x if direction > 0.0 else bounds.position.x
	var hand: Vector2 = global_position + Vector2(bounds.get_center().x, ledge_grip_offset)
	var reach: float = absf(side - bounds.get_center().x) + ledge_grab_reach
	var lower: Vector2 = hand + Vector2(0.0, ledge_height_tolerance)
	var upper: Vector2 = hand - Vector2(0.0, ledge_height_tolerance)
	var wall: Dictionary = _ledge_ray(lower, lower + Vector2(direction * reach, 0.0))
	if wall.is_empty() or not _ledge_ray(upper, upper + Vector2(direction * reach, 0.0)).is_empty():
		return false
	var normal: Vector2 = wall.normal
	if normal.dot(Vector2(-direction, 0.0)) < cos(deg_to_rad(ledge_wall_angle_tolerance)):
		return false
	if not _ledge_surface_is_grabbable(wall):
		return false
	var body: Node2D = wall.collider as Node2D
	var probe: Vector2 = Vector2(wall.position.x + direction * ledge_top_probe_inset, upper.y)
	var top: Dictionary = _ledge_ray(probe, Vector2(probe.x, lower.y + ledge_top_probe_extension))
	if top.is_empty() or top.collider != body:
		return false
	var top_normal: Vector2 = top.normal
	if top_normal.dot(Vector2.UP) < cos(deg_to_rad(ledge_top_angle_tolerance)):
		return false
	if not _ledge_surface_is_grabbable(top):
		return false
	var corner: Vector2 = Vector2(wall.position.x, top.position.y)
	var target: Vector2 = Vector2(corner.x - side - direction * ledge_clearance, corner.y - ledge_grip_offset)
	if not _ledge_path_clear(global_position, target):
		return false
	global_position = target
	_ledge_top = corner
	_ledge_direction = direction
	_ledge_body = body
	_ledge_body_transform = body.global_transform
	velocity = Vector2.ZERO
	is_climbing = false
	ground_jump_available = false
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	_clear_wall_jump_inputs()
	_animation_travel = Vector2.ZERO
	_update_sprite_facing(direction)
	_transition_to_state(PlayerState.LEDGE_HANG)
	return true

func _release_ledge() -> void:
	_ledge_regrab_timer = ledge_regrab_delay
	_ledge_waypoints.clear()
	_ledge_body = null
	velocity = Vector2.ZERO
	_transition_to_state(PlayerState.FALL)

func _begin_ledge_climb() -> void:
	var bounds: Rect2 = _body_bounds()
	var raised: Vector2 = Vector2(global_position.x, _ledge_top.y - bounds.end.y - ledge_clearance)
	var inner_side: float = bounds.position.x if _ledge_direction > 0.0 else bounds.end.x
	var standing: Vector2 = Vector2(_ledge_top.x - inner_side + _ledge_direction * ledge_clearance, raised.y)
	if not _ledge_path_clear(global_position, raised) or not _ledge_path_clear(raised, standing):
		return
	# Confirm the destination is supported, including on narrow platforms.
	var foot: Vector2 = standing + Vector2(bounds.get_center().x, bounds.end.y)
	var support: Dictionary = _ledge_ray(foot, foot + Vector2(0.0, ledge_support_probe_depth))
	if support.is_empty() or support.collider != _ledge_body or not _ledge_surface_is_grabbable(support):
		return
	_ledge_waypoints.assign([raised, standing])
	_transition_to_state(PlayerState.LEDGE_CLIMB)

func _process_ledge(delta: float) -> void:
	_animation_travel = Vector2.ZERO
	if not ledge_hang_unlocked or not is_instance_valid(_ledge_body):
		_release_ledge()
		return
	if _ledge_body.global_transform != _ledge_body_transform:
		_release_ledge()
		return
	stamina -= maxf(0.0, ledge_stamina_drain) * delta
	if stamina <= 0.0 or Input.is_action_pressed("move_down") or cached_input_dir * _ledge_direction < 0.0:
		var jump_away: bool = stamina > 0.0 and Input.is_action_just_pressed("move_jump") and not Input.is_action_pressed("move_down")
		_release_ledge()
		if jump_away:
			_execute_wall_jump(-_ledge_direction)
		return
	if Input.is_action_just_pressed("move_jump"):
		_release_ledge()
		_execute_wall_jump(-_ledge_direction)
		return
	_handle_dash_input()
	if is_dashing:
		_release_ledge()
		_transition_to_state(PlayerState.DASH)
		return
	if current_state == PlayerState.LEDGE_HANG:
		if Input.is_action_just_pressed("move_up"):
			_begin_ledge_climb()
		return
	var destination: Vector2 = global_position.move_toward(_ledge_waypoints[0], ledge_pull_up_speed * get_stamina_speed_multiplier() * delta)
	if not _ledge_path_clear(global_position, destination):
		_release_ledge()
		return
	_animation_travel = destination - global_position
	global_position = destination
	if global_position.is_equal_approx(_ledge_waypoints[0]):
		_ledge_waypoints.pop_front()
		if _ledge_waypoints.is_empty():
			_release_ledge()

func _process_state_transitions() -> void:
	if is_climbing and is_on_wall_only() and not is_dashing:
		if wall_reposition_timer > 0.0:
			_transition_to_state(PlayerState.WALL_REPOSITION)
		elif velocity.y < 0.0:
			_transition_to_state(PlayerState.WALL_CLIMB)
		elif velocity.y > 0.0:
			_transition_to_state(PlayerState.WALL_SLIDE)
		else:
			_transition_to_state(PlayerState.WALL_HOLD)
		return
	if current_state in [PlayerState.WALL_HOLD, PlayerState.WALL_CLIMB, PlayerState.WALL_REPOSITION]:
		if is_dashing:
			_transition_to_state(PlayerState.DASH)
		elif is_on_floor():
			_transition_to_state(PlayerState.WALK if absf(velocity.x) > 0.0 else PlayerState.IDLE)
		else:
			_transition_to_state(PlayerState.JUMP if velocity.y < 0.0 else PlayerState.FALL)
		return
	if not _state_transitions.has(current_state):
		return

	for transition: Dictionary in _state_transitions[current_state]:
		var condition: Callable = transition["condition"]
		if condition.call():
			_transition_to_state(transition["target"])
			break

func _transition_to_state(new_state: PlayerState) -> void:
	if current_state == new_state:
		return
	var old_state: PlayerState = current_state
	current_state = new_state
	state_changed.emit(PlayerState.keys()[old_state], PlayerState.keys()[new_state])

# --- State Transition Condition Evaluators ---

func _cond_is_dashing() -> bool:
	return is_dashing

func _cond_is_wall_sliding() -> bool:
	return is_climbing and is_on_wall_only() and velocity.y > 0.0

func _cond_not_wall_sliding() -> bool:
	return not _cond_is_wall_sliding()

func _cond_is_jumping() -> bool:
	return not is_on_floor() and velocity.y < 0.0 and not is_dashing

func _cond_is_falling() -> bool:
	return not is_on_floor() and velocity.y >= 0.0 and not is_dashing

func _cond_is_walking() -> bool:
	return is_on_floor() and (cached_input_dir != 0.0 or velocity.x != 0.0)

func _cond_is_grounded_walking() -> bool:
	return is_on_floor() and cached_input_dir != 0.0

func _cond_is_idle() -> bool:
	return is_on_floor() and cached_input_dir == 0.0 and velocity.x == 0.0

func _cond_dash_ended_idle() -> bool:
	return not is_dashing and is_on_floor() and cached_input_dir == 0.0

func _cond_dash_ended_walking() -> bool:
	return not is_dashing and is_on_floor() and cached_input_dir != 0.0

func _cond_dash_ended_jumping() -> bool:
	return not is_dashing and not is_on_floor() and velocity.y < 0.0

func _cond_dash_ended_falling() -> bool:
	return not is_dashing and not is_on_floor() and velocity.y >= 0.0

func _cond_dash_ended_wall_slide() -> bool:
	return not is_dashing and _cond_is_wall_sliding()

# --- Physics & Core Handlers ---

func _resolve_facing(input_dir: float) -> void:
	if is_climbing and is_on_wall_only():
		_update_sprite_facing(-get_wall_normal().x)
	elif wall_jump_timer > 0.0:
		_update_sprite_facing(velocity.x)
	elif input_dir != 0.0:
		_update_sprite_facing(input_dir)

func _update_sprite_facing(facing_dir: float) -> void:
	if sprite != null and facing_dir != 0.0:
		sprite.flip_h = facing_dir < 0.0

## Returns 1.0 when the player faces right and -1.0 when facing left.
func get_facing_direction() -> float:
	if sprite == null:
		return 1.0 if velocity.x >= 0.0 else -1.0
	return -1.0 if sprite.flip_h else 1.0

# Capture only this physics move, excluding teleports between ticks.
func _move_with_animation_travel() -> void:
	var before_move: Vector2 = global_position
	move_and_slide()
	_animation_travel = global_position - before_move

# Locomotion is distance-driven: FPS and speed_scale do not control its cadence.
func _update_animation() -> void:
	var travel: Vector2 = _animation_travel
	_animation_travel = Vector2.ZERO
	if sprite == null:
		return
	if current_state == PlayerState.LEDGE_HANG:
		if not _hang_visual_active:
			_sprite_rest_scale = sprite.scale
			_sprite_rest_position = sprite.position
			_hang_visual_active = true
		sprite.scale = _sprite_rest_scale * ledge_sprite_scale
		var grip: Vector2 = ledge_sprite_grip
		if sprite.flip_h:
			grip.x = -grip.x
		sprite.position = to_local(_ledge_top) - sprite.transform.basis_xform(grip)
	elif _hang_visual_active:
		sprite.scale = _sprite_rest_scale
		sprite.position = _sprite_rest_position
		_hang_visual_active = false
	var animation_name: StringName = &"idle"
	var cycle_advance: float = 0.0
	var distance_driven: bool = false
	match current_state:
		PlayerState.LEDGE_HANG:
			animation_name = &"hang"
		PlayerState.LEDGE_CLIMB:
			animation_name = &"climb"
			distance_driven = true
			cycle_advance = travel.length() / maxf(climb_cycle_distance * sprite.global_transform.y.length(), 0.001)
		PlayerState.WALK:
			animation_name = &"walk"
			distance_driven = true
			var cycle_distance: float = walk_cycle_distance * sprite.global_transform.x.length()
			if absf(travel.x) > 0.001:
				cycle_advance = absf(travel.x) / maxf(cycle_distance, 0.001)
		PlayerState.JUMP:
			animation_name = &"jump"
		PlayerState.FALL:
			animation_name = &"fall"
		PlayerState.DASH:
			animation_name = &"dash"
		PlayerState.WALL_CLIMB, PlayerState.WALL_SLIDE, PlayerState.WALL_HOLD, PlayerState.WALL_REPOSITION:
			animation_name = &"climb"
			distance_driven = true
			var cycle_distance: float = climb_cycle_distance * sprite.global_transform.y.length()
			# Tired slipping keeps the grip pose; intentional descent reverses the cycle.
			if is_climbing and cached_climb_input != 0.0 and absf(travel.y) > 0.001:
				cycle_advance = -travel.y / maxf(cycle_distance, 0.001)
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_name):
		return
	if sprite.animation != animation_name:
		_animation_cycle = 0.0
		sprite.animation = animation_name
	if distance_driven:
		sprite.pause()
		_animation_cycle = fposmod(_animation_cycle + cycle_advance, 1.0)
		_set_locomotion_frame(sprite)
	else:
		sprite.play(animation_name)

func _set_locomotion_frame(animated_sprite: AnimatedSprite2D) -> void:
	var frames: SpriteFrames = animated_sprite.sprite_frames
	var animation_name: StringName = animated_sprite.animation
	var frame_count: int = frames.get_frame_count(animation_name)
	var total_duration: float = 0.0
	for index: int in range(frame_count):
		total_duration += frames.get_frame_duration(animation_name, index)
	var remaining: float = _animation_cycle * total_duration
	for index: int in range(frame_count):
		var duration: float = frames.get_frame_duration(animation_name, index)
		if remaining < duration or index == frame_count - 1:
			animated_sprite.set_frame_and_progress(index, remaining / maxf(duration, 0.001))
			return
		remaining -= duration

func _update_timers(delta: float) -> void:
	coyote_timer = maxf(0.0, coyote_timer - delta)
	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)
	wall_jump_timer = maxf(0.0, wall_jump_timer - delta)
	wall_reposition_timer = maxf(0.0, wall_reposition_timer - delta)
	_wall_jump_input_timer = maxf(0.0, _wall_jump_input_timer - delta)
	_wall_away_input_timer = maxf(0.0, _wall_away_input_timer - delta)
	_ledge_regrab_timer = maxf(0.0, _ledge_regrab_timer - delta)

func _update_weapon_cooldowns(delta: float) -> void:
	for weapon: WeaponData in inventory:
		if weapon != null:
			weapon.update(delta)

func _handle_ground_state() -> void:
	if is_on_floor():
		_clear_wall_jump_inputs()
		_wall_jump_origin_normal = 0.0
		wall_reposition_timer = 0.0
		coyote_timer = coyote_time
		ground_jump_available = true
		jumps_left = _air_jumps_available()
		is_climbing = false

func _apply_gravity(delta: float) -> void:
	if not is_on_floor() and not is_dashing and not is_climbing:
		var current_gravity: float = gravity_jump
		if velocity.y > 0.0 or not Input.is_action_pressed("move_jump"):
			current_gravity = gravity_fall
		velocity.y += current_gravity * delta
		velocity.y = minf(velocity.y, max_fall_speed)

func _apply_horizontal_movement(input_dir: float, delta: float) -> void:
	if wall_jump_timer > 0.0:
		return

	var accel: float = acceleration if is_on_floor() else air_acceleration
	var deccel: float = friction if is_on_floor() else air_resistance

	if input_dir != 0.0:
		velocity.x = move_toward(velocity.x, input_dir * move_speed * get_stamina_speed_multiplier(), accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deccel * delta)

func _handle_jump() -> void:
	if jump_buffer_timer > 0.0:
		if ground_jump_available and coyote_timer > 0.0:
			_execute_jump(false)
		elif jumps_left > 0:
			_execute_jump(true)

func _execute_jump(uses_air_jump: bool) -> void:
	_clear_wall_jump_inputs()
	velocity.y = initial_jump_velocity * get_stamina_speed_multiplier()
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	ground_jump_available = false
	is_climbing = false
	if uses_air_jump:
		jumps_left -= 1

func _clear_wall_jump_inputs() -> void:
	_wall_jump_input_timer = 0.0
	_wall_away_input_timer = 0.0
	_wall_away_normal = 0.0

func _execute_wall_jump(saved_normal: float = 0.0) -> void:
	var wall_normal: float = saved_normal if saved_normal != 0.0 else get_wall_normal().x
	_clear_wall_jump_inputs()
	_wall_jump_origin_normal = wall_normal
	wall_reposition_timer = 0.0
	velocity.x = wall_normal * wall_jump_impulse.x * get_stamina_speed_multiplier()
	velocity.y = wall_jump_impulse.y * get_stamina_speed_multiplier()
	jump_buffer_timer = 0.0
	wall_jump_timer = wall_jump_control_lock
	jumps_left = _air_jumps_available()
	coyote_timer = 0.0
	ground_jump_available = false
	is_climbing = false

# Returns the first hit on collider, skipping other bodies that would hide the contacted wall's top.
func _wall_height_ray(from: Vector2, to: Vector2, collider: Object) -> Dictionary:
	var excluded: Array[RID] = [get_rid()]
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, collision_mask, excluded)
	query.hit_from_inside = true
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	while not hit.is_empty() and hit.collider != collider:
		excluded.append(hit.rid)
		query.exclude = excluded
		hit = get_world_2d().direct_space_state.intersect_ray(query)
	return hit

func _wall_is_tall_enough() -> bool:
	var bounds: Rect2 = _body_bounds()
	var height: float = bounds.size.y
	if height <= 0.0:
		return false
	var feet_y: float = global_position.y + bounds.end.y
	for index: int in range(get_slide_collision_count()):
		var contact: KinematicCollision2D = get_slide_collision(index)
		var normal: Vector2 = contact.get_normal()
		if absf(normal.x) < 0.9:
			continue
		# Only the wall above the current feet plane counts. Start at head height;
		# an inside hit means the wall reaches at least one character height above it.
		var inside: Vector2 = contact.get_position() - normal * 0.1
		var start: Vector2 = Vector2(inside.x, feet_y - height - 0.001)
		var top: Dictionary = _wall_height_ray(start, inside, contact.get_collider())
		if top.is_empty():
			continue
		var top_position: Vector2 = top.position
		if feet_y - top_position.y >= height - 0.001:
			return true
	return false

func _handle_wall_interactions(input_dir: float, climb_input: float, delta: float) -> bool:
	var was_climbing: bool = is_climbing
	is_climbing = false
	if not wall_climb_unlocked or not is_on_wall_only() or wall_jump_timer > 0.0:
		return false
	if not _wall_is_tall_enough():
		_clear_wall_jump_inputs()
		return false
	if stamina <= 0.0:
		if was_climbing:
			velocity.y = maxf(0.0, velocity.y)
		return true
	var wall_normal: float = get_wall_normal().x
	if _wall_jump_origin_normal * wall_normal < 0.0:
		# Start on arrival, not takeoff; allow holding/sliding but block upward climbing.
		wall_reposition_timer = maxf(0.0, wall_reposition_duration)
		_wall_jump_origin_normal = 0.0
	# Normals point away from either wall: positive product means away input.
	if input_dir * wall_normal > 0.0:
		if _wall_jump_input_timer > 0.0 or Input.is_action_just_pressed("move_jump"):
			_execute_wall_jump()
		else:
			_push_off_wall()
		return true
	var holding: bool = input_dir * wall_normal < 0.0
	var climbing: bool = climb_input != 0.0
	if not was_climbing and not holding and not climbing:
		return false
	stamina -= maxf(0.0, wall_stamina_drain) * delta
	if stamina <= 0.0:
		velocity.y = maxf(0.0, velocity.y)
		return true
	is_climbing = true
	var tired: bool = stamina < wall_low_stamina_threshold
	if climbing and (climb_input > 0.0 or wall_reposition_timer <= 0.0):
		velocity.y = climb_input * wall_climb_speed * get_stamina_speed_multiplier()
		if tired:
			velocity.y *= clampf(wall_tired_climb_multiplier, 0.0, 1.0)
	else:
		velocity.y = maxf(0.0, wall_tired_slide_speed) if tired else 0.0
	# Push into the surface to retain collision contact while holding or climbing.
	velocity.x = -wall_normal * move_speed * get_stamina_speed_multiplier()
	return true

# A downward push-off spends the remaining air jumps; a Jump press within the grace window
# upgrades it to a wall jump, which refills them.
func _push_off_wall() -> void:
	_clear_wall_jump_inputs()
	var wall_normal: float = get_wall_normal().x
	_wall_away_normal = wall_normal
	_wall_away_input_timer = maxf(0.0, wall_jump_input_grace)
	velocity.x = wall_normal * absf(wall_drop_impulse.x) * get_stamina_speed_multiplier()
	velocity.y = maxf(velocity.y, absf(wall_drop_impulse.y) * get_stamina_speed_multiplier())
	wall_jump_timer = wall_jump_control_lock
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	ground_jump_available = false
	jumps_left = 0
	is_climbing = false

func _handle_dash_input() -> void:
	if dash_unlocked and Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and not is_dashing:
		var raw_dir: Vector2 = Vector2(cached_input_dir, cached_climb_input)
		if raw_dir != Vector2.ZERO:
			dash_direction = raw_dir.normalized()
		else:
			dash_direction = Vector2(get_facing_direction(), 0.0)

		is_dashing = true
		_clear_wall_jump_inputs()
		dash_start_vertical_velocity = velocity.y
		dash_timer = dash_duration
		dash_cooldown_timer = dash_cooldown

func _process_dash(delta: float) -> void:
	is_climbing = false
	stamina -= maxf(0.0, dash_stamina_drain) * minf(delta, maxf(0.0, dash_timer))
	dash_timer -= delta
	velocity = dash_direction * dash_speed * get_stamina_speed_multiplier()

	if dash_preserve_vertical and is_zero_approx(dash_direction.y):
		velocity.y = dash_start_vertical_velocity

	if dash_timer <= 0.0:
		is_dashing = false

func _handle_weapon_input() -> void:
	if inventory.is_empty():
		return

	if Input.is_action_just_pressed("next_weapon"):
		_select_weapon(active_weapon_index + 1)
	elif Input.is_action_just_pressed("prev_weapon"):
		_select_weapon(active_weapon_index - 1)

	if Input.is_action_just_pressed("attack"):
		_use_weapon()

## Adds a copy of weapon to the inventory so its cooldown is per player. Returns the new slot index.
func add_weapon(weapon: WeaponData, equip: bool = true) -> int:
	inventory.append(weapon.duplicate() as WeaponData)
	var index: int = inventory.size() - 1
	# The first weapon is always active, so announce it even without equip.
	if equip or index == 0:
		_select_weapon(index)
	return index

func _select_weapon(index: int) -> void:
	active_weapon_index = posmod(index, inventory.size())
	weapon_switched.emit(active_weapon_index, inventory[active_weapon_index])

func _use_weapon() -> void:
	if active_weapon_index >= inventory.size():
		return
	var current_weapon: WeaponData = inventory[active_weapon_index]
	if current_weapon != null and current_weapon.execute(self, Vector2(get_facing_direction(), 0.0)):
		weapon_used.emit(active_weapon_index, current_weapon)
