extends SceneTree

var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)

func _run() -> void:
	var player: PlayerController = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	_check(sprite.animation == &"idle", "Starts idle")
	_check(sprite.sprite_frames.get_frame_count(&"walk") == 11, "Walk uses exactly 11 frames")
	for index: int in range(11):
		var texture: AtlasTexture = sprite.sprite_frames.get_frame_texture(&"walk", index) as AtlasTexture
		var expected_region: Rect2 = Rect2((index % 5) * 256, floori(index / 5.0) * 256, 256, 256)
		_check(texture != null and texture.region == expected_region, "Walk frames follow sheet order: %d" % index)
	var walk_distance: float = player.walk_cycle_distance * sprite.global_transform.x.length()
	player.current_state = PlayerController.PlayerState.WALK
	player._animation_travel = Vector2(walk_distance * 0.25, 0.0)
	player._update_animation()
	_check(is_equal_approx(player._animation_cycle, 0.25), "Quarter cycle follows quarter travel")
	_check(sprite.animation == &"walk", "Walking state selects walk animation")
	_check(sprite.frame == 2 and is_equal_approx(sprite.frame_progress, 0.75), "11-frame walk phase mapping")
	player._animation_travel = Vector2(walk_distance, 0.0)
	player._update_animation()
	_check(sprite.frame == 2 and is_equal_approx(sprite.frame_progress, 0.75), "Full walk cycle loops to the same frame and progress")
	var held_frame: int = sprite.frame
	await create_timer(0.1).timeout
	_check(sprite.frame == held_frame, "Clock cannot advance distance-driven animation")
	for speed: float in [0.0, 0.5, 3.0, -2.0]:
		sprite.speed_scale = speed
		sprite.sprite_frames.set_animation_speed(&"walk", 60.0)
		player.move_speed = 700.0
		player.stamina = 9.0
		player._animation_cycle = 0.0
		for step: int in range(10):
			player._animation_travel = Vector2(walk_distance * 0.025, 0.0)
			player._update_animation()
		_check(is_equal_approx(player._animation_cycle, 0.25), "Equal travel must ignore FPS, playback speed, stamina and maximum speed")
	player._animation_cycle = 0.0
	sprite.scale *= 2.0
	player._animation_travel = Vector2(-walk_distance * 0.5, 0.0)
	player._update_sprite_facing(-1.0)
	player._update_animation()
	_check(sprite.flip_h and is_equal_approx(player._animation_cycle, 0.25), "Scale and leftward movement")
	sprite.scale *= 0.5
	player.current_state = PlayerController.PlayerState.WALL_CLIMB
	player.is_climbing = true
	var climb_distance: float = player.climb_cycle_distance * sprite.global_transform.y.length()
	player.cached_climb_input = -1.0
	player._animation_travel = Vector2(0.0, -climb_distance * 0.4)
	player._update_animation()
	_check(is_equal_approx(player._animation_cycle, 0.4), "Upward travel advances climb")
	player.cached_climb_input = 0.0
	player.current_state = PlayerController.PlayerState.WALL_HOLD
	player._update_animation()
	_check(is_equal_approx(player._animation_cycle, 0.4), "Hold preserves grip phase")
	player.cached_climb_input = 1.0
	player.current_state = PlayerController.PlayerState.WALL_REPOSITION
	player._animation_travel = Vector2(0.0, climb_distance * 0.1)
	player._update_animation()
	_check(is_equal_approx(player._animation_cycle, 0.3), "Descent reverses phase even during reposition")
	player.cached_climb_input = 0.0
	player.current_state = PlayerController.PlayerState.WALL_SLIDE
	player._animation_travel = Vector2(0.0, 3.0)
	player._update_animation()
	_check(is_equal_approx(player._animation_cycle, 0.3), "Tired slipping preserves grip pose")
	player.current_state = PlayerController.PlayerState.WALK
	player._update_animation()
	player.position += Vector2(1000.0, 1000.0)
	player.velocity = Vector2.ZERO
	player._move_with_animation_travel()
	player._update_animation()
	_check(is_zero_approx(player._animation_cycle), "Teleport between ticks does not advance cycle")
	# Exercise the same collision-movement capture used by the physics loop.
	var start_x: float = player.global_position.x
	player.velocity = Vector2(120.0, 0.0)
	player._move_with_animation_travel()
	player._update_animation()
	_check(player._animation_cycle > 0.0 and is_equal_approx(player._animation_cycle, (player.global_position.x - start_x) / walk_distance), "Actual movement advances the rendered cycle")
	player._animation_cycle = 0.0
	sprite.sprite_frames.set_frame(&"walk", 0, sprite.sprite_frames.get_frame_texture(&"walk", 0), 2.0)
	player._animation_travel = Vector2(walk_distance / 12.0, 0.0)
	player._update_animation()
	_check(sprite.frame == 0 and is_equal_approx(sprite.frame_progress, 0.5), "Relative frame durations retain their timing within the distance cycle")
	player.current_state = PlayerController.PlayerState.DASH
	player._update_animation()
	_check(sprite.sprite_frames.get_frame_count(sprite.animation) == 1, "Dash retains a still pose")
	_check_jump_animation(player, sprite)
	print("Animation tests: ", failures, " failures")
	quit(1 if failures > 0 else 0)

func _check_jump_animation(player: PlayerController, sprite: AnimatedSprite2D) -> void:
	for animation_name: StringName in [&"jump", &"fall", &"land"]:
		for index: int in range(sprite.sprite_frames.get_frame_count(animation_name)):
			var texture: AtlasTexture = sprite.sprite_frames.get_frame_texture(animation_name, index) as AtlasTexture
			_check(texture != null and texture.atlas.resource_path == "res://assets/images/Skelly/Skelly-jump.png", "%s must use the Skelly jump sheet" % animation_name)
			_check(texture != null and texture.get_size() == Vector2(256, 256), "Shadow-cropped jump frames must keep the 256 px frame size")
	var rest_scale: Vector2 = sprite.scale
	player.current_state = PlayerController.PlayerState.JUMP
	player.velocity.y = player.initial_jump_velocity
	player._update_animation()
	_check(sprite.animation == &"jump" and sprite.frame == 0, "Takeoff shows the first rising frame")
	_check(sprite.scale.is_equal_approx(rest_scale * PlayerController.LARGE_SHEET_SCALE), "Jump art must be scaled to match the walk art")
	player.velocity.y = 0.0
	player._update_animation()
	_check(sprite.frame == 2, "Apex shows the last rising frame")
	player._transition_to_state(PlayerController.PlayerState.FALL)
	player._update_animation()
	_check(sprite.animation == &"fall" and sprite.frame == 0, "Falling starts from the apex fall frame")
	player.velocity.y = -player.initial_jump_velocity
	player._update_animation()
	_check(sprite.frame == 1, "Fast falling shows the last fall frame")
	player._transition_to_state(PlayerController.PlayerState.IDLE)
	player._update_animation()
	_check(sprite.animation == &"land" and sprite.is_playing(), "Landing into idle plays the landing frames")
	sprite.frame = sprite.sprite_frames.get_frame_count(&"land") - 1
	sprite.pause()
	player._update_animation()
	_check(sprite.animation == &"idle" and sprite.scale.is_equal_approx(rest_scale), "Idle and walk scale return after landing")
