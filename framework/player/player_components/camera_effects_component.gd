class_name CameraEffectsComponent
extends Node

@export_category("Spring Settings")
@export var translation_stiffness: float = 240.0
@export var translation_damping: float = 18.0
@export var rotation_stiffness: float = 200.0
@export var rotation_damping: float = 16.0
@export var effects_hinge: Node3D = null

@export_category("Head Bob")
@export var head_bob: bool = true
@export var min_speed_for_bob: float = 1.0
@export var walk_bob_speed: float = 7.0
@export var sprint_bob_speed: float = 10.0

@export var walk_bob_frequency: float = 12.0
@export var walk_bob_amplitude: Vector2 = Vector2(0.03, 0.02) # X (horizontal), Y (vertical)
@export var walk_bob_roll_intensity: float = 0.015 # Radians of roll (Z axis tilt)

@export var sprint_bob_frequency: float = 15.0
@export var sprint_bob_amplitude: Vector2 = Vector2(0.06, 0.04)
@export var sprint_bob_roll_intensity: float = 0.03

@export_category("Strafe Tilt")
@export var strafe_tilt: bool = true
@export var strafe_tilt_angle: float = 2.0 ## Max tilt angle in degrees when strafing
@export var strafe_tilt_speed: float = 8.0 ## How quickly the tilt interpolates (higher = snappier)

@export_category("Jump Kick")
@export var jump_kick_translation_impulse: Vector3 = Vector3(0.0, -0.15, 0.03) # Downward dip, backward kick
@export var jump_kick_rotation_impulse: Vector3 = Vector3(deg_to_rad(-2.0), 0.0, 0.0) # Pitch up initially

@export_category("Landing Kick")
@export var fall_kick: bool = true
@export var land_kick_translation_factor: float = 0.015 # translation Y offset per unit of vertical velocity
@export var land_kick_rotation_factor: float = 0.006 # pitch rotation per unit of vertical velocity
@export var max_land_kick_translation: float = 0.20
@export var max_land_kick_rotation: float = deg_to_rad(5.0)

@export_category("Speed FOV Effect")
@export var speed_effect_fov: bool = true
@export var min_payer_speed_for_fov_threshold: float = 7.0
@export var max_player_speed_for_fov_threshold: float = 10.0
@export var max_fov_change: float = 10.0

@export_category("Wall Jump Kick")
@export var wall_roll_tilt_impulse: float = deg_to_rad(6.0) # in radians
@export var wall_pitch_up_impulse: float = deg_to_rad(1.0)
@export var wall_fov_pop: float = 8.0

@export_category("Damage Kick")
@export var damage_translation_factor: float = 0.01
@export var damage_rotation_factor: float = 0.006
@export var max_damage_translation: float = 0.20
@export var max_damage_rotation: float = deg_to_rad(5.0)

# Springs for procedural recoil/kicks
class Spring3D:
	var current: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var target: Vector3 = Vector3.ZERO
	var stiffness: float = 200.0
	var damping: float = 15.0
	
	func _init(p_stiffness: float, p_damping: float) -> void:
		stiffness = p_stiffness
		damping = p_damping
		
	func update(delta: float) -> Vector3:
		# We run this calculation 3 times per frame using a smaller slice of time (step_delta). 
		# This is a game development trick: if the game suddenly lags, a normal spring calculation might 
		# overshoot and explode (fly off to infinity). Sub-stepping keeps the physics 100% stable at any framerate.
		var steps = 3
		var step_delta = delta / steps
		for i in range(steps):
			var accel = (target - current) * stiffness - velocity * damping
			velocity += accel * step_delta
			current += velocity * step_delta
		return current
		
	func apply_impulse(impulse: Vector3) -> void:
		velocity += impulse

var translation_spring: Spring3D
var rotation_spring: Spring3D

# Phase accumulator for head bobbing (eliminates speed-change phase jumps)
var bob_phase: float = 0.0

# Dynamic head bob amplitude and roll states (to smooth start/stops)
var current_bob_amp: Vector2 = Vector2.ZERO
var current_bob_roll: float = 0.0
var current_strafe_tilt: float = 0.0

# Landing detection helper variables
var was_on_floor: bool = true
var max_falling_speed: float = 0.0

var default_fov: float = 75.0

var player_character:FPSPlayer
var player_info:PlayerInfo
var camera:Camera3D

