class_name PlayerController
extends CharacterBody2D

signal state_changed(old_state: String, new_state: String)
signal weapon_switched(weapon_index: int, weapon_data: WeaponData)
signal weapon_used(weapon_index: int, weapon_data: WeaponData)
signal ability_changed(ability: StringName, unlocked: bool)
signal stamina_changed(value: float)
signal stamina_exhausted()

enum PlayerState { IDLE, RUN, JUMP, FALL, DASH, WALL_SLIDE, WALL_HOLD, WALL_CLIMB, WALL_REPOSITION }

@export_category("Node References")
@export var sprite: Node2D

@export_category("Movement Base")
@export var move_speed: float = 200.0
@export var acceleration: float = 1200.0
@export var friction: float = 1600.0
@export var air_acceleration: float = 800.0
@export var air_resistance: float = 300.0

@export_category("Stamina")
## Stamina percentage. Also sets the starting stamina in the Inspector.
@export_range(0.0, 100.0, 0.1) var stamina: float = 100.0:
	set(value):
		var previous: float = stamina
		stamina = clampf(value, 0.0, 100.0)
		if not is_equal_approx(previous, stamina):
			stamina_changed.emit(stamina)
			if previous > 0.0 and stamina == 0.0:
				stamina_exhausted.emit()
## Percentage points consumed or restored per second.
@export_range(0.0, 100.0, 0.1) var wall_stamina_drain: float = 5.0
@export_range(0.0, 100.0, 0.1) var dash_stamina_drain: float = 10.0
@export_range(0.0, 100.0, 0.1) var stamina_recovery: float = 8.0
## General movement slows by at most half; low-stamina climbing has its own limit.
@export_range(0.5, 1.0, 0.01) var exhausted_speed_multiplier: float = 0.5

@export_category("Jump & Gravity")
@export var jump_height: float = 120.0
@export var time_to_peak: float = 0.35
@export var time_to_descent: float = 0.30
@export var max_fall_speed: float = 400.0
@export var max_jumps: int = 2

@export_category("Unlockable Abilities")
@export var dash_unlocked: bool = false
@export var double_jump_unlocked: bool = false
@export var wall_climb_unlocked: bool = false

@export_category("Juice & Assist Timers")
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.12

@export_category("Wall Movement")
@export var wall_slide_speed: float = 60.0
@export var wall_climb_speed: float = 120.0
@export var wall_jump_impulse: Vector2 = Vector2(250.0, -320.0)
@export var wall_jump_control_lock: float = 0.15
## Maximum separation between away and jump presses, in either order (seconds).
@export_range(0.0, 0.5, 0.01, "or_greater") var wall_jump_input_grace: float = 0.2
## Time spent repositioning after reaching the opposite wall following a wall jump.
@export_range(0.0, 5.0, 0.05, "or_greater") var wall_reposition_duration: float = 1.0
@export var wall_drop_impulse: Vector2 = Vector2(180.0, 120.0)
@export_range(0.0, 100.0, 0.1) var wall_low_stamina_threshold: float = 10.0
@export_range(0.0, 100.0, 0.1) var wall_tired_slide_speed: float = 20.0
@export_range(0.0, 1.0, 0.01) var wall_tired_climb_multiplier: float = 0.15

@export_category("Dash Feature")
@export var dash_speed: float = 450.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.6
@export var dash_preserve_vertical: bool = true

@export_category("Weapons")
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
var _wall_jump_origin_normal: float = 0.0
var _wall_jump_input_timer: float = 0.0
var _wall_away_input_timer: float = 0.0
var _wall_away_normal: float = 0.0
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.RIGHT
var active_weapon_index: int = 0
var cached_input_dir: float = 0.0
var ground_jump_available: bool = false
var is_climbing: bool = false
var dash_start_vertical_velocity: float = 0.0

var current_state: PlayerState = PlayerState.IDLE
var _state_transitions: Dictionary = {}

func _ready() -> void:
	_recalculate_physics()
	jumps_left = _air_jumps_available()
	_setup_sprite_reference()
	_init_state_machine()
	_update_animation()

func _setup_sprite_reference() -> void:
	if sprite != null:
		return
		
	if has_node("Sprite2D"):
		sprite = get_node("Sprite2D") as Node2D
	elif has_node("AnimatedSprite2D"):
		sprite = get_node("AnimatedSprite2D") as Node2D
	else:
		for child in get_children():
			if child is Sprite2D or child is AnimatedSprite2D:
				sprite = child as Node2D
				break

