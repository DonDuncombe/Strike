class_name Projectile
extends Area2D

## Projectile travel speed in world pixels per second. Ranged weapon resources override this when spawning a projectile.
@export var speed: float = 600.0
## Seconds before the projectile removes itself if it has not collided. Increase for longer travel range.
@export var max_lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var source_owner: Node2D = null

var _lifetime_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(p_direction: Vector2, p_damage: float, p_owner: Node2D) -> void:
	direction = p_direction.normalized()
	damage = p_damage
	source_owner = p_owner
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	
	_lifetime_timer += delta
	if _lifetime_timer >= max_lifetime:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body == source_owner:
		return
	_apply_damage_and_destroy(body)

func _on_area_entered(area: Area2D) -> void:
	if area == source_owner:
		return
	_apply_damage_and_destroy(area)

func _apply_damage_and_destroy(target: Node) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)
	queue_free()
