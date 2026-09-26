class_name DashOrb2D
extends Area2D

signal collected(by_player: PlayerController, amount: float)

## Dash energy percentage points restored on pickup. 25 refills a quarter of the meter; 100 refills it completely.
@export_range(0.0, 100.0, 0.1) var restore_amount: float = 25.0

@export_subgroup("Visuals")
## Orb sprite to animate. Assign a Sprite2D child to enable bobbing and pulsing.
@export var sprite_node: Sprite2D
## Maximum vertical bob distance in local pixels around Y = 0. Set to 0 to disable bobbing.
@export var float_amplitude: float = 3.0
## Bobbing angular speed in radians per second. A full cycle takes 2 * PI divided by this value; 0 stops the animation.
@export var float_frequency: float = 3.0
## Scale pulse fraction around the sprite's starting scale. 0.08 pulses between 92 and 108 percent; 0 disables pulsing.
@export_range(0.0, 0.5, 0.01) var pulse_amount: float = 0.08

var _time_passed: float = 0.0
var _sprite_rest_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	# Offset the phase so neighbouring orbs do not bob in sync.
	_time_passed = randf() * TAU
	if sprite_node != null:
		_sprite_rest_scale = sprite_node.scale

func _process(delta: float) -> void:
	if sprite_node == null:
		return
	_time_passed += delta
	var wave: float = sin(_time_passed * float_frequency)
	sprite_node.position.y = wave * float_amplitude
	sprite_node.scale = _sprite_rest_scale * (1.0 + wave * pulse_amount)

# Polling overlaps instead of body_entered lets a player standing on the orb collect it once energy drops below full.
func _physics_process(_delta: float) -> void:
	for body: Node2D in get_overlapping_bodies():
		var player: PlayerController = body as PlayerController
		if player == null or player.dash_energy >= 100.0:
			continue
		player.restore_dash_energy(restore_amount)
		set_deferred("monitoring", false)
		set_physics_process(false)
		collected.emit(player, restore_amount)
		queue_free()
		return
