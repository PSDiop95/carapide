extends GutTest
## Tout niveau listé dans data/config/levels.json doit être valide et soluble.


func test_every_listed_level_passes_the_checker() -> void:
	var catalog: VehicleCatalog = VehicleCatalog.load_default()
	for path: String in LevelCatalog.level_paths():
		var errors: PackedStringArray = LevelChecker.check_file(path, catalog)
		assert_eq(errors.size(), 0, "%s : %s" % [path, errors])
	pass_test("Niveaux vérifiés")
