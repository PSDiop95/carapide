class_name VehicleCatalog
extends RefCounted
## Types de véhicules disponibles, chargés depuis la configuration.

const DEFAULT_PATH: String = "res://data/config/vehicles.json"

var _specs: Dictionary[String, VehicleSpec] = {}


static func load_default() -> VehicleCatalog:
	return load_file(DEFAULT_PATH)


static func load_file(path: String) -> VehicleCatalog:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var catalog: VehicleCatalog = VehicleCatalog.new()
	if parsed is Dictionary:
		var raw: Dictionary = parsed
		catalog._fill(raw)
	else:
		push_error("Catalogue de véhicules illisible : %s" % path)
	return catalog


func has_type(type_name: String) -> bool:
	return _specs.has(type_name)


func get_spec(type_name: String) -> VehicleSpec:
	return _specs[type_name]


func _fill(raw: Dictionary) -> void:
	for type_name: String in raw:
		var entry: Dictionary = raw[type_name]
		var capacity: float = entry["capacity"]
		var length: float = entry["length"]
		var width: float = entry["width"]
		_specs[type_name] = VehicleSpec.new(int(capacity), length, width)
