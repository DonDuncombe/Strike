class_name WeaponPickup2D
extends Area2D

signal picked_up(by_entity: Node2D, weapon_data: WeaponData)

@export var weapon_data: WeaponData
@export var auto_equip: bool = true

@export_subgroup("Visuals")
@export var sprite_node: Sprite2D
@export var float_amplitude: float = 4.0
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