class_name VaultMaltAndClimbState
extends MovementState

enum ParkourAction {NONE, VAULT, CLIMB}

@export_category("Toggle Options")
@export var enable_vault_malt: bool = true
@export var enable_ledge_climb: bool = true
@export var use_impulse_vault: bool = true # Set true to test Minecraft-style impulse vault!


@export_category("Common Parameters")
@export var player_height: float = 1.9
@export_flags_3d_physics var collision_layers_to_check: int = 1

@export_category("Vault and Malt Parameters")
@export var vault_distance: float = 0.5
@export var vault_detection_distance: float = 0.5
@export var max_height_of_obstacle_to_vault: float = 1.7
@export var min_depth_for_malt: float = 1.0
@export var vault_boost: float = 0.0
@export var vault_upward_boost: float = 0.0

@export_category("Ledge Climb Parameters")
@export var max_climb_height: float = 2.4
@export var player_width: float = 1.2
@export var ledge_detection_distance: float = 0.5

@export_category("Durations")
@export var vault_time: float = 0.125
@export var mantle_time: float = 0.28
@export var climb_time: float = 1.0

var _current_action: ParkourAction = ParkourAction.NONE
var _is_executing: bool = false
var _vault_query_result: Dictionary = {
	"obstacle_detected": false,
	"obstacle_position_at_contact": Vector3.ZERO,
	"obstacle_top_position_at_contact": Vector3.ZERO,
	"obstacle_top_position_at_malt_depth": Vector3.ZERO,
	"landing_position": Vector3.ZERO,
}
var _climb_query_result: Dictionary = {
	"ledge_detected": false,
	"ledge_top_point_at_contact": Vector3.ZERO,
	"landing_position": Vector3.ZERO,
	"is_landing_zone_available": false,
}

func _can_enter(_player_info: PlayerInfo) -> bool:
	_get_vault_and_malt_query_results()
	_get_ledge_climb_query_results()
	DebugConsole.watch("Vault Query Result", _vault_query_result)
	DebugConsole.watch("Ledge Query Result", _climb_query_result)
	_current_action = _check_which_action_can_be_performed(_vault_query_result, _climb_query_result)
	return _current_action != ParkourAction.NONE and Input.is_action_just_pressed("jump")

func _can_exit(_player_info: PlayerInfo) -> bool:
	return !_is_executing

func _on_enter(player_info: PlayerInfo) -> void:
	if _current_action == ParkourAction.VAULT:
		player_info.is_vaulting = true
		if use_impulse_vault:
			_perform_impulse_vault(player_info)
		else:
			_perfrom_vault_or_malt(player_info)

	elif _current_action == ParkourAction.CLIMB:
		player_info.is_climbing = true
		_perform_climb(player_info)

func _on_exit(player_info: PlayerInfo) -> void:
	player_info.is_vaulting = false
	player_info.is_climbing = false
	pass

func _physics_update(delta: float, player_info: PlayerInfo) -> void:
	pass

