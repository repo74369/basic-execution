class_name FPSPlayer
extends CharacterBody3D

@export var player_info: PlayerInfo = PlayerInfo.new()
@export var movement_controller: MovementController
@export var look_controller: LookController
@export var player_neck: Node3D
@export var player_camera: Camera3D
@export var crouch_collider: CollisionShape3D
@export var standing_collider: CollisionShape3D
@export var standing_eye_height: float = 1.65
@export var crouch_eye_height: float = 0.65
@export var custom_gravity: float = -15.0
@export var fast_fall_multiplier: float = 2.5

@export_category("Stairs and Small Obstacles Climb")
@export var enble_stairs_climbing: bool = true
@export var max_step_height: float = 0.35
@export var min_step_height: float = 0.01
@export var camera_smooth_speed_while_stairs_climbing: float = 16.0


signal player_crouched
signal player_uncrouched

func _toggle_to_crouch_collider() -> void:
	crouch_collider.disabled = false
	standing_collider.disabled = true

func _toggle_to_standing_collider() -> void:
	crouch_collider.disabled = true
	standing_collider.disabled = false

func _ready() -> void:
	if not player_neck:
		if not player_camera:
			push_error("Either player neck or camera needs to be assigned in order to set ")
		player_neck = player_camera
	else:
		player_neck.position.y = standing_eye_height
	floor_snap_length = max_step_height
		

func crouch() -> void:
	if not player_neck:
		push_error("Set player neck for crouch to work properly")
		return
   
	_toggle_to_crouch_collider()
	var tween := create_tween()
	tween.tween_property(player_neck, "position:y", crouch_eye_height, 0.1)
	await tween.finished
	player_crouched.emit()

func uncrouch() -> void:
	if not player_neck:
		push_error("Set player neck for uncrouch to work properly")
		return
	_toggle_to_standing_collider()
	var tween := create_tween()
	tween.tween_property(player_neck, "position:y", standing_eye_height, 0.1)
	player_uncrouched.emit()

func can_uncrouch() -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
    
	query.shape = crouch_collider.shape # Use crouch collider and displace it to 1m above
	query.transform = global_transform
	query.transform = query.transform.translated(Vector3(0, standing_eye_height - crouch_eye_height, 0))
	query.exclude = [self.get_rid()]
	query.collision_mask = collision_mask
    
	var results := space.intersect_shape(query, 1)
	return results.is_empty()

# CHeck if step up is possible using test move
func step_up_check(move_step: Vector3) -> void:
	# Takes in horizontal move step and checks if player can step up
	# Return if character is not on floor or move steop is zero
	DebugConsole.watch("move step", move_step, Color.RED)

	if not is_on_floor() or move_step.is_zero_approx():
		return
	
	var check_dist: float = max(move_step.length(), 0.15) # 0.15 is minimum distance check
	move_step = move_step.normalized() * check_dist
	var test_collision: KinematicCollision3D = KinematicCollision3D.new()

	# Test move move_step location to check if ther is obstacle
	if not test_move(global_transform, move_step, test_collision):
		return
	
	# If there is collision make sure it's not a slope/ramp (move and slide already handles that)
	if test_collision.get_normal().angle_to(up_direction) <= floor_max_angle:
		return
	
	# Check if enough head space is there for player to step up
	var up_translation = Vector3.UP * max_step_height
	var up_transform = global_transform
	if test_move(up_transform, up_translation, test_collision):
		return # There is an obstacle on head
	
	up_transform = up_transform.translated(up_translation)

	# Test forward movement at the elevated height
	if test_move(up_transform, move_step, test_collision):
		return # There is an obstacle in move_step direction

	var forward_transform = up_transform.translated(move_step)

	# Probe down to find landing surface
	var step_down_vector: Vector3 = Vector3(0, - (max_step_height + 0.05), 0)
	if not test_move(forward_transform, step_down_vector, test_collision):
		return # No landing area detected
	
	# Verify the landing surface is walkable floor (not a steep angled mesh or wall)
	if test_collision.get_normal().angle_to(up_direction) > floor_max_angle:
		return

	# Calculate net vertical rise
	var down_travel_y: float = test_collision.get_travel().y # get_travel returns the vector moved before collision is detected
	var step_hight_diff: float = max_step_height + down_travel_y # down_travel_y will be negative

	# Minimum height check
	if step_hight_diff < min_step_height:
		return
	
	global_position.y += step_hight_diff
	
	apply_camera_step_smoothing(step_hight_diff)
	DebugConsole.watch("step height diff", step_hight_diff, Color.RED)

	return

func apply_camera_step_smoothing(step_height_diff: float) -> void:
	if not player_neck:
		return
	
	player_neck.position.y -= step_height_diff

func update_camera_step_smoothing(delta) -> void:
	if not player_neck:
		return
	
	# Target eye height depends on whether crouching or standing
	var target_eye_height = crouch_eye_height if player_info.is_crouching else standing_eye_height
	
	if not is_equal_approx(player_neck.position.y, target_eye_height):
		# Smoothly decay the offset back to target height
		player_neck.position.y = lerp(player_neck.position.y, target_eye_height, delta * camera_smooth_speed_while_stairs_climbing)