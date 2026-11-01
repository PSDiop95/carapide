class_name ParkedVehicle
extends RefCounted
## Véhicule garé à une place de la gare.

var vehicle_id: int
var dest: String
var capacity: int
var slot: int
var loaded: int = 0


func _init(id: int, vehicle_dest: String, vehicle_capacity: int, slot_index: int) -> void:
	vehicle_id = id
	dest = vehicle_dest
	capacity = vehicle_capacity
	slot = slot_index


func copy() -> ParkedVehicle:
	var clone: ParkedVehicle = ParkedVehicle.new(vehicle_id, dest, capacity, slot)
	clone.loaded = loaded
	return clone


func free_seats() -> int:
	return capacity - loaded


func is_full() -> bool:
	return loaded >= capacity
