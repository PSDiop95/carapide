extends SceneTree
## Valide tous les niveaux : godot --headless -s res://tools/validate_levels.gd
## Code retour non nul si un niveau est invalide ou insoluble.

const BOT_ROUNDS: int = 400
const BOT_SEED: int = 11


func _init() -> void:
	var catalog: VehicleCatalog = VehicleCatalog.load_default()
	var failures: int = 0
	for path: String in LevelCatalog.level_paths():
		var errors: PackedStringArray = LevelChecker.check_file(path, catalog)
		failures += errors.size()
		for message: String in errors:
			printerr(message)
		if errors.is_empty():
			print(_summary(path, catalog))
	print("Erreurs : %d" % failures)
	quit(1 if failures > 0 else 0)


func _summary(path: String, catalog: VehicleCatalog) -> String:
	var level: LevelData = LevelLoader.load_file(path, catalog).level
	var result: SolverResult = Solver.solve(level, level.slots)
	var dests: int = level.passengers_by_dest().size()
	var random_rate: float = LevelChecker.bot_win_rate(level, false, BOT_ROUNDS, BOT_SEED) * 100.0
	var head_rate: float = LevelChecker.bot_win_rate(level, true, BOT_ROUNDS, BOT_SEED) * 100.0
	var naive: String = "gagne" if Solver.naive_play(level) else "perd"
	return "%s : %d véhicules, %d destinations, marge %d, %d nœuds, naïf %s, hasard %d %%, tête d'abord %d %%, boosters min %s" % [path, level.vehicles.size(), dests, result.min_margin, result.nodes_explored, naive, int(random_rate), int(head_rate), _boosters_needed(level, result.min_slots)]


## Marge sans booster à part : ici, boosters minimum à places réelles, puis une place sous le minimum.
func _boosters_needed(level: LevelData, min_slots: int) -> String:
	var at_slots: BoosterSolveResult = BoosterSolver.boosters_needed_min(level, level.slots)
	var tight_slots: int = maxi(min_slots - 1, 1)
	var tight: BoosterSolveResult = BoosterSolver.boosters_needed_min(level, tight_slots)
	return "%s (à %d places : %s)" % [_needed_text(at_slots), tight_slots, _needed_text(tight)]


func _needed_text(result: BoosterSolveResult) -> String:
	if result.aborted:
		return "plafond"
	return "> %d" % BoosterSolver.DEFAULT_MAX_BOOSTERS if result.needed_min == BoosterSolveResult.UNKNOWN else str(result.needed_min)
