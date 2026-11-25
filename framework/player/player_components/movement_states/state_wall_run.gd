extends MovementState
class_name WallRunState

@export_category("Feature Flags")
@export var allow_direction_reversal: bool = false
@export var allow_look_influence: bool = false
@export var stop_without_input: bool = false
@export var influence_by_gravity: bool = false
@export var reduced_gravity: float = 2.0

@export_category("Look Influence")
@export_range(0.0, 1.0) var virtical_look_influence: float = 0.5

@export_category("Implementation Parameters")
@export var player_half_width: float = 0.5
@export var wall_detection_range: float = 0.5
@export var wall_run_duration: float = 1.5
@export var wall_run_speed_boost: float = 5.0
@export var wall_run_max_speed: float = 18.0
@export var wall_jump_horizontal_force: float = 12.0
@export var wall_jump_upward_force: float = 8.0
@export var same_wall_angle_threshold_degrees: float = 20.0
@export var wall_jump_cooldown: float = 0.1
@export_flags_3d_physics var wall_collision_mask: int = 1

@export_category("Camera Tilt")
@export var enable_camera_tilt: bool = true
@export var max_camera_tilt_angle_degrees: float = 15.0
@export var tilt_speed: float = 5.0

var _wall_query_detection_result: Dictionary = {
	"wall_detected": false,
	"wall_normal": Vector3.ZERO,
	"wall_collision_point": Vector3.ZERO,
	"wall_forward": Vector3.ZERO,
	"wall_side": 0
}

var _player_custom_gravity_before_start: float
var _wall_direction_sign_on_enter: float = 0.0
var _wall_run_timer: float = 0.0
var _wall_push_force: float = 5.0
var _has_wall_jumped: bool = false
var _lost_wall_time: float = 0.0
var _last_wall_jump_time: float = -10.0
var _tilt_tween: Tween
const WALL_LOST_GRACE_TIME: float = 0.15

func _can_enter(_player_info: PlayerInfo) -> bool:
	if not player_character or player_character.is_on_floor():
		if _player_info:
			_player_info.last_wall_run_normal = Vector3.ZERO
		return false

	if (Time.get_ticks_msec() / 1000.0) - _last_wall_jump_time < wall_jump_cooldown:
		return false

	_query_wall_detection(_player_info)
	if not _wall_query_detection_result["wall_detected"]:
		return false

	# If entering fresh from air, prevent re-latching to the same flat wall unless it has curved
	if not _player_info.is_wall_running and _player_info.last_wall_run_normal != Vector3.ZERO:
		var detected_normal: Vector3 = _wall_query_detection_result["wall_normal"]
		var dot: float = detected_normal.dot(_player_info.last_wall_run_normal)
		var max_same_wall_dot: float = cos(deg_to_rad(same_wall_angle_threshold_degrees))
		# If the angle difference is smaller than the threshold, reject as same flat wall
		if dot >= max_same_wall_dot:
			return false

	return true

func _can_exit(_player_info: PlayerInfo) -> bool:
	if _has_wall_jumped:
		return true
	if not player_character or player_character.is_on_floor():
		return true
	if _wall_run_timer >= wall_run_duration:
		return true
	if not _wall_query_detection_result["wall_detected"] and _lost_wall_time >= WALL_LOST_GRACE_TIME:
		return true
	if _player_info.is_sprinting and _player_info.is_crouching:
		return true
	return false

func _on_enter(_player_info: PlayerInfo) -> void:
	if not player_character:
		return
	_player_info.is_wall_running = true
	_wall_run_timer = 0.0
	_lost_wall_time = 0.0
	_has_wall_jumped = false
	_player_custom_gravity_before_start = player_character.custom_gravity
	
	if influence_by_gravity:
		player_character.custom_gravity = -abs(reduced_gravity)
	else:
		player_character.custom_gravity = 0.0
		# Nullify vertical momentum so player glides cleanly
		_player_info.velocity.y = 0.0

	if _wall_query_detection_result["wall_detected"]:
		var player_forward = -player_character.global_transform.basis.z
		var player_up = player_character.global_transform.basis.y
		var wall_tangent = player_up.cross(_wall_query_detection_result["wall_normal"])
		if wall_tangent.dot(player_forward) > 0:
			_wall_direction_sign_on_enter = 1.0
		else:
			_wall_direction_sign_on_enter = -1.0
		
		# Smoothly redirect player momentum along wall run direction
		var run_dir = _get_wall_run_direction(_player_info)
		var current_speed = max(_player_info.velocity.length(), _player_info.max_run_speed)
		current_speed = min(current_speed + wall_run_speed_boost, wall_run_max_speed)
		_player_info.velocity = run_dir * current_speed

	_tilt_camera()

