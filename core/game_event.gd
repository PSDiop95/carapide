class_name GameEvent
extends RefCounted
## Événement renvoyé par GameRules et rejoué par la présentation.

enum Type { MOVED, BLOCKED, BOARDED, DEPARTED, WON, LOST }

var type: Type
var vehicle_id: int = -1
var blocker_id: int = -1
var slot: int = -1
var count: int = 0
var loaded: int = 0
var dest: String = ""


func _init(event_type: Type) -> void:
	type = event_type


static func moved(id: int, slot_index: int) -> GameEvent:
	var event: GameEvent = GameEvent.new(Type.MOVED)
	event.vehicle_id = id
	event.slot = slot_index
	return event


static func blocked(id: int, blocker: int) -> GameEvent:
	var event: GameEvent = GameEvent.new(Type.BLOCKED)
	event.vehicle_id = id
	event.blocker_id = blocker
	return event


static func boarded(parked: ParkedVehicle, amount: int) -> GameEvent:
	var event: GameEvent = GameEvent.new(Type.BOARDED)
	event.vehicle_id = parked.vehicle_id
	event.slot = parked.slot
	event.dest = parked.dest
	event.count = amount
	event.loaded = parked.loaded
	return event


static func departed(parked: ParkedVehicle) -> GameEvent:
	var event: GameEvent = GameEvent.new(Type.DEPARTED)
	event.vehicle_id = parked.vehicle_id
	event.slot = parked.slot
	return event
