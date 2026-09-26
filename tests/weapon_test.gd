extends SceneTree

var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)

func _target_script() -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = "extends StaticBody2D\nvar hits: int = 0\nfunc take_damage(_amount: float) -> void:\n\thits += 1\n"
	script.reload()
	return script

func _run() -> void:
	for action: StringName in [&"next_weapon", &"prev_weapon", &"attack"]:
		_check(InputMap.has_action(action), "Weapon input action must exist: %s" % action)

	var player: PlayerController = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var switched: Array[int] = []
	player.weapon_switched.connect(func(index: int, _weapon: WeaponData) -> void: switched.append(index))

	var melee: MeleeWeaponData = MeleeWeaponData.new()
	melee.cooldown_time = 1.0
	_check(player.add_weapon(melee, false) == 0, "First weapon must use slot 0")
	_check(switched == [0], "First weapon must be announced even without equip")
	_check(player.inventory[0] != melee, "Inventory must hold a copy, not the shared resource")
	player.add_weapon(melee, false)
	_check(switched == [0] and player.active_weapon_index == 0, "Later weapons without equip must not switch")
	player.inventory[0].execute(player, Vector2.RIGHT)
	_check(not player.inventory[0].can_use() and player.inventory[1].can_use() and melee.can_use(), "Cooldowns must be independent per copy")

	# A target with two shapes inside the melee circle must only take one hit.
	var target: StaticBody2D = StaticBody2D.new()
	target.set_script(_target_script())
	for offset: float in [10.0, 20.0]:
		var collision: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(4.0, 4.0)
		collision.shape = shape
		collision.position = Vector2(offset, 0.0)
		target.add_child(collision)
	target.position = player.position
	root.add_child(target)
	await physics_frame
	player.inventory[1].execute(player, Vector2.RIGHT)
	_check(target.get("hits") == 1, "Melee must damage a multi-shape target once, got %s" % target.get("hits"))

	# A projectile scene with the wrong root type must not leak its instance.
	var wrong_root: PackedScene = PackedScene.new()
	var wrong_node: Node2D = Node2D.new()
	wrong_root.pack(wrong_node)
	wrong_node.free()
	var ranged: RangedWeaponData = RangedWeaponData.new()
	ranged.projectile_scene = wrong_root
	var nodes_before: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	ranged.execute(player, Vector2.RIGHT)
	_check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == nodes_before, "Rejected projectile instance must be freed")

	var pickup: WeaponPickup2D = WeaponPickup2D.new()
	pickup.weapon_data = RangedWeaponData.new()
	root.add_child(pickup)
	pickup._on_body_entered(player)
	_check(player.inventory.size() == 3 and player.active_weapon_index == 2, "Pickup must add and equip through the player")
	_check(pickup.is_queued_for_deletion(), "Pickup must remove itself")
	print("Weapon tests: %d failures" % failures)
	quit(1 if failures else 0)
