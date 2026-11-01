class_name GarageLogic
extends RefCounted
## Rangée Garage : véhicules sortis de la gare avec leurs passagers. Non bloquante, sans limite.

var _stored: Array[ParkedVehicle] = []


func copy() -> GarageLogic:
	var clone: GarageLogic = GarageLogic.new()
	for parked: ParkedVehicle in _stored:
		clone._stored.append(parked.copy())
	return clone


func size() -> int:
	return _stored.size()


func store(parked: ParkedVehicle) -> void:
	_stored.append(parked)


func has_dest(dest: String) -> bool:
	for parked: ParkedVehicle in _stored:
		if parked.dest == dest:
			return true
	return false


## Retire le plus rempli de cette destination ; à égalité, le premier rentré. Null si aucun.
func take_fullest(dest: String) -> ParkedVehicle:
	var best: ParkedVehicle = null
	for parked: ParkedVehicle in _stored:
		if parked.dest == dest and (best == null or parked.loaded > best.loaded):
			best = parked
	if best != null:
		_stored.erase(best)
	return best


func add_free_seats_to(totals: Dictionary[String, int]) -> void:
	for parked: ParkedVehicle in _stored:
		totals[parked.dest] = totals.get(parked.dest, 0) + parked.free_seats()


func loaded_total() -> int:
	var total: int = 0
	for parked: ParkedVehicle in _stored:
		total += parked.loaded
	return total


## Trié : l'ordre d'entrée ne change pas la suite, sauf à égalité où les véhicules sont interchangeables.
func state_key() -> String:
	if _stored.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for parked: ParkedVehicle in _stored:
		parts.append("%s,%d,%d" % [parked.dest, parked.capacity, parked.loaded])
	parts.sort()
	return ";".join(parts)