func _on_exit(_player_info: PlayerInfo) -> void:
	if _wall_query_detection_result["wall_detected"]:
		_player_info.last_wall_run_normal = _wall_query_detection_result["wall_normal"]
	_player_info.is_wall_running = false
	_wall_run_timer = 0.0
	_lost_wall_time = 0.0
	_has_wall_jumped = false
	if player_character:
		player_character.custom_gravity = _player_custom_gravity_before_start
		_untilt_camera()

func _query_wall_detection(_player_info: PlayerInfo) -> void:
	if not player_character:
		return
	# Stop wall running if player is sprinting and crouching (Cancel wall run)
	if _player_info.is_sprinting and _player_info.is_crouching:
		_wall_query_detection_result["wall_detected"] = false
		return

	var space = player_character.get_world_3d().direct_space_state
	# Cast rays from player center/chest height to avoid skimming the floor
	var ray_origin = player_character.global_position + Vector3.UP * 1.0
	var forward = -player_character.global_transform.basis.z
	var right = player_character.global_transform.basis.x
	var reach = player_half_width + wall_detection_range
	var exclude = [player_character.get_rid()]

	# Check left: cast directly left, plus diagonal forward-left
	var left_dirs = [-right, (-right + forward * 0.5).normalized()]
	for dir in left_dirs:
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + dir * reach, wall_collision_mask, exclude)
		var hit = space.intersect_ray(query)
		if hit:
			_wall_query_detection_result["wall_detected"] = true
			_wall_query_detection_result["wall_normal"] = hit["normal"]
			_wall_query_detection_result["wall_collision_point"] = hit["position"]
			_wall_query_detection_result["wall_forward"] = forward
			_wall_query_detection_result["wall_side"] = -1
			return

	# Check right: cast directly right, plus diagonal forward-right
	var right_dirs = [right, (right + forward * 0.5).normalized()]
	for dir in right_dirs:
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + dir * reach, wall_collision_mask, exclude)
		var hit = space.intersect_ray(query)
		if hit:
			_wall_query_detection_result["wall_detected"] = true
			_wall_query_detection_result["wall_normal"] = hit["normal"]
			_wall_query_detection_result["wall_collision_point"] = hit["position"]
			_wall_query_detection_result["wall_forward"] = forward
			_wall_query_detection_result["wall_side"] = 1
			return

	# Fallback: check CharacterBody3D is_on_wall() when body is touching
	if player_character.is_on_wall():
		var wall_norm = player_character.get_wall_normal()
		var side_dot = wall_norm.dot(right)
		if abs(side_dot) > 0.2:
			_wall_query_detection_result["wall_detected"] = true
			_wall_query_detection_result["wall_normal"] = wall_norm
			_wall_query_detection_result["wall_collision_point"] = ray_origin
			_wall_query_detection_result["wall_forward"] = forward
			_wall_query_detection_result["wall_side"] = -1 if side_dot > 0 else 1
			return

	_wall_query_detection_result["wall_detected"] = false

