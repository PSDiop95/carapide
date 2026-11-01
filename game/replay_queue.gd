class_name ReplayQueue
extends RefCounted
## File d'actions de la présentation : le core a déjà tout résolu, seul le rejeu s'étale.
## Un véhicule part tout de suite si sa place est visuellement libre ; le reste passe dans l'ordre.

var _pending: Array[GameEvent] = []
var _busy_slots: Dictionary[int, bool] = {}


## Vrai si l'événement doit être rejoué tout de suite, sans attendre la file.
func add(event: GameEvent) -> bool:
	if _is_arrival(event) and not _is_slot_taken(event.slot):
		_busy_slots[event.slot] = true
		return true
	_pending.append(event)
	return false


func is_empty() -> bool:
	return _pending.is_empty()


## Prochain événement à rejouer ; met à jour l'occupation visuelle des places.
func next() -> GameEvent:
	var event: GameEvent = _pending.pop_front()
	if _is_arrival(event):
		_busy_slots[event.slot] = true
	elif event.type == GameEvent.Type.DEPARTED:
		_busy_slots.erase(event.slot)
	return event


static func _is_arrival(event: GameEvent) -> bool:
	return event.type == GameEvent.Type.MOVED or event.type == GameEvent.Type.FLEW


func _is_slot_taken(slot: int) -> bool:
	if _busy_slots.has(slot):
		return true
	for event: GameEvent in _pending:
		if _is_arrival(event) and event.slot == slot:
			return true
	return false