func _recalculate_physics() -> void:
	gravity_jump = (2.0 * jump_height) / (time_to_peak * time_to_peak)
	gravity_fall = (2.0 * jump_height) / (time_to_descent * time_to_descent)
	initial_jump_velocity = -((2.0 * jump_height) / time_to_peak)

# Call this from pickups or progression code; the exported flags set starting abilities.
func set_ability_unlocked(ability: StringName, unlocked: bool = true) -> void:
	match ability:
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
	return lerpf(clampf(exhausted_speed_multiplier, 0.5, 1.0), 1.0, stamina / 100.0)

func _recover_stamina(delta: float) -> void:
	if is_on_floor() and cached_input_dir == 0.0 and velocity.is_zero_approx() and not is_dashing:
		stamina += maxf(0.0, stamina_recovery) * delta

func _init_state_machine() -> void:
	_state_transitions = {
		PlayerState.IDLE: [
			{"target": PlayerState.DASH, "condition": Callable(self, "_cond_is_dashing")},
			{"target": PlayerState.WALL_SLIDE, "condition": Callable(self, "_cond_is_wall_sliding")},
			{"target": PlayerState.JUMP, "condition": Callable(self, "_cond_is_jumping")},
			{"target": PlayerState.FALL, "condition": Callable(self, "_cond_is_falling")},
			{"target": PlayerState.RUN, "condition": Callable(self, "_cond_is_running")}
		],
		PlayerState.RUN: [
			{"target": PlayerState.DASH, "condition": Callable(self, "_cond_is_dashing")},
			{"target": PlayerState.WALL_SLIDE, "condition": Callable(self, "_cond_is_wall_sliding")},
			{"target": PlayerState.JUMP, "condition": Callable(self, "_cond_is_jumping")},
			{"target": PlayerState.FALL, "condition": Callable(self, "_cond_is_falling")},
			{"target": PlayerState.IDLE, "condition": Callable(self, "_cond_is_idle")}
		],
		PlayerState.JUMP: [
			{"target": PlayerState.DASH, "condition": Callable(self, "_cond_is_dashing")},
			{"target": PlayerState.WALL_SLIDE, "condition": Callable(self, "_cond_is_wall_sliding")},
			{"target": PlayerState.FALL, "condition": Callable(self, "_cond_is_falling")},
			{"target": PlayerState.RUN, "condition": Callable(self, "_cond_is_grounded_running")},
			{"target": PlayerState.IDLE, "condition": Callable(self, "_cond_is_idle")}
		],
		PlayerState.FALL: [
			{"target": PlayerState.DASH, "condition": Callable(self, "_cond_is_dashing")},
			{"target": PlayerState.WALL_SLIDE, "condition": Callable(self, "_cond_is_wall_sliding")},
			{"target": PlayerState.JUMP, "condition": Callable(self, "_cond_is_jumping")},
			{"target": PlayerState.RUN, "condition": Callable(self, "_cond_is_grounded_running")},
			{"target": PlayerState.IDLE, "condition": Callable(self, "_cond_is_idle")}
		],
		PlayerState.DASH: [
			{"target": PlayerState.WALL_SLIDE, "condition": Callable(self, "_cond_dash_ended_wall_slide")},
			{"target": PlayerState.JUMP, "condition": Callable(self, "_cond_dash_ended_jumping")},
			{"target": PlayerState.FALL, "condition": Callable(self, "_cond_dash_ended_falling")},
			{"target": PlayerState.RUN, "condition": Callable(self, "_cond_dash_ended_running")},
			{"target": PlayerState.IDLE, "condition": Callable(self, "_cond_dash_ended_idle")}
		],
		PlayerState.WALL_SLIDE: [
			{"target": PlayerState.DASH, "condition": Callable(self, "_cond_is_dashing")},
			{"target": PlayerState.JUMP, "condition": Callable(self, "_cond_is_jumping")},
			{"target": PlayerState.FALL, "condition": Callable(self, "_cond_not_wall_sliding")},
			{"target": PlayerState.RUN, "condition": Callable(self, "_cond_is_grounded_running")},
			{"target": PlayerState.IDLE, "condition": Callable(self, "_cond_is_idle")}
		]
	}

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_weapon_cooldowns(delta)
	_handle_weapon_input()
	
	cached_input_dir = Input.get_axis("move_left", "move_right")
	var climb_input: float = Input.get_axis("move_up", "move_down")

	if is_dashing:
		_process_dash(delta)
		_update_sprite_facing(dash_direction.x)
		move_and_slide()
		_process_state_transitions()
		_update_animation()
		return

	_handle_ground_state()
	_handle_dash_input()
	if is_dashing:
		_process_dash(delta)
		_update_sprite_facing(dash_direction.x)
		move_and_slide()
		_process_state_transitions()
		_update_animation()
		return
	if Input.is_action_just_pressed("move_jump"):
		jump_buffer_timer = jump_buffer_time
		if wall_climb_unlocked and stamina > 0.0 and is_on_wall_only():
			_wall_jump_input_timer = maxf(0.0, wall_jump_input_grace)
	# Upgrade a recent downward push-off to a wall jump, even after losing contact.
	var late_wall_jump: bool = (
		Input.is_action_just_pressed("move_jump") and _wall_away_input_timer > 0.0
		and wall_climb_unlocked and stamina > 0.0 and not is_on_floor()
		and cached_input_dir * _wall_away_normal >= 0.0 and climb_input <= 0.0
	)
	if late_wall_jump:
		_execute_wall_jump(_wall_away_normal)
	_apply_horizontal_movement(cached_input_dir, delta)
	if not late_wall_jump and not _handle_wall_interactions(cached_input_dir, climb_input, delta):
		_handle_jump(cached_input_dir)
	_apply_gravity(delta)
	
	_resolve_facing(cached_input_dir)

	move_and_slide()
	_recover_stamina(delta)
	_process_state_transitions()
	_update_animation()

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
			_transition_to_state(PlayerState.RUN if absf(velocity.x) > 0.0 else PlayerState.IDLE)
		else:
			_transition_to_state(PlayerState.JUMP if velocity.y < 0.0 else PlayerState.FALL)
		return
	if not _state_transitions.has(current_state):
		return

	var transitions: Array = _state_transitions[current_state]
	for transition in transitions:
		var condition: Callable = transition["condition"]
		if condition.call():
			_transition_to_state(transition["target"])
			break

