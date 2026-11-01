class_name StationLogic
extends RefCounted
## Gare : places, place Coxeur réservée au booster, chargement et départs.

const NO_SLOT: int = -1

## Dernier index : juste à droite des places normales.
var coxeur_slot: int

var _slot_count: int
## Véhicules garés, du plus ancien au plus récent.
var _parked: Array[ParkedVehicle] = []


func _init(slot_count: int) -> void:
	_slot_count = slot_count
	coxeur_slot = slot_count


func copy() -> StationLogic:
	var clone: StationLogic = StationLogic.new(_slot_count)
	for parked: ParkedVehicle in _parked:
		clone._parked.append(parked.copy())
	return clone


## La place Coxeur n'accueille aucun tap : elle ne compte pas ici.
func is_full() -> bool:
	return first_free_slot() == NO_SLOT


func is_coxeur_free() -> bool:
	return not _is_slot_used(coxeur_slot)


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


## La place Coxeur doit être libre.
func park_coxeur(vehicle_id: int, dest: String, capacity: int) -> ParkedVehicle:
	var parked: ParkedVehicle = ParkedVehicle.new(vehicle_id, dest, capacity, coxeur_slot)
	_parked.append(parked)
	return parked


## Passagers manquants de chaque véhicule garé, places de gauche à droite.
func needs_by_slot() -> Array[QueueBlock]:
	var needs: Array[QueueBlock] = []
	for slot: int in coxeur_slot + 1:
		for parked: ParkedVehicle in _parked:
			if parked.slot == slot:
				needs.append(QueueBlock.new(parked.dest, parked.free_seats()))
	return needs


## L'ordre d'arrivée compte à l'intérieur d'une destination, pas entre destinations.
func state_key() -> String:
	var by_dest: Dictionary[String, String] = {}
	for parked: ParkedVehicle in _parked:
		by_dest[parked.dest] = by_dest.get(parked.dest, "") + "%d,%d;" % [parked.capacity, parked.loaded]
	var dests: Array[String] = by_dest.keys()
	dests.sort()
	var key: String = "x" if is_coxeur_free() else "c"
	for dest: String in dests:
		key += "%s=%s" % [dest, by_dest[dest]]
	return key


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
