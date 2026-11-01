class_name LevelLoader
extends RefCounted
## Lit le JSON d'un niveau et refuse tout niveau incohérent, avec un message explicite.

const REQUIRED_KEYS: Array[String] = ["id", "slots", "board", "vehicles", "queue"]


static func load_file(path: String, catalog: VehicleCatalog) -> LevelLoadResult:
	if not FileAccess.file_exists(path):
		return _failure(PackedStringArray(["Fichier de niveau introuvable : %s" % path]))
	return parse_text(FileAccess.get_file_as_string(path), catalog)


static func parse_text(text: String, catalog: VehicleCatalog) -> LevelLoadResult:
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		var message: String = "JSON de niveau invalide, ligne %d : %s" % [json.get_error_line(), json.get_error_message()]
		return _failure(PackedStringArray([message]))
	if not json.data is Dictionary:
		return _failure(PackedStringArray(["JSON de niveau invalide : objet attendu"]))
	var raw: Dictionary = json.data
	return parse_dict(raw, catalog)


static func parse_dict(raw: Dictionary, catalog: VehicleCatalog) -> LevelLoadResult:
	var errors: PackedStringArray = PackedStringArray()
	for key: String in REQUIRED_KEYS:
		if not raw.has(key):
			errors.append("Clé manquante : %s" % key)
	if not errors.is_empty():
		return _failure(errors)
	var level: LevelData = _build_level(raw, catalog, errors)
	if errors.is_empty():
		errors.append_array(LevelValidator.validate(level))
	if not errors.is_empty():
		return _failure(errors)
	var result: LevelLoadResult = LevelLoadResult.new()
	result.level = level
	return result


static func _build_level(raw: Dictionary, catalog: VehicleCatalog, errors: PackedStringArray) -> LevelData:
	var level: LevelData = LevelData.new()
	var raw_id: float = raw["id"]
	var raw_slots: float = raw["slots"]
	var board: Array = raw["board"]
	var board_width: float = board[0]
	var board_height: float = board[1]
	level.id = int(raw_id)
	level.slots = int(raw_slots)
	level.board_width = board_width
	level.board_height = board_height
	var raw_vehicles: Array = raw["vehicles"]
	for entry: Dictionary in raw_vehicles:
		var vehicle: LevelVehicle = _build_vehicle(entry, level.vehicles.size(), catalog, errors)
		if vehicle != null:
			level.vehicles.append(vehicle)
	var raw_queue: Array = raw["queue"]
	for entry: Dictionary in raw_queue:
		var dest: String = entry["dest"]
		var count: float = entry["count"]
		level.queue.append(QueueBlock.new(dest, int(count)))
	return level


static func _build_vehicle(entry: Dictionary, id: int, catalog: VehicleCatalog, errors: PackedStringArray) -> LevelVehicle:
	var type_name: String = entry["type"]
	if not catalog.has_type(type_name):
		errors.append("Type de véhicule inconnu : %s" % type_name)
		return null
	var spec: VehicleSpec = catalog.get_spec(type_name)
	var pos: Array = entry["pos"]
	var pos_x: float = pos[0]
	var pos_y: float = pos[1]
	var angle: float = entry["angle"]
	var dest: String = entry["dest"]
	var vehicle: LevelVehicle = LevelVehicle.new()
	vehicle.id = id
	vehicle.type_name = type_name
	vehicle.dest = dest
	vehicle.pos_x = pos_x
	vehicle.pos_y = pos_y
	vehicle.angle = angle
	vehicle.capacity = spec.capacity
	vehicle.length = spec.length
	vehicle.width = spec.width
	return vehicle


static func _failure(errors: PackedStringArray) -> LevelLoadResult:
	var result: LevelLoadResult = LevelLoadResult.new()
	result.errors = errors
	return result
