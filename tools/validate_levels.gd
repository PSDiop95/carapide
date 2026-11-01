extends SceneTree
## Valide tous les niveaux : godot --headless -s res://tools/validate_levels.gd
## Code retour non nul si un niveau est invalide ou insoluble.


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
	return "%s : %d véhicules, %d destinations, marge %d, %d nœuds" % [path, level.vehicles.size(), dests, result.min_margin, result.nodes_explored]
