class_name AirMovementState
extends MovementState

@export var air_control:float = 2
@export var air_control_speed: float = 5
@export var double_jump_thrust_force:float = 10.0
@export var custom_double_jump_speed:float = 8.0

var _air_time: float = 0

func _can_enter(player_info: PlayerInfo) -> bool:
	return not player_info.is_on_floor

func _can_exit(_player_info: PlayerInfo) -> bool:
	return true

func _on_enter(player_info: PlayerInfo) -> void:
	_air_time = 0
	player_info.is_in_air_state = true

func _on_exit(player_info: PlayerInfo) -> void:
	player_info.jump_count = 0
	player_info.is_in_air_state = false

func _physics_update(delta: float, player_info: PlayerInfo) -> void:
	_air_time += delta

	# Fast fall: pull down faster and cut upward float when sprint + crouch are active
	if player_info.is_sprinting and player_info.is_crouching:
		if player_info.velocity.y > 0.0:
			player_info.velocity.y = 0.0
		var extra_gravity = player_character.custom_gravity * (player_character.fast_fall_multiplier - 1.0)
		player_info.velocity.y += extra_gravity * delta

	var cam_basis = player_character.global_transform.basis
	var dir = (cam_basis.x * player_info.input_dir.x - cam_basis.z *player_info.input_dir.y)
	var input_dir = dir.normalized()
	# dir.y = player.velocity.y
	var target_velocity = player_info.velocity # Get initial velocity so that momentum is preserved
	var current_speed_in_input_dir = target_velocity.dot(input_dir)
	var speed_to_add = air_control_speed - current_speed_in_input_dir
	if speed_to_add > 0:
		var accel = min(air_control * delta * air_control_speed, speed_to_add)
		target_velocity += input_dir * accel

	target_velocity.y = player_info.velocity.y # preserve back player y velocity
	player_info.velocity = target_velocity

	if player_info.jump_pressed and player_info.jump_count < player_info.max_jump_count:
		player_info.jump_count += 1
		var jump_speed = player_info.jump_speed
		if custom_double_jump_speed != 0:
			jump_speed = custom_double_jump_speed
		player_info.velocity.y += jump_speed
	super._physics_update(delta,player_info)
