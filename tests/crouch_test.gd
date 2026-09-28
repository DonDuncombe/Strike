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

func _run() -> void:
	_body(Vector2(0.0, 200.0), Vector2(2000.0, 20.0))
	player = (load("res://scenes/player.tscn") as PackedScene).instantiate() as PlayerController
	root.add_child(player)
	player.position = Vector2(0.0, 100.0)
	var sprite: AnimatedSprite2D = player.sprite
	var rest_scale: Vector2 = sprite.scale
	var rest_position: Vector2 = sprite.position
	_check(sprite.sprite_frames.get_frame_count(&"crouch") == 5, "Crouch must use all five source frames")
	for index: int in range(5):
		var texture: AtlasTexture = sprite.sprite_frames.get_frame_texture(&"crouch", index) as AtlasTexture
		_check(texture.region == Rect2(index * 256, 0, 256, 256), "Crouch frames must follow sheet order")
		_check(texture.atlas.resource_path == "res://assets/images/Skelly/Skelly-crouch.png", "Crouch must use the Skelly crouch sheet")
	await _frames(40)
	_check(player.is_on_floor(), "Player must start on the floor")
	var standing: Rect2 = player._body_bounds()

	Input.action_press("move_crouch")
	await _frames(20)
	var crouched: Rect2 = player._body_bounds()
	_check(player.is_crouching and player.current_state == PlayerController.PlayerState.CROUCH, "Holding crouch on the floor must crouch")
	_check(crouched.size.y < standing.size.y and is_equal_approx(crouched.end.y, standing.end.y), "Crouching must lower the collider top and keep the feet in place")
	_check(sprite.animation == &"crouch" and sprite.frame == 4 and not sprite.is_playing(), "Full crouch must hold the last crouch frame")
	_check(sprite.scale.is_equal_approx(rest_scale * PlayerController.LARGE_SHEET_SCALE), "Crouch art must be scaled to match the walk art")

	var x_before: float = player.position.x
	Input.action_press("move_left")
	Input.action_press("move_jump")
	await _frames(30)
	Input.action_release("move_jump")
	Input.action_release("move_left")
	var crouch_speed: float = player.move_speed * player.get_stamina_speed_multiplier() * PlayerController.CROUCH_WALK_SPEED_MULTIPLIER
	_check(player.position.x < x_before and is_equal_approx(absf(player.velocity.x), crouch_speed), "Crouch-walk must move at the reduced crouch speed")
	_check(player.is_on_floor() and player.current_state == PlayerController.PlayerState.CROUCH, "Crouching must block jumping and stay in the crouch state while moving")
	_check(sprite.animation == &"crouch" and sprite.frame == 4, "Crouch-walk must hold the full crouch frame")
	_check(sprite.flip_h, "Crouching must still turn to face input")
	await _frames(20)
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	_check(not player.is_dashing, "Crouching must block dashing")

	var ceiling: StaticBody2D = _body(player.global_position + Vector2(0.0, standing.position.y + 10.0), Vector2(200.0, 10.0))
	await _frames(2)
	Input.action_release("move_crouch")
	await _frames(5)
	_check(player.is_crouching, "Releasing crouch under a low ceiling must stay crouched")
	ceiling.queue_free()
	await _frames(2)
	_check(not player.is_crouching and player.current_state == PlayerController.PlayerState.IDLE, "Crouch must end once there is headroom")
	_check(is_equal_approx(player._body_bounds().size.y, standing.size.y), "Standing up must restore the collider")
	_check(sprite.animation == &"crouch" and sprite.frame < 4, "Standing up must replay the crouch frames in reverse")
	await _frames(15)
	_check(sprite.animation == &"idle", "Idle animation must return after standing up")
	_check(sprite.scale.is_equal_approx(rest_scale) and sprite.position.is_equal_approx(rest_position), "Standing up must restore the sprite transform")

	Input.action_press("move_down")
	await _frames(5)
	_check(player.is_crouching, "Holding Down on the floor must also crouch")
	# Crawl out from under a low ceiling while holding only a direction.
	ceiling = _body(player.global_position + Vector2(-40.0, standing.position.y + 10.0), Vector2(100.0, 10.0))
	await _frames(2)
	Input.action_release("move_down")
	Input.action_press("move_right")
	await _frames(5)
	_check(player.is_crouching, "Crouch must hold under the ceiling after Down is released")
	await _frames(120)
	Input.action_release("move_right")
	_check(not player.is_crouching, "Crouch-walking out from under the ceiling must stand up")
	ceiling.queue_free()

	print("Crouch tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