func _transition_to_state(new_state: PlayerState) -> void:
	if current_state == new_state:
		return
		
	var old_state_enum: PlayerState = current_state
	_exit_state(old_state_enum)
	current_state = new_state
	_enter_state(new_state)
	
	state_changed.emit(PlayerState.keys()[old_state_enum], PlayerState.keys()[new_state])

func _enter_state(_state: PlayerState) -> void:
	pass

func _exit_state(_state: PlayerState) -> void:
	pass

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

func _cond_is_running() -> bool:
	return is_on_floor() and (cached_input_dir != 0.0 or velocity.x != 0.0)

func _cond_is_grounded_running() -> bool:
	return is_on_floor() and cached_input_dir != 0.0

func _cond_is_idle() -> bool:
	return is_on_floor() and cached_input_dir == 0.0 and velocity.x == 0.0

func _cond_dash_ended_idle() -> bool:
	return not is_dashing and is_on_floor() and cached_input_dir == 0.0

func _cond_dash_ended_running() -> bool:
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
	if sprite == null or facing_dir == 0.0:
		return
		
	var target_sign: float = signf(facing_dir)

	if sprite is Sprite2D:
		(sprite as Sprite2D).flip_h = (target_sign < 0.0)
	elif sprite is AnimatedSprite2D:
		(sprite as AnimatedSprite2D).flip_h = (target_sign < 0.0)
	else:
		sprite.scale.x = absf(sprite.scale.x) * target_sign

# The supplied sheets contain walk and climb cycles; other states use still poses.
func _update_animation() -> void:
	if not sprite is AnimatedSprite2D:
		return
	var animated_sprite: AnimatedSprite2D = sprite as AnimatedSprite2D
	var animation_name: StringName = &"idle"
	var playback_speed: float = 1.0
	var hold_pose: bool = false
	match current_state:
		PlayerState.RUN:
			animation_name = &"run"
			playback_speed = absf(velocity.x) / maxf(move_speed, 1.0)
		PlayerState.JUMP:
			animation_name = &"jump"
		PlayerState.FALL:
			animation_name = &"fall"
		PlayerState.DASH:
			animation_name = &"dash"
		PlayerState.WALL_CLIMB, PlayerState.WALL_SLIDE, PlayerState.WALL_HOLD, PlayerState.WALL_REPOSITION:
			animation_name = &"climb"
			playback_speed = -velocity.y / maxf(wall_climb_speed, 1.0)
			hold_pose = is_zero_approx(velocity.y) or current_state == PlayerState.WALL_REPOSITION
	if animated_sprite.sprite_frames == null or not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	animated_sprite.play(animation_name, playback_speed)
	if hold_pose:
		animated_sprite.pause()

func _get_current_facing_direction() -> float:
	if sprite == null:
		return 1.0 if velocity.x >= 0.0 else -1.0
		
	if sprite is Sprite2D:
		return -1.0 if (sprite as Sprite2D).flip_h else 1.0
	elif sprite is AnimatedSprite2D:
		return -1.0 if (sprite as AnimatedSprite2D).flip_h else 1.0
	else:
		return signf(sprite.scale.x) if sprite.scale.x != 0.0 else 1.0

