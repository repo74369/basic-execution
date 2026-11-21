# Priority base HSM root machine
class_name HStateMachine
extends Node

var _states: Array[HState] = []
var _active_state: HState = null


## Discovers child HState nodes, sorts by priority.
## Subclasses (or enter()) activate the default state.
func _init_states(context: Resource) -> void:
	_states.clear()
	for child in get_children():
		if child is HState:
			_states.append(child)
			child._init_states(context)
	_states.sort_custom(func(a, b): return a.priority > b.priority)
	if not _states.is_empty() and not (self is HState):
		# Only the root state machine auto-activates its default state at boot.
		# Sub-states wait until their parent state's enter() is called.
		_transition_to(_states.back(), context)

## Run physics tick: evaluate transitions, then delegate physics update to active state.
func physics_update(delta: float, context: Resource) -> void:
	_try_transition(context)
	if _active_state:
		DebugConsole.watch(self.name + "_" + "active state", _active_state.name)
		_active_state.physics_update(delta, context)


## Run frame tick (visuals / animations).
func update(delta: float, context: Resource) -> void:
	if _active_state:
		_active_state.update(delta, context)


## Force an immediate transition regardless of can_enter/can_exit.
func force_transition(next: HState, context: Resource) -> void:
	_transition_to(next, context)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _try_transition(context: Resource) -> void:
	if not _active_state:
		return
	if not _active_state.can_exit(context):
		return

	var current_is_valid := _active_state.can_enter(context)

	for state in _states:
		if state == _active_state:
			if current_is_valid:
				break
			else:
				continue

		if state.can_enter(context):
			_transition_to(state, context)
			return

	if not current_is_valid and not _states.is_empty():
		var fallback: HState = _states.back()
		if fallback != _active_state:
			_transition_to(fallback, context)


func _transition_to(next: HState, context: Resource) -> void:
	if _active_state:
		_active_state.exit(context)
	_active_state = next
	_active_state.enter(context)
