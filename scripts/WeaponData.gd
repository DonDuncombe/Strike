class_name WeaponData
extends Resource

signal weapon_fired()
signal cooldown_started(duration: float)

@export var weapon_name: String = "Default Weapon"
@export var cooldown_time: float = 0.5
@export var damage: float = 10.0

var _current_cooldown: float = 0.0

func update(delta: float) -> void:
	if _current_cooldown > 0.0:
		_current_cooldown = maxf(0.0, _current_cooldown - delta)

func can_use() -> bool:
	return _current_cooldown <= 0.0

func execute(user: CharacterBody2D, fire_direction: Vector2) -> bool:
	if not can_use():
		return false
		
	_current_cooldown = cooldown_time
	cooldown_started.emit(cooldown_time)
	_on_execute(user, fire_direction)
	weapon_fired.emit()
	return true

# Virtual method - override in custom inherited weapon resources
func _on_execute(_user: CharacterBody2D, _fire_direction: Vector2) -> void:
	pass