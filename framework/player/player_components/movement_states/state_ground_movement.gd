class_name GroundMovementState
extends MovementState


func _can_enter(player_info: PlayerInfo) -> bool:
	return player_info.is_on_floor

func _can_exit(_player_info: PlayerInfo) -> bool:
	return true

func _on_exit(player_info: PlayerInfo) -> void:
	player_info.is_sprinting = false
	player_info.is_crouching = false

func _physics_update(delta: float, player_info: PlayerInfo) -> void:
	if player_info.jump_pressed:
		player_info.jump_count += 1
		player_info.velocity.y += player_info.jump_speed
	super._physics_update(delta,player_info)
