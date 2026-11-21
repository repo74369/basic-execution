class_name SprintSubState
extends MovementState


func _can_enter(player_info: PlayerInfo) -> bool:
    return player_info.is_sprinting

func _on_enter(player_info: PlayerInfo) -> void:
    player_info.is_crouching = false

func _physics_update(delta: float, player_info: PlayerInfo) -> void:
    var forward: Vector3 = -player_character.global_transform.basis.z
    var right: Vector3 = player_character.global_transform.basis.x
    var move_dir: Vector3 = (forward * player_info.input_dir.y + right * player_info.input_dir.x).normalized()

    var target_velocity: Vector3 = move_dir * player_info.max_run_speed
    target_velocity.y = player_info.velocity.y
    var current_velocity: Vector3 = player_info.velocity
    var acceleration: Vector3 = PhysicsUtils.accelerate_toward(current_velocity, target_velocity, player_info.acceleration, delta)
    player_info.velocity += acceleration * delta