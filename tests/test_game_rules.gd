extends GutTest


## Véhicules sur des voies verticales indépendantes, sauf positions explicites.
func _level(vehicles: Array, queue: Array, slots: int = 4) -> LevelData:
	var entries: Array = []
	var lane: float = 1.0
	for vehicle: Array in vehicles:
		var pos: Array = vehicle[2] if vehicle.size() > 2 else [lane, 5.0]
		entries.append({"type": vehicle[0], "dest": vehicle[1], "pos": pos, "angle": 90})
		lane += 1.0
	var blocks: Array = []
	for block: Array in queue:
		blocks.append({"dest": block[0], "count": block[1]})
	var raw: Dictionary = {"id": 1, "slots": slots, "board": [12, 12], "vehicles": entries, "queue": blocks}
	var result: LevelLoadResult = LevelLoader.parse_dict(raw, VehicleCatalog.load_default())
	assert_true(result.is_ok(), "%s" % result.errors)
	return result.level


func _types(events: Array[GameEvent]) -> Array[GameEvent.Type]:
	var types: Array[GameEvent.Type] = []
	for event: GameEvent in events:
		types.append(event.type)
	return types


func test_moved_then_boarded_then_departed_then_won() -> void:
	var rules: GameRules = GameRules.new(_level([["taxi", "a"]], [["a", 4]]))
	var events: Array[GameEvent] = rules.tap(0)
	var expected: Array[GameEvent.Type] = [
		GameEvent.Type.MOVED, GameEvent.Type.BOARDED, GameEvent.Type.DEPARTED, GameEvent.Type.WON,
	]
	assert_eq(_types(events), expected)
	assert_eq(events[0].slot, 0)
	assert_eq(events[1].count, 4)
	assert_eq(events[1].loaded, 4)
	assert_eq(rules.status, GameRules.Status.WON)


func test_blocked_reports_blocker_and_costs_nothing() -> void:
	var level: LevelData = _level([["taxi", "a", [1.0, 2.0]], ["taxi", "a", [1.0, 8.0]]], [["a", 8]])
	var rules: GameRules = GameRules.new(level)
	var events: Array[GameEvent] = rules.tap(0)
	assert_eq(events.size(), 1)
	assert_eq(events[0].type, GameEvent.Type.BLOCKED)
	assert_eq(events[0].blocker_id, 1)
	assert_eq(rules.status, GameRules.Status.PLAYING)
	assert_eq(rules.passengers_remaining(), 8)


func test_blocker_exit_frees_blocked_vehicle() -> void:
	var level: LevelData = _level([["taxi", "a", [1.0, 2.0]], ["taxi", "a", [1.0, 8.0]]], [["a", 8]])
	var rules: GameRules = GameRules.new(level)
	rules.tap(1)
	var events: Array[GameEvent] = rules.tap(0)
	assert_eq(events[0].type, GameEvent.Type.MOVED)
	assert_eq(rules.status, GameRules.Status.WON)


func test_no_match_parks_without_boarding() -> void:
	var rules: GameRules = GameRules.new(_level([["taxi", "a"], ["taxi", "b"]], [["a", 4], ["b", 4]]))
	var events: Array[GameEvent] = rules.tap(1)
	var expected: Array[GameEvent.Type] = [GameEvent.Type.MOVED]
	assert_eq(_types(events), expected)
	assert_eq(rules.passengers_remaining(), 8)


func test_chain_loads_parked_vehicle_after_departure() -> void:
	var rules: GameRules = GameRules.new(_level([["taxi", "a"], ["taxi", "b"]], [["a", 4], ["b", 4]]))
	rules.tap(1)
	var events: Array[GameEvent] = rules.tap(0)
	var expected: Array[GameEvent.Type] = [
		GameEvent.Type.MOVED, GameEvent.Type.BOARDED, GameEvent.Type.DEPARTED,
		GameEvent.Type.BOARDED, GameEvent.Type.DEPARTED, GameEvent.Type.WON,
	]
	assert_eq(_types(events), expected)
	assert_eq(events[3].vehicle_id, 1)


func test_partial_load_stays_parked_until_its_block_returns() -> void:
	var level: LevelData = _level([["taxi", "a"], ["taxi", "b"]], [["a", 2], ["b", 4], ["a", 2]])
	var rules: GameRules = GameRules.new(level)
	var events: Array[GameEvent] = rules.tap(0)
	var expected: Array[GameEvent.Type] = [GameEvent.Type.MOVED, GameEvent.Type.BOARDED]
	assert_eq(_types(events), expected)
	assert_eq(events[1].loaded, 2)
	events = rules.tap(1)
	assert_eq(events[-1].type, GameEvent.Type.WON)
	assert_eq(events[1].vehicle_id, 1)
	assert_eq(events[3].vehicle_id, 0)
	assert_eq(events[3].loaded, 4)


