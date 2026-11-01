class_name Features
extends RefCounted
## Drapeaux de data/config/features.json. L'écran de playtest peut les forcer sur ce téléphone.

const PATH: String = "res://data/config/features.json"
const BOOSTERS_KEY: String = "boosters_enabled"
const SAVE_BOOSTERS_KEY: String = "feature_boosters"
const NOT_FORCED: int = -1


static func boosters_enabled(save: SaveService) -> bool:
	var forced: int = save.get_int(SAVE_BOOSTERS_KEY, NOT_FORCED)
	return _default_boosters() if forced == NOT_FORCED else forced == 1


static func force_boosters(save: SaveService, enabled: bool) -> void:
	save.set_int(SAVE_BOOSTERS_KEY, 1 if enabled else 0)


static func _default_boosters() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		var flags: Dictionary = parsed
		var enabled: bool = flags.get(BOOSTERS_KEY, false)
		return enabled
	push_error("Configuration illisible : %s" % PATH)
	return false
