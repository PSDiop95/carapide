extends GutTest
## Garage mécano : évacuation, place en plus, retour automatique, conservation, solveur, pop-up.

const RANDOM_STATES: int = 1000
const MIN_GARAGES: int = 500
const CONSERVATION_LEVELS: Array[int] = [6, 10, 13, 15]


func _load(number: int) -> LevelData:
	return LevelLoader.load_file(LevelCatalog.level_paths()[number - 1], VehicleCatalog.load_default()).level


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


## Deux places prises par b et c, tête a encore dans le bouchon.
func _stuck_rules(access: BoosterAccess = BoosterAccess.new(true)) -> GameRules:
	var level: LevelData = _level([["taxi", "b"], ["taxi", "c"], ["taxi", "a"]], [["a", 4], ["b", 4], ["c", 4]])
	var rules: GameRules = GameRules.new(level, access)
	rules.tap(0)
	rules.tap(1)
	return rules


func _types(events: Array[GameEvent]) -> Array[GameEvent.Type]:
	var types: Array[GameEvent.Type] = []
	for event: GameEvent in events:
		types.append(event.type)
	return types


class OnlyGarage:
	extends BoosterAccess

	func can_obtain(kind: BoosterAccess.Kind) -> bool:
		return kind == BoosterAccess.Kind.GARAGE

	func garage_max_uses() -> int:
		return 2


func test_garage_empties_station_and_adds_a_slot() -> void:
	var rules: GameRules = _stuck_rules()
	assert_eq(rules.status, GameRules.Status.BLOCKED)
	var events: Array[GameEvent] = rules.use_garage()
	assert_eq(events[0].type, GameEvent.Type.GARAGED)
	assert_eq(events[0].garaged_ids, PackedInt32Array([0, 1]))
	assert_eq(events[0].count, 3)
	assert_eq(rules.slot_count(), 3)
	assert_eq(rules.garage_size(), 2)
	assert_eq(rules.occupied_slots(), 0)
	assert_eq(rules.status, GameRules.Status.PLAYING)


func test_garage_only_in_blocked_state() -> void:
	var level: LevelData = _level([["taxi", "a"], ["taxi", "b"]], [["a", 4], ["b", 4]])
	var rules: GameRules = GameRules.new(level, BoosterAccess.new(true))
	assert_false(rules.can_use_garage())
	assert_true(rules.use_garage().is_empty())
	assert_eq(rules.slot_count(), 2)


func test_garaged_vehicle_keeps_passengers_and_returns_to_finish() -> void:
	# a charge 4 sur 8 puis la tête passe à b : a reste garé à moitié plein.
	var level: LevelData = _level(
		[["car_rapide", "a"], ["taxi", "c"], ["taxi", "b"]],
		[["a", 4], ["b", 4], ["a", 4], ["c", 4]])
	var rules: GameRules = GameRules.new(level, BoosterAccess.new(true))
	rules.tap(0)
	rules.tap(1)
	assert_eq(rules.status, GameRules.Status.BLOCKED)
	assert_eq(rules.passengers_aboard(), 4)
	rules.use_garage()
	assert_eq(rules.passengers_aboard(), 4, "Passagers conservés au Garage")
	var events: Array[GameEvent] = rules.tap(2)
	assert_has(_types(events), GameEvent.Type.RECALLED, "Tête a : retour automatique")
	var recalled: GameEvent = null
	for event: GameEvent in events:
		if event.type == GameEvent.Type.RECALLED and recalled == null:
			recalled = event
	assert_eq(recalled.vehicle_id, 0)
	assert_eq(recalled.loaded, 4)
	assert_eq(rules.status, GameRules.Status.WON)


func test_fullest_vehicle_returns_first() -> void:
	var garage: GarageLogic = GarageLogic.new()
	var low: ParkedVehicle = ParkedVehicle.new(1, "a", 8, 0)
	low.loaded = 2
	var high: ParkedVehicle = ParkedVehicle.new(2, "a", 8, 1)
	high.loaded = 6
	var other: ParkedVehicle = ParkedVehicle.new(3, "b", 8, 2)
	other.loaded = 7
	garage.store(low)
	garage.store(high)
	garage.store(other)
	assert_eq(garage.take_fullest("a").vehicle_id, 2)
	assert_eq(garage.take_fullest("a").vehicle_id, 1)
	assert_null(garage.take_fullest("a"))
	assert_eq(garage.size(), 1)


