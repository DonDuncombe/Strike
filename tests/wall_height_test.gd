extends SceneTree

var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)

func _run() -> void:
	# Geometry below the feet plane must not contribute to wall height.
	var floor_body: StaticBody2D = StaticBody2D.new()
	var floor_collision: CollisionShape2D = CollisionShape2D.new()
	var floor_shape: RectangleShape2D = RectangleShape2D.new()
	floor_shape.size = Vector2(1000.0, 100.0)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position.y = 135.0
	root.add_child(floor_body)
	for direction: float in [-1.0, 1.0]:
		for dimensions: Vector2 in [Vector2(40, 40), Vector2(81, 200), Vector2(82, 200), Vector2(160, 200)]:
			var height: float = dimensions.x
			var wall: StaticBody2D = StaticBody2D.new()
			var collision: CollisionShape2D = CollisionShape2D.new()
			var shape: RectangleShape2D = RectangleShape2D.new()
			shape.size = Vector2(40.0, dimensions.y)
			collision.shape = shape
			wall.add_child(collision)
			wall.position = Vector2(direction * 100.0, dimensions.y * 0.5 - height)
			root.add_child(wall)
			var player: PlayerController = load("res://scenes/player.tscn").instantiate()
			root.add_child(player)
			player.set_physics_process(false)
			player.position = Vector2(direction * 60.0, -52.0)
			await physics_frame
			await process_frame
			player.velocity = Vector2(direction * 600.0, 0.0)
			player.move_and_slide()
			_check(player.is_on_wall_only(), "Fixture must touch wall")
			var tall_enough: bool = height >= 82.0
			_check(player._wall_is_tall_enough() == tall_enough, "Wall height classification: %s, side %s" % [height, direction])
			player.velocity.y = -200.0
			player.jump_buffer_timer = player.jump_buffer_time
			player.ground_jump_available = true
			player.coyote_timer = player.coyote_time
			var handled: bool = player._handle_wall_interactions(direction, -1.0, 1.0 / 60.0)
			_check(handled == tall_enough and player.is_climbing == tall_enough, "Only character-height walls may take over jump")
			if not handled:
				_check(player.velocity.y == -200.0 and player.stamina == 100.0, "Short wall must preserve upward velocity and stamina")
				player._handle_jump()
				_check(is_equal_approx(player.velocity.y, player.initial_jump_velocity) and not player.is_climbing, "Short wall must allow buffered regular jump")
			player.free()
			wall.free()
	floor_body.free()
	# Adjacent tiles form one wall, despite each individual tile being shorter than the player.
	var level: Node = load("res://scenes/main.tscn").instantiate()
	var grid: TileMapLayer = level.get_node("CollisionGrid")
	level.remove_child(grid)
	level.free()
	grid.clear()
	root.add_child(grid)
	for count: int in [1, 2]:
		grid.set_cell(Vector2i(0, count - 1), 0, Vector2i.ZERO)
		for direction: float in [-1.0, 1.0]:
			var player: PlayerController = load("res://scenes/player.tscn").instantiate()
			root.add_child(player)
			player.set_physics_process(false)
			player.position = Vector2(-20.0 if direction > 0.0 else 85.0, count * 64.0 - 52.0)
			await physics_frame
			await process_frame
			player.velocity = Vector2(direction * 600.0, 0.0)
			player.move_and_slide()
			_check(player.is_on_wall_only(), "Tile fixture must touch wall")
			_check(player._wall_is_tall_enough() == (count == 2), "Only stacked tiles must allow climbing")
			if count == 2:
				# Raising the feet to the first tile top leaves only 64px above them.
				player.position.y = 64.0 - 52.0
				player.velocity = Vector2(direction * 600.0, 0.0)
				player.move_and_slide()
				_check(not player._wall_is_tall_enough(), "Tiles below the feet must not make a low exposed wall climbable")
			player.free()
	print("Wall height tests: %d failures" % failures)
	quit(1 if failures else 0)

