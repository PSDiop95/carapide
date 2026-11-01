extends GutTest
## Dioulé : invariant de capacité, non-consommation, déterminisme, véhicules garés intacts.

const MAX_NODES: int = 260
const RANDOM_RUNS: int = 12


func _load(number: int) -> LevelData:
	return LevelLoader.load_file(LevelCatalog.level_paths()[number - 1], VehicleCatalog.load_default()).level


func _level(vehicles: Array, queue: Array, slots: int = 2) -> LevelData:
	var entries: Array = []
	var lane: float = 1.0
	for vehicle: Array in vehicles:
		entries.append({"type": vehicle[0], "dest": vehicle[1], "pos": [lane, 5.0], "angle": 90})
		lane += 1.0
	var blocks: Array = []
	for block: Array in queue:
		blocks.append({"dest": block[0], "count": block[1]})
	var raw: Dictionary = {"id": 1, "slots": slots, "board": [12, 12], "vehicles": entries, "queue": blocks}
	var result: LevelLoadResult = LevelLoader.parse_dict(raw, VehicleCatalog.load_default())
	assert_true(result.is_ok(), "%s" % result.errors)
	return result.level


## Position de jeu tirée au hasard.
func _random_state(level: LevelData, rng: RandomNumberGenerator) -> GameRules:
	var rules: GameRules = GameRules.new(level, BoosterAccess.new(true))
	var taps: int = rng.randi_range(0, 4)
	for _tap: int in taps:
		var free: PackedInt32Array = rules.free_vehicles()
		if rules.status != GameRules.Status.PLAYING or free.is_empty():
			break
		rules.tap(free[rng.randi_range(0, free.size() - 1)])
	return rules


func test_invariant_seats_equal_passengers_after_mix() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var mixes: int = 0
	for number: int in [10, 13, 15]:
		for _run: int in RANDOM_RUNS:
			var rules: GameRules = _random_state(_load(number), rng)
			var mix: PackedStringArray = DiouleMixer.mix(rules, MAX_NODES)
			if mix.is_empty():
				continue
			mixes += 1
			rules.use_dioule(mix)
			assert_eq(rules.seats_left_by_dest(), rules.passengers_left_by_dest(), "Niveau %d" % number)
	assert_gt(mixes, 10, "Trop peu de mélanges pour prouver l'invariant")


func test_mix_keeps_capacity_of_each_vehicle_class() -> void:
	var level: LevelData = _load(13)
	var rules: GameRules = GameRules.new(level, BoosterAccess.new(true))
	var mix: PackedStringArray = DiouleMixer.mix(rules, MAX_NODES)
	assert_false(mix.is_empty())
	var before: Dictionary = {}
	var after: Dictionary = {}
	for vehicle: LevelVehicle in level.vehicles:
		var old_key: String = "%d/%s" % [vehicle.capacity, vehicle.dest]
		var new_key: String = "%d/%s" % [vehicle.capacity, mix[vehicle.id]]
		before[old_key] = before.get(old_key, 0) + 1
		after[new_key] = after.get(new_key, 0) + 1
	assert_eq(before, after)
	assert_ne(mix, rules.destinations(), "Le mélange doit changer quelque chose")


func test_same_state_same_seed_same_result() -> void:
	var level: LevelData = _load(14)
	var first: GameRules = GameRules.new(level, BoosterAccess.new(true))
	var second: GameRules = GameRules.new(level, BoosterAccess.new(true))
	assert_eq(first.state_key(), second.state_key())
	assert_eq(DiouleMixer.mix(first, MAX_NODES), DiouleMixer.mix(second, MAX_NODES))
	var seeded: PackedStringArray = DiouleMixer.mix_with_seed(first, MAX_NODES, 1234)
	assert_eq(seeded, DiouleMixer.mix_with_seed(second, MAX_NODES, 1234))


func test_other_seed_can_give_other_result() -> void:
	var rules: GameRules = GameRules.new(_load(15), BoosterAccess.new(true))
	var results: Dictionary = {}
	for seed_value: int in 8:
		results[DiouleMixer.mix_with_seed(rules, MAX_NODES, seed_value)] = true
	assert_gt(results.size(), 1)


func test_chosen_mix_is_winnable_with_current_slots() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	for _run: int in RANDOM_RUNS:
		var rules: GameRules = _random_state(_load(13), rng)
		var mix: PackedStringArray = DiouleMixer.mix(rules, MAX_NODES)
		if not mix.is_empty():
			assert_true(BoosterSolver.can_still_win(rules.with_destinations(mix), 0))


