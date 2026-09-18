extends CanvasLayer

@export var player: PlayerController

const STAMINA_GREEN: Color = Color("52d66b")
const STAMINA_YELLOW: Color = Color("f2d34f")
const STAMINA_RED: Color = Color("f06b67")

var _flash_elapsed: float = 0.0

@onready var stamina_bar: ProgressBar = $Panel/StaminaBar
@onready var stamina_label: Label = $Panel/StaminaLabel
@onready var stamina_fill: StyleBoxFlat = stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat

func _ready() -> void:
	set_process(false)
	if player == null:
		push_warning("HUD requires a player reference.")
		hide()
		return
	player.stamina_changed.connect(_update_stamina)
	_update_stamina(player.stamina)

func _update_stamina(value: float) -> void:
	stamina_bar.value = value
	stamina_label.text = "STAMINA  %d%%" % floori(value)
	if value <= 0.0:
		stamina_label.text = "STAMINA  0%  •  EXHAUSTED"
	elif value <= player.wall_low_stamina_threshold:
		stamina_label.text += "  •  LOW"
	var status_color: Color = STAMINA_GREEN
	if value < 30.0:
		status_color = STAMINA_RED
	elif value < 70.0:
		status_color = STAMINA_YELLOW
	stamina_fill.bg_color = status_color
	stamina_label.self_modulate = status_color
	set_process(value < 10.0)
	if value >= 10.0:
		_flash_elapsed = 0.0
		stamina_bar.self_modulate.a = 1.0
	else:
		_apply_flash()

func _process(delta: float) -> void:
	_flash_elapsed = fmod(_flash_elapsed + delta, 0.8)
	_apply_flash()

func _apply_flash() -> void:
	var opacity: float = 1.0 if _flash_elapsed < 0.4 else 0.3
	stamina_bar.self_modulate.a = opacity
	# Keep the warning visible even when the bar is completely empty.
	stamina_label.self_modulate.a = opacity
