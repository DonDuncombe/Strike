extends SceneTree

var failures: int = 0
var player: PlayerController

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)

func _body(at: Vector2, size: Vector2) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = at
	root.add_child(body)
	return body

func _reset(direction: float) -> void:
	player._release_ledge()
	player.position = Vector2(direction * 76.0, 24.0)
	player.velocity = Vector2(0.0, 10.0)
	player.cached_input_dir = direction
	player.stamina = 100.0
	player.ledge_hang_unlocked = true
	player._ledge_regrab_timer = 0.0
	player.wall_jump_timer = 0.0

func _run() -> void:
	_body(Vector2(200.0, 100.0), Vector2(200.0, 200.0))
	_body(Vector2(-200.0, 100.0), Vector2(200.0, 200.0))
	player = load("res://scenes/player.tscn").instantiate() as PlayerController
	root.add_child(player)
	player.set_physics_process(false)
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	var rest_scale: Vector2 = sprite.scale
	var rest_position: Vector2 = sprite.position
	_check(sprite.sprite_frames.get_frame_count(&"hang") == 3, "Hang must use all three source frames")
	for index: int in range(3):
		var texture: AtlasTexture = sprite.sprite_frames.get_frame_texture(&"hang", index) as AtlasTexture
		_check(texture != null and texture.region == Rect2(index * 128, 0, 128, 128), "Hang frames must follow sheet order")
		_check(texture.atlas.resource_path == "res://assets/images/Skelly/Skelly-hang.png", "Hang must use Skelly-hang artwork")
	await physics_frame
	await process_frame
	for direction: float in [-1.0, 1.0]:
		_reset(direction)
		_check(player._try_grab_ledge(), "Must grab on either side")
		_check(player.current_state == PlayerController.PlayerState.LEDGE_HANG, "Grab must enter hang state")
		_check(player.velocity == Vector2.ZERO, "Hang must stop velocity")
		player._update_animation()
		_check(sprite.animation == &"hang" and sprite.is_playing(), "Hanging must play the hang animation")
		_check(sprite.flip_h == (direction < 0.0), "Hang must face the ledge")
		var grip: Vector2 = player.ledge_sprite_grip
		grip.x *= direction
		_check(sprite.to_global(grip).is_equal_approx(player._ledge_top), "Rendered hands must align with ledge on either side")
		var initial_frame: int = sprite.frame
		await create_timer(0.25).timeout
		_check(sprite.frame != initial_frame, "Hang must animate while stationary")
		player._process_ledge(1.0)
		_check(is_equal_approx(player.stamina, 95.0), "Hang stamina drain")
		player._begin_ledge_climb()
		_check(player.current_state == PlayerController.PlayerState.LEDGE_CLIMB, "Clear ledge must allow climb")
		player._update_animation()
		_check(sprite.animation == &"climb", "Pull-up must select climbing animation")
		_check(sprite.scale.is_equal_approx(rest_scale) and sprite.position.is_equal_approx(rest_position), "Leaving hang must restore normal sprite transform")
		for tick: int in range(180):
			if player._is_on_ledge():
				player._process_ledge(1.0 / 60.0)
		_check(not player._is_on_ledge() and player.position.y < -50.0, "Pull-up must finish above platform")
		_reset(direction)
		player.set_ability_unlocked(&"ledge_hang", false)
		_check(not player._try_grab_ledge(), "Locked ability must not grab")
		player.set_ability_unlocked(&"ledge_hang", true)
		_check(player._try_grab_ledge(), "Runtime unlock must enable grabbing")
		player.set_ability_unlocked(&"ledge_hang", false)
		_check(not player._is_on_ledge(), "Runtime lock must release grip")
		_reset(direction)
		player._try_grab_ledge()
		player.stamina = 0.01
		player._process_ledge(1.0)
		_check(not player._is_on_ledge(), "Exhaustion must release grip")
		player.stamina = 100.0
		_check(not player._try_grab_ledge(), "Release must prevent immediate regrab")
	_reset(1.0)
	var ceiling: StaticBody2D = _body(Vector2(110.0, -80.0), Vector2(100.0, 10.0))
	await physics_frame
	await process_frame
	_check(player._try_grab_ledge(), "Low ceiling must still permit hanging")
	player._begin_ledge_climb()
	_check(player.current_state == PlayerController.PlayerState.LEDGE_HANG, "Low ceiling must block pull-up")
	ceiling.queue_free()
	await physics_frame
	await process_frame
	_reset(1.0)
	player.position.y = 100.0
	_check(not player._try_grab_ledge(), "Continuous wall must not count as ledge")
	_reset(1.0)
	player.is_dashing = true
	_check(not player._try_grab_ledge(), "Active dash must not grab")
	player.is_dashing = false
	_reset(1.0)
	player._try_grab_ledge()
	Input.action_press("move_jump")
	player._process_ledge(0.016)
	_check(not player._is_on_ledge() and player.velocity.x < 0.0 and player.velocity.y < 0.0, "Jump must launch away from ledge")
	Input.action_release("move_jump")
	await process_frame
	_reset(1.0)
	player._try_grab_ledge()
	Input.action_press("move_down")
	player._process_ledge(0.016)
	_check(not player._is_on_ledge(), "Down must release ledge")
	Input.action_release("move_down")
	await process_frame
	_reset(1.0)
	player._try_grab_ledge()
	Input.action_press("dash")
	player._process_ledge(0.016)
	_check(player.is_dashing and player.current_state == PlayerController.PlayerState.DASH, "Dash must release ledge into dash state")
	Input.action_release("dash")
	player.is_dashing = false
	await process_frame
	_reset(1.0)
	var obstruction: StaticBody2D = _body(Vector2(94.0, 70.0), Vector2(6.0, 8.0))
	await physics_frame
	await process_frame
	_check(not player._try_grab_ledge(), "Blocked hanging destination must prevent grab")
	obstruction.queue_free()
	await physics_frame
	await process_frame
	_reset(1.0)
	player.set_physics_process(true)
	Input.action_press("move_right")
	for tick: int in range(3):
		await physics_frame
		await process_frame
	_check(player._is_on_ledge(), "Normal physics loop must grab ledge")
	Input.action_release("move_right")
	player.set_physics_process(false)
	# Use the actual square tile platforms from the level, not only standalone bodies.
	var level: Node = load("res://scenes/main.tscn").instantiate()
	var grid: TileMapLayer = level.get_node("CollisionGrid")
	level.remove_child(grid)
	level.free()
	# Clear the overhead blocks so this fixture tests an unobstructed pull-up.
	grid.erase_cell(Vector2i(2, 3))
	grid.erase_cell(Vector2i(5, 3))
	root.add_child(grid)
	await physics_frame
	await process_frame
	for direction: float in [-1.0, 1.0]:
		_reset(direction)
		player.position = Vector2(168.0 if direction > 0.0 else 408.0, 344.0)
		var wall_hit: Dictionary = player._ledge_ray(player.position + Vector2(0, -14), player.position + Vector2(direction * 30, -14))
		_check(not wall_hit.is_empty() and wall_hit.collider == grid, "Side ray must detect square tile platform")
		_check(player._try_grab_ledge(), "Must grab actual square TileMapLayer corners on both sides")
		player._begin_ledge_climb()
		_check(player.current_state == PlayerController.PlayerState.LEDGE_CLIMB, "Square tile must allow pull-up")
		for tick: int in range(180):
			if player._is_on_ledge():
				player._process_ledge(1.0 / 60.0)
		_check(not player._is_on_ledge() and player.position.y < 270.0, "Square tile pull-up must finish above the platform")
	_reset(1.0)
	player.position = Vector2(168.0, 344.0)
	player.ledge_grab_reach = 1.0
	_check(not player._try_grab_ledge(), "Shortened side ray must not reach the tile")
	player.ledge_grab_reach = 12.0
	_check(player._try_grab_ledge(), "Restoring side ray reach must enable tile grab")
	player.ledge_support_probe_depth = 0.5
	player._begin_ledge_climb()
	_check(player.current_state == PlayerController.PlayerState.LEDGE_HANG, "Support ray shorter than clearance must block pull-up")
	player.ledge_support_probe_depth = 3.0
	# Local tile lookup must still work after translating and scaling the layer.
	player._release_ledge()
	grid.position = Vector2(700.0, 500.0)
	grid.scale = Vector2(1.5, 1.5)
	await physics_frame
	await process_frame
	_reset(1.0)
	player.position = grid.to_global(Vector2(192.0, 320.0)) + Vector2(-24.0, 24.0)
	_check(player._try_grab_ledge(), "Translated and scaled tile layer must support grabs")
	grid.position.x += 10.0
	player._process_ledge(0.016)
	_check(not player._is_on_ledge(), "Moving a grabbed tile layer must release grip")
	grid.position = Vector2.ZERO
	grid.scale = Vector2.ONE
	grid.tile_set = grid.tile_set.duplicate(true) as TileSet
	var tile_data: TileData = grid.get_cell_tile_data(Vector2i(3, 5))
	tile_data.set_collision_polygon_one_way(0, 0, true)
	grid.update_internals()
	await physics_frame
	await process_frame
	_reset(1.0)
	player.position = Vector2(168.0, 344.0)
	_check(not player._try_grab_ledge(), "One-way tile must not allow hanging")
	tile_data.set_collision_polygon_one_way(0, 0, false)
	tile_data.set_constant_linear_velocity(0, Vector2(10.0, 0.0))
	grid.update_internals()
	await physics_frame
	await process_frame
	_check(not player._try_grab_ledge(), "Conveyor tile must not allow hanging")
	print("Ledge tests: %d failures" % failures)
	quit(1 if failures else 0)