func test_parked_vehicles_and_queue_stay_untouched() -> void:
	var rules: GameRules = GameRules.new(_load(13), BoosterAccess.new(true))
	var parked_id: int = rules.free_vehicles()[0]
	rules.tap(parked_id)
	assert_true(rules.can_use_dioule())
	var parked_dest: String = rules.destinations()[parked_id]
	var queue_before: Dictionary[String, int] = rules.passengers_left_by_dest()
	var mix: PackedStringArray = DiouleMixer.mix(rules, MAX_NODES)
	assert_false(mix.is_empty())
	assert_eq(mix[parked_id], parked_dest, "Véhicule garé intact")
	var events: Array[GameEvent] = rules.use_dioule(mix)
	assert_eq(rules.passengers_left_by_dest(), queue_before)
	assert_eq(events.size(), 1)
	assert_false(events[0].dests_by_vehicle.has(parked_id), "Événement limité au bouchon")


func test_positions_are_kept_only_destinations_change() -> void:
	var level: LevelData = _load(13)
	var rules: GameRules = GameRules.new(level, BoosterAccess.new(true))
	var free_before: PackedInt32Array = rules.free_vehicles()
	rules.use_dioule(DiouleMixer.mix(rules, MAX_NODES))
	assert_eq(rules.free_vehicles(), free_before)
	assert_eq(level.vehicles[0].dest, _load(13).vehicles[0].dest, "LevelData immuable")


func test_no_mix_when_every_vehicle_shares_the_destination() -> void:
	var level: LevelData = _level([["taxi", "a"], ["taxi", "a"]], [["a", 8]])
	assert_true(DiouleMixer.mix(GameRules.new(level), MAX_NODES).is_empty())


func test_no_mix_when_capacities_forbid_every_swap() -> void:
	var level: LevelData = _level([["taxi", "a"], ["car_rapide", "b"]], [["a", 4], ["b", 8]])
	assert_true(DiouleMixer.mix(GameRules.new(level), MAX_NODES).is_empty())


func test_blocked_game_refuses_the_mix() -> void:
	var level: LevelData = _level([["taxi", "b"], ["taxi", "c"], ["taxi", "a"]], [["a", 4], ["b", 4], ["c", 4]])
	var rules: GameRules = GameRules.new(level, BoosterAccess.new(true))
	rules.tap(0)
	rules.tap(1)
	assert_eq(rules.status, GameRules.Status.BLOCKED)
	assert_false(rules.can_use_dioule())
	assert_true(DiouleMixer.mix(rules, MAX_NODES).is_empty())
	assert_true(rules.use_dioule(rules.destinations()).is_empty())


func test_tapped_vehicle_uses_mixed_destination() -> void:
	var rules: GameRules = GameRules.new(_load(13), BoosterAccess.new(true))
	var mix: PackedStringArray = DiouleMixer.mix(rules, MAX_NODES)
	rules.use_dioule(mix)
	var id: int = rules.free_vehicles()[0]
	var moved: GameEvent = rules.tap(id)[0]
	assert_eq(moved.dest, mix[id])


func test_mixed_state_key_differs_from_original() -> void:
	var rules: GameRules = GameRules.new(_load(13), BoosterAccess.new(true))
	var before: String = rules.state_key()
	rules.use_dioule(DiouleMixer.mix(rules, MAX_NODES))
	assert_ne(rules.state_key(), before)


func test_config_unlocks_at_13_with_gift_and_price() -> void:
	var inventory: BoosterInventory = BoosterInventory.new(BoosterConfig.load_default(), SaveService.new(), WalletService.new(), AdsService.new())
	inventory.enter_level(12)
	assert_eq(inventory.offer(BoosterAccess.Kind.DIOULE), BoosterInventory.Offer.LOCKED)
	inventory.enter_level(13)
	assert_eq(inventory.stock(BoosterAccess.Kind.DIOULE), 3)
	assert_eq(inventory.config.price(BoosterAccess.Kind.DIOULE), 120)


## Non-consommation de bout en bout : la barre ne paie pas sans mélange soluble.
func test_flow_keeps_stock_when_market_is_calm() -> void:
	var save: SaveService = SaveService.new()
	var inventory: BoosterInventory = BoosterInventory.new(BoosterConfig.load_default(), save, WalletService.new(), AdsService.new())
	inventory.enter_level(13)
	UiStrings.register()
	var config: PresentationConfig = PresentationConfig.load_default()
	var flow: BoosterFlow = BoosterFlow.new()
	add_child_autofree(flow)
	var hud: Hud = Hud.new()
	hud.configure(config)
	add_child_autofree(hud)
	flow.setup(inventory, hud)
	var view: LevelView = LevelView.new()
	add_child_autofree(view)
	view.setup(_level([["taxi", "colobane"], ["taxi", "colobane"]], [["colobane", 8]]), config, inventory, true)
	flow.attach(view)
	inventory.mark_tutorial_done(BoosterAccess.Kind.COXEUR)
	inventory.mark_tutorial_done(BoosterAccess.Kind.DIOULE)
	flow.bar.booster_pressed.emit(BoosterAccess.Kind.DIOULE)
	await wait_process_frames(2)
	assert_eq(inventory.stock(BoosterAccess.Kind.DIOULE), 3, "Booster non consommé")
