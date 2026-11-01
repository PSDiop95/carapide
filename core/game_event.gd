class_name GameEvent
extends RefCounted
## Événement renvoyé par GameRules et rejoué par la présentation.

## BLOCKED : choc d'un tap. RESCUE_NEEDED : la partie entre dans Status.BLOCKED.
enum Type { MOVED, BLOCKED, BOARDED, DEPARTED, WON, LOST, FLEW, QUEUE_REORDERED, RESCUE_NEEDED, DESTINATIONS_CHANGED, GARAGED, RECALLED }

var type: Type
var vehicle_id: int = -1
var blocker_id: int = -1
var slot: int = -1
var count: int = 0
var loaded: int = 0
var dest: String = ""
var blocks: Array[QueueBlock] = []
## Destination de chaque véhicule du bouchon après un Dioulé.
var dests_by_vehicle: Dictionary[int, String] = {}
## Véhicules envoyés au Garage, de la gauche vers la droite ; `count` donne alors le nouveau nombre de places.
var garaged_ids: PackedInt32Array = PackedInt32Array()


func _init(event_type: Type) -> void:
	type = event_type


static func moved(id: int, slot_index: int, vehicle_dest: String = "") -> GameEvent:
	var event: GameEvent = GameEvent.new(Type.MOVED)
	event.vehicle_id = id
	event.slot = slot_index
	event.dest = vehicle_dest
	return event


static func flew(id: int, slot_index: int, vehicle_dest: String = "") -> GameEvent:
	var event: GameEvent = GameEvent.new(Type.FLEW)
	event.vehicle_id = id
	event.slot = slot_index
	event.dest = vehicle_dest
	return event


static func destinations_changed(dests: Dictionary[int, String]) -> GameEvent:
	var event: GameEvent = GameEvent.new(Type.DESTINATIONS_CHANGED)
	event.dests_by_vehicle = dests
	return event


static func garaged(ids: PackedInt32Array, slot_count: int) -> GameEvent:
	var event: GameEvent = GameEvent.new(Type.GARAGED)
	event.garaged_ids = ids
	event.count = slot_count
	return event


static func recalled(parked: ParkedVehicle) -> GameEvent:
	var event: GameEvent = GameEvent.new(Type.RECALLED)
	event.vehicle_id = parked.vehicle_id
	event.slot = parked.slot
	event.dest = parked.dest
	event.loaded = parked.loaded
	return event


static func queue_reordered(new_blocks: Array[QueueBlock]) -> GameEvent:
	var event: GameEvent = GameEvent.new(Type.QUEUE_REORDERED)
	event.blocks = new_blocks
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
