class_name GameMode
extends Node
## Authoritative round logic for an experience. Runs on the solo device,
## the host, or the dedicated server - never on plain clients.
## Emits events that are applied locally and broadcast to clients.

## reliable = false for frequent, disposable updates (e.g. lava height).
signal event(ev: Dictionary, reliable: bool)


## State for players joining mid-round (applied like a normal event).
func snapshot() -> Dictionary:
	return {}


func emit_event(ev: Dictionary, reliable: bool = true) -> void:
	event.emit(ev, reliable)
