extends SceneTree

var failures: int = 0

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

func _press_dash() -> void:
	Input.action_press("dash")
	await _frames(1)
	Input.action_release("dash")

func _run() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var player: PlayerController = main.get_node("Player") as PlayerController
	var grid: TileMapLayer = main.get_node("CollisionGrid") as TileMapLayer
	var dash_bar: ProgressBar = main.get_node("HUD/Panel/DashBar") as ProgressBar
	var small_orbs: int = 0
	var large_orbs: int = 0
	for orb: DashOrb2D in main.get_node("DashOrbs").get_children():
		_check(grid.get_cell_source_id(grid.local_to_map(grid.to_local(orb.global_position))) == -1, "%s must not sit inside a tile" % orb.name)
		if is_equal_approx(orb.restore_amount, 25.0):
			small_orbs += 1
		elif is_equal_approx(orb.restore_amount, 100.0):
			large_orbs += 1
	_check(small_orbs == 3 and large_orbs == 3, "Level needs three 25% and three 100% dash orbs")
	main.get_node("DashOrbs").queue_free()
	await _frames(30)

	_check(player.dash_energy == 100.0 and dash_bar.value == 100.0, "Dash energy must start full on the HUD")
	var start_x: float = player.global_position.x
	await _press_dash()
	_check(player.is_dashing, "Dash must start with enough energy")
	_check(is_equal_approx(player.dash_energy, 100.0 - player.dash_energy_cost), "Dash must consume its energy cost once")
	_check(is_equal_approx(dash_bar.value, player.dash_energy), "HUD dash bar must follow dash energy")
	await _frames(90)
	var travelled: float = absf(player.global_position.x - start_x)
	_check(travelled <= player.dash_max_distance + 20.0, "Dash must not slide far past its distance cap (travelled %.1f)" % travelled)

	player.dash_energy = player.dash_energy_cost - 1.0
	player.dash_cooldown_timer = 0.0
	await _press_dash()
	_check(not player.is_dashing, "Dash must be blocked without enough energy")
	player.restore_dash_energy(500.0)
	_check(player.dash_energy == 100.0, "Restored energy must clamp at 100")

	var orb: DashOrb2D = (load("res://scenes/dash_orb_small.tscn") as PackedScene).instantiate() as DashOrb2D
	main.add_child(orb)
	orb.global_position = player.global_position
	await _frames(5)
	_check(is_instance_valid(orb), "Orb must stay when dash energy is already full")
	player.dash_energy = 50.0
	await _frames(5)
	_check(not is_instance_valid(orb), "Orb must be collected once energy is below full")
	_check(is_equal_approx(player.dash_energy, 75.0), "Small orb must restore 25%")

	orb = (load("res://scenes/dash_orb_large.tscn") as PackedScene).instantiate() as DashOrb2D
	main.add_child(orb)
	orb.global_position = player.global_position
	player.dash_energy = 10.0
	await _frames(5)
	_check(player.dash_energy == 100.0, "Large orb must refill dash energy")

	print("Dash energy tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
