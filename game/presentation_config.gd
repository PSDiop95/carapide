class_name PresentationConfig
extends RefCounted
## Valeurs ressenties de la présentation (data/config/). Aucune n'influence les règles.

const CONFIG_PATH: String = "res://data/config/presentation.json"
const DESTINATIONS_PATH: String = "res://data/config/destinations.json"

var camera_tilt_degrees: float = 0.0
var exit_max_duration: float = 0.0
var exit_min_duration: float = 0.0
var exit_speed: float = 1.0
var blocked_highlight_duration: float = 0.0
var bump_distance: float = 0.0
var bump_duration: float = 0.0
var boarding_rate: float = 1.0
var depart_duration: float = 0.0
var tap_tolerance: float = 0.0
var danger_warning_free_slots: int = 0
var danger_critical_free_slots: int = 0
var danger_pulse_period: float = 1.0
var danger_vibration_ms: int = 0
var tap_move_threshold: float = 0.0
var zoom_max: float = 1.0
var zoom_wheel_step: float = 1.0
var queue_chip_count: int = 0
var queue_sign_count: int = 0
var coxeur_flight_duration: float = 0.0
var coxeur_arc_height: float = 0.0
var dioule_wave_duration: float = 0.0
var dioule_hop_duration: float = 0.0
var dioule_hop_height: float = 0.0
var garage_move_duration: float = 0.0
var garage_vehicle_scale: float = 1.0
var hub_queue_count: int = 0
var hub_queue_pitch: float = 1.0
var hub_queue_speed: float = 0.0
var hub_queue_phase: float = 0.0
var hub_queue_bob: float = 0.0
var victory_cheer_height: float = 0.0
var victory_cheer_speed: float = 0.0
var victory_cheer_swing: float = 0.0
var dest_colors: Dictionary[String, Color] = {}
var dest_pictos: Dictionary[String, String] = {}
var dest_name_keys: Dictionary[String, String] = {}


static func load_default() -> PresentationConfig:
	var config: PresentationConfig = PresentationConfig.new()
	var raw: Dictionary = _read_dict(CONFIG_PATH)
	config.camera_tilt_degrees = raw["camera_tilt_degrees"]
	config.exit_max_duration = raw["exit_max_duration"]
	config.exit_min_duration = raw["exit_min_duration"]
	config.exit_speed = raw["exit_speed"]
	config.blocked_highlight_duration = raw["blocked_highlight_duration"]
	config.bump_distance = raw["bump_distance"]
	config.bump_duration = raw["bump_duration"]
	config.boarding_rate = raw["boarding_rate"]
	config.depart_duration = raw["depart_duration"]
	config.tap_tolerance = raw["tap_tolerance"]
	config.danger_warning_free_slots = _read_int(raw, "danger_warning_free_slots")
	config.danger_critical_free_slots = _read_int(raw, "danger_critical_free_slots")
	config.danger_pulse_period = raw["danger_pulse_period"]
	config.danger_vibration_ms = _read_int(raw, "danger_vibration_ms")
	config.tap_move_threshold = raw["tap_move_threshold"]
	config.zoom_max = raw["zoom_max"]
	config.zoom_wheel_step = raw["zoom_wheel_step"]
	config.queue_chip_count = _read_int(raw, "queue_chip_count")
	config.queue_sign_count = _read_int(raw, "queue_sign_count")
	config.coxeur_flight_duration = raw["coxeur_flight_duration"]
	config.coxeur_arc_height = raw["coxeur_arc_height"]
	config.dioule_wave_duration = raw["dioule_wave_duration"]
	config.dioule_hop_duration = raw["dioule_hop_duration"]
	config.dioule_hop_height = raw["dioule_hop_height"]
	config.garage_move_duration = raw["garage_move_duration"]
	config.garage_vehicle_scale = raw["garage_vehicle_scale"]
	config.hub_queue_count = _read_int(raw, "hub_queue_count")
	config.hub_queue_pitch = raw["hub_queue_pitch"]
	config.hub_queue_speed = raw["hub_queue_speed"]
	config.hub_queue_phase = raw["hub_queue_phase"]
	config.hub_queue_bob = raw["hub_queue_bob"]
	config.victory_cheer_height = raw["victory_cheer_height"]
	config.victory_cheer_speed = raw["victory_cheer_speed"]
	config.victory_cheer_swing = raw["victory_cheer_swing"]
	config._load_destinations()
	return config


func _load_destinations() -> void:
	var destinations: Dictionary = _read_dict(DESTINATIONS_PATH)
	for dest: String in destinations:
		var entry: Dictionary = destinations[dest]
		var html: String = entry["color"]
		dest_colors[dest] = Color.html(html)
		dest_pictos[dest] = entry["picto"]
		dest_name_keys[dest] = entry["name_key"]


func color_of(dest: String) -> Color:
	return dest_colors.get(dest, Color.GRAY)


func picto_of(dest: String) -> String:
	return dest_pictos.get(dest, PictoShapes.NAMES[0])


func name_key_of(dest: String) -> String:
	return dest_name_keys.get(dest, dest)


static func _read_int(raw: Dictionary, key: String) -> int:
	var value: float = raw[key]
	return int(value)


static func _read_dict(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_error("Configuration illisible : %s" % path)
	return {}
