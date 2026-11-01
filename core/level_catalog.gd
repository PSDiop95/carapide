class_name LevelCatalog
extends RefCounted
## Ordre des niveaux (data/config/levels.json).

const CONFIG_PATH: String = "res://data/config/levels.json"
const LEVELS_DIR: String = "res://data/levels/"


static func level_paths() -> PackedStringArray:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	var paths: PackedStringArray = PackedStringArray()
	if not parsed is Dictionary:
		push_error("Configuration illisible : %s" % CONFIG_PATH)
		return paths
	var config: Dictionary = parsed
	var files: Array = config["order"]
	for file_name: String in files:
		paths.append(LEVELS_DIR + file_name)
	return paths
