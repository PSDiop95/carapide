extends GutTest
## Tout niveau listé doit être valide, soluble et conforme au plan de difficulté.

const LEVEL_COUNT: int = 15
## Prompt 02 A7 : à partir de ce niveau, taper le premier véhicule libre doit perdre.
const NAIVE_LOSES_FROM: int = 4
const REQUIRED_MARGIN_MIN: Array[int] = [3, 3, 3, 3, 3, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2]
const REQUIRED_MARGIN_MAX: Array[int] = [3, 3, 3, 3, 3, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2]
const REQUIRED_DESTS_MIN: Array[int] = [2, 2, 2, 2, 2, 3, 3, 3, 3, 5, 3, 3, 3, 3, 3]
const REQUIRED_DESTS_MAX: Array[int] = [2, 2, 2, 3, 3, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5]
## GDD §4 : 8–15 véhicules en 1–5, 15–30 en 6–20.
const REQUIRED_VEHICLES_MIN: Array[int] = [8, 8, 8, 8, 8, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15]
const REQUIRED_VEHICLES_MAX: Array[int] = [15, 15, 15, 15, 15, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30]
## GDD §3 : niveau d'apparition de chaque véhicule.
const UNLOCK_LEVEL: Dictionary[String, int] = {"taxi": 1, "car_rapide": 1, "clando": 6, "ndiaga_ndiaye": 10}

var _catalog: VehicleCatalog


func before_all() -> void:
	_catalog = VehicleCatalog.load_default()


func _level(index: int) -> LevelData:
	return LevelLoader.load_file(LevelCatalog.level_paths()[index], _catalog).level


func test_catalog_lists_every_level() -> void:
	assert_eq(LevelCatalog.level_paths().size(), LEVEL_COUNT)


func test_every_listed_level_passes_the_checker() -> void:
	for path: String in LevelCatalog.level_paths():
		var errors: PackedStringArray = LevelChecker.check_file(path, _catalog)
		assert_eq(errors.size(), 0, "%s : %s" % [path, errors])


func test_levels_follow_difficulty_plan() -> void:
	for index: int in LEVEL_COUNT:
		var level: LevelData = _level(index)
		var result: SolverResult = Solver.solve(level, level.slots)
		var dests: int = level.passengers_by_dest().size()
		var label: String = "Niveau %d" % (index + 1)
		assert_eq(level.id, index + 1, label)
		assert_eq(level.slots, 4, label)
		assert_between(result.min_margin, REQUIRED_MARGIN_MIN[index], REQUIRED_MARGIN_MAX[index], label + " marge")
		assert_between(dests, REQUIRED_DESTS_MIN[index], REQUIRED_DESTS_MAX[index], label + " destinations")
		assert_between(level.vehicles.size(), REQUIRED_VEHICLES_MIN[index], REQUIRED_VEHICLES_MAX[index], label + " véhicules")


func test_vehicles_respect_gdd_unlock_levels() -> void:
	for index: int in LEVEL_COUNT:
		for vehicle: LevelVehicle in _level(index).vehicles:
			assert_true(UNLOCK_LEVEL.has(vehicle.type_name), vehicle.type_name)
			var unlock: int = UNLOCK_LEVEL.get(vehicle.type_name, LEVEL_COUNT + 1)
			assert_true(unlock <= index + 1, "Niveau %d : %s trop tôt" % [index + 1, vehicle.type_name])


func test_solution_of_every_level_wins_through_game_rules() -> void:
	for index: int in LEVEL_COUNT:
		var level: LevelData = _level(index)
		var rules: GameRules = GameRules.new(level)
		for vehicle_id: int in Solver.solve(level, level.slots).solution:
			rules.tap(vehicle_id)
		assert_eq(rules.status, GameRules.Status.WON, "Niveau %d" % (index + 1))


func test_naive_play_loses_from_level_four() -> void:
	for number: int in range(NAIVE_LOSES_FROM, LEVEL_COUNT + 1):
		assert_false(Solver.naive_play(_level(number - 1)), "Niveau %d gagné au jeu naïf" % number)


func test_jam_has_real_dependencies_from_level_three() -> void:
	for index: int in range(2, LEVEL_COUNT):
		var level: LevelData = _level(index)
		var board: BoardLogic = BoardLogic.new(level)
		var blocked: int = 0
		for vehicle: LevelVehicle in level.vehicles:
			if not board.can_exit(vehicle.id):
				blocked += 1
		assert_gt(blocked * 3, level.vehicles.size(), "Niveau %d : trop peu de blocage (%d)" % [index + 1, blocked])


func _load_level(number: int) -> LevelData:
	var loaded: LevelLoadResult = LevelLoader.load_file(LevelCatalog.level_paths()[number - 1], VehicleCatalog.load_default())
	return loaded.level


## Le tutoriel force ce coup : il ne doit pas rendre le niveau ingagnable.
func test_coxeur_tutorial_keeps_level_3_winnable_without_booster() -> void:
	var rules: GameRules = GameRules.new(_load_level(3), BoosterAccess.new(true))
	rules.use_coxeur(rules.tutorial_vehicle())
	assert_true(BoosterSolver.can_still_win(rules, 0))


func test_apprenti_tutorial_keeps_level_8_winnable_after_any_first_vehicle() -> void:
	var level: LevelData = _load_level(8)
	for id: int in GameRules.new(level).free_vehicles():
		var rules: GameRules = GameRules.new(level, BoosterAccess.new(true))
		rules.tap(id)
		if rules.can_use_apprenti():
			rules.use_apprenti()
			assert_true(BoosterSolver.can_still_win(rules, 1), "Véhicule %d" % id)
