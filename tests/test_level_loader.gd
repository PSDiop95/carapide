extends GutTest

var _catalog: VehicleCatalog


func before_all() -> void:
	_catalog = VehicleCatalog.load_default()


func _valid_level() -> Dictionary:
	return {
		"id": 1, "slots": 4, "board": [8, 10],
		"vehicles": [{"type": "car_rapide", "dest": "colobane", "pos": [3, 5], "angle": 90}],
		"queue": [{"dest": "colobane", "count": 8}],
	}


func test_catalog_matches_gdd_capacities() -> void:
	assert_eq(_catalog.get_spec("taxi").capacity, 4)
	assert_eq(_catalog.get_spec("clando").capacity, 4)
	assert_eq(_catalog.get_spec("car_rapide").capacity, 8)
	assert_eq(_catalog.get_spec("ndiaga_ndiaye").capacity, 12)
	assert_eq(_catalog.get_spec("tata").capacity, 12)
	assert_eq(_catalog.get_spec("moto_jakarta").capacity, 2)


func test_valid_level_is_parsed() -> void:
	var result: LevelLoadResult = LevelLoader.parse_dict(_valid_level(), _catalog)
	assert_true(result.is_ok(), "%s" % result.errors)
	var vehicle: LevelVehicle = result.level.vehicles[0]
	assert_eq(result.level.slots, 4)
	assert_eq(result.level.board_width, 8.0)
	assert_eq(vehicle.id, 0)
	assert_eq(vehicle.capacity, 8)
	assert_eq(vehicle.length, 3.0)
	assert_eq(vehicle.pos_y, 5.0)
	assert_eq(vehicle.angle, 90.0)


func test_parse_text_rejects_invalid_json() -> void:
	var result: LevelLoadResult = LevelLoader.parse_text("{pas du json", _catalog)
	assert_false(result.is_ok())
	assert_null(result.level)


func test_missing_file_gives_explicit_error() -> void:
	var result: LevelLoadResult = LevelLoader.load_file("res://data/levels/absent.json", _catalog)
	assert_string_contains(result.errors[0], "absent.json")


func test_missing_key_names_the_key() -> void:
	var raw: Dictionary = _valid_level()
	raw.erase("board")
	var result: LevelLoadResult = LevelLoader.parse_dict(raw, _catalog)
	assert_string_contains(result.errors[0], "board")


func test_unknown_vehicle_type_is_rejected() -> void:
	var raw: Dictionary = _valid_level()
	raw["vehicles"] = [{"type": "avion", "dest": "colobane", "pos": [3, 5], "angle": 90}]
	var result: LevelLoadResult = LevelLoader.parse_dict(raw, _catalog)
	assert_string_contains(result.errors[0], "avion")


func test_passenger_capacity_mismatch_names_destination_and_counts() -> void:
	var raw: Dictionary = _valid_level()
	raw["queue"] = [{"dest": "colobane", "count": 6}]
	var result: LevelLoadResult = LevelLoader.parse_dict(raw, _catalog)
	assert_false(result.is_ok())
	assert_string_contains(result.errors[0], "colobane a 6 passagers pour 8 places")


func test_destination_without_vehicle_is_rejected() -> void:
	var raw: Dictionary = _valid_level()
	raw["queue"] = [{"dest": "colobane", "count": 8}, {"dest": "yoff", "count": 4}]
	var result: LevelLoadResult = LevelLoader.parse_dict(raw, _catalog)
	assert_string_contains(result.errors[0], "yoff a 4 passagers pour 0 places")


func test_odd_passenger_count_is_rejected() -> void:
	var raw: Dictionary = _valid_level()
	raw["vehicles"] = []
	raw["queue"] = [{"dest": "colobane", "count": 3}]
	var result: LevelLoadResult = LevelLoader.parse_dict(raw, _catalog)
	assert_string_contains("%s" % result.errors, "impair")


func test_invalid_slots_is_rejected() -> void:
	var raw: Dictionary = _valid_level()
	raw["slots"] = 0
	assert_false(LevelLoader.parse_dict(raw, _catalog).is_ok())


func test_empty_block_is_rejected() -> void:
	var raw: Dictionary = _valid_level()
	raw["queue"] = [{"dest": "colobane", "count": 8}, {"dest": "colobane", "count": 0}]
	assert_false(LevelLoader.parse_dict(raw, _catalog).is_ok())