func _ready() -> void:
	player_character = get_parent()
	if player_character is not FPSPlayer:
		push_error("Parent must be FPSPlayer")
	camera = player_character.player_camera
	player_info = player_character.player_info
	if not effects_hinge:
		effects_hinge = camera
	if camera:
		default_fov = camera.fov
	if player_info:
		player_info.wall_jumped.connect(_on_wall_jumped)
			
	# Initialize springs with configured stiffness/damping
	translation_spring = Spring3D.new(translation_stiffness, translation_damping)
	rotation_spring = Spring3D.new(rotation_stiffness, rotation_damping)
	
	if player_info:
		player_info.recoil_weapon.connect(_add_weapon_kick)
		player_info.taking_damage.connect(_damage_kick)

func _process(delta: float) -> void:
	if not player_character or not camera:
		return
		
	# Synchronize spring properties from inspector values in case they are tweaked at runtime
	translation_spring.stiffness = translation_stiffness
	translation_spring.damping = translation_damping
	rotation_spring.stiffness = rotation_stiffness
	rotation_spring.damping = rotation_damping

	var horizontal_velocity = Vector2(player_info.velocity.x, player_info.velocity.z)
	var horizontal_speed = horizontal_velocity.length()
	
	# --- 1. Track Landing Impacts ---
	var on_floor = player_info.is_on_floor
	if not on_floor:
		# Track the maximum downward velocity while in the air
		if player_info.velocity.y < max_falling_speed:
			max_falling_speed = player_info.velocity.y
	else:
		# Just landed: only trigger landing kick on significant falls, not gentle stair steps
		var is_in_air_state = player_info.is_in_air_state
		if (not was_on_floor or is_in_air_state) and max_falling_speed < -3.5:
			_on_land(max_falling_speed)
		max_falling_speed = 0.0
		
	was_on_floor = on_floor
	
	# --- 2. Head Bobbing ---
	var target_bob_amp = Vector2.ZERO
	var target_bob_roll = 0.0
	var target_bob_freq = 0.0
	
	if head_bob and player_info.is_on_floor and horizontal_speed > min_speed_for_bob:
		if not player_info.is_vaulting and not player_info.is_climbing and not player_info.is_sliding:
			# Interpolate between walk and sprint bobs based on current speed
			var t = clamp((horizontal_speed - walk_bob_speed) / max(sprint_bob_speed - walk_bob_speed, 0.1), 0.0, 1.0)
			target_bob_amp = lerp(walk_bob_amplitude, sprint_bob_amplitude, t)
			target_bob_roll = lerp(walk_bob_roll_intensity, sprint_bob_roll_intensity, t)
			target_bob_freq = lerp(walk_bob_frequency, sprint_bob_frequency, t)
			
	# Smoothly interpolate amplitude and roll to prevent snapping on start/stop
	current_bob_amp = current_bob_amp.lerp(target_bob_amp, 12.0 * delta)
	current_bob_roll = lerp(current_bob_roll, target_bob_roll, 12.0 * delta)
	
	# Continuously accumulate phase
	bob_phase += target_bob_freq * delta
	# Keep bob_phase within reasonable bounds to prevent precision loss over time
	if bob_phase > 2.0 * PI * 1000.0:
		bob_phase -= 2.0 * PI * 1000.0
		
	# Calculate displacement offset & rotation for head bob
	var bob_offset = Vector3.ZERO
	var bob_rot = Vector3.ZERO
	if head_bob:
		# Use sin for horizontal sway, and cos for vertical/roll to keep them out of phase,
		# creating a smooth, organic circular swaying motion instead of a diagonal shake.
		bob_offset.x = sin(bob_phase) * current_bob_amp.x
		bob_offset.y = cos(bob_phase * 2.0) * current_bob_amp.y
		bob_rot.z = cos(bob_phase) * current_bob_roll

	# --- 3. Strafe Tilt ---
	var strafe_tilt_offset = Vector3.ZERO
	if strafe_tilt and player_info.is_on_floor and horizontal_speed > min_speed_for_bob:
			 
		if not player_info.is_vaulting and not player_info.is_climbing and not player_info.is_sliding:
			# Use the raw lateral input (X axis) so tilt responds to input, not velocity
			var lateral_input = player_info.input_dir.x
			# Tilt opposite to movement direction for a natural leaning feel
			var target_tilt = -lateral_input * deg_to_rad(strafe_tilt_angle)
			current_strafe_tilt = lerp(current_strafe_tilt, target_tilt, strafe_tilt_speed * delta)
		else:
			current_strafe_tilt = lerp(current_strafe_tilt, 0.0, strafe_tilt_speed * delta)
	else:
		current_strafe_tilt = lerp(current_strafe_tilt, 0.0, strafe_tilt_speed * delta)
	strafe_tilt_offset.z = current_strafe_tilt

	# --- 4. Update Spring Dynamics ---
	var spring_translation = translation_spring.update(delta)
	var spring_rotation = rotation_spring.update(delta)
	
	# --- 5. Apply Dynamic FOV ---
	if speed_effect_fov:
		var target_fov = default_fov
		if horizontal_speed > min_payer_speed_for_fov_threshold:
			var speed_diff = max_player_speed_for_fov_threshold - min_payer_speed_for_fov_threshold
			var fov_percent = (horizontal_speed - min_payer_speed_for_fov_threshold) / max(speed_diff, 0.1)
			target_fov += max_fov_change * clamp(fov_percent, 0.0, 1.5)
		camera.fov = lerp(camera.fov, target_fov, 10.0 * delta)
	else:
		camera.fov = lerp(camera.fov, default_fov, 10.0 * delta)
		
	DebugConsole.watch("Camera_FOV", camera.fov)
	
	# --- 6. Apply Transformations ---
	if effects_hinge:
		effects_hinge.position = spring_translation + bob_offset
		effects_hinge.rotation = spring_rotation + bob_rot + strafe_tilt_offset

