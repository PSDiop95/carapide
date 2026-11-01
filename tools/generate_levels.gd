extends SceneTree
## Régénère data/levels/ : godot --headless -s res://tools/generate_levels.gd
## Déterministe : même seed, mêmes niveaux.
## Les niveaux livrés sont retouchés à la main : régénérer les écrase, d'où `-- --overwrite`.

const LEVELS_DIR: String = "res://data/levels/"
const ATTEMPTS_PER_LEVEL: int = 200


func _init() -> void:
	if not OS.get_cmdline_user_args().has("--overwrite"):
		printerr("Refus : niveaux retouchés à la main. Relancer avec -- --overwrite pour les écraser.")
		quit(1)
		return
	var catalog: VehicleCatalog = VehicleCatalog.load_default()
	var order: Array[String] = []
	var failures: int = 0
	for spec: LevelSpec in LevelPlan.all():
		var raw: Dictionary = _generate_one(spec, catalog)
		if raw.is_empty():
			printerr("Niveau %d : échec de génération" % spec.id)
			failures += 1
			continue
		var file_name: String = "level_%02d.json" % spec.id
		_write(LEVELS_DIR + file_name, JSON.stringify(raw, "  "))
		order.append(file_name)
		print("Niveau %d généré" % spec.id)
	if failures == 0:
		_write(LevelCatalog.CONFIG_PATH, JSON.stringify({"order": order}, "  ") + "\n")
	quit(1 if failures > 0 else 0)


func _generate_one(spec: LevelSpec, catalog: VehicleCatalog) -> Dictionary:
	for attempt: int in ATTEMPTS_PER_LEVEL:
		var generator: LevelGenerator = LevelGenerator.new(catalog, LevelPlan.SEED + spec.id * 1000 + attempt)
		var raw: Dictionary = generator.generate(spec)
		if not raw.is_empty():
			return raw
	return {}


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