func _get_vault_and_malt_query_results() -> void:
	if not enable_vault_malt:
		return
	if not player_character:
		return

	var space := player_character.get_world_3d().direct_space_state
	var forward := -player_character.global_transform.basis.z.normalized()
	var origin := player_character.global_position

	# Vault & Malt  Wall Detection forward from player half height
	var fwd_ray_from: Vector3 = origin + Vector3.UP * (player_height / 2)
	var fwd_ray_to: Vector3 = fwd_ray_from + forward * (vault_detection_distance + player_width)
	var fwd_ray_query_parameter = PhysicsRayQueryParameters3D.create(fwd_ray_from, fwd_ray_to, collision_layers_to_check, [player_character.get_rid()])
	var fwd_result: Dictionary = space.intersect_ray(fwd_ray_query_parameter)
	if fwd_result.is_empty():
		_vault_query_result["obstacle_detected"] = false
		_vault_query_result["obstacle_position_at_contact"] = fwd_ray_to
		return
	else:
		_vault_query_result["obstacle_detected"] = true
		_vault_query_result["obstacle_position_at_contact"] = fwd_result["position"]
	
	# Ray down from player height to the detected wall height position, nudged slightly forward into the wall
	var nudge: Vector3 = forward * 0.05
	var apex_ray_from: Vector3 = fwd_result["position"] + nudge + Vector3.UP * player_height
	var apex_ray_to: Vector3 = fwd_result["position"] + nudge - Vector3.UP * 0.01
	var apex_ray_query_parameter = PhysicsRayQueryParameters3D.create(apex_ray_from, apex_ray_to, collision_layers_to_check, [player_character.get_rid()])
	var apex_result: Dictionary = space.intersect_ray(apex_ray_query_parameter)
	if apex_result.is_empty():
		_vault_query_result["obstacle_top_position_at_contact"] = apex_ray_to
	else:
		_vault_query_result["obstacle_top_position_at_contact"] = apex_result["position"]
	
	# Query to find top of the obstacle at malt depth
	# Ray from player height to wall contact at forward offset of 'min_depth_for_malt'
	var malt_depth_ray_from: Vector3 = fwd_result["position"] + forward * min_depth_for_malt + Vector3.UP * player_height
	var malt_depth_ray_to: Vector3 = (fwd_result["position"] + forward * min_depth_for_malt) - (Vector3.UP * 0.01)
	var malt_depth_ray_query_parameter = PhysicsRayQueryParameters3D.create(malt_depth_ray_from, malt_depth_ray_to, collision_layers_to_check, [player_character.get_rid()])
	var malt_depth_result: Dictionary = space.intersect_ray(malt_depth_ray_query_parameter)
	if malt_depth_result.is_empty():
		_vault_query_result["obstacle_top_position_at_malt_depth"] = malt_depth_ray_to
	else:
		_vault_query_result["obstacle_top_position_at_malt_depth"] = malt_depth_result["position"]

	# Landing position detection
	# Ray down from player height to ground at vault distance
	var landing_ray_from: Vector3 = fwd_result["position"] + forward * vault_distance + Vector3.UP * player_height
	var landing_ray_to: Vector3 = (fwd_result["position"] + forward * vault_distance) - (Vector3.UP * 0.01)
	var landing_ray_query_parameter = PhysicsRayQueryParameters3D.create(landing_ray_from, landing_ray_to, collision_layers_to_check, [player_character.get_rid()])
	var landing_result: Dictionary = space.intersect_ray(landing_ray_query_parameter)
	if landing_result.is_empty():
		_vault_query_result["landing_position"] = landing_ray_to
	else:
		_vault_query_result["landing_position"] = landing_result["position"]

