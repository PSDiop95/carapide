class_name StationLogic
extends RefCounted
## Gare : places, chargement et départs.

const NO_SLOT: int = -1

var _slot_count: int
## Véhicules garés, du plus ancien au plus récent.
var _parked: Array[ParkedVehicle] = []


func _init(slot_count: int) -> void:
	_slot_count = slot_count


func is_full() -> bool:
	return _parked.size() >= _slot_count


func parked_count() -> int:
	return _parked.size()


func first_free_slot() -> int:
	for slot: int in _slot_count:
		if not _is_slot_used(slot):
			return slot
	return NO_SLOT


## Gare le véhicule à la première place libre. La gare ne doit pas être pleine.
func park(vehicle_id: int, dest: String, capacity: int) -> ParkedVehicle:
	var parked: ParkedVehicle = ParkedVehicle.new(vehicle_id, dest, capacity, first_free_slot())
	_parked.append(parked)
	return parked


## Le plus ancien véhicule garé de cette destination, ou null.
func oldest_for(dest: String) -> ParkedVehicle:
	for parked: ParkedVehicle in _parked:
		if parked.dest == dest:
			return parked
	return null


func depart(parked: ParkedVehicle) -> void:
	_parked.erase(parked)


func _is_slot_used(slot: int) -> bool:
	for parked: ParkedVehicle in _parked:
		if parked.slot == slot:
			return true
	return false
