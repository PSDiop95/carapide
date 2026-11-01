extends GutTest


func _layout() -> LevelLayout:
	var level: LevelData = LevelData.new()
	level.board_width = 8.0
	level.board_height = 10.0
	level.slots = 4
	return LevelLayout.new(level)


func _vehicle(x: float, y: float, angle: float) -> LevelVehicle:
	var vehicle: LevelVehicle = LevelVehicle.new()
	vehicle.pos_x = x
	vehicle.pos_y = y
	vehicle.angle = angle
	vehicle.length = 2.0
	vehicle.width = 0.9
	return vehicle


func test_board_and_world_round_trip() -> void:
	var layout: LevelLayout = _layout()
	var world: Vector3 = layout.board_to_world(3.0, 7.0)
	assert_eq(world, Vector3(-1.0, 0.0, 3.0))
	assert_eq(layout.world_to_board(world), Vector2(3.0, 7.0))


func test_higher_board_y_is_toward_the_station() -> void:
	var layout: LevelLayout = _layout()
	assert_lt(layout.board_to_world(1.0, 9.0).z, layout.board_to_world(1.0, 1.0).z)
	assert_lt(layout.slot_world(0).z, layout.board_to_world(1.0, 10.0).z)
	assert_lt(layout.queue_world(0).z, layout.slot_world(0).z)


func test_slots_are_centered() -> void:
	var layout: LevelLayout = _layout()
	assert_almost_eq(layout.slot_world(0).x, -layout.slot_world(3).x, 0.0001)


func test_queue_snakes_between_rows() -> void:
	var layout: LevelLayout = _layout()
	var columns: int = layout.queue_columns()
	assert_almost_eq(layout.queue_world(columns - 1).x, layout.queue_world(columns).x, 0.0001)
	assert_lt(layout.queue_world(columns).z, layout.queue_world(columns - 1).z)


func test_exit_point_follows_arrow_past_the_edge() -> void:
	var layout: LevelLayout = _layout()
	assert_eq(layout.exit_point(_vehicle(3.0, 5.0, 90.0)), layout.board_to_world(3.0, 11.0))
	assert_eq(layout.exit_point(_vehicle(3.0, 5.0, 180.0)), layout.board_to_world(-1.0, 5.0))
