class_name SlideMovementState
extends MovementState
@export_category("Parameters")
@export var min_slide_time: float = 1.0
@export var slide_friction: float = 6.0
@export var slide_acceleration: float = 1.0
@export var slope_slide_multiplier: float = 40.0
@export var slide_boost: float = 4.0
@export var slide_stop_speed: float = 3.0
@export var slide_speed_cap: float = 15.0
@export var crounc_transition_speed: float = 5.0
@export var max_slide_time: float = 1.0
@export var crouch_animation_name: String = "crouch"
@export var crouch_animation_speed: float = 3.0
@export var slide_steer_rate: float = 2.5 # How fast the slide direction turns toward input
@export var slope_sustain_angle_threshold: float = 12.0 # minimum slope angle to sustain slide

@export_category("Collision Detectors")
@export var floor_detector:RayCast3D

func _can_enter(_player_info: PlayerInfo) -> bool:
	var wants_crouch = _player_info.is_crouching or Input.is_action_just_pressed("crouch")
	return _player_info.is_on_floor and _player_info.is_sprinting and wants_crouch

func _can_exit(_player_info: PlayerInfo) -> bool:
	return not _player_info.is_on_floor or _player_info.current_speed < slide_stop_speed or _player_info.jump_pressed

func _on_enter(_player_info: PlayerInfo) -> void:
	_player_info.is_sliding = true
	player_character.crouch()
	player_character.floor_snap_length = 0.5
	var horiz_vel = Vector3(_player_info.velocity.x, 0, _player_info.velocity.z)
	if horiz_vel.length() > 0.1:
		_player_info.velocity += horiz_vel.normalized() * slide_boost

func _on_exit(_player_info: PlayerInfo) -> void:
	_player_info.is_sliding = false
	player_character.uncrouch()

func _physics_update(_delta: float, _player_info: PlayerInfo) -> void:
	# Get Floor Normal and Slope Angle
	var floor_normal = _player_info.floor_normal
	if floor_detector and floor_detector.is_colliding():
		floor_normal = floor_detector.get_collision_normal()
	
	var slope_angle = rad_to_deg(floor_normal.angle_to(Vector3.UP))
	var is_on_sustained_slope = slope_angle >= slope_sustain_angle_threshold
	
	# Increasing velocity accross slope
	var slope_dir = Vector3.DOWN.slide(floor_normal)
	if slope_dir.length() > 0.001:
		slope_dir = slope_dir.normalized()
		_player_info.velocity += slope_dir * slope_slide_multiplier * _delta
	
	# player input influence during slide
	var horizontal = Vector3(_player_info.velocity.x, 0, _player_info.velocity.z)
	var speed = horizontal.length()

	if speed > 0.1:
		var current_dir = horizontal.normalized()

		var cam_basis = player_character.global_transform.basis
		var input_dir = (cam_basis.x * _player_info.input_dir.x -
						cam_basis.z * _player_info.input_dir.y)
		input_dir.y = 0
		input_dir = input_dir.normalized()

		if input_dir.length() > 0.1:
			current_dir = current_dir.lerp(input_dir, slide_steer_rate * _delta).normalized()
			_player_info.velocity.x = current_dir.x * speed
			_player_info.velocity.z = current_dir.z * speed
	
	# apply friction for flat/gentle slopes only
	if _player_info.is_on_floor and not is_on_sustained_slope:
		var horizontal_vel = Vector3(_player_info.velocity.x, 0, _player_info.velocity.z)
		var friction = slide_friction * _delta
		horizontal_vel = horizontal_vel.move_toward(Vector3.ZERO, friction)
		_player_info.velocity.x = horizontal_vel.x
		_player_info.velocity.z = horizontal_vel.z
	
	# clamp slide speed
	var h_speed = Vector3(_player_info.velocity.x, 0, _player_info.velocity.z).length()
	if h_speed > slide_speed_cap:
		var dir = Vector3(_player_info.velocity.x, 0, _player_info.velocity.z).normalized()
		_player_info.velocity.x = dir.x * slide_speed_cap
		_player_info.velocity.z = dir.z * slide_speed_cap


