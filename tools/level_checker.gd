class_name LevelChecker
extends RefCounted
## Validation d'un fichier de niveau : chargement, cohérence, solvabilité.

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
