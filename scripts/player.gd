class_name PlayerController
extends CharacterBody2D

signal state_changed(old_state: String, new_state: String)
signal weapon_switched(weapon_index: int, weapon_data: WeaponData)
signal weapon_used(weapon_index: int, weapon_data: WeaponData)
signal ability_changed(ability: StringName, unlocked: bool)

enum PlayerState { IDLE, RUN, JUMP, FALL, DASH, WALL_SLIDE }

@export_category("Node References")
@export var sprite: Node2D

@export_category("Movement Base")
@export var move_speed: float = 200.0
@export var acceleration: float = 1200.0
@export var friction: float = 1600.0
@export var air_acceleration: float = 800.0
@export var air_resistance: float = 300.0

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
		return

	_handle_ground_state()
	_handle_dash_input()
	if is_dashing:
		_process_dash(delta)
		_update_sprite_facing(dash_direction.x)
		move_and_slide()
		_process_state_transitions()
		return
	_handle_jump(cached_input_dir)
	_apply_horizontal_movement(cached_input_dir, delta)
	_handle_wall_interactions(cached_input_dir, climb_input)
	_apply_gravity(delta)
	
	_resolve_facing(cached_input_dir)

	move_and_slide()
	_process_state_transitions()

func _process_state_transitions() -> void:
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
	return wall_climb_unlocked and is_on_wall_only() and velocity.y > 0.0 and cached_input_dir == -get_wall_normal().x

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
	if is_on_wall_only() and velocity.y > 0.0:
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

func _update_weapon_cooldowns(delta: float) -> void:
	for weapon in inventory:
		if weapon != null:
			weapon.update(delta)

func _handle_ground_state() -> void:
	if is_on_floor():
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
		velocity.x = move_toward(velocity.x, input_dir * move_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deccel * delta)

func _handle_jump(input_dir: float) -> void:
	if Input.is_action_just_pressed("move_jump"):
		jump_buffer_timer = jump_buffer_time

	if jump_buffer_timer > 0.0:
		if ground_jump_available and coyote_timer > 0.0:
			_execute_jump(false)
		elif wall_climb_unlocked and is_on_wall_only() and input_dir != 0.0:
			_execute_wall_jump()
		elif jumps_left > 0:
			_execute_jump(true)

func _execute_jump(uses_air_jump: bool) -> void:
	velocity.y = initial_jump_velocity
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	ground_jump_available = false
	is_climbing = false
	if uses_air_jump:
		jumps_left -= 1

func _execute_wall_jump() -> void:
	var wall_normal: float = get_wall_normal().x
	velocity.x = wall_normal * wall_jump_impulse.x
	velocity.y = wall_jump_impulse.y
	jump_buffer_timer = 0.0
	wall_jump_timer = wall_jump_control_lock
	jumps_left = _air_jumps_available()
	coyote_timer = 0.0
	ground_jump_available = false
	is_climbing = false

func _handle_wall_interactions(input_dir: float, climb_input: float) -> void:
	is_climbing = false
	if wall_climb_unlocked and is_on_wall_only():
		if Input.is_action_pressed("climb"):
			is_climbing = true
			velocity.y = climb_input * wall_climb_speed
		elif velocity.y > 0.0 and input_dir == -get_wall_normal().x:
			velocity.y = minf(velocity.y, wall_slide_speed)

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
		dash_start_vertical_velocity = velocity.y
		dash_timer = dash_duration
		dash_cooldown_timer = dash_cooldown

func _process_dash(delta: float) -> void:
	dash_timer -= delta
	velocity = dash_direction * dash_speed
	
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
