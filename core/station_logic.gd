class_name StationLogic
extends RefCounted
## Gare : places, place Coxeur réservée au booster, chargement et départs.

const NO_SLOT: int = -1

## Dernier index : juste à droite des places normales.
var coxeur_slot: int
## Places retirées du jeu, pour mesurer la marge d'une position.
var reserved_slots: int = 0

var _slot_count: int
## Véhicules garés, du plus ancien au plus récent.
var _parked: Array[ParkedVehicle] = []


func _init(slot_count: int) -> void:
	_slot_count = slot_count
	coxeur_slot = slot_count


func copy() -> StationLogic:
	var clone: StationLogic = StationLogic.new(_slot_count)
	clone.reserved_slots = reserved_slots
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


## Passagers à bord des véhicules garés.
func loaded_total() -> int:
	var total: int = 0
	for parked: ParkedVehicle in _parked:
		total += parked.loaded
	return total


## Places normales encore libres.
func free_slot_count() -> int:
	var used: int = 0
	for parked: ParkedVehicle in _parked:
		if parked.slot < _slot_count:
			used += 1
	return _slot_count - reserved_slots - used


func first_free_slot() -> int:
	if free_slot_count() <= 0:
		return NO_SLOT
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


## Vide la gare et ajoute une place : la place Coxeur, vide elle aussi, se décale d'un rang.
func evacuate_and_grow() -> Array[ParkedVehicle]:
	var evacuated: Array[ParkedVehicle] = _parked
	_parked = []
	_slot_count += 1
	coxeur_slot = _slot_count
	return evacuated


func total_slots() -> int:
	return _slot_count


## Remet un véhicule du Garage à la première place libre. La gare ne doit pas être pleine.
func park_returning(parked: ParkedVehicle) -> void:
	parked.slot = first_free_slot()
	_parked.append(parked)


## Passagers manquants de chaque véhicule garé, places de gauche à droite.
func needs_by_slot() -> Array[QueueBlock]:
	var needs: Array[QueueBlock] = []
	for slot: int in coxeur_slot + 1:
		for parked: ParkedVehicle in _parked:
			if parked.slot == slot:
				needs.append(QueueBlock.new(parked.dest, parked.free_seats()))
	return needs


## Sièges libres de chaque destination dans les véhicules garés.
func free_seats_by_dest() -> Dictionary[String, int]:
	var totals: Dictionary[String, int] = {}
	for parked: ParkedVehicle in _parked:
		totals[parked.dest] = totals.get(parked.dest, 0) + parked.free_seats()
	return totals


## L'ordre d'arrivée compte à l'intérieur d'une destination, pas entre destinations.
func state_key() -> String:
	var by_dest: Dictionary[String, String] = {}
	for parked: ParkedVehicle in _parked:
		by_dest[parked.dest] = by_dest.get(parked.dest, "") + "%d,%d;" % [parked.capacity, parked.loaded]
	var dests: Array[String] = by_dest.keys()
	dests.sort()
	var key: String = "%d%s" % [_slot_count, "x" if is_coxeur_free() else "c"]
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