func test_no_return_while_station_is_full() -> void:
	var rules: GameRules = GameRules.new(_level([["taxi", "a"]], [["a", 4]], 1), BoosterAccess.new(true))
	assert_false(rules.can_use_garage())


func test_maximum_two_uses_per_level() -> void:
	var vehicles: Array = [["taxi", "b"], ["taxi", "c"], ["taxi", "d"], ["taxi", "e"], ["taxi", "f"], ["taxi", "g"], ["taxi", "a"]]
	var queue: Array = [["a", 4], ["b", 4], ["c", 4], ["d", 4], ["e", 4], ["f", 4], ["g", 4]]
	var rules: GameRules = GameRules.new(_level(vehicles, queue, 1), OnlyGarage.new())
	rules.tap(0)
	assert_eq(rules.status, GameRules.Status.BLOCKED)
	rules.use_garage()
	rules.tap(1)
	rules.tap(2)
	assert_eq(rules.status, GameRules.Status.BLOCKED)
	rules.use_garage()
	assert_eq(rules.slot_count(), 3)
	rules.tap(3)
	rules.tap(4)
	rules.tap(5)
	assert_eq(rules.status, GameRules.Status.LOST, "Troisième Garage refusé : plus de secours")
	assert_false(rules.can_use_garage())


func test_blocked_detection_counts_the_garage_offer() -> void:
	var with_garage: GameRules = _stuck_rules(OnlyGarage.new())
	assert_eq(with_garage.status, GameRules.Status.BLOCKED)
	var without: GameRules = _stuck_rules(BoosterAccess.new())
	assert_eq(without.status, GameRules.Status.LOST)


func test_no_garage_rescue_when_nothing_could_come_after() -> void:
	# Le seul véhicule restant est bloqué par un autre garé impossible : ici aucun ne sort.
	var level: LevelData = _level(
		[["taxi", "b"], ["taxi", "a", [3.0, 3.0]], ["taxi", "c", [3.0, 6.0]], ["taxi", "d", [3.0, 9.0]]],
		[["a", 4], ["b", 4], ["c", 4], ["d", 4]], 1)
	var rules: GameRules = GameRules.new(level, OnlyGarage.new())
	rules.tap(0)
	assert_true(rules.status == GameRules.Status.BLOCKED or rules.status == GameRules.Status.LOST)
	if rules.status == GameRules.Status.BLOCKED:
		assert_true(rules.can_use_garage())


func test_copy_of_garage_is_independent() -> void:
	var rules: GameRules = _stuck_rules()
	rules.use_garage()
	var clone: GameRules = rules.copy()
	clone.tap(2)
	assert_eq(rules.garage_size(), 2)
	assert_eq(rules.occupied_slots(), 0)


func test_state_key_sees_garage_and_new_slot() -> void:
	var rules: GameRules = _stuck_rules()
	var before: String = rules.state_key()
	rules.use_garage()
	assert_ne(rules.state_key(), before)


func test_solver_counts_garage_as_a_booster() -> void:
	# Aucun coxeur ni apprenti utile : seul le Garage rouvre une place.
	var rules: GameRules = _stuck_rules(OnlyGarage.new())
	assert_false(BoosterSolver.can_still_win(rules, 0))
	assert_true(BoosterSolver.can_still_win(rules, 1))


func test_solver_can_win_after_a_garage_state() -> void:
	var rules: GameRules = _stuck_rules()
	rules.use_garage()
	assert_true(BoosterSolver.can_still_win(rules, 0), "Reprise après Garage gagnable sans autre booster")


func test_advice_never_proposes_the_garage() -> void:
	var advice: BoosterAdvice = BoosterSolver.advise(_stuck_rules(OnlyGarage.new()), OnlyGarage.new())
	assert_null(advice, "Le Garage a son propre bouton")