func _get_ledge_climb_query_results() -> void:
	if not enable_ledge_climb:
		return
	if not player_character:
		return

	var space := player_character.get_world_3d().direct_space_state
	var forward := -player_character.global_transform.basis.z.normalized()
	var origin := player_character.global_position

	# Ledge Climb Detection Ray
	var fwd_ray_from: Vector3 = origin + Vector3.UP * player_height
	var fwd_ray_to: Vector3 = fwd_ray_from + forward * (ledge_detection_distance + player_width)
	var fwd_ray_query_parameter = PhysicsRayQueryParameters3D.create(fwd_ray_from, fwd_ray_to, collision_layers_to_check, [player_character.get_rid()])
	var fwd_result: Dictionary = space.intersect_ray(fwd_ray_query_parameter)
	if fwd_result.is_empty():
		_climb_query_result["ledge_detected"] = false
		_climb_query_result["ledge_top_point_at_contact"] = Vector3.ZERO
		_climb_query_result["landing_position"] = Vector3.ZERO
		return
	else:
		_climb_query_result["ledge_detected"] = true
	
	# Ray down from above the wall to find the ledge top edge (nudged 5cm into the obstacle)
	var nudge: Vector3 = forward * 0.05
	var ledge_top_ray_from: Vector3 = fwd_result["position"] + nudge + Vector3.UP * max_climb_height
	var ledge_top_ray_to: Vector3 = fwd_result["position"] + nudge - Vector3.UP * 0.5
	var ledge_top_ray_query_parameter = PhysicsRayQueryParameters3D.create(ledge_top_ray_from, ledge_top_ray_to, collision_layers_to_check, [player_character.get_rid()])
	var ledge_top_result: Dictionary = space.intersect_ray(ledge_top_ray_query_parameter)
	if ledge_top_result.is_empty():
		_climb_query_result["ledge_top_point_at_contact"] = fwd_result["position"] + Vector3.UP * 0.2
	else:
		_climb_query_result["ledge_top_point_at_contact"] = ledge_top_result["position"]

	var ledge_surface_y: float = _climb_query_result["ledge_top_point_at_contact"].y

	# Landing position detection: 0.4m into the ledge, casting down through the ledge surface
	var landing_depth: float = 0.4
	var landing_ray_from: Vector3 = fwd_result["position"] + forward * landing_depth
	landing_ray_from.y = ledge_surface_y + 1.0
	var landing_ray_to: Vector3 = landing_ray_from - Vector3.UP * 1.5
	var landing_ray_query_parameter = PhysicsRayQueryParameters3D.create(landing_ray_from, landing_ray_to, collision_layers_to_check, [player_character.get_rid()])
	var landing_result: Dictionary = space.intersect_ray(landing_ray_query_parameter)
	if landing_result.is_empty():
		_climb_query_result["landing_position"] = Vector3(landing_ray_from.x, ledge_surface_y, landing_ray_from.z)
	else:
		_climb_query_result["landing_position"] = landing_result["position"]

	
func _check_which_action_can_be_performed(vault_query_result: Dictionary, climb_query_result: Dictionary) -> ParkourAction:
	# Climbing takes priority over vaulting
	if climb_query_result["ledge_detected"]:
		# check if there is any obstacle for climbing
		# Test move character by first lifting the character to landing height and translating to landing position
		var start_transform = player_character.global_transform
		start_transform.origin.y = climb_query_result["landing_position"].y + 0.01 # small buffer of 0.01
		var motion: Vector3 = climb_query_result["landing_position"] - start_transform.origin
		if not player_character.test_move(start_transform, motion):
			return ParkourAction.CLIMB
	
	if vault_query_result["obstacle_detected"]:
		# Check if obstacle is too high to vault
		var obstacle_height: float = (vault_query_result["obstacle_top_position_at_contact"] - vault_query_result["obstacle_position_at_contact"]).length() + (player_height / 2.0)
		if obstacle_height > max_height_of_obstacle_to_vault:
			return ParkourAction.NONE
		# Make sure player don't vault or malt of a steep inclined slope
		# Check if malting position is significantly higher than the initial vault height
		var malt_point_to_intital_point_difference: float = (vault_query_result["obstacle_top_position_at_malt_depth"] - vault_query_result["obstacle_position_at_contact"]).length()
		var is_malt_point_heigher: bool = vault_query_result["obstacle_top_position_at_malt_depth"].y > vault_query_result["obstacle_position_at_contact"].y
		if malt_point_to_intital_point_difference > max_height_of_obstacle_to_vault and is_malt_point_heigher:
			return ParkourAction.NONE
		return ParkourAction.VAULT
	
	return ParkourAction.NONE
	
