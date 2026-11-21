class_name PlayerInfo
extends Resource

@export_category("Player Stats")
@export var max_health:float = 100.0
@export var max_stamina:float = 100.0
@export var max_walk_speed:float = 7.0
@export var max_run_speed:float = 10.0
@export var max_jump_force:float = 5.0
@export var max_crouch_speed:float = 5.0
@export var max_jump_count:int = 2
@export var acceleration:float = 30.0
@export var jump_speed:float = 5.0

signal recoil_weapon(h_intensity: float, v_intensity: float)
signal taking_damage(damage: float, multiplier: float, hit_direction: Vector3)
signal wall_jumped(side:float)

# Status Variables
var health:float
var stamina:float

# Input Variables
var is_sprinting:bool
var is_crouching:bool
var input_dir:Vector2
var jump_pressed:bool
var jump_released:bool

# Physics Variables
var current_speed:float
var is_on_floor:bool
var is_on_ceiling:bool
var is_on_wall:bool
var is_in_air_state:bool
var wall_normal:Vector3
var floor_normal:Vector3

# Writable State Variables
var velocity:Vector3
var jump_count:int

# Player Action Variables
var is_firing:bool
var is_reloading:bool
var is_aiming:bool
var weapon_recoil
var is_vaulting:bool
var is_climbing:bool
var is_sliding:bool
var is_dashing:bool