func test_oldest_parked_vehicle_of_destination_fills_first() -> void:
	var level: LevelData = _level([["taxi", "b"], ["taxi", "a"], ["taxi", "a"]], [["b", 4], ["a", 8]])
	var rules: GameRules = GameRules.new(level)
	rules.tap(2)
	rules.tap(1)
	var events: Array[GameEvent] = rules.tap(0)
	assert_eq(events[3].vehicle_id, 2)
	assert_eq(events[5].vehicle_id, 1)


func test_freed_slot_is_reused_first() -> void:
	var level: LevelData = _level([["taxi", "a"], ["taxi", "b"], ["taxi", "c"]], [["a", 4], ["c", 4], ["b", 4]])
	var rules: GameRules = GameRules.new(level)
	assert_eq(rules.tap(1)[0].slot, 0)
	assert_eq(rules.tap(0)[0].slot, 1)
	assert_eq(rules.tap(2)[0].slot, 1)


func test_full_station_without_match_is_lost() -> void:
	var level: LevelData = _level([["taxi", "a"], ["taxi", "b"], ["taxi", "c"]], [["a", 4], ["b", 4], ["c", 4]], 2)
	var rules: GameRules = GameRules.new(level)
	rules.tap(1)
	var events: Array[GameEvent] = rules.tap(2)
	assert_eq(events[-1].type, GameEvent.Type.LOST)
	assert_eq(rules.status, GameRules.Status.LOST)


func test_full_station_with_match_is_not_lost() -> void:
	var level: LevelData = _level([["taxi", "a"], ["taxi", "b"]], [["a", 4], ["b", 4]], 2)
	var rules: GameRules = GameRules.new(level)
	rules.tap(1)
	var events: Array[GameEvent] = rules.tap(0)
	assert_eq(events[-1].type, GameEvent.Type.WON)


func test_no_exit_left_is_lost() -> void:
	var level: LevelData = _level([["taxi", "a"], ["taxi", "b"]], [["a", 4], ["b", 4]])
	# Un cycle de blocage est refusé au chargement : on le force pour tester le filet.
	level.vehicles[0].pos_x = 2.0
	level.vehicles[0].pos_y = 5.0
	level.vehicles[0].angle = 0.0
	level.vehicles[1].pos_x = 8.0
	level.vehicles[1].pos_y = 5.0
	level.vehicles[1].angle = 180.0
	var third: LevelVehicle = LevelVehicle.new()
	third.id = 2
	third.dest = "c"
	third.pos_x = 11.0
	third.pos_y = 11.0
	third.angle = 0.0
	third.length = 1.0
	third.width = 0.9
	third.capacity = 2
	level.vehicles.append(third)
	level.queue.append(QueueBlock.new("c", 2))
	var rules: GameRules = GameRules.new(level)
	var events: Array[GameEvent] = rules.tap(2)
	assert_eq(events[-1].type, GameEvent.Type.LOST)


func test_tap_after_end_or_on_gone_vehicle_does_nothing() -> void:
	var level: LevelData = _level([["taxi", "b"], ["taxi", "a"]], [["a", 4], ["b", 4]])
	var rules: GameRules = GameRules.new(level)
	rules.tap(0)
	assert_eq(rules.tap(0).size(), 0)
	assert_eq(rules.tap(99).size(), 0)
	rules.tap(1)
	assert_eq(rules.status, GameRules.Status.WON)
	assert_eq(rules.tap(1).size(), 0)


func test_same_taps_give_same_events() -> void:
	var level: LevelData = _level([["taxi", "b"], ["taxi", "a"]], [["a", 4], ["b", 4]])
	var first: GameRules = GameRules.new(level)
	var second: GameRules = GameRules.new(level)
	first.tap(0)
	second.tap(0)
	assert_eq(_types(first.tap(1)), _types(second.tap(1)))


func test_queue_logic_take_advances_blocks() -> void:
	var blocks: Array[QueueBlock] = [QueueBlock.new("a", 2), QueueBlock.new("b", 4)]
	var queue: QueueLogic = QueueLogic.new(blocks)
	assert_eq(queue.head_dest(), "a")
	assert_eq(queue.take(8), 2)
	assert_eq(queue.head_dest(), "b")
	assert_eq(queue.total_remaining(), 4)
	assert_eq(queue.take(1), 1)
	assert_eq(queue.head_remaining(), 3)
	queue.take(3)
	assert_true(queue.is_empty())
	assert_eq(queue.head_dest(), "")
