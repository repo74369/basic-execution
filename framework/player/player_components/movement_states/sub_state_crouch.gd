class_name CrouchSubState
extends MovementState


func _can_enter(player_info: PlayerInfo) -> bool:
    return player_info.is_crouching

func _can_exit(player_info: PlayerInfo) -> bool:
    if not player_info.is_crouching:
        return player_character.can_uncrouch()
    return true

func _on_enter(player_info: PlayerInfo) -> void:
    player_info.is_sprinting = false
    player_character.crouch()

func _on_exit(player_info: PlayerInfo) -> void:
    player_character.uncrouch()
    player_info.is_crouching = false

func _physics_update(delta: float, player_info: PlayerInfo) -> void:
    if not player_info.is_crouching and not player_character.can_uncrouch():
        player_info.is_crouching = true

    var forward: Vector3 = -player_character.global_transform.basis.z
    var right: Vector3 = player_character.global_transform.basis.x
    var move_dir: Vector3 = (forward * player_info.input_dir.y + right * player_info.input_dir.x).normalized()

    var target_velocity: Vector3 = move_dir * player_info.max_crouch_speed
    target_velocity.y = player_info.velocity.y
    var current_velocity: Vector3 = player_info.velocity
    var acceleration: Vector3 = PhysicsUtils.accelerate_toward(current_velocity, target_velocity, player_info.acceleration, delta)
    player_info.velocity += acceleration * delta
