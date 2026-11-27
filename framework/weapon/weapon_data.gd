class_name WeaponData
extends Resource

enum WEAPON_SLOT {PRIMARY, SECONDARY, TERTIARY, SPECIAL}
enum FIRE_TYPE {FULL_AUTO, SEMI_AUTO, SINGLE_SHOT, BURST_FIRE}
enum WEAPON_TYPE {PROJECTILE, HITSCAN}

@export_category("Weapon Info")
@export var weapon_name: String
@export var weapon_slot: WEAPON_SLOT
@export var fire_type: FIRE_TYPE
@export var mag_size: float
@export var weapon_type: WEAPON_TYPE

@export_category("Damage Info")
@export var damage_curve: Curve

@export_category("Bullet")
## Used for collosion detection for projectie weapons and just for visual for raycast weapons
@export var projectile_scene_path: PackedScene

@export_category("Projectile Weapon Specific")
@export var projectile_speed: float