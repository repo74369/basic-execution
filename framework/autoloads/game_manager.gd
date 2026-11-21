extends Node

enum Context { GAMEPLAY, UI, CINEMATIC, DEAD }
signal context_changed(new_context: Context)
var current_context: Context = Context.GAMEPLAY

func is_gameplay_active() -> bool:
    return current_context == Context.GAMEPLAY

func set_context(ctx: Context) -> void:
    current_context = ctx
    context_changed.emit(ctx)
    