extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var player: PlayerController = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	assert(sprite.animation == &"idle")
	assert(sprite.sprite_frames.get_frame_count(&"run") == 25)
	assert(sprite.sprite_frames.get_frame_count(&"climb") == 25)
	player.current_state = PlayerController.PlayerState.RUN
	player.velocity = Vector2(100, 0)
	player._update_animation()
	assert(sprite.animation == &"run")
	assert(is_equal_approx(sprite.get_playing_speed(), 0.5))
	await create_timer(0.2).timeout
	assert(sprite.frame > 0)
	player._update_sprite_facing(-1)
	assert(sprite.flip_h)
	player.current_state = PlayerController.PlayerState.WALL_CLIMB
	player.velocity.y = -120
	player._update_animation()
	assert(sprite.animation == &"climb" and sprite.get_playing_speed() > 0)
	player.current_state = PlayerController.PlayerState.WALL_HOLD
	player.velocity.y = 0
	player._update_animation()
	assert(not sprite.is_playing())
	player.current_state = PlayerController.PlayerState.WALL_SLIDE
	player.velocity.y = 60
	player._update_animation()
	assert(sprite.get_playing_speed() < 0)
	for state: int in [PlayerController.PlayerState.JUMP, PlayerController.PlayerState.FALL, PlayerController.PlayerState.DASH]:
		player.current_state = state as PlayerController.PlayerState
		player._update_animation()
		assert(sprite.sprite_frames.get_frame_count(sprite.animation) == 1)
	print("Skelly animation checks passed")
	quit()