func _perfrom_vault_or_malt(player_info: PlayerInfo) -> void:
	_is_executing = true
	player_character._toggle_to_crouch_collider()
	var offset: Vector3 = Vector3(0, player_height / 2, 0)
	var peak_position: Vector3 = _vault_query_result["obstacle_top_position_at_contact"] + offset
	var landing_position: Vector3 = _vault_query_result["landing_position"]
	if landing_position.y > _vault_query_result["obstacle_top_position_at_malt_depth"].y:
		landing_position = _vault_query_result["obstacle_top_position_at_malt_depth"] + Vector3(0, 0.1, 0)
	var tween := player_character.create_tween().set_parallel(false)
	var cam_tween := player_character.create_tween().set_parallel(false)
	var base_neck_y := player_character.player_neck.position.y
	# tween.tween_property(player_character, "global_position", peak_position, vault_time)\
	# 	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(player_character, "global_position", landing_position, vault_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Quick dip
	cam_tween.tween_property(player_character.player_neck, "position:y", base_neck_y - 0.1, vault_time * 0.3)
	cam_tween.tween_property(player_character.player_neck, "position:y", base_neck_y, vault_time * 0.7)

	await tween.finished
	player_character._toggle_to_standing_collider()
	# Momentum handoff
	var forward := -player_character.global_transform.basis.z.normalized()
	player_info.velocity = forward * max(player_info.max_walk_speed, player_info.velocity.length())
	_is_executing = false

## Minecraft-style physics impulse vault (morph hitbox + step-assist lift + additive velocity impulse)
func _perform_impulse_vault(player_info: PlayerInfo) -> void:
	_is_executing = true
	# 1. Morph hitbox height to crouch shape so it clears the obstacle lip
	player_character._toggle_to_crouch_collider()

	var forward := -player_character.global_transform.basis.z.normalized()
	var obstacle_top_y: float = _vault_query_result["obstacle_top_position_at_contact"].y
	var lift_needed: float = max(0.0, obstacle_top_y - player_character.global_position.y + 0.05)

	# 2. Step-assist: pop capsule Y over the lip and nudge 15cm forward past front face
	if lift_needed > 0.0:
		player_character.global_position.y += lift_needed
	player_character.global_position += forward * 0.15

	# 3. Additive Velocity Impulse: keeps full sprint momentum and adds the forward vault boost
	var current_h_speed: float = Vector2(player_info.velocity.x, player_info.velocity.z).length()
	var launch_h_speed: float = max(current_h_speed + vault_boost, player_info.max_run_speed + vault_boost)
	player_info.velocity.x = forward.x * launch_h_speed
	player_info.velocity.z = forward.z * launch_h_speed
	player_info.velocity.y = max(player_info.velocity.y, vault_upward_boost)

	# 4. Decoupled visual camera dip (purely visual feel, zero interference with physics)
	var base_neck_y := player_character.player_neck.position.y
	var cam_tween := player_character.create_tween().set_parallel(false)
	cam_tween.tween_property(player_character.player_neck, "position:y", base_neck_y - 0.12, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	cam_tween.tween_property(player_character.player_neck, "position:y", base_neck_y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 5. Let move_and_slide() drive the character through the air without position fighting
	await player_character.get_tree().create_timer(vault_time * 0.75).timeout

	if player_character.can_uncrouch():
		player_character._toggle_to_standing_collider()

	_is_executing = false

func _perform_climb(player_info: PlayerInfo) -> void:
	_is_executing = true
	var offset: Vector3 = Vector3(0, player_height / 2, 0)
	var peak_position: Vector3 = _climb_query_result["ledge_top_point_at_contact"] + offset
	var landing_position: Vector3 = _climb_query_result["landing_position"]
	
	var tween := player_character.create_tween().set_parallel(false)
	var cam_tween := player_character.create_tween().set_parallel(false)
	var base_neck_y := player_character.player_neck.position.y
	tween.tween_property(player_character, "global_position", peak_position, climb_time * 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(player_character, "global_position", landing_position, climb_time * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Pronounced camera pitch/pull for climb exertion
	cam_tween.tween_property(player_character.player_neck, "position:y", base_neck_y - 0.22, climb_time * 0.5)
	cam_tween.tween_property(player_character.player_neck, "position:y", base_neck_y, climb_time * 0.5)
	
	await tween.finished
	_is_executing = false