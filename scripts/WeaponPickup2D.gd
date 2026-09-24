class_name WeaponPickup2D
extends Area2D

signal picked_up(by_entity: Node2D, weapon_data: WeaponData)

## Weapon resource granted when a player touches this pickup. Leave empty to disable pickup behavior.
@export var weapon_data: WeaponData
## Immediately equip this weapon after pickup. Disable to add it to the inventory without switching weapons.
@export var auto_equip: bool = true

@export_subgroup("Visuals")
## Pickup sprite to animate. Assign a Sprite2D child to enable the floating visual.
@export var sprite_node: Sprite2D
## Maximum vertical bob distance in local pixels around Y = 0. Set to 0 to disable bobbing.
@export var float_amplitude: float = 4.0
## Bobbing angular speed in radians per second. A full cycle takes 2 * PI divided by this value; 0 stops the animation.
@export var float_frequency: float = 2.0

var _base_y_position: float = 0.0
var _time_passed: float = 0.0

func _ready() -> void:
	_base_y_position = position.y
	body_entered.connect(_on_body_entered)
	_update_visuals()

func _process(delta: float) -> void:
	if sprite_node == null:
		return
	_time_passed += delta
	sprite_node.position.y = sin(_time_passed * float_frequency) * float_amplitude

func _update_visuals() -> void:
	if weapon_data == null or sprite_node == null:
		return
	# Resource name or placeholder setup
	sprite_node.queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if weapon_data == null:
		return

	if body is PlayerController:
		var player := body as PlayerController
		player.inventory.append(weapon_data)
		
		if auto_equip:
			player.active_weapon_index = player.inventory.size() - 1
			player.weapon_switched.emit(player.active_weapon_index, weapon_data)
			
		picked_up.emit(player, weapon_data)
		queue_free()
