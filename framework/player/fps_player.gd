class_name FPSPlayer
extends CharacterBody3D

@export var player_info:PlayerInfo = PlayerInfo.new()
@export var movement_controller:MovementController
@export var look_controller:LookController
@export var player_neck:Node3D
@export var player_camera:Camera3D
@export var crouch_collider:CollisionShape3D
@export var standing_collider:CollisionShape3D
@export var standing_eye_height:float = 1.65
@export var crouch_eye_height:float = 0.65
@export var custom_gravity:float = -15.0
@export var fast_fall_multiplier:float = 2.5

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
    
	query.shape = crouch_collider.shape          # Use crouch collider and displace it to 1m above
	query.transform = global_transform            
	query.transform = query.transform.translated(Vector3(0, standing_eye_height-crouch_eye_height, 0))          
	query.exclude = [self.get_rid()]                         
	query.collision_mask = collision_mask          
    
	var results := space.intersect_shape(query, 1) 
	return results.is_empty()