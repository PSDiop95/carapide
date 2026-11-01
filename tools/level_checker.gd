class_name LevelChecker
extends RefCounted
## Validation d'un fichier de niveau : chargement, cohérence, solvabilité.

## Part de parties gagnées par un joueur simulé, tapant au hasard parmi les véhicules libres.
## `head_first` : préfère un véhicule de la destination en tête de file. Seed injectée.
static func bot_win_rate(level: LevelData, head_first: bool, rounds: int, seed_value: int) -> float:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var wins: int = 0
	for _round: int in rounds:
		var rules: GameRules = GameRules.new(level)
		while rules.status == GameRules.Status.PLAYING:
			var pool: PackedInt32Array = _bot_choices(rules, level, head_first)
			if pool.is_empty():
				break
			rules.tap(pool[rng.randi_range(0, pool.size() - 1)])
		if rules.status == GameRules.Status.WON:
			wins += 1
	return float(wins) / float(rounds)


static func _bot_choices(rules: GameRules, level: LevelData, head_first: bool) -> PackedInt32Array:
	var free: PackedInt32Array = rules.free_vehicles()
	if not head_first:
		return free
	var matching: PackedInt32Array = PackedInt32Array()
	for id: int in free:
		if level.vehicles[id].dest == rules.head_dest():
			matching.append(id)
	return free if matching.is_empty() else matching


## Erreurs du fichier ; vide si le niveau est valide et soluble.
static func check_file(path: String, catalog: VehicleCatalog) -> PackedStringArray:
	var loaded: LevelLoadResult = LevelLoader.load_file(path, catalog)
	if not loaded.is_ok():
		return loaded.errors
	var result: SolverResult = Solver.solve(loaded.level, loaded.level.slots)
	var errors: PackedStringArray = PackedStringArray()
	if result.aborted:
		errors.append("%s : plafond du solveur atteint, solvabilité non prouvée" % path)
	elif not result.solvable:
		errors.append("%s : niveau insoluble avec %d places" % [path, loaded.level.slots])
	return errors
