class_name MovementState
extends HState

## Injected by parent and propagated down to all child MovementStates recursively.
var player_character: FPSPlayer:
	set(value):
		player_character = value
		for state in _states:
			if state is MovementState:
				state.player_character = value


# ---------------------------------------------------------------------------
# HState interface — DO NOT override in subclasses. Bridges to typed hooks below.
# ---------------------------------------------------------------------------

func can_enter(context: Resource) -> bool:
	return _can_enter(context as PlayerInfo)

func _can_exit_self(context: Resource) -> bool:
	return _can_exit(context as PlayerInfo)

func enter(context: Resource) -> void:
	super(context)
	_on_enter(context as PlayerInfo)

func exit(context: Resource) -> void:
	_on_exit(context as PlayerInfo)
	super(context)

func physics_update(delta: float, context: Resource) -> void:
	super(delta, context)
	_physics_update(delta, context as PlayerInfo)

func update(delta: float, context: Resource) -> void:
	super(delta, context)
	_update(delta, context as PlayerInfo)


# ---------------------------------------------------------------------------
# Typed hooks — override these in subclasses
# ---------------------------------------------------------------------------

func _can_enter(_player_info: PlayerInfo) -> bool:
	return false

func _can_exit(_player_info: PlayerInfo) -> bool:
	return true

func _on_enter(_player_info: PlayerInfo) -> void:
	pass

func _on_exit(_player_info: PlayerInfo) -> void:
	pass

## Called every physics tick after child sub-states have run.
## Write velocity to player_info.velocity — do NOT call move_and_slide().
func _physics_update(_delta: float, _player_info: PlayerInfo) -> void:
	pass

## Called every frame tick (for camera tilt, visuals, animations).
func _update(_delta: float, _player_info: PlayerInfo) -> void:
	pass
