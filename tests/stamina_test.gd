extends SceneTree

var failures: int = 0
var player: PlayerController

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)

func _frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame
		await process_frame

func _add_body(position: Vector2, size: Vector2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = position
	root.add_child(body)

func _run() -> void:
	_add_body(Vector2(0.0, 300.0), Vector2(2000.0, 20.0))
	_add_body(Vector2(200.0, 0.0), Vector2(10.0, 400.0))
	_add_body(Vector2(-200.0, 0.0), Vector2(10.0, 400.0))
	player = PlayerController.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(10.0, 10.0)
	collision.shape = shape
	player.add_child(collision)
	root.add_child(player)
	player.set_physics_process(false)
	for amount: float in [100.0, 50.0, 0.0]:
		player.stamina = amount
		_check(is_equal_approx(player.get_stamina_speed_multiplier(), 0.5 + amount / 200.0), "Incorrect speed scaling")
	player.stamina = -10.0
	_check(player.stamina == 0.0, "Stamina must clamp at zero")
	player._execute_jump(false)
	_check(is_equal_approx(player.velocity.y, player.initial_jump_velocity * 0.5), "Exhausted jump speed")
	player.stamina = 200.0
	_check(player.stamina == 100.0, "Stamina must clamp at 100")
	player.is_dashing = true
	player.dash_timer = 0.2
	player.dash_direction = Vector2.RIGHT
	player.dash_preserve_vertical = false
	player._process_dash(0.2)
	_check(is_equal_approx(player.stamina, 98.0), "Dash drain must use elapsed seconds")
	_check(is_equal_approx(player.velocity.x, player.dash_speed * 0.99), "Dash must use stamina speed")

	player.position = Vector2(0.0, 280.0)
	player.velocity = Vector2.ZERO
	player.stamina = 50.0
	player.set_physics_process(true)
	await _frames(30)
	_check(player.is_on_floor() and player.stamina > 50.0, "Grounded rest must recover stamina")
	Input.action_press("move_right")
	await _frames(2)
	var walking_stamina: float = player.stamina
	await _frames(15)
	_check(is_equal_approx(player.stamina, walking_stamina), "Walking must neither drain nor restore stamina")
	Input.action_release("move_right")
	await _frames(60)
	player.stamina = 99.99
	await _frames(5)
	_check(player.stamina == 100.0, "Rest must refill to exactly 100")

	player.wall_climb_unlocked = true
	player.position = Vector2(189.0, 0.0)
	player.velocity = Vector2.ZERO
	player.stamina = 50.0
	Input.action_press("move_right")
	await _frames(10)
	_check(player.is_climbing and player.stamina < 50.0, "Holding a wall must consume stamina")
	_check(is_zero_approx(player.velocity.y), "Toward input must hold still")
	Input.action_press("move_up")
	Input.action_release("move_right")
	await _frames(5)
	_check(player.is_climbing, "Up must maintain contact without horizontal input")
	await _frames(5)
	_check(player.velocity.y < 0.0 and player.is_climbing, "Climbing must move upward")
	_check(is_equal_approx(player.velocity.y, -player.wall_climb_speed * player.get_stamina_speed_multiplier()), "Climb speed must scale with stamina")
	player.stamina = 9.0
	await _frames(3)
	_check(player.velocity.y < 0.0 and absf(player.velocity.y) < player.wall_climb_speed * 0.1, "Below 10 percent, climbing must be very slow")
	Input.action_release("move_up")
	Input.action_press("move_right")
	await _frames(3)
	_check(is_equal_approx(player.velocity.y, player.wall_tired_slide_speed), "Below 10 percent, holding must slowly slide")
	Input.action_press("move_up")
	player.stamina = 0.01
	var held_height: float = player.position.y
	await _frames(15)
	_check(player.stamina == 0.0 and not player.is_climbing, "Exhaustion must release the wall")
	_check(player.position.y > held_height and player.velocity.y > 0.0, "Exhaustion must cause a fall even with climb held")
	Input.action_release("move_up")
	Input.action_release("move_right")
	for side: float in [-1.0, 1.0]:
		var toward: String = "move_right" if side > 0.0 else "move_left"
		var away: String = "move_left" if side > 0.0 else "move_right"
		for action: String in ["away", "jump", "down"]:
			player.position = Vector2(side * 189.0, 0.0)
			player.velocity = Vector2.ZERO
			player.move_and_slide()
			player.wall_jump_timer = 0.0
			player.stamina = 50.0
			Input.action_press(toward)
			await _frames(10)
			_check(player.is_climbing, "Wall test must start attached")
			Input.action_release(toward)
			if action == "down":
				Input.action_press("move_down")
			else:
				Input.action_press(away)
				if action == "jump":
					Input.action_press("move_jump")
			var before_release: float = player.stamina
			await _frames(2)
			_check(not player.is_climbing, "Release action must detach")
			_check(is_equal_approx(player.stamina, before_release), "Detaching must not drain stamina")
			if action == "down":
				_check(is_zero_approx(player.velocity.x) and player.velocity.y > 0.0, "Down must drop vertically")
			else:
				_check(player.velocity.x * side < 0.0, "Away impulse must point away on both walls")
				_check(player.velocity.y < 0.0 if action == "jump" else player.velocity.y > 0.0, "Wall push vertical direction")
			Input.action_release(away)
			Input.action_release("move_jump")
			Input.action_release("move_down")
	await _test_wall_jump_grace()
	# Simulate wall transfers with real contacts; flight time must not consume the delay.
	for delay: float in [1.0, 0.2, 0.0]:
		player.wall_reposition_duration = delay
		player.position = Vector2(189.0, 0.0)
		player.velocity = Vector2.ZERO
		player.move_and_slide()
		player.wall_jump_timer = 0.0
		player.stamina = 100.0
		Input.action_press("move_right")
		await _frames(10)
		player._execute_wall_jump()
		player._update_timers(2.0)
		_check(player.wall_reposition_timer == 0.0, "Reposition delay must not start at takeoff")
		Input.action_release("move_right")
		player.position = Vector2(-189.0, 0.0)
		player.velocity = Vector2.ZERO
		player.move_and_slide()
		Input.action_press("move_left")
		Input.action_press("move_up")
		await _frames(5)
		if delay > 0.0:
			_check(player.wall_reposition_timer > 0.0 and is_zero_approx(player.velocity.y), "Opposite wall must block climbing during reposition")
			_check(player.current_state == PlayerController.PlayerState.WALL_REPOSITION, "Reposition state must be available for animation")
			var before_wait: float = player.stamina
			await _frames(int(delay * 60.0) + 3)
			_check(player.stamina < before_wait, "Reposition holding must continue to use stamina")
		_check(player.wall_reposition_timer == 0.0 and player.velocity.y < 0.0, "Climbing must resume after configurable delay")
		Input.action_release("move_left")
		Input.action_release("move_up")
	print("Stamina tests: ", failures, " failures")
	quit(1 if failures > 0 else 0)

func _test_wall_jump_grace() -> void:
	for side: float in [-1.0, 1.0]:
		var toward: String = "move_right" if side > 0.0 else "move_left"
		var away: String = "move_left" if side > 0.0 else "move_right"
		for jump_first: bool in [true, false]:
			for grace: float in [0.0, 0.05, 0.3]:
				player.position = Vector2(side * 189.0, 0.0)
				player.velocity = Vector2.ZERO
				player.move_and_slide()
				player._update_timers(10.0)
				player.stamina = 100.0
				player.wall_jump_input_grace = grace
				Input.action_press(toward)
				await _frames(10)
				_check(player.is_climbing, "Grace test must start on a wall")
				if jump_first:
					Input.action_press("move_jump")
				else:
					Input.action_release(toward)
					Input.action_press(away)
				# About 167ms: longer than the ordinary jump buffer, within 300ms grace.
				await _frames(10)
				if jump_first:
					Input.action_release("move_jump")
					Input.action_release(toward)
					Input.action_press(away)
				else:
					Input.action_press("move_jump")
				await _frames(2)
				_check(player.velocity.x * side < 0.0, "Grace wall jump must point away")
				if grace > 0.2:
					_check(player.velocity.y < 0.0, "Both input orders must jump within the grace window")
					_check(player._wall_away_input_timer == 0.0 and player._wall_jump_input_timer == 0.0, "Wall jump must consume buffered inputs")
				else:
					_check(player.velocity.y > 0.0, "Expired or disabled grace must keep the downward push-off")
				Input.action_release(away)
				Input.action_release("move_jump")
	player.wall_jump_input_grace = 0.2