func _update_timers(delta: float) -> void:
	coyote_timer = maxf(0.0, coyote_timer - delta)
	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)
	wall_jump_timer = maxf(0.0, wall_jump_timer - delta)
	wall_reposition_timer = maxf(0.0, wall_reposition_timer - delta)
	_wall_jump_input_timer = maxf(0.0, _wall_jump_input_timer - delta)
	_wall_away_input_timer = maxf(0.0, _wall_away_input_timer - delta)

func _update_weapon_cooldowns(delta: float) -> void:
	for weapon in inventory:
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

func _handle_jump(_input_dir: float) -> void:
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

func _handle_wall_interactions(input_dir: float, climb_input: float, delta: float) -> bool:
	var was_climbing: bool = is_climbing
	is_climbing = false
	if not wall_climb_unlocked or not is_on_wall_only() or wall_jump_timer > 0.0:
		return false
	if stamina <= 0.0:
		if was_climbing:
			velocity.y = maxf(0.0, velocity.y)
		return true
	var wall_normal: float = get_wall_normal().x
	if _wall_jump_origin_normal * wall_normal < 0.0:
		wall_reposition_timer = maxf(0.0, wall_reposition_duration)
		_wall_jump_origin_normal = 0.0
		# Start on arrival, not takeoff; allow holding/sliding but block upward climbing.
	# Normals point away from either wall: positive product means away input.
	if input_dir * wall_normal > 0.0:
		if _wall_jump_input_timer > 0.0 or Input.is_action_just_pressed("move_jump"):
			_execute_wall_jump()
		else:
			_release_wall(true)
		return true
	if climb_input > 0.0:
		_release_wall(false)
		return true
	var holding: bool = input_dir * wall_normal < 0.0
	var climbing: bool = climb_input < 0.0
	if not holding and not climbing:
		return false
	stamina -= maxf(0.0, wall_stamina_drain) * delta
	if stamina <= 0.0:
		velocity.y = maxf(0.0, velocity.y)
		return true
	is_climbing = true
	var tired: bool = stamina < wall_low_stamina_threshold
	if climbing and wall_reposition_timer <= 0.0:
		velocity.y = climb_input * wall_climb_speed * get_stamina_speed_multiplier()
		if tired:
			velocity.y *= clampf(wall_tired_climb_multiplier, 0.0, 1.0)
	else:
		velocity.y = maxf(0.0, wall_tired_slide_speed) if tired else 0.0
	# Push into the surface to retain collision contact while holding or climbing.
	velocity.x = -wall_normal * move_speed * get_stamina_speed_multiplier()
	return true

func _release_wall(push_away: bool) -> void:
	_clear_wall_jump_inputs()
	if push_away:
		_wall_away_normal = get_wall_normal().x
		_wall_away_input_timer = maxf(0.0, wall_jump_input_grace)
	velocity.x = get_wall_normal().x * absf(wall_drop_impulse.x) * get_stamina_speed_multiplier() if push_away else 0.0
	velocity.y = maxf(velocity.y, absf(wall_drop_impulse.y) * get_stamina_speed_multiplier())
	wall_jump_timer = wall_jump_control_lock
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	ground_jump_available = false
	is_climbing = false

func _handle_dash_input() -> void:
	if dash_unlocked and Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and not is_dashing:
		var raw_dir: Vector2 = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down")
		)
		
		if raw_dir != Vector2.ZERO:
			dash_direction = raw_dir.normalized()
		else:
			dash_direction = Vector2(_get_current_facing_direction(), 0.0)

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
		active_weapon_index = posmod(active_weapon_index + 1, inventory.size())
		weapon_switched.emit(active_weapon_index, inventory[active_weapon_index])
	elif Input.is_action_just_pressed("prev_weapon"):
		active_weapon_index = posmod(active_weapon_index - 1, inventory.size())
		weapon_switched.emit(active_weapon_index, inventory[active_weapon_index])
		
	if Input.is_action_just_pressed("attack"):
		_use_weapon()

func _use_weapon() -> void:
	if active_weapon_index >= inventory.size():
		return
		
	var current_weapon: WeaponData = inventory[active_weapon_index]
	if current_weapon == null:
		return
		
	var fire_dir: Vector2 = Vector2(_get_current_facing_direction(), 0.0)
	if current_weapon.can_use():
		if current_weapon.execute(self, fire_dir):
			weapon_used.emit(active_weapon_index, current_weapon)
