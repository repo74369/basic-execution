class_name MovementController
extends HStateMachine

var player_character: FPSPlayer
var player_info: PlayerInfo

var _is_crouching: bool = false
var _is_sprinting: bool = false


func _ready() -> void:
	var parent = get_parent() as FPSPlayer
	player_info = parent.player_info
	if not parent is FPSPlayer:
		push_error("MovementController parent must be an FPSPlayer")
		return
	player_character = parent

	# 1. Initialize states hierarchy first so all child arrays are populated
	_init_states(player_info)

	# 2. Propagate player_character down from parent to children (cascades recursively)
	for state in _states:
		if state is MovementState:
			state.player_character = player_character
	
	initialize_default_player_action_variables()
	
func initialize_default_player_action_variables() -> void:
	player_info.is_vaulting = false
	player_info.is_climbing = false
	player_info.is_sliding = false
	player_info.is_dashing = false
	player_info.is_in_air_state = false
	

func _physics_process(delta: float) -> void:
	_update_player_context()

	physics_update(delta, player_info)

	# Apply gravity when not on floor
	if not player_character.is_on_floor():
		player_info.velocity += Vector3(0, player_character.custom_gravity, 0) * delta

	player_character.velocity = player_info.velocity
	DebugConsole.watch("player_velocity", player_info.velocity, Color.YELLOW)
	player_character.move_and_slide()
	player_info.velocity = player_character.velocity  # write back corrected velocity


func _process(delta: float) -> void:
	update(delta, player_info)


# ---------------------------------------------------------------------------
# Input + physics context — resolved once per frame, written into player_info
# ---------------------------------------------------------------------------

func _update_player_context() -> void:
	# Crouch
	if Settings.setting_data.toggle_crouch:
		if Input.is_action_just_pressed("crouch"):
			_is_crouching = not _is_crouching
	else:
		_is_crouching = Input.is_action_pressed("crouch")
	player_info.is_crouching = _is_crouching

	# Sprint
	if Settings.setting_data.toggle_sprint:
		if Input.is_action_just_pressed("sprint"):
			_is_sprinting = not _is_sprinting
	else:
		_is_sprinting = Input.is_action_pressed("sprint")
	player_info.is_sprinting = _is_sprinting

	# Movement & jump
	player_info.input_dir     = Input.get_vector("move_left", "move_right", "move_down", "move_up").normalized()
	player_info.jump_pressed  = Input.is_action_just_pressed("jump")
	player_info.jump_released = Input.is_action_just_released("jump")

	# Physics
	player_info.is_on_floor   = player_character.is_on_floor()
	player_info.is_on_ceiling = player_character.is_on_ceiling()
	player_info.floor_normal  = player_character.get_floor_normal()
	player_info.current_speed = player_character.velocity.length()
	