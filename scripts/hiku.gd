extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -800.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("move_left", "move_right")

	# Flip the sprite based on direction
	if direction != 0:
		animated_sprite.flip_h = (direction < 0)

	# Apply movement
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	# Update animation based on state
	update_animation(direction)

func update_animation(direction: float) -> void:
	if not is_on_floor():
		# In the air
		if velocity.y < 0:
			animated_sprite.play("jump")   # Rising
		else:
			animated_sprite.play("fall")   # Falling
	elif direction != 0:
		# Moving on the ground
		animated_sprite.play("walk")        # or "walk" depending on your animation names
	else:
		# Standing still on the ground
		animated_sprite.play("idle")