func _on_player_jumped(is_double_jump: bool) -> void:
	var intensity_multiplier = 1.2 if is_double_jump else 1.0
	# Apply jump launch kick directly to translation and rotation spring displacement for instant responsiveness
	translation_spring.current += jump_kick_translation_impulse * intensity_multiplier
	rotation_spring.current += jump_kick_rotation_impulse * intensity_multiplier

func _on_land(velocity_y: float) -> void:
	if not fall_kick:
		return
	# velocity_y is negative (downward)
	var impact_speed = abs(velocity_y)
	
	# Proportional displacement and rotation kicks
	var trans_kick = Vector3(0.0, -impact_speed * land_kick_translation_factor, 0.0)
	var rot_kick = Vector3(impact_speed * land_kick_rotation_factor, 0.0, 0.0)
	
	# Clamp to safety limits
	trans_kick.y = clamp(trans_kick.y, -max_land_kick_translation, 0.0)
	rot_kick.x = clamp(rot_kick.x, 0.0, max_land_kick_rotation)
	
	# Add slight horizontal tilt/roll randomly based on land speed
	var roll_tilt = randf_range(-0.015, 0.015) * (impact_speed / 10.0)
	rot_kick.z = roll_tilt
	
	translation_spring.current += trans_kick
	rotation_spring.current += rot_kick

func _add_weapon_kick(h_intensity: float, v_intensity: float) -> void:
	# Add recoil directly to the rotation spring displacement for an instant kick
	# Pitch kick up (negative X), random yaw kick left/right (Y)
	var kick_pitch = deg_to_rad(-v_intensity * 1.5)
	var kick_yaw = deg_to_rad(randf_range(-h_intensity, h_intensity) * 1.5)
	rotation_spring.current += Vector3(kick_pitch, kick_yaw, 0.0)
	
	# Add a tiny backward translation recoil kick directly to translation spring displacement (Z)
	translation_spring.current += Vector3(0.0, 0.0, 0.03 * (v_intensity + h_intensity))

func _on_wall_jumped(side: float) -> void:
	# 1. Apply a violent roll kick in the opposite direction of the wall (in radians)
	# side is 1 (wall on right) or -1 (wall on left)
	var roll_tilt_impulse = deg_to_rad(wall_roll_tilt_impulse) * side
	rotation_spring.current.z += roll_tilt_impulse
	
	# Apply a minor forward rotational pitch down kick for texture
	rotation_spring.current.x += deg_to_rad(wall_pitch_up_impulse)
	
	# 2. FOV Pop: Expand the FOV instantly. 
	# Since _process constantly lerps camera.fov back to its target, 
	# this will snap wide and contract naturally over a few frames!
	camera.fov += wall_fov_pop

func _damage_kick(damage: float, multiplier: float, hit_direction: Vector3 = Vector3.ZERO) -> void:
	var damage_amount = damage * multiplier
	
	# Vertical dip and forward pitch — proportional to damage received
	var trans_kick = Vector3(0.0, -damage_amount * damage_translation_factor, 0.0)
	var rot_kick = Vector3(damage_amount * damage_rotation_factor, 0.0, 0.0)
	
	# Clamp to configured safety limits
	trans_kick.y = clamp(trans_kick.y, -max_damage_translation, 0.0)
	rot_kick.x = clamp(rot_kick.x, 0.0, max_damage_rotation)
	
	# Lateral roll kick: tilt opposite to where the hit came from
	# e.g. hit from the right -> roll camera left for a physical "recoil" feel
	if hit_direction != Vector3.ZERO and player_character:
		var local_hit = player_character.global_transform.basis.inverse() * hit_direction
		var lateral = clamp(local_hit.x, -1.0, 1.0)
		rot_kick.z = - lateral * max_damage_rotation * 0.5
	
	translation_spring.current += trans_kick
	rotation_spring.current += rot_kick
