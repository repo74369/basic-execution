class_name LookController
extends Node
 
@export var player_character:FPSPlayer
@export var max_virtical_rotation_angle_degrees:float = 90.0 

var player_rotation_on_y_axis:float = 0.0
var camera_rotation_change_on_x_axis:float = 0.0
var camera_rotation:float = 0.0
var mouse_sensitivity:float = 0.002

func _reset_direction():
	player_rotation_on_y_axis = 0.0
	camera_rotation_change_on_x_axis = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not player_character:
		if get_parent() is not FPSPlayer:
			push_error("Parent must be FPS player if not explictly set in the editor")
		player_character = get_parent() as FPSPlayer
	mouse_sensitivity = Settings.setting_data.mouse_sensitivity
	Settings.settings_changed.connect(_on_settings_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		player_rotation_on_y_axis -= event.relative.x * mouse_sensitivity
		camera_rotation_change_on_x_axis -= event.relative.y * mouse_sensitivity


func _process(delta: float) -> void:
	player_character.rotate_y(player_rotation_on_y_axis)
	camera_rotation = clamp(camera_rotation + camera_rotation_change_on_x_axis, deg_to_rad(-max_virtical_rotation_angle_degrees), deg_to_rad(max_virtical_rotation_angle_degrees))
	player_character.player_neck.rotation.x = camera_rotation
	call_deferred("_reset_direction")

func _on_settings_changed(new_values:SettingsResource):
	mouse_sensitivity = new_values.mouse_sensitivity