func _get_wall_run_direction(_player_info: PlayerInfo) -> Vector3:
	if not player_character:
		return Vector3.ZERO
	
	var base_direction: Vector3 = player_character.global_transform.basis.y.cross(_wall_query_detection_result["wall_normal"])

	var horizontal_direction: Vector3
	
	if allow_direction_reversal:
		var is_facing_forward: bool = -player_character.global_transform.basis.z.dot(base_direction) > 0.0
		if is_facing_forward:
			horizontal_direction = base_direction
		else:
			horizontal_direction = -base_direction
	else:
		horizontal_direction = base_direction * _wall_direction_sign_on_enter
	
	var final_move_direction: Vector3 = horizontal_direction.normalized()
	if allow_look_influence and player_character.player_neck and virtical_look_influence > 0.0:
		var wall_up_slope = _wall_query_detection_result["wall_normal"].cross(horizontal_direction)
		var look_dir = -player_character.player_neck.global_transform.basis.z
		var pitch_factor: float = look_dir.dot(player_character.global_transform.basis.y)
		var vertical_influence: Vector3 = wall_up_slope * (pitch_factor * virtical_look_influence)
		final_move_direction = (horizontal_direction + vertical_influence).normalized()
	
	return final_move_direction

func _apply_wall_normal_force(_player_info: PlayerInfo) -> void:
	if not _wall_query_detection_result["wall_detected"]:
		return
	var wall_norm = _wall_query_detection_result["wall_normal"]
	# Cancel any velocity pushing away from the wall
	var outward_speed = _player_info.velocity.dot(wall_norm)
	if outward_speed > 0.0:
		_player_info.velocity -= wall_norm * outward_speed
	# Apply gentle inward stick velocity
	_player_info.velocity -= wall_norm * (_wall_push_force * 0.2)

func _tilt_camera() -> void:
	if player_character and player_character.player_neck and enable_camera_tilt:
		if _tilt_tween and _tilt_tween.is_valid():
			_tilt_tween.kill()
		_tilt_tween = player_character.create_tween()
		var target_z = -max_camera_tilt_angle_degrees * _wall_direction_sign_on_enter
		var dur = 1.0 / max(tilt_speed, 0.1)
		_tilt_tween.tween_property(player_character.player_neck, "rotation_degrees:z", target_z, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _untilt_camera() -> void:
	if player_character and player_character.player_neck and enable_camera_tilt:
		if _tilt_tween and _tilt_tween.is_valid():
			_tilt_tween.kill()
		_tilt_tween = player_character.create_tween()
		var dur = 1.0 / max(tilt_speed, 0.1)
		_tilt_tween.tween_property(player_character.player_neck, "rotation_degrees:z", 0.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _perform_wall_jump(_player_info: PlayerInfo, move_direction: Vector3) -> void:
	var wall_norm = _wall_query_detection_result["wall_normal"]
	var jump_h_dir = (move_direction + wall_norm).normalized()
	var horizontal_jump_velocity = jump_h_dir * wall_jump_horizontal_force
	var vertical_jump_velocity = player_character.global_transform.basis.y * wall_jump_upward_force
	_player_info.velocity = horizontal_jump_velocity + vertical_jump_velocity
	
	# Emit signal for camera effect (side: 1 for right wall, -1 for left wall)
	var side = _wall_query_detection_result.get("wall_side", 1)
	_player_info.wall_jumped.emit(float(side))
	
	# Store the wall normal at the exact moment of jumping
	_player_info.last_wall_run_normal = wall_norm
	_has_wall_jumped = true
	_player_info.jump_count += 1
	_last_wall_jump_time = Time.get_ticks_msec() / 1000.0

func _physics_update(_delta: float, _player_info: PlayerInfo) -> void:
	_wall_run_timer += _delta
	
	# Re-query wall detection each physics frame
	_query_wall_detection(_player_info)
	if not _wall_query_detection_result["wall_detected"]:
		_lost_wall_time += _delta
	else:
		_lost_wall_time = 0.0
		
	var move_direction: Vector3 = _get_wall_run_direction(_player_info)
	var target_speed = clamp(_player_info.max_run_speed + wall_run_speed_boost, 0.0, wall_run_max_speed)
	var target_velocity = move_direction * target_speed
	
	# Accelerate towards target velocity without wiping out velocity
	var current_velocity = _player_info.velocity
	var accel = PhysicsUtils.accelerate_toward(current_velocity, target_velocity, _player_info.acceleration, _delta)
	_player_info.velocity += accel * _delta
	
	# Keep player securely attached to the wall
	_apply_wall_normal_force(_player_info)
	
	# Jump mid wall run
	if _player_info.jump_pressed:
		_perform_wall_jump(_player_info, move_direction)
