extends CanvasLayer

const STAMINA_GREEN: Color = Color("52d66b")
const STAMINA_YELLOW: Color = Color("f2d34f")
const STAMINA_RED: Color = Color("f06b67")
## Stamina below these percentages turns the bar yellow, then red.
const YELLOW_BELOW: float = 70.0
const RED_BELOW: float = 30.0
## Stamina below this percentage flashes the bar and label.
const FLASH_BELOW: float = 10.0
const FLASH_PERIOD: float = 0.8
const DASH_BLUE: Color = Color("4f9dff")

## Player whose stamina and dash energy are shown by this HUD. Assign the Player node; the HUD hides itself when this is empty.
@export var player: PlayerController

var _flash_elapsed: float = 0.0

@onready var stamina_bar: ProgressBar = $Panel/StaminaBar
@onready var stamina_label: Label = $Panel/StaminaLabel
@onready var stamina_fill: StyleBoxFlat = stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat
@onready var dash_bar: ProgressBar = $Panel/DashBar
@onready var dash_label: Label = $Panel/DashLabel

func _ready() -> void:
	set_process(false)
	if player == null:
		push_warning("HUD requires a player reference.")
		hide()
		return
	player.stamina_changed.connect(_update_stamina)
	_update_stamina(player.stamina)
	dash_label.self_modulate = DASH_BLUE
	player.dash_energy_changed.connect(_update_dash_energy)
	_update_dash_energy(player.dash_energy)

func _update_dash_energy(value: float) -> void:
	dash_bar.value = value
	dash_label.text = "DASH  %d%%" % floori(value)
	if value < player.dash_energy_cost:
		dash_label.text += "  •  EMPTY"

func _update_stamina(value: float) -> void:
	stamina_bar.value = value
	stamina_label.text = "STAMINA  %d%%" % floori(value)
	if value <= 0.0:
		stamina_label.text = "STAMINA  0%  •  EXHAUSTED"
	elif value <= player.wall_low_stamina_threshold:
		stamina_label.text += "  •  LOW"
	var status_color: Color = STAMINA_GREEN
	if value < RED_BELOW:
		status_color = STAMINA_RED
	elif value < YELLOW_BELOW:
		status_color = STAMINA_YELLOW
	stamina_fill.bg_color = status_color
	stamina_label.self_modulate = status_color
	set_process(value < FLASH_BELOW)
	if value >= FLASH_BELOW:
		_flash_elapsed = 0.0
		stamina_bar.self_modulate.a = 1.0
	else:
		_apply_flash()

func _process(delta: float) -> void:
	_flash_elapsed = fmod(_flash_elapsed + delta, FLASH_PERIOD)
	_apply_flash()

func _apply_flash() -> void:
	var opacity: float = 1.0 if _flash_elapsed < FLASH_PERIOD * 0.5 else 0.3
	stamina_bar.self_modulate.a = opacity
	# Keep the warning visible even when the bar is completely empty.
	stamina_label.self_modulate.a = opacity
