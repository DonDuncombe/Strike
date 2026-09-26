extends SceneTree

const ACTIONS: Array[String] = ["move_left", "move_right", "move_up", "move_down", "move_jump", "dash"]

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

func _body(at: Vector2, size: Vector2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = at
	root.add_child(body)

# Grips the tall wall on the right at mid height, then lets go of every input.
func _grip() -> void:
	for action: String in ACTIONS:
		Input.action_release(action)
	player.position = Vector2(128.0, 0.0)
	player.velocity = Vector2.ZERO
	player.stamina = 100.0
	player.wall_jump_timer = 0.0
	player.wall_reposition_timer = 0.0
	player._wall_jump_origin_normal = 0.0
	player._wall_hop_direction = 0.0
	player._update_timers(10.0)
	Input.action_press("move_right")
	await _frames(12)
	Input.action_release("move_right")
	await _frames(3)
	_check(player.is_climbing, "Test must start gripping the wall")

func _run() -> void:
	# Tall wall face at x = 150 with open air to its left; floor far below.
	_body(Vector2(200.0, 0.0), Vector2(100.0, 3000.0))
	_body(Vector2(0.0, 1400.0), Vector2(2000.0, 20.0))
	player = (load("res://scenes/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	await _frames(2)

	await _grip()
	var start: Vector2 = player.position
	Input.action_press("move_jump")
	await _frames(2)
	_check(not player.is_climbing and is_zero_approx(player.velocity.x) and player.velocity.y >= 0.0, "Neutral Jump must drop straight down")
	await _frames(30)
	Input.action_release("move_jump")
	_check(not player.is_climbing and player.position.y > start.y + 50.0 and absf(player.position.x - start.x) < 2.0, "Neutral drop must keep falling straight without re-gripping")

	await _grip()
	start = player.position
	Input.action_press("move_right")
	Input.action_press("move_jump")
	await _frames(2)
	_check(not player.is_climbing, "Toward + Jump must drop like neutral (toward is blocked by the wall)")
	Input.action_release("move_jump")
	await _frames(25)
	_check(player.is_climbing and player.position.y > start.y, "Holding toward after the drop must grip again lower down")

	await _grip()
	start = player.position
	Input.action_press("move_up")
	Input.action_press("move_jump")
	await _frames(2)
	_check(player._wall_hop_direction < 0.0 and player.velocity.y < 0.0, "Up + Jump must hop up the wall")
	await _frames(40)
	Input.action_release("move_jump")
	_check(player.is_climbing and player.is_on_wall_only(), "Up hop must land back on the same wall")
	_check(player.position.y < start.y - 0.6 * player.jump_height, "Up hop must gain roughly a jump height (rose %.1f)" % (start.y - player.position.y))
	Input.action_release("move_up")

	await _grip()
	start = player.position
	Input.action_press("move_down")
	Input.action_press("move_jump")
	await _frames(2)
	Input.action_release("move_jump")
	_check(player._wall_hop_direction > 0.0 and player.velocity.y > 0.0, "Down + Jump must hop down the wall")
	Input.action_release("move_down")
	await _frames(40)
	var dropped: float = player.position.y - start.y
	_check(player.is_climbing and player.is_on_wall_only(), "Down hop must catch the same wall again")
	_check(dropped >= player.wall_hop_down_distance and dropped < player.wall_hop_down_distance + 40.0, "Down hop must fall about Wall Hop Down Distance (fell %.1f)" % dropped)

	await _grip()
	Input.action_press("move_left")
	Input.action_press("move_down")
	Input.action_press("move_jump")
	await _frames(2)
	_check(not player.is_climbing and player.velocity.x < 0.0 and player.velocity.y > 0.0, "Away + Down + Jump must push off downward and away")

	await _grip()
	Input.action_press("move_left")
	Input.action_press("move_up")
	Input.action_press("move_jump")
	await _frames(2)
	_check(player.velocity.x < 0.0 and player.velocity.y < 0.0, "Away + Up + Jump must wall jump up and away")
	for action: String in ACTIONS:
		Input.action_release(action)

	print("Wall jump rules tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
