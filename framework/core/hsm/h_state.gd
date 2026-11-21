## Priority-based Hierarchical State (HState)
## Supports arbitrary nesting depth (State -> SubState -> SubSubState...).
class_name HState
extends HStateMachine

## Higher priority states are preferred during transition evaluation.
@export var priority: int = 0

## Return true when this state is eligible to become active.
func can_enter(context: Resource) -> bool:
	return false


## Return false to prevent any transition away from this state (lock/veto).
## Recursively checks active child state first so any descendant can veto exit.
func can_exit(context: Resource) -> bool:
	if _active_state and not _active_state.can_exit(context):
		return false
	return _can_exit_self(context)


## Override to specify self exit condition without breaking sub-state exit recursion.
func _can_exit_self(_context: Resource) -> bool:
	return true


## Called once when this state becomes active. Cascades down to deepest default sub-state.
func enter(context: Resource) -> void:
	if not _states.is_empty():
		_active_state = _states.back()  # lowest priority = default fallback
		_active_state.enter(context)


## Called once when this state is deactivated. Cascades down to active sub-state.
func exit(context: Resource) -> void:
	if _active_state:
		_active_state.exit(context)
		_active_state = null
