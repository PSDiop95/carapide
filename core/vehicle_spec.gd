class_name VehicleSpec
extends RefCounted
## Gabarit d'un type de véhicule (data/config/vehicles.json).

var capacity: int
var length: float
var width: float


func _init(spec_capacity: int, spec_length: float, spec_width: float) -> void:
	capacity = spec_capacity
	length = spec_length
	width = spec_width
