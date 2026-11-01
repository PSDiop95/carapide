class_name PresentationConfig
extends RefCounted
## Valeurs ressenties de la présentation (data/config/). Aucune n'influence les règles.

const CONFIG_PATH: String = "res://data/config/presentation.json"
const DESTINATIONS_PATH: String = "res://data/config/destinations.json"

var camera_tilt_degrees: float = 0.0
var exit_duration: float = 0.0
var blocked_highlight_duration: float = 0.0
var bump_distance: float = 0.0
var bump_duration: float = 0.0
var boarding_rate: float = 1.0
var depart_duration: float = 0.0
var tap_tolerance: float = 0.0
var danger_warning_free_slots: int = 0
var danger_critical_free_slots: int = 0
var dest_colors: Dictionary[String, Color] = {}


static func load_default() -> PresentationConfig:
	var config: PresentationConfig = PresentationConfig.new()
	var raw: Dictionary = _read_dict(CONFIG_PATH)
	config.camera_tilt_degrees = raw["camera_tilt_degrees"]
	config.exit_duration = raw["exit_duration"]
	config.blocked_highlight_duration = raw["blocked_highlight_duration"]
	config.bump_distance = raw["bump_distance"]
	config.bump_duration = raw["bump_duration"]
	config.boarding_rate = raw["boarding_rate"]
	config.depart_duration = raw["depart_duration"]
	config.tap_tolerance = raw["tap_tolerance"]
	var warning: float = raw["danger_warning_free_slots"]
	var critical: float = raw["danger_critical_free_slots"]
	config.danger_warning_free_slots = int(warning)
	config.danger_critical_free_slots = int(critical)
	var colors: Dictionary = _read_dict(DESTINATIONS_PATH)
	for dest: String in colors:
		var html: String = colors[dest]
		config.dest_colors[dest] = Color.html(html)
	return config


func color_of(dest: String) -> Color:
	return dest_colors.get(dest, Color.GRAY)


static func _read_dict(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_error("Configuration illisible : %s" % path)
	return {}
