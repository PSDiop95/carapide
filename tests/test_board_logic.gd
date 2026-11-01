extends GutTest


func _level(vehicles: Array, board: Array = [10, 10]) -> LevelData:
	var capacity: int = vehicles.size() * 8
	var entries: Array = []
	for vehicle: Array in vehicles:
		entries.append({"type": "car_rapide", "dest": "colobane", "pos": [vehicle[0], vehicle[1]], "angle": vehicle[2]})
	var raw: Dictionary = {
		"id": 1, "slots": 4, "board": board, "vehicles": entries,
		"queue": [{"dest": "colobane", "count": capacity}],
	}
	var result: LevelLoadResult = LevelLoader.parse_dict(raw, VehicleCatalog.load_default())
	assert_true(result.is_ok(), "%s" % result.errors)
	return result.level


func test_free_vehicle_can_exit() -> void:
	var board: BoardLogic = BoardLogic.new(_level([[5, 5, 90]]))
	assert_true(board.can_exit(0))
	assert_eq(board.first_blocker(0), BoardLogic.NO_VEHICLE)


func test_vehicle_ahead_blocks() -> void:
	var board: BoardLogic = BoardLogic.new(_level([[5, 2, 90], [5, 7, 90]]))
	assert_false(board.can_exit(0))
	assert_eq(board.first_blocker(0), 1)
	assert_true(board.can_exit(1))


func test_vehicle_behind_does_not_block() -> void:
	var board: BoardLogic = BoardLogic.new(_level([[5, 7, 90], [5, 2, 90]]))
	assert_true(board.can_exit(0))


func test_adjacent_parallel_lane_does_not_block() -> void:
	var board: BoardLogic = BoardLogic.new(_level([[5, 5, 90], [6, 8, 90]]))
	assert_true(board.can_exit(0))


func test_nose_to_tail_contact_is_valid_and_blocks() -> void:
	var board: BoardLogic = BoardLogic.new(_level([[5, 2, 90], [5, 5, 90]]))
	assert_false(board.can_exit(0))
	assert_eq(board.first_blocker(0), 1)


func test_first_blocker_is_nearest_along_the_arrow() -> void:
	var board: BoardLogic = BoardLogic.new(_level([[1.5, 5, 0], [8, 5, 90], [5, 5, 90]]))
	assert_eq(board.first_blocker(0), 2)


func test_removing_blocker_frees_vehicle() -> void:
	var board: BoardLogic = BoardLogic.new(_level([[5, 2, 90], [5, 7, 90]]))
	board.remove(1)
	assert_true(board.can_exit(0))
	assert_false(board.has_vehicle(1))
	assert_eq(board.remaining_count(), 1)


func test_diagonal_blocked_by_vehicle_on_its_line() -> void:
	var board: BoardLogic = BoardLogic.new(_level([[2, 2, 45], [6, 6, 135]]))
	assert_false(board.can_exit(0))
	assert_eq(board.first_blocker(0), 1)


func test_diagonal_passes_beside_a_vehicle_off_its_line() -> void:
	var board: BoardLogic = BoardLogic.new(_level([[2, 2, 45], [7, 2, 90]]))
	assert_true(board.can_exit(0))


func test_free_angle_uses_exact_heading() -> void:
	var board: BoardLogic = BoardLogic.new(_level([[2, 5, 30], [7, 8.2, 0], [7, 5, 0]]))
	assert_eq(board.first_blocker(0), 1)


func test_vehicle_at_board_edge_exits_outward() -> void:
	var board: BoardLogic = BoardLogic.new(_level([[1.5, 5, 180], [5, 5, 90]]))
	assert_true(board.can_exit(0))


func test_vehicle_at_board_edge_facing_inward_can_be_blocked() -> void:
	var board: BoardLogic = BoardLogic.new(_level([[1.5, 5, 0], [5, 5, 90]]))
	assert_false(board.can_exit(0))


func test_angle_is_normalized() -> void:
	var board: BoardLogic = BoardLogic.new(_level([[5, 2, 450], [5, 7, 90]]))
	assert_eq(board.first_blocker(0), 1)
	var negative: BoardLogic = BoardLogic.new(_level([[5, 2, -270], [5, 7, 90]]))
	assert_eq(negative.first_blocker(0), 1)


func test_box_outside_board_is_rejected() -> void:
	var raw: Dictionary = {
		"id": 1, "slots": 4, "board": [10, 10],
		"vehicles": [{"type": "car_rapide", "dest": "a", "pos": [0.2, 5], "angle": 0}],
		"queue": [{"dest": "a", "count": 8}],
	}
	var result: LevelLoadResult = LevelLoader.parse_dict(raw, VehicleCatalog.load_default())
	assert_string_contains(result.errors[0], "hors plateau")


func test_overlapping_vehicles_are_rejected() -> void:
	var raw: Dictionary = {
		"id": 1, "slots": 4, "board": [10, 10],
		"vehicles": [
			{"type": "car_rapide", "dest": "a", "pos": [5, 5], "angle": 90},
			{"type": "car_rapide", "dest": "a", "pos": [5, 6], "angle": 90},
		],
		"queue": [{"dest": "a", "count": 16}],
	}
	var result: LevelLoadResult = LevelLoader.parse_dict(raw, VehicleCatalog.load_default())
	assert_string_contains(result.errors[0], "se chevauchent")


func test_mutual_blockers_are_rejected() -> void:
	var raw: Dictionary = {
		"id": 1, "slots": 4, "board": [10, 10],
		"vehicles": [
			{"type": "car_rapide", "dest": "a", "pos": [2, 5], "angle": 0},
			{"type": "car_rapide", "dest": "a", "pos": [8, 5], "angle": 180},
		],
		"queue": [{"dest": "a", "count": 16}],
	}
	var result: LevelLoadResult = LevelLoader.parse_dict(raw, VehicleCatalog.load_default())
	assert_string_contains(result.errors[0], "aucun ordre de sortie")


func test_vehicle_at_finds_remaining_vehicle_with_tolerance() -> void:
	var board: BoardLogic = BoardLogic.new(_level([[5, 5, 90]]))
	assert_eq(board.vehicle_at(5.0, 6.0, 0.0), 0)
	assert_eq(board.vehicle_at(5.6, 5.0, 0.0), BoardLogic.NO_VEHICLE)
	assert_eq(board.vehicle_at(5.6, 5.0, 0.2), 0)
	board.remove(0)
	assert_eq(board.vehicle_at(5.0, 5.0, 0.0), BoardLogic.NO_VEHICLE)
