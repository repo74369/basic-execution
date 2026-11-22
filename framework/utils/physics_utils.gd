class_name PhysicsUtils
extends RefCounted



static func accelerate_toward(current_velocity: Vector3, target_velocity: Vector3, accel_rate: float, delta: float) -> Vector3:
    var diff = target_velocity - current_velocity
    var diff_length = diff.length()
    if diff_length > 0:
        var accel = diff.normalized() * min(diff_length / delta, accel_rate)
        return accel
    return Vector3.ZERO

static func character_accelerate_toward(character:CharacterBody3D, target_velocity: Vector3, accel_rate: float, delta: float) -> void:
    var diff = target_velocity - character.velocity 
    var diff_length = diff.length()
    if diff_length > 0:
        var accel = diff.normalized() * min(diff_length / delta, accel_rate)
        character.velocity += accel * delta