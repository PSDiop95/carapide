extends GutTest
## BLOCKED, Coxeur, Apprenti, file mutable, boosters_needed_min.


func _level(vehicles: Array, queue: Array, slots: int = 2) -> LevelData:
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


## Deux places, toutes prises par b et c, tête a : bloqué sans correspondance.
func _stuck_level() -> LevelData:
	return _level([["taxi", "b"], ["taxi", "c"], ["taxi", "a"]], [["a", 4], ["b", 4], ["c", 4]])


func _stuck_rules(access: BoosterAccess) -> GameRules:
	var rules: GameRules = GameRules.new(_stuck_level(), access)
	rules.tap(0)
	rules.tap(1)
	return rules


func _types(events: Array[GameEvent]) -> Array[GameEvent.Type]:
	var types: Array[GameEvent.Type] = []
	for event: GameEvent in events:
		types.append(event.type)
	return types


func _queue_text(blocks: Array[QueueBlock]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for block: QueueBlock in blocks:
		parts.append("%s%d" % [block.dest, block.count])
	return " ".join(parts)


func _blocks(raw: Array) -> Array[QueueBlock]:
	var blocks: Array[QueueBlock] = []
	for entry: Array in raw:
		var dest: String = entry[0]
		var count: int = entry[1]
		blocks.append(QueueBlock.new(dest, count))
	return blocks


# --- Machine à états ---

func test_without_access_stuck_station_loses_at_once() -> void:
	var rules: GameRules = GameRules.new(_stuck_level())
	rules.tap(0)
	var events: Array[GameEvent] = rules.tap(1)
	assert_eq(rules.status, GameRules.Status.LOST)
	assert_true(_types(events).has(GameEvent.Type.LOST))


func test_playing_to_blocked_when_a_booster_can_help() -> void:
	var rules: GameRules = GameRules.new(_stuck_level(), BoosterAccess.new(true))
	rules.tap(0)
	assert_eq(rules.status, GameRules.Status.PLAYING)
	var events: Array[GameEvent] = rules.tap(1)
	assert_eq(rules.status, GameRules.Status.BLOCKED)
	assert_true(_types(events).has(GameEvent.Type.RESCUE_NEEDED))
	assert_false(_types(events).has(GameEvent.Type.LOST))


func test_blocked_ignores_taps() -> void:
	var rules: GameRules = _stuck_rules(BoosterAccess.new(true))
	assert_true(rules.tap(2).is_empty())
	assert_eq(rules.status, GameRules.Status.BLOCKED)


func test_blocked_to_lost_by_abandon() -> void:
	var rules: GameRules = _stuck_rules(BoosterAccess.new(true))
	var events: Array[GameEvent] = rules.abandon()
	assert_eq(rules.status, GameRules.Status.LOST)
	assert_true(_types(events).has(GameEvent.Type.LOST))


func test_abandon_outside_blocked_does_nothing() -> void:
	var rules: GameRules = GameRules.new(_stuck_level(), BoosterAccess.new(true))
	assert_true(rules.abandon().is_empty())
	assert_eq(rules.status, GameRules.Status.PLAYING)


func test_blocked_to_playing_by_coxeur() -> void:
	var rules: GameRules = _level_for_resume()
	assert_eq(rules.status, GameRules.Status.BLOCKED)
	rules.use_coxeur(2)
	assert_eq(rules.status, GameRules.Status.PLAYING)


## Après le vol de a, b embarque et part : une place se libère, d reste à sortir.
func _level_for_resume() -> GameRules:
	var level: LevelData = _level(
		[["taxi", "b"], ["taxi", "c"], ["taxi", "a"], ["taxi", "d"]],
		[["a", 4], ["b", 4], ["d", 4], ["c", 4]])
	var rules: GameRules = GameRules.new(level, BoosterAccess.new(true))
	rules.tap(0)
	rules.tap(1)
	return rules


func test_blocked_to_playing_by_apprenti() -> void:
	var rules: GameRules = _stuck_rules(BoosterAccess.new(true))
	rules.use_apprenti()
	assert_eq(rules.status, GameRules.Status.PLAYING)
	assert_eq(rules.occupied_slots(), 0)


func test_blocked_to_won_by_booster_when_queue_empties() -> void:
	var rules: GameRules = GameRules.new(_level([["taxi", "b"], ["taxi", "a"]], [["a", 4], ["b", 4]], 1), BoosterAccess.new(true))
	rules.tap(0)
	assert_eq(rules.status, GameRules.Status.BLOCKED)
	var events: Array[GameEvent] = rules.use_coxeur(1)
	assert_eq(rules.status, GameRules.Status.WON)
	assert_true(_types(events).has(GameEvent.Type.WON))


func test_lost_when_coxeur_is_taken_and_apprenti_is_unavailable() -> void:
	var access: OnlyCoxeur = OnlyCoxeur.new()
	var level: LevelData = _level(
		[["taxi", "b"], ["taxi", "c"], ["taxi", "d"], ["taxi", "a"]],
		[["a", 4], ["b", 4], ["c", 4], ["d", 4]])
	var rules: GameRules = GameRules.new(level, access)
	rules.tap(0)
	rules.tap(1)
	assert_eq(rules.status, GameRules.Status.BLOCKED)
	rules.use_coxeur(2)
	assert_eq(rules.status, GameRules.Status.LOST)


# --- Coxeur ---

func test_coxeur_ignores_blockers_and_parks_on_reserved_slot() -> void:
	var level: LevelData = _level(
		[["taxi", "a", [1.0, 2.0]], ["taxi", "b", [1.0, 8.0]]],
		[["a", 4], ["b", 4]], 4)
	var rules: GameRules = GameRules.new(level)
	assert_eq(_types(rules.tap(0)), [GameEvent.Type.BLOCKED] as Array[GameEvent.Type])
	var events: Array[GameEvent] = rules.use_coxeur(0)
	assert_eq(events[0].type, GameEvent.Type.FLEW)
	assert_eq(events[0].slot, 4)


func test_coxeur_vehicle_loads_and_departs_then_slot_is_free_again() -> void:
	var level: LevelData = _level(
		[["taxi", "a"], ["taxi", "b"]],
		[["a", 4], ["b", 4]], 4)
	var rules: GameRules = GameRules.new(level)
	var events: Array[GameEvent] = rules.use_coxeur(0)
	assert_eq(_types(events), [GameEvent.Type.FLEW, GameEvent.Type.BOARDED, GameEvent.Type.DEPARTED] as Array[GameEvent.Type])
	assert_true(rules.can_use_coxeur(1))


func test_coxeur_refused_when_slot_taken_or_vehicle_gone() -> void:
	var level: LevelData = _level([["taxi", "b"], ["taxi", "c"], ["taxi", "a"]], [["a", 4], ["b", 4], ["c", 4]], 4)
	var rules: GameRules = GameRules.new(level)
	rules.use_coxeur(0)
	assert_false(rules.can_use_coxeur(1))
	assert_true(rules.use_coxeur(1).is_empty())
	assert_true(rules.use_coxeur(0).is_empty())
	assert_eq(rules.occupied_slots(), 1)


func test_empty_coxeur_slot_does_not_count_and_normal_tap_never_uses_it() -> void:
	var level: LevelData = _level([["taxi", "b"], ["taxi", "a"]], [["a", 4], ["b", 4]], 1)
	var station: StationLogic = StationLogic.new(level.slots)
	assert_false(station.is_full())
	var parked: ParkedVehicle = station.park(0, "b", 4)
	assert_eq(parked.slot, 0)
	assert_true(station.is_full())
	assert_true(station.is_coxeur_free())
	assert_eq(station.first_free_slot(), StationLogic.NO_SLOT)


func test_coxeur_occupied_leaves_normal_slots_available() -> void:
	var station: StationLogic = StationLogic.new(1)
	station.park_coxeur(0, "a", 4)
	assert_false(station.is_full())
	assert_eq(station.first_free_slot(), 0)


# --- Apprenti : file ---

func test_level_queue_stays_immutable_after_boarding_and_apprenti() -> void:
	var level: LevelData = _stuck_level()
	var rules: GameRules = _stuck_rules(BoosterAccess.new(true))
	rules.use_apprenti()
	var fresh: LevelData = _stuck_level()
	assert_eq(_queue_text(level.queue), _queue_text(fresh.queue))
	var other: LevelData = _level([["taxi", "a"]], [["a", 4]])
	GameRules.new(other).tap(0)
	assert_eq(other.queue[0].count, 4)


func test_apprenti_nominal_brings_needs_in_slot_order_and_keeps_the_rest_stable() -> void:
	var queue: QueueLogic = QueueLogic.new(_blocks([["x", 2], ["a", 2], ["y", 2], ["b", 4], ["a", 2]]))
	queue.prioritize(_blocks([["b", 4], ["a", 3]]))
	assert_eq(_queue_text(queue.blocks()), "b4 a3 x2 y2 a1")


func test_apprenti_missing_destination_brings_what_is_left() -> void:
	var queue: QueueLogic = QueueLogic.new(_blocks([["x", 2], ["a", 2], ["y", 2]]))
	queue.prioritize(_blocks([["a", 4], ["z", 2]]))
	assert_eq(_queue_text(queue.blocks()), "a2 x2 y2")


func test_apprenti_two_vehicles_same_destination() -> void:
	var level: LevelData = _level(
		[["taxi", "a"], ["taxi", "a"], ["taxi", "x"]],
		[["x", 2], ["a", 3], ["x", 2], ["a", 5]])
	var rules: GameRules = GameRules.new(level, BoosterAccess.new(true))
	rules.tap(0)
	rules.tap(1)
	assert_eq(rules.occupied_slots(), 2)
	var events: Array[GameEvent] = rules.use_apprenti()
	assert_eq(_queue_text(events[0].blocks), "a8 x4")
	assert_eq(rules.occupied_slots(), 0)
	assert_eq(rules.passengers_remaining(), 4)


func test_apprenti_on_ordered_queue_is_a_noop_not_consumed() -> void:
	var queue: QueueLogic = QueueLogic.new(_blocks([["a", 4], ["b", 2]]))
	assert_false(queue.would_reorder(_blocks([["a", 4]])))
	var level: LevelData = _level([["taxi", "a"]], [["a", 4]], 4)
	var rules: GameRules = GameRules.new(level, BoosterAccess.new(true))
	assert_false(rules.can_use_apprenti())
	assert_true(rules.use_apprenti().is_empty())


func test_apprenti_empties_the_station_and_keeps_remaining_order() -> void:
	var level: LevelData = _level(
		[["taxi", "b"], ["taxi", "c"], ["taxi", "a"], ["taxi", "d"]],
		[["a", 2], ["d", 2], ["b", 4], ["a", 2], ["c", 4], ["d", 2]])
	var rules: GameRules = GameRules.new(level, BoosterAccess.new(true))
	rules.tap(0)
	rules.tap(1)
	var events: Array[GameEvent] = rules.use_apprenti()
	assert_eq(events[0].type, GameEvent.Type.QUEUE_REORDERED)
	assert_eq(_queue_text(events[0].blocks), "b4 c4 a2 d2 a2 d2")
	assert_eq(rules.occupied_slots(), 0)
	assert_eq(rules.status, GameRules.Status.PLAYING)


func test_copy_is_independent() -> void:
	var rules: GameRules = GameRules.new(_stuck_level(), BoosterAccess.new(true))
	rules.tap(0)
	var clone: GameRules = rules.copy()
	clone.tap(1)
	clone.use_apprenti()
	assert_eq(rules.occupied_slots(), 1)
	assert_eq(rules.passengers_remaining(), 12)
	assert_eq(rules.status, GameRules.Status.PLAYING)
	assert_true(rules.can_use_coxeur(1))


# --- Solveur avec boosters ---

func test_boosters_needed_min_is_zero_on_solvable_level() -> void:
	var level: LevelData = _level([["taxi", "a"], ["taxi", "b"]], [["a", 4], ["b", 4]], 2)
	var result: BoosterSolveResult = BoosterSolver.boosters_needed_min(level, 2)
	assert_eq(result.needed_min, 0)
	assert_false(result.aborted)


func test_boosters_needed_min_counts_booster_on_level_needing_one() -> void:
	## Tête bloquée derrière d'autres destinations, une seule place.
	var level: LevelData = _level(
		[["taxi", "a", [1.0, 2.0]], ["taxi", "b", [1.0, 8.0]]],
		[["a", 4], ["b", 4]], 1)
	assert_false(Solver.solve(level, 1).solvable)
	var result: BoosterSolveResult = BoosterSolver.boosters_needed_min(level, 1)
	assert_eq(result.needed_min, 1)


func test_margin_stays_computed_without_booster() -> void:
	var level: LevelData = _level(
		[["taxi", "a", [1.0, 2.0]], ["taxi", "b", [1.0, 8.0]]],
		[["a", 4], ["b", 4]], 2)
	var result: SolverResult = Solver.solve(level, 2)
	assert_eq(result.min_slots, 2)
	assert_eq(result.min_margin, 0)


func test_advise_prefers_a_booster_that_wins() -> void:
	var rules: GameRules = _stuck_rules(BoosterAccess.new(true))
	var advice: BoosterAdvice = BoosterSolver.advise(rules, BoosterAccess.new(true))
	assert_not_null(advice)
	assert_eq(advice.kind, BoosterAccess.Kind.COXEUR)
	assert_eq(advice.vehicle_id, 2)
	assert_eq(advice.further_boosters, 0)
	assert_eq(rules.status, GameRules.Status.BLOCKED)


func test_advise_only_offers_what_the_player_can_obtain() -> void:
	var rules: GameRules = _stuck_rules(BoosterAccess.new(true))
	var advice: BoosterAdvice = BoosterSolver.advise(rules, OnlyApprenti.new())
	assert_eq(advice.kind, BoosterAccess.Kind.APPRENTI)
	assert_null(BoosterSolver.advise(rules, BoosterAccess.new()))


func test_advise_reports_abort_with_fallback() -> void:
	var rules: GameRules = _level_for_resume()
	var advice: BoosterAdvice = BoosterSolver.advise(rules, BoosterAccess.new(true), 0)
	assert_true(advice.aborted)
	assert_eq(advice.further_boosters, BoosterAdvice.UNKNOWN)


class OnlyCoxeur:
	extends BoosterAccess

	func can_obtain(kind: BoosterAccess.Kind) -> bool:
		return kind == BoosterAccess.Kind.COXEUR


class OnlyApprenti:
	extends BoosterAccess

	func can_obtain(kind: BoosterAccess.Kind) -> bool:
		return kind == BoosterAccess.Kind.APPRENTI