func test_inventory_pays_garage_with_coins_or_ad_not_stock() -> void:
	var wallet: WalletService = WalletService.new()
	var inventory: BoosterInventory = BoosterInventory.new(BoosterConfig.load_default(), SaveService.new(), wallet, AdsService.new())
	inventory.enter_level(1)
	assert_eq(inventory.stock(BoosterAccess.Kind.GARAGE), 0)
	assert_eq(inventory.config.price(BoosterAccess.Kind.GARAGE), 900)
	assert_eq(inventory.garage_max_uses(), 2)
	assert_eq(inventory.offer(BoosterAccess.Kind.GARAGE), BoosterInventory.Offer.AD)
	wallet.add(900)
	assert_eq(inventory.offer(BoosterAccess.Kind.GARAGE), BoosterInventory.Offer.COINS)


## Aucun passager créé ni perdu : file + à bord + partis reste égal au total, à chaque pas.
func test_conservation_over_random_states() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2026
	var garages: int = 0
	var levels: Array[LevelData] = []
	for number: int in CONSERVATION_LEVELS:
		levels.append(_load(number))
	for run: int in RANDOM_STATES:
		garages += _play_random_game(levels[run % levels.size()], rng)
	assert_gt(garages, MIN_GARAGES, "Le Garage doit être réellement exercé")


func _play_random_game(level: LevelData, rng: RandomNumberGenerator) -> int:
	var rules: GameRules = GameRules.new(level, BoosterAccess.new(true))
	var total: int = level.total_passengers()
	var departed: Array[int] = [0]
	var garages: int = 0
	while rules.status == GameRules.Status.PLAYING or rules.status == GameRules.Status.BLOCKED:
		var events: Array[GameEvent] = _random_step(rules, rng)
		if events.is_empty():
			break
		if events[0].type == GameEvent.Type.GARAGED:
			garages += 1
		_count_departures(events, rules, departed)
		var accounted: int = rules.passengers_remaining() + rules.passengers_aboard() + departed[0]
		if accounted != total:
			assert_eq(accounted, total, "Passagers non conservés")
			return garages
		if rules.seats_left_by_dest() != rules.passengers_left_by_dest():
			assert_eq(rules.seats_left_by_dest(), rules.passengers_left_by_dest(), "Sièges et file divergent")
			return garages
	return garages


func _random_step(rules: GameRules, rng: RandomNumberGenerator) -> Array[GameEvent]:
	if rules.status == GameRules.Status.BLOCKED:
		return rules.use_garage() if rules.can_use_garage() else rules.abandon()
	var free: PackedInt32Array = rules.free_vehicles()
	if free.is_empty():
		return rules.abandon()
	return rules.tap(free[rng.randi_range(0, free.size() - 1)])


func _count_departures(events: Array[GameEvent], rules: GameRules, departed: Array[int]) -> void:
	for event: GameEvent in events:
		if event.type == GameEvent.Type.DEPARTED:
			departed[0] += rules.vehicle_capacity(event.vehicle_id)


## Pop-up : conseil, Garage, Recommencer, dans cet ordre, et rappel de la carte.
func test_popup_order_and_hold_to_see_the_map() -> void:
	UiStrings.register()
	var popup: BlockedPopup = BlockedPopup.new()
	add_child_autofree(popup)
	popup.open("Conseil", "Garage")
	var column: Node = popup.advice_button.get_parent()
	assert_lt(popup.advice_button.get_index(), popup.garage_button.get_index())
	assert_lt(popup.garage_button.get_index(), popup.restart_button.get_index())
	var hint: Label = column.get_child(column.get_child_count() - 1)
	assert_eq(hint.text, tr("BLOCKED_HOLD_HINT"))
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	popup._gui_input(press)
	assert_eq(popup.modulate.a, 0.0)
	press.pressed = false
	popup._gui_input(press)
	assert_eq(popup.modulate.a, 1.0)
	popup.open("", "")
	assert_false(popup.advice_button.visible)
	assert_false(popup.garage_button.visible)
	assert_true(popup.restart_button.visible)
