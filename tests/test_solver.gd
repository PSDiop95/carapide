extends GutTest

const SEED: int = 20261101
const RANDOM_LEVELS: int = 30
const RANDOM_VEHICLES: int = 5
const DESTS: Array[String] = ["a", "b", "c"]

var _catalog: VehicleCatalog


func before_all() -> void:
	_catalog = VehicleCatalog.load_default()


func _lanes(vehicles: Array, queue: Array, slots: int = 4) -> LevelData:
	var entries: Array = []
	for index: int in vehicles.size():
		entries.append({"type": "taxi", "dest": vehicles[index], "pos": [float(index) + 1.0, 5.0], "angle": 90})
	var blocks: Array = []
	for block: Array in queue:
		blocks.append({"dest": block[0], "count": block[1]})
	var raw: Dictionary = {"id": 1, "slots": slots, "board": [12, 12], "vehicles": entries, "queue": blocks}
	var result: LevelLoadResult = LevelLoader.parse_dict(raw, _catalog)
	assert_true(result.is_ok(), "%s" % result.errors)
	return result.level


func _replay_wins(level: LevelData, solution: PackedInt32Array) -> bool:
	var rules: GameRules = GameRules.new(level)
	for vehicle_id: int in solution:
		rules.tap(vehicle_id)
	return rules.status == GameRules.Status.WON


func test_margin_is_slots_minus_minimum_needed() -> void:
	var level: LevelData = _lanes(["a", "b"], [["a", 4], ["b", 4]])
	var result: SolverResult = Solver.solve(level, 4)
	assert_true(result.solvable)
	assert_eq(result.min_margin, 3)
	assert_eq(result.min_slots, 1)


func test_interleaved_queue_needs_two_slots() -> void:
	var level: LevelData = _lanes(["a", "b"], [["a", 2], ["b", 2], ["a", 2], ["b", 2]])
	var result: SolverResult = Solver.solve(level, 4)
	assert_eq(result.min_slots, 2)
	assert_eq(result.min_margin, 2)


func test_not_enough_slots_is_unsolvable() -> void:
	var level: LevelData = _lanes(["a", "b"], [["a", 2], ["b", 2], ["a", 2], ["b", 2]], 1)
	var result: SolverResult = Solver.solve(level, 1)
	assert_false(result.solvable)
	assert_eq(result.min_margin, -1)
	assert_false(result.aborted)


func test_blocking_order_is_respected_in_solution() -> void:
	var raw: Dictionary = {
		"id": 1, "slots": 4, "board": [8, 12],
		"vehicles": [
			{"type": "taxi", "dest": "a", "pos": [1, 2], "angle": 90},
			{"type": "taxi", "dest": "b", "pos": [1, 8], "angle": 90},
		],
		"queue": [{"dest": "a", "count": 4}, {"dest": "b", "count": 4}],
	}
	var level: LevelData = LevelLoader.parse_dict(raw, _catalog).level
	var result: SolverResult = Solver.solve(level, 4)
	assert_eq(result.min_slots, 2, "b doit sortir et attendre avant a")
	assert_true(_replay_wins(level, result.solution))


func test_node_limit_reports_abort_not_unsolvable() -> void:
	var level: LevelData = _lanes(["a", "b", "a", "b"], [["a", 8], ["b", 8]])
	var result: SolverResult = Solver.solve(level, 1, 1)
	assert_true(result.aborted)
	assert_false(result.solvable)


func test_arrival_order_within_destination_changes_outcome() -> void:
	# Gare de 2 : deux véhicules de "a" de tailles différentes. Sortir le grand d'abord
	# bloque sa place ; la clé d'état doit distinguer les ordres d'arrivée.
	var raw: Dictionary = {
		"id": 1, "slots": 2, "board": [8, 12],
		"vehicles": [
			{"type": "taxi", "dest": "a", "pos": [1, 5], "angle": 90},
			{"type": "car_rapide", "dest": "a", "pos": [2, 5], "angle": 90},
			{"type": "taxi", "dest": "b", "pos": [3, 5], "angle": 90},
		],
		"queue": [{"dest": "a", "count": 4}, {"dest": "b", "count": 4}, {"dest": "a", "count": 8}],
	}
	var level: LevelData = LevelLoader.parse_dict(raw, _catalog).level
	assert_eq(Solver.solve(level, 2).min_slots, _brute_force_min_slots(level))


func test_solver_agrees_with_exhaustive_game_rules_on_random_levels() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	for _round: int in RANDOM_LEVELS:
		var level: LevelData = _random_level(rng)
		var result: SolverResult = Solver.solve(level, level.slots)
		var expected: int = _brute_force_min_slots(level)
		var found: int = result.min_slots
		assert_eq(found, expected, "%s" % JSON.stringify(_describe(level)))
		if found > 0:
			assert_true(_replay_wins(level, result.solution))


func test_insoluble_fixture_fails_level_check() -> void:
	var errors: PackedStringArray = LevelChecker.check_file("res://tests/fixtures/insoluble.json", _catalog)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "insoluble")


func test_level_check_reports_invalid_file() -> void:
	assert_false(LevelChecker.check_file("res://tests/fixtures/absent.json", _catalog).is_empty())


func _random_level(rng: RandomNumberGenerator) -> LevelData:
	var vehicles: Array = []
	var chunks: Array = []
	for _index: int in RANDOM_VEHICLES:
		var dest: String = DESTS[rng.randi_range(0, DESTS.size() - 1)]
		vehicles.append(dest)
		chunks.append([dest, 2])
		chunks.append([dest, 2])
	for index: int in range(chunks.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var held: Array = chunks[index]
		chunks[index] = chunks[other]
		chunks[other] = held
	return _lanes(vehicles, chunks)


func _describe(level: LevelData) -> Array:
	var blocks: Array = []
	for block: QueueBlock in level.queue:
		blocks.append([block.dest, block.count])
	return blocks


## Plus petit nombre de places gagnant, par essai de tous les ordres via GameRules.
func _brute_force_min_slots(level: LevelData) -> int:
	var original_slots: int = level.slots
	var found: int = -1
	for slots: int in range(1, original_slots + 1):
		level.slots = slots
		if _can_win(level, PackedInt32Array()):
			found = slots
			break
	level.slots = original_slots
	return found


func _can_win(level: LevelData, taps: PackedInt32Array) -> bool:
	for vehicle: LevelVehicle in level.vehicles:
		if taps.has(vehicle.id):
			continue
		var attempt: PackedInt32Array = taps.duplicate()
		attempt.append(vehicle.id)
		var rules: GameRules = GameRules.new(level)
		var events: Array[GameEvent] = []
		for vehicle_id: int in attempt:
			events = rules.tap(vehicle_id)
		if rules.status == GameRules.Status.WON:
			return true
		var was_blocked: bool = events.size() == 1 and events[0].type == GameEvent.Type.BLOCKED
		if rules.status == GameRules.Status.PLAYING and not was_blocked and _can_win(level, attempt):
			return true
	return false
