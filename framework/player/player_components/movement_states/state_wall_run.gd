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
@export var wall_jump_horizontal_force: float = 8.0
@export var wall_jump_upward_force: float = 12.0
@export_flags_3d_physics var wall_collision_mask: int = 1

@export_category("Camera Tilt")
@export var enable_camera_tilt: bool = true
@export var max_camera_tilt_angle_degrees: float = 15.0
@export var tilt_speed: float = 5.0

var _wall_query_detection_result: Dictionary = {
    "wall_detected": false,
    "wall_normal": Vector3.ZERO,
    "wall_collision_point": Vector3.ZERO,
    "wall_forward": Vector3.ZERO
}

var _player_custom_gravity_before_start: float
var _wall_direction_sign_on_enter: float = 0.0

func _on_enter(_player_info: PlayerInfo) -> void:
    if player_character:
        _player_custom_gravity_before_start = player_character.custom_gravity
        if influence_by_gravity:
            player_character.custom_gravity = reduced_gravity
        else:
            player_character.custom_gravity = 0.0
        if _wall_query_detection_result["wall_detected"]:
            var player_forward = - player_character.global_transform.basis.z
            var player_up = player_character.global_transform.basis.y
            var wall_tangent = player_up.cross(_wall_query_detection_result["wall_normal"])
            if wall_tangent.dot(player_forward) > 0:
                _wall_direction_sign_on_enter = 1.0
            else:
                _wall_direction_sign_on_enter = -1.0

func _on_exit(_player_info: PlayerInfo) -> void:
    if player_character:
        player_character.custom_gravity = _player_custom_gravity_before_start
        

func _query_wall_detection(_player_info: PlayerInfo) -> void:
    if not player_character:
        return
    var space = player_character.get_world_3d().direct_space_state
    var origin = player_character.global_position
    var forward = - player_character.global_transform.basis.z
    var right = player_character.global_transform.basis.x

    # Detect wall to the left
    var left_ray_start = origin - (right * player_half_width)
    var left_ray_end = left_ray_start - (right * wall_detection_range)
    var left_query_params = PhysicsRayQueryParameters3D.create(left_ray_start, left_ray_end, wall_collision_mask, [player_character.get_rid()])
    var left_query_result = space.intersect_ray(left_query_params)
    if left_query_result:
        _wall_query_detection_result["wall_detected"] = true
        _wall_query_detection_result["wall_normal"] = left_query_result["normal"]
        _wall_query_detection_result["wall_collision_point"] = left_query_result["position"]
        _wall_query_detection_result["wall_forward"] = forward
        return
    else:
        _wall_query_detection_result["wall_detected"] = false
    
    # Detect wall to the right
    var right_ray_start = origin + (right * player_half_width)
    var right_ray_end = right_ray_start + (right * wall_detection_range)
    var right_query_params = PhysicsRayQueryParameters3D.create(right_ray_start, right_ray_end, wall_collision_mask, [player_character.get_rid()])
    var right_query_result = space.intersect_ray(right_query_params)
    if right_query_result:
        _wall_query_detection_result["wall_detected"] = true
        _wall_query_detection_result["wall_normal"] = right_query_result["normal"]
        _wall_query_detection_result["wall_collision_point"] = right_query_result["position"]
        _wall_query_detection_result["wall_forward"] = forward
        return
    else:
        _wall_query_detection_result["wall_detected"] = false
    
func _get_wall_run_direction(_player_info: PlayerInfo) -> Vector3:
    if not player_character:
        return Vector3.ZERO
    
    var base_direction: Vector3 = player_character.global_transform.basis.y.cross(_wall_query_detection_result["wall_normal"])

    var horizontal_direction: Vector3
    
    if allow_direction_reversal:
        var is_facing_forward: bool = - player_character.global_transform.basis.z.dot(base_direction) > 0.0
        if is_facing_forward:
            horizontal_direction = base_direction
        else:
            horizontal_direction = - base_direction
    else:
        horizontal_direction = base_direction * _wall_direction_sign_on_enter
    
    var final_move_direction: Vector3 = horizontal_direction.normalized()
    if allow_look_influence and player_character.player_neck and virtical_look_influence > 0.0:
        var wall_up_slope = _wall_query_detection_result["wall_normal"].cross(horizontal_direction)
        var look_dir = - player_character.player_neck.global_transform.basis.z
        # check if looking up or down
        var pitch_factor: float = look_dir.dot(player_character.global_transform.basis.y)
        
        var vertical_influence: Vector3 = wall_up_slope * (pitch_factor * virtical_look_influence)
        final_move_direction = (horizontal_direction + vertical_influence).normalized()
    
    return final_move_direction

func _physics_update(_delta: float, _player_info: PlayerInfo) -> void:
    var move_dirction: Vector3 = _get_wall_run_direction(_player_info)